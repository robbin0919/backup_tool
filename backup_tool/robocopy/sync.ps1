<#
.SYNOPSIS
    提供一個可使用方向鍵操作的選單介面，使用 Robocopy 同步預先設定好的多組目錄。

.DESCRIPTION
    這個 PowerShell 腳本透過讀取使用者按鍵，實現了可用方向鍵 (上/下) 選擇、Enter 鍵執行的互動式選單。
    使用者可以預先設定多組來源與目標目錄，並在執行時透過光棒選單來選擇要同步的任務。

.NOTES
    作者: Gemini
    日期: 2025-12-19
    版本: 3.0

.WARNING
    腳本中的 /MIR 參數會刪除目標目錄中有，但來源目錄沒有的檔案與資料夾。
    在執行前請再三確認 `$SyncTasks` 中的路徑設定正確，以避免重要資料遺失。
#>

#----------------------------------------------------------------------
# 1. 設定區：請在此處新增或修改您的同步路徑
#----------------------------------------------------------------------
$SyncTasks = @(
    [PSCustomObject]@{
        Name        = "範例 1: 我的文件"
        Source      = "C:\Users\YourUser\Documents"
        Destination = "D:\Backup\Documents"
    },
    [PSCustomObject]@{
        Name        = "範例 2: 專案檔案"
        Source      = "C:\Projects"
        Destination = "D:\Backup\Projects"
    },
    [PSCustomObject]@{
        Name        = "範例 3: 照片"
        Source      = "C:\Users\YourUser\Pictures"
        Destination = "E:\Backup\Pictures"
    }
)

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
    Write-Host "使用 [↑] [↓] 方向鍵選擇，按下 [Enter] 執行，[Q] 退出。`n"

    for ($i = 0; $i -lt $MenuItems.Count; $i++) {
        $item = $MenuItems[$i]
        
        # 根據是否為當前選中項來設定顯示顏色
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
                # 遍歷原始的 SyncTasks，排除 "ALL" 和 "QUIT"
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
