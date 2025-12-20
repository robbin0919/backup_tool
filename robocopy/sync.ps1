<#
.SYNOPSIS
    提供一個可使用方向鍵操作的選單介面，使用 Robocopy 從外部 JSON 設定檔同步目錄。

.DESCRIPTION
    此腳本會讀取名為 sync_config.json 的外部設定檔來動態建立同步任務清單。
    使用者可以透過光棒選單選擇要執行的任務。
    Robocopy 的參數現在也由此 JSON 檔案設定。

.NOTES
    作者: Gemini
    日期: 2025-12-20
    版本: 5.0

.WARNING
    腳本中的 /MIR 參數會刪除目標目錄中有，但來源目錄沒有的檔案與資料夾。
    在執行前請再三確認 `sync_config.json` 中的路徑設定正確，以避免重要資料遺失。
#>

#----------------------------------------------------------------------
# 1. 讀取與驗證 JSON 設定檔
#----------------------------------------------------------------------
$ConfigFilePath = Join-Path $PSScriptRoot "sync_config.json"
$Config = $null

if (-not (Test-Path $ConfigFilePath)) {
    Write-Host "[錯誤] 找不到設定檔: $ConfigFilePath" -ForegroundColor Red
    Read-Host "請按 Enter 鍵結束..."
    exit
}

try {
    $Config = Get-Content -Path $ConfigFilePath -Raw | ConvertFrom-Json
}
catch {
    Write-Host "[錯誤] 無法解析設定檔 $ConfigFilePath。" -ForegroundColor Red
    Write-Host "請檢查 JSON 格式: $($_.Exception.Message)" -ForegroundColor Yellow
    Read-Host "請按 Enter 鍵結束..."
    exit
}

# 從設定檔中分別取得全域設定與任務清單
$GlobalRobocopyOptions = $Config.robocopyOptions
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

    # 合併全域與任務特定的 Robocopy 選項
    $FinalOptions = $GlobalRobocopyOptions.psobject.Copy()
    if ($Task.PSObject.Properties.Name -contains 'overrideRobocopyOptions') {
        foreach ($prop in $Task.overrideRobocopyOptions.PSObject.Properties) {
            $FinalOptions.PSObject.Properties[$prop.Name].Value = $prop.Value
        }
    }

    # 根據選項建構 Robocopy 參數
    $RobocopyArgs = @( $Task.Source, $Task.Destination )
    if ($FinalOptions.mirror) { $RobocopyArgs += "/MIR" }
    if ($FinalOptions.copyDirectoryTimestamps) { $RobocopyArgs += "/DCOPY:T" }
    $RobocopyArgs += "/R:$($FinalOptions.retryCount)"
    $RobocopyArgs += "/W:$($FinalOptions.retryWaitTime)"
    if ($FinalOptions.logTee) { $RobocopyArgs += "/TEE" }
    
    # 處理日誌檔案路徑
    if (-not ([string]::IsNullOrWhiteSpace($FinalOptions.logPath))) {
        # 確保日誌目錄存在
        $LogDirectory = Join-Path $PSScriptRoot $FinalOptions.logPath
        if (-not (Test-Path $LogDirectory)) {
            New-Item -Path $LogDirectory -ItemType Directory | Out-Null
        }
        $LogFile = Join-Path $LogDirectory "robocopy_log_$($Task.Name -replace '[^a-zA-Z0-9]', '_')_$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        $RobocopyArgs += "/LOG+:$LogFile"
    }
    
    # 添加額外參數
    if ($FinalOptions.extraArgs) {
        $RobocopyArgs += $FinalOptions.extraArgs
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
# 3. 光棒選單核心邏輯 (與前一版類似，但傳遞整個任務物件)
#----------------------------------------------------------------------
$CurrentIndex = 0
$MenuItems = @($SyncTasks) + 
             [PSCustomObject]@{ Name = "--- 全部同步 (Execute ALL) ---"; Source = "ALL"; Destination = "ALL" } +
             [PSCustomObject]@{ Name = "--- 退出 (Quit) ---"; Source = "QUIT"; Destination = "QUIT" }

function Show-Menu {
    Clear-Host
    Write-Host "================ Robocopy 同步選單 (v5.0) ================" -ForegroundColor Yellow
    Write-Host "設定檔: $ConfigFilePath" -ForegroundColor Gray
    Write-Host "使用 [↑] [↓] 方向鍵選擇，按下 [Enter] 執行，[Q] 退出。`n"

    for ($i = 0; $i -lt $MenuItems.Count; $i++) {
        $item = $MenuItems[$i]
        
        $bgColor = if ($i -eq $CurrentIndex) { [ConsoleColor]::White } else { $Host.UI.RawUI.BackgroundColor }
        $fgColor = if ($i -eq $CurrentIndex) { [ConsoleColor]::Black } else { $Host.UI.RawUI.ForegroundColor }

        $displayText = if ($item.Source -in @("ALL", "QUIT")) {
            "  $($item.Name)"
        } else {
            "  $($item.Name) `t($($item.Source) -> $($item.Destination))"
        }
        
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
