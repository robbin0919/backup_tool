# --- 1. 設定 ---
# 要處理的目標目錄 (包含子目錄)
$targetDir = "C:\目錄B"

# 壓縮檔案要存放的位置
$archiveStorageDir = "C:\Archives"

# 檔案被視為「舊檔案」的天數
$daysToKeep = 14

# --- 腳本核心邏輯 (一般情況下無需修改) ---

# 建立壓縮檔的完整路徑，檔名包含當前日期
$archiveFileName = "Archive-$(Get-Date -Format 'yyyy-MM-dd').zip"
$archiveFullPath = Join-Path $archiveStorageDir $archiveFileName

# 確保壓縮檔儲存目錄存在
if (-not (Test-Path $archiveStorageDir)) {
    Write-Host "壓縮檔儲存目錄不存在，正在建立: $archiveStorageDir" -ForegroundColor Yellow
    New-Item -Path $archiveStorageDir -ItemType Directory | Out-Null
}

# --- 2. 尋找與篩選檔案 ---
Write-Host "正在 '$targetDir' 中尋找修改時間超過 $daysToKeep 天的檔案..."
$cutoffDate = (Get-Date).AddDays(-$daysToKeep)
$filesToArchive = Get-ChildItem -Path $targetDir -Recurse -File | Where-Object { $_.LastWriteTime -lt $cutoffDate }

# 如果沒有找到任何符合條件的檔案，則結束腳本
if (-not $filesToArchive) {
    Write-Host "沒有找到任何符合條件的舊檔案。" -ForegroundColor Green
    exit
}

Write-Host "找到了 $($filesToArchive.Count) 個要處理的檔案。"

# --- 3. 壓縮與刪除 ---
try {
    Write-Host "正在將檔案壓縮至: $archiveFullPath"
    
    # 將所有找到的檔案路徑傳給 Compress-Archive
    # 使用 -Force 可以在當天重複執行時覆蓋舊的壓縮檔
    Compress-Archive -Path $filesToArchive.FullName -DestinationPath $archiveFullPath -Force
    
    Write-Host "壓縮成功！" -ForegroundColor Green
    
    # --- 刪除原始檔案 ---
    Write-Host "正在刪除已被壓縮的原始檔案..."
    $filesToArchive | ForEach-Object {
        $filePath = $_.FullName
        Write-Host " - 正在刪除: $filePath"
        Remove-Item -Path $filePath -Force
    }
    
    Write-Host "原始檔案已全數刪除，成功釋出空間。" -ForegroundColor Green
}
catch {
    # 如果壓縮或刪除過程中發生任何錯誤
    Write-Host "處理過程中發生嚴重錯誤！" -ForegroundColor Red
    Write-Host "錯誤訊息: $($_.Exception.Message)"
    Write-Host "為安全起見，尚未刪除任何檔案。"
}

Write-Host "腳本執行完畢。"
