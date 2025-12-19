@ECHO OFF
SETLOCAL

REM =================================================================
REM Robocopy 目錄同步腳本
REM
REM 說明：
REM 這個腳本使用 Robocopy 工具，將一個來源目錄的完整內容
REM (包含所有子目錄與檔案) 同步到一個目標目錄。
REM
REM "同步" 的意思是：
REM   1. 來源目錄的新檔案會被複製到目標目錄。
REM   2. 來源目錄已變更的檔案會覆寫目標目錄的檔案。
REM   3. 來源目錄已刪除的檔案也會從目標目錄中刪除。
REM
REM 警告：
REM   /MIR 參數會刪除目標目錄中有，但來源目錄沒有的檔案，
REM   請在執行前確認路徑設定正確，以免資料遺失。
REM =================================================================

REM --- 請修改以下路徑 ---
SET "SourceDir=C:\Path\To\Your\Source\DirectoryA"
SET "DestinationDir=D:\Path\To\Your\Destination\DirectoryB"
SET "LogFile=robocopy_sync_log.txt"
REM --- 路徑設定結束 ---


ECHO.
ECHO [INFO] 開始進行目錄同步...
ECHO [INFO] 來源 (Source): %SourceDir%
ECHO [INFO] 目標 (Destination): %DestinationDir%
ECHO [INFO] 日誌 (Log): %LogFile%
ECHO.

REM 執行 Robocopy 命令
REM 參數說明：
REM   /MIR     :: 鏡像整個目錄樹 (Mirror a directory tree)，等同於 /E 和 /PURGE。
REM            - /E: 複製子目錄，包含空的。
REM            - /PURGE: 刪除來源目錄中不再存在的目標檔案/目錄。
REM   /DCOPY:T :: 複製目錄的時間戳記。
REM   /R:3     :: 失敗時的重試次數 (Retry)。
REM   /W:5     :: 每次重試之間的等待時間 (Wait)。
REM   /LOG:%LogFile% :: 將輸出狀態寫入日誌檔 (覆蓋舊檔)。
REM   /TEE     :: 同時輸出到主控台視窗與日誌檔。
robocopy "%SourceDir%" "%DestinationDir%" /MIR /DCOPY:T /R:3 /W:5 /LOG:%LogFile% /TEE

ECHO.
ECHO [SUCCESS] 同步作業完成。
ECHO [INFO] 詳細過程請參考日誌檔: %LogFile%
ECHO.

PAUSE
