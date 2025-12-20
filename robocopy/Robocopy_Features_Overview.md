# Robocopy 功能完整概覽

Robocopy (Robust File Copy) 是 Windows 內建的一個功能強大且用途廣泛的命令列工具，遠不止是簡單的檔案複製。它的設計初衷是為了進行可靠、高效的檔案同步與備份。

除了我們在 `sync_config.json` 中使用的基本同步功能外，Robocopy 還提供了大量進階選項，可滿足各種複雜的檔案管理需求。

---

### 1. 進階複製控制 (Advanced Copying Control)

Robocopy 提供了對檔案複製過程的精細控制。

- **備份模式 (`/B`, `/ZB`)**:
  - `/B` (Backup mode): 使用備份權限來複製檔案，允許 Robocopy 複製當前使用者可能沒有權限存取的檔案。
  - `/ZB` (Restartable + Backup mode): 結合了可重新啟動模式與備份模式。在一般模式下複製，若遇到權限問題，則自動切換到備份模式。這是備份系統檔案或他人檔案時的推薦選項。

- **可重新啟動模式 (`/Z`)**:
  在複製大型檔案時，如果網路中斷或複製過程被中斷，此模式可讓 Robocopy 從中斷點繼續複製，而非從頭開始。

- **精細的檔案與目錄篩選**:
  - `/XF [檔案]`：排除 (eXclude File) 符合指定名稱/路徑/萬用字元的檔案。
  - `/XD [目錄]`：排除 (eXclude Directory) 符合指定名稱/路徑/萬用字元的目錄。
  - `/IF [檔案]`：包含 (Include File) 僅複製符合指定條件的檔案。
  - `/IA:[RASHCNETO]`：包含 (Include Attributes) 僅複製具有指定屬性的檔案 (例如 `/IA:R` 只複製唯讀檔案)。
  - `/XA:[RASHCNETO]`：排除 (eXclude Attributes) 排除具有指定屬性的檔案。

---

### 2. 目錄管理與同步 (Directory Management & Synchronization)

這些是 Robocopy 最強大的功能之一，但也需要謹慎使用。

- **鏡像模式 (`/MIR`)**:
  `robocopy C:\Source D:\Dest /MIR`
  此模式會讓目標目錄 `D:\Dest` 的結構與檔案**完全等同於**來源目錄 `C:\Source`。這意味著：
  - 來源端有的，目標端沒有 -> 複製過去。
  - 來源端與目標端都有 -> 如果檔案不同，則更新目標端。
  - **來源端沒有，但目標端有 -> 從目標端刪除！** (這是此模式最具風險但也最高效的地方)。

- **移動檔案或目錄 (`/MOV`, `/MOVE`)**:
  - `/MOV`: 複製檔案後，從**來源端刪除檔案** (不刪除目錄)。
  - `/MOVE`: 複製檔案與目錄後，從**來源端刪除檔案與目錄**。

- **清除模式 (`/PURGE`)**:
  此參數等同於 `/MIR` 中刪除目標端多餘檔案的功能，但它不會複製任何新檔案。`robocopy C:\Source D:\Dest /PURGE` 會刪除 `D:\Dest` 中所有不存在於 `C:\Source` 的檔案與目錄。

---

### 3. 紀錄與監控 (Logging & Monitoring)

Robocopy 提供了詳盡的日誌功能，便於追蹤與稽核。

- **僅列出模式 (`/L`)**:
  `robocopy C:\Source D:\Dest /L`
  模擬複製過程，但**不實際執行**任何檔案複製、刪除或修改。這是一個絕佳的「預演」工具，可以在執行真正的同步前，檢查 Robocopy 將會做什麼。

- **詳細輸出 (`/V`)**:
  (Verbose) 產生包含所有被跳過檔案的詳細輸出。

- **進度與報告控制**:
  - `/ETA`：顯示複製檔案的預估完成時間 (Estimated Time of Arrival)。
  - `/NP`：(No Progress) 不顯示複製進度的百分比。
  - `/LOG:file`：將狀態輸出寫入日誌檔案 (覆蓋現有日誌)。
  - `/LOG+:file`：將狀態輸出**附加**到現有日誌檔案。
  - `/TEE`：同時在主控台視窗與日誌檔案中顯示輸出。

---

### 4. 效能與網路控制 (Performance & Network Control)

- **多執行緒複製 (`/MT:n`)**:
  `robocopy C:\Source D:\Dest /MT:8`
  使用 `n` 個執行緒進行複製，可以大幅提升在多核心 CPU 與高速儲存裝置上的複製速度。`n` 的值建議在 1 到 128 之間，預設為 8。

- **封包間距 (`/IPG:n`)**:
  (Inter-Packet Gap) 在傳輸封包之間插入 `n` 毫秒的延遲。此功能可用於在低速或不穩定的網路上釋放頻寬，避免 Robocopy 佔用所有網路資源。

- **作業檔案 (`/JOB`, `/SAVE`, `/QUIT`)**:
  - `/SAVE:JobName`：將當前使用的 Robocopy 指令與參數儲存到一個名為 `JobName.RCJ` 的作業檔案中。
  - `/JOB:JobName`：從作業檔案 `JobName.RCJ` 中讀取並執行參數。
  - `/QUIT`：僅執行 `/JOB` 指令來顯示作業檔案中的參數，而不實際執行複製。

---

### 總結

Robocopy 是一個非常靈活的工具。透過組合上述參數，您可以建立出符合各種情境的自動化備份、同步、遷移或檔案管理腳本。

在 `sync.ps1` 與 `sync_config.json` 的設計中，我們正是利用了它的一部分核心功能，並透過 JSON 設定檔讓這些功能變得易於管理與擴充。
