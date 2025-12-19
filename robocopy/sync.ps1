<#
.SYNOPSIS
    提供一個可使用方向鍵操作的選單介面，使用 Robocopy 從外部 JSON 設定檔同步目錄。

.DESCRIPTION
    此腳本會讀取名為 sync_config.json 的外部設定檔來動態建立同步任務清單。
    使用者可以透過光棒選單選擇要執行的任務。

.NOTES
    作者: Gemini
    日期: 2025-12-19
    版本: 4.0

.WARNING
    腳本中的 /MIR 參數會刪除目標目錄中有，但來源目錄沒有的檔案與資料夾。
    在執行前請再三確認 `sync_config.json` 中的路徑設定正確，以避免重要資料遺失。
#>

#----------------------------------------------------------------------
# 1. 讀取與驗證 JSON 設定檔
#----------------------------------------------------------------------
$ConfigFilePath = Join-Path $PSScriptRoot "sync_config.json"
$SyncTasks = $null

# 檢查設定檔是否存在
if (-not (Test-Path $ConfigFilePath)) {
    Write-Host "[錯誤] 找不到設定檔: $ConfigFilePath" -ForegroundColor Red
    Write-Host "請確認 'sync_config.json' 與腳本位於同一個目錄下。" -ForegroundColor Yellow
    Read-Host "請按 Enter 鍵結束..."
    exit
}

# 嘗試讀取並解析 JSON
try {
    $SyncTasks = Get-Content -Path $ConfigFilePath -Raw | ConvertFrom-Json
}
catch {
    Write-Host "[錯誤] 無法解析設定檔 $ConfigFilePath。" -ForegroundColor Red
    Write-Host "請檢查 JSON 格式是否正確 (例如：雙引號、逗號、反斜線是否正確)。" -ForegroundColor Yellow
    Write-Host "錯誤訊息: $($_.Exception.Message)"
    Read-Host "請按 Enter 鍵結束..."
    exit
}

# 檢查解析後的任務是否為空
if (-not $SyncTasks -or $SyncTasks.Count -eq 0) {
    Write-Host "[警告] 設定檔為空，或不包含任何有效的同步任務。" -ForegroundColor Yellow
    Read-Host "請按 Enter 鍵結束..."
    exit
}


#----------------------------------------------------------------------
# 2. Robocopy 執行函式 (與前一版相同)
#----------------------------------------------------------------------
function Start-RobocopySync {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TaskName,

        [Parameter(Mandatory=$true)]
        [string]$SourcePath,

        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )

    Write-Host "------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host ">> 正在執行任務: $TaskName" -ForegroundColor Cyan
    Write-Host "   - 來源: $SourcePath"
    Write-Host "   - 目標: $DestinationPath"
    Write-Host "------------------------------------------------------------`n"

    if (-not (Test-Path -Path $SourcePath -PathType Container)) {
        Write-Host "[錯誤] 來源目錄不存在: $SourcePath`n" -ForegroundColor Red
        return
    }

    if (-not (Test-Path -Path $DestinationPath -PathType Container)) {
        Write-Host "[警告] 目標目錄不存在，將自動建立: $DestinationPath`n" -ForegroundColor Yellow
        New-Item -Path $DestinationPath -ItemType Directory | Out-Null
    }

    $LogFile = "robocopy_log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
    $RobocopyArgs = @( $SourcePath, $DestinationPath, "/MIR", "/DCOPY:T", "/R:3", "/W:5", "/LOG+:$LogFile", "/TEE" )

    try {
        Start-Process -FilePath "robocopy.exe" -ArgumentList $RobocopyArgs -Wait -NoNewWindow
        Write-Host "`n[成功] 任務 '$TaskName' 完成。日誌記錄於 $LogFile`n" -ForegroundColor Green
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
# 將所有同步任務和固定選項整合到一個選單陣列中
$MenuItems = @($SyncTasks) + 
             [PSCustomObject]@{ Name = "--- 全部同步 (Execute ALL) ---"; Source = "ALL"; Destination = "ALL" } +
             [PSCustomObject]@{ Name = "--- 退出 (Quit) ---"; Source = "QUIT"; Destination = "QUIT" }

function Show-Menu {
    Clear-Host
    Write-Host "================ Robocopy 同步選單 ================" -ForegroundColor Yellow
    Write-Host "設定檔: $ConfigFilePath" -ForegroundColor Gray
    Write-Host "使用 [↑] [↓] 方向鍵選擇，按下 [Enter] 執行，[Q] 退出。`n"

    for ($i = 0; $i -lt $MenuItems.Count; $i++) {
        $item = $MenuItems[$i]
        
        if ($i -eq $CurrentIndex) {
            $bgColor = [ConsoleColor]::White
            $fgColor = [ConsoleColor]::Black
        } else {
            $bgColor = $Host.UI.RawUI.BackgroundColor
            $fgColor = $Host.UI.RawUI.ForegroundColor
        }

        $displayText = if ($item.Source -in @("ALL", "QUIT")) {
            "  $($item.Name)"
        } else {
            "  $($item.Name) `t($($item.Source) -> $($item.Destination))"
        }
        
        Write-Host $displayText -BackgroundColor $bgColor -ForegroundColor $fgColor
    }
}

# 主迴圈：監聽按鍵並更新選單
do {
    Show-Menu
    $keyInfo = [Console]::ReadKey($true)

    switch ($keyInfo.Key) {
        "UpArrow" {
            if ($CurrentIndex -gt 0) { $CurrentIndex-- }
        }
        "DownArrow" {
            if ($CurrentIndex -lt ($MenuItems.Count - 1)) { $CurrentIndex++ }
        }
        "Enter" {
            $selectedItem = $MenuItems[$CurrentIndex]
            Clear-Host

            if ($selectedItem.Source -eq "QUIT") {
                $choice = 'q' # 觸發退出條件
            }
            elseif ($selectedItem.Source -eq "ALL") {
                Write-Host "`n[INFO] 即將執行所有同步任務...`n" -ForegroundColor Cyan
                foreach ($task in $SyncTasks) {
                    Start-RobocopySync -TaskName $task.Name -SourcePath $task.Source -DestinationPath $task.Destination
                }
                Read-Host "`n所有任務已執行完畢。請按 Enter 返回選單..."
            }
            else {
                Start-RobocopySync -TaskName $selectedItem.Name -SourcePath $selectedItem.Source -DestinationPath $selectedItem.Destination
                Read-Host "`n單一任務已完成。請按 Enter 返回選單..."
            }
        }
        "Q" {
            $choice = 'q'
        }
    }
} while ($choice -ne 'q')

Write-Host "`n腳本執行結束。" -ForegroundColor Yellow
