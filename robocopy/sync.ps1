<#
.SYNOPSIS
    提供一個可使用方向鍵操作的選單介面，使用 Robocopy 從外部 JSON 設定檔同步目錄。

.DESCRIPTION
    此腳本會讀取名為 sync_config.json 的外部設定檔來動態建立同步任務清單。
    使用者可以透過光棒選單選擇要執行的任務。
    Robocopy 的參數現在也由此 JSON 檔案設定。

.NOTES
    作者: Robbin Lee
    日期: 2025-12-21
    版本: 9.1

.WARNING
    腳本中的 /MIR 參數會刪除目標目錄中有，但來源目錄沒有的檔案與資料夾。
    在執行前請再三確認 `sync_config.json` 中的路徑設定正確，以避免重要資料遺失。
#>

#----------------------------------------------------------------------
# 1. 讀取與驗證 JSON 設定檔
#----------------------------------------------------------------------
$PSScriptRoot = Get-Location
$ConfigFilePath = Join-Path $PSScriptRoot "sync_config.json"
$Config = $null

# 讀取主要任務設定檔
if (-not (Test-Path $ConfigFilePath)) {
    Write-Host "[錯誤] 找不到任務設定檔: $ConfigFilePath" -ForegroundColor Red
    Read-Host "請按 Enter 鍵結束..."
    exit
}
try {
    $Config = Get-Content -Path $ConfigFilePath -Raw | ConvertFrom-Json
}
catch {
    Write-Host "[錯誤] 無法解析任務設定檔 $ConfigFilePath。" -ForegroundColor Red
    Write-Host "請檢查 JSON 格式: $($_.Exception.Message)" -ForegroundColor Yellow
    Read-Host "請按 Enter 鍵結束..."
    exit
}

$SyncTasks = $Config.tasks

if (-not $SyncTasks -or $SyncTasks.Count -eq 0) {
    Write-Host "[警告] 設定檔中找不到有效的同步任務 ('tasks' 陣列)。" -ForegroundColor Yellow
    Read-Host "請按 Enter 鍵結束..."
    exit
}


#----------------------------------------------------------------------
# 2. Robocopy 執行函式
#----------------------------------------------------------------------
function Start-RobocopySync {
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Task
    )

    Write-Host "------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host ">> 正在執行任務: $($Task.Name)" -ForegroundColor Cyan
    Write-Host "   - 來源: $($Task.Source)"
    Write-Host "   - 目標: $($Task.Destination)"
    Write-Host "------------------------------------------------------------`n"

    # 驗證來源與目標路徑
    if (-not (Test-Path -Path $Task.Source -PathType Container)) {
        Write-Host "[錯誤] 來源目錄不存在: $($Task.Source)`n" -ForegroundColor Red
        return
    }
    if (-not (Test-Path -Path $Task.Destination -PathType Container)) {
        Write-Host "[警告] 目標目錄不存在，將自動建立: $($Task.Destination)`n" -ForegroundColor Yellow
        New-Item -Path $Task.Destination -ItemType Directory | Out-Null
    }

    $TaskOptions = $Task.robocopyOptions
    $RobocopyArgs = @( $Task.Source, $Task.Destination )
    $LogFile = $null

    # 安全性檢查：強制要求 listOnly 參數必須存在
    if (-not ($TaskOptions.PSObject.Properties.Name -contains 'listOnly')) {
        Write-Host "[錯誤] 任務 '$($Task.Name)' 未設定 'listOnly' 參數。" -ForegroundColor Red
        Write-Host "       為防止意外操作，此為必填參數。" -ForegroundColor Red
        Write-Host "       請在 'robocopyOptions' 中加入 '\"listOnly\": true' (測試模式) 或 '\"listOnly\": false' (實際執行)。`n" -ForegroundColor Red
        return
    }

    # 根據選項建構 Robocopy 參數 (硬編碼邏輯)
    if ($TaskOptions.PSObject.Properties.Name -contains 'mirror' -and $TaskOptions.mirror -eq $true) { $RobocopyArgs += "/MIR" }
    if ($TaskOptions.PSObject.Properties.Name -contains 'copyDirectoryTimestamps' -and $TaskOptions.copyDirectoryTimestamps -eq $true) { $RobocopyArgs += "/DCOPY:T" }
    if ($TaskOptions.PSObject.Properties.Name -contains 'retryCount') { $RobocopyArgs += "/R:$($TaskOptions.retryCount)" }
    if ($TaskOptions.PSObject.Properties.Name -contains 'retryWaitTime') { $RobocopyArgs += "/W:$($TaskOptions.retryWaitTime)" }
    if ($TaskOptions.PSObject.Properties.Name -contains 'logTee' -and $TaskOptions.logTee -eq $true) { $RobocopyArgs += "/TEE" }
    if ($TaskOptions.listOnly -eq $true) { $RobocopyArgs += "/L" }

    # 處理日誌檔案路徑
    if ($TaskOptions.PSObject.Properties.Name -contains 'logPath' -and -not([string]::IsNullOrWhiteSpace($TaskOptions.logPath))) {
        $LogDirectory = Join-Path $PSScriptRoot $TaskOptions.logPath
        if (-not (Test-Path $LogDirectory)) {
            New-Item -Path $LogDirectory -ItemType Directory | Out-Null
        }
        $LogFile = Join-Path $LogDirectory "robocopy_log_$($Task.Name -replace '[^a-zA-Z0-9]', '_')_$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        $RobocopyArgs += "/LOG+:$LogFile"
    }
    
    # 添加額外參數
    if ($TaskOptions.PSObject.Properties.Name -contains 'extraArgs' -and $TaskOptions.extraArgs -and $TaskOptions.extraArgs.Count -gt 0) {
        $RobocopyArgs += $TaskOptions.extraArgs
    }


    Write-Host "[INFO] 使用 Robocopy 參數: $($RobocopyArgs -join ' ')" -ForegroundColor Gray
    
    # 執行 Robocopy
    try {
        Start-Process -FilePath "robocopy.exe" -ArgumentList $RobocopyArgs -Wait -NoNewWindow
        Write-Host "`n[成功] 任務 '$($Task.Name)' 完成。" -ForegroundColor Green
        if ($LogFile) { Write-Host "[INFO] 日誌記錄於 $LogFile" -ForegroundColor Green }
    }
    catch {
        Write-Host "`n[重大錯誤] 執行 Robocopy 時發生例外狀況。" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

#----------------------------------------------------------------------
# 3. 光棒選單核心邏輯
#----------------------------------------------------------------------
$CurrentIndex = 0
$MenuItems = @($SyncTasks) + 
             [PSCustomObject]@{ Name = "--- 全部同步 (Execute ALL) ---"; Source = "ALL"; Destination = "ALL" } +
             [PSCustomObject]@{ Name = "--- 退出 (Quit) ---"; Source = "QUIT"; Destination = "QUIT" }

function Show-Menu {
    Clear-Host
    Write-Host "================ Robocopy 同步選單 (v9.2) ================" -ForegroundColor Yellow
    Write-Host "任務設定: $ConfigFilePath" -ForegroundColor Gray
    Write-Host "使用 [↑] [↓] 方向鍵選擇，按下 [Enter] 執行，[Q] 退出。`n"

    for ($i = 0; $i -lt $MenuItems.Count; $i++) {
        $item = $MenuItems[$i]
        $bgColor = if ($i -eq $CurrentIndex) { [ConsoleColor]::White } else { $Host.UI.RawUI.BackgroundColor }
        $fgColor = if ($i -eq $CurrentIndex) { [ConsoleColor]::Black } else { $Host.UI.RawUI.ForegroundColor }
        $displayText = if ($item.Source -in @("ALL", "QUIT")) { "  $($item.Name)" } else { "  $($item.Name) `t($($item.Source) -> $($item.Destination))" }
        Write-Host $displayText -BackgroundColor $bgColor -ForegroundColor $fgColor
    }
}

# 主迴圈
do {
    Show-Menu
    $keyInfo = [Console]::ReadKey($true)

    switch ($keyInfo.Key) {
        "UpArrow"   { if ($CurrentIndex -gt 0) { $CurrentIndex-- } }
        "DownArrow" { if ($CurrentIndex -lt ($MenuItems.Count - 1)) { $CurrentIndex++ } }
        "Enter" {
            $selectedItem = $MenuItems[$CurrentIndex]
            Clear-Host

            if ($selectedItem.Source -eq "QUIT") {
                $choice = 'q'
            }
            elseif ($selectedItem.Source -eq "ALL") {
                Write-Host "`n[INFO] 即將執行所有同步任務...`n" -ForegroundColor Cyan
                foreach ($task in $SyncTasks) {
                    Start-RobocopySync -Task $task
                }
                Read-Host "`n所有任務已執行完畢。請按 Enter 返回選單..."
            }
            else {
                Start-RobocopySync -Task $selectedItem
                Read-Host "`n單一任務已完成。請按 Enter 返回選單..."
            }
        }
        "Q" { $choice = 'q' }
    }
} while ($choice -ne 'q')

Write-Host "`n腳本執行結束。" -ForegroundColor Yellow
