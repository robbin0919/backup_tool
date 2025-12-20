# Robocopy 參數說明文件

這是 `sync_config.json` 中 `robocopyOptions` 可用參數的說明文件。

| 參數 (Key)              | Robocopy 命令 | 類型 (Type) | 說明                                                                                   |
| ----------------------- | ------------- | ----------- | -------------------------------------------------------------------------------------- |
| `mirror`                | `/MIR`        | `boolean`   | **鏡像同步**。此選項會讓目標目錄與來源目錄完全一致，會刪除目標端多餘的檔案。         |
| `copyDirectoryTimestamps` | `/DCOPY:T`    | `boolean`   | **複製目錄時間戳**。                                                                   |
| `retryCount`            | `/R:n`        | `integer`   | **重試次數**。設定檔案複製失敗後的重試次數 `n`。                                       |
| `retryWaitTime`         | `/W:n`        | `integer`   | **重試等待時間**。設定每次重試之間要等待 `n` 秒。                                      |
| `logPath`               | `/LOG+:path`  | `string`    | **日誌路徑**。指定存放日誌的目錄，腳本會自動產生檔名。                                 |
| `logTee`                | `boolean`   | **螢幕與日誌同時輸出**。將狀態同時顯示在主控台視窗與日誌檔案中。                     |
| `listOnly`              | `/L`          | `boolean`   | **(強制性)** **僅列出**。`true` 為模擬執行，`false` 為實際執行。此為安全開關，避免意外操作。 |
| `extraArgs`             | (多樣)        | `array`     | **額外參數**。一個包含額外 Robocopy 參數的字串陣列。詳見下方說明。                 |

---

### `extraArgs` 詳細說明
`extraArgs` 允許您傳遞腳本未直接提供的任何 Robocopy 參數。這是一個字串陣列，其中參數與其值（如果有的話）應該是分開的陣列元素。

以下是一些常用參數範例：

| 參數        | 說明                                       | `sync_config.json` 中的 `extraArgs` 範例                               |
| :---------- | :----------------------------------------- | :------------------------------------------------------------------- |
| `/XF [檔案]`  | **排除檔案** (Exclude File)。可使用萬用字元 `*`。 | `["/XF", "*.tmp", "*.log"]`                                           |
| `/XD [目錄]`  | **排除目錄** (Exclude Directory)。可使用萬用字元 `*`。 | `["/XD", "temp", "node_modules", "obj"]`                             |
| `/MAXAGE:n` | **最長檔案存留時間**。排除比 `n` 天更早的檔案。 | `["/MAXAGE:30"]` (排除超過30天的舊檔案)                            |
| `/MINAGE:n` | **最短檔案存留時間**。排除比 `n` 天更新的檔案。 | `["/MINAGE:2"]` (排除2天內的新檔案，常用於穩定備份)              |
| `/COPY:flag`| **指定要複製的檔案內容**。預設為 `/COPY:DAT` (D=資料, A=屬性, T=時間戳)。 | `["/COPY:DATSOU"]` (S=安全性=NTFS ACLs, O=擁有者資訊, U=稽核資訊) |
| `/SEC`      | **複製安全性設定**。等同於 `/COPY:DATS`。    | `["/SEC"]`                                                           |
| `/NJH`      | **無作業標頭** (No Job Header)。不在日誌中輸出 Robocopy 作業標頭。 | `["/NJH"]`                                                           |
| `/NJS`      | **無作業摘要** (No Job Summary)。不在日誌中輸出作業結束時的摘要。 | `["/NJS"]`                                                           |

**組合範例**：

若要排除所有 `.log` 檔案以及 `temp` 目錄，並複製 NTFS 安全性設定，您的 `extraArgs` 會是：

```json
"extraArgs": [
  "/XF",
  "*.log",
  "/XD",
  "temp",
  "/SEC"
]
```

---

### 進階應用範例

#### 範例：移動超過 7 天的舊檔案進行封存

**情境**：您希望將 `C:\Source` 目錄（包含所有子目錄）中，最後修改時間超過 7 天的所有檔案，移動到 `D:\Archive` 目錄下進行封存。

**`sync_config.json` 設定**：

在 `tasks` 陣列中新增一個任務，如下所示：

```json
{
  "Name": "封存舊檔案",
  "Source": "C:\\Source",
  "Destination": "D:\\Archive",
  "robocopyOptions": {
    "listOnly": false,
    "logPath": "./robocopy_logs/",
    "logTee": true,
    "extraArgs": [
      "/E",
      "/MOV",
      "/MINAGE:7"
    ]
  }
}
```

**設定解析**：

- `"listOnly": false`：設定為 `false` 表示這是一個**實際執行**的任務。若設為 `true`，則只會模擬並列出將被移動的檔案。
- `"mirror": false`：我們**沒有**設定 `mirror: true`，因為我們不想讓來源和目標完全同步，我們只想「移動」符合條件的檔案。
- `extraArgs` 是此操作的核心：
  - `"/E"`：表示複製所有子目錄，包括空的子目錄。確保了來源的目錄結構在目標端被重建。
  - `"/MOV"`：**移動**檔案。Robocopy 會在成功複製檔案到目標後，從**來源**刪除該檔案。
  - `"/MINAGE:7"`：這是篩選條件，只選取**最小存留時間**為 7 天的檔案，也就是最後修改時間在 7 天前的檔案。

透過這個設定，您可以輕鬆地建立一個自動化的檔案封存任務。
**強烈建議**：在正式執行前，可以先將 `listOnly` 設為 `true` 來預覽 Robocopy 將會移動哪些檔案，以確保設定正確無誤。

---

#### 範例：單向同步 (讓目錄B與目錄A保持一致)

**情境**：這是 Robocopy 最常見的用途，也就是建立一個從來源「目錄A」到目標「目錄B」的單向備份。您希望目錄B的內容隨時與目錄A保持完全一致。

**`sync_config.json` 設定**：

```json
{
  "Name": "同步A到B",
  "Source": "C:\\Path\\To\\DirectoryA",
  "Destination": "D:\\Backups\\DirectoryA_Backup",
  "robocopyOptions": {
    "listOnly": false,
    "mirror": true,
    "retryCount": 5,
    "retryWaitTime": 10,
    "logPath": "./robocopy_logs/",
    "logTee": true
  }
}
```

**設定解析**：

- `"listOnly": false`：設定為 `false` 表示這是一個**實際執行**的備份任務。
- `"mirror": true`：這是此操作的核心，代表「鏡像」同步。它會執行以下操作：
    1.  **複製**：將 A 中所有 B 沒有的檔案和目錄複製到 B。
    2.  **更新**：如果 A 中的檔案比 B 中的新，則更新 B 中的檔案。
    3.  **刪除**：將 B 中存在但 A 中已不存在的檔案和目錄**刪除**。
- `retryCount` 和 `retryWaitTime`：增加了備份的可靠性，如果因為網路問題或檔案被鎖定而複製失敗，腳本會自動重試。

**注意**：`mirror` 參數非常強大且高效，但它會**刪除目標目錄的檔案**以維持同步。請確保您了解此行為，且目標目錄的路徑設定正確。

---

#### 範例：實現雙向同步 (目錄A與目錄B互相同步)

**重要觀念**：Robocopy 本身是一個**單向**同步工具。它總是將「來源」的變更同步到「目標」。因此，無法用一個命令實現雙向同步。

要實現雙向同步，我們需要執行**兩次**鏡像操作：
1.  將 A 的變更同步到 B。
2.  將 B 的變更同步到 A。

這需要在 `sync_config.json` 中設定**兩個獨立的任務**。

**`sync_config.json` 設定**：

```json
{
  "Name": "雙向同步：A -> B",
  "Source": "C:\\Path\\To\\DirectoryA",
  "Destination": "C:\\Path\\To\\DirectoryB",
  "robocopyOptions": {
    "listOnly": false,
    "mirror": true,
    "logPath": "./robocopy_logs/",
    "logTee": true
  }
},
{
  "Name": "雙向同步：B -> A",
  "Source": "C:\\Path\\To\\DirectoryB",
  "Destination": "C:\\Path\\To\\DirectoryA",
  "robocopyOptions": {
    "listOnly": false,
    "mirror": true,
    "logPath": "./robocopy_logs/",
    "logTee": true
  }
}
```

**設定解析**：

- **兩個任務**：我們定義了兩個任務，一個從 A 到 B，另一個從 B 到 A。當您在腳本選單中選擇「全部執行」時，它會依序執行這兩個任務，從而完成一次完整的雙向同步。
- `"mirror": true`：這是實現同步的核心。它會讓目標目錄變得與來源目錄完全相同。
  - 在第一個任務中，A 的新增和修改會被複製到 B，且 B 中有但 A 中沒有的檔案會被**刪除**。
  - 在第二個任務中，B 的新增和修改會被複製到 A，且 A 中有但 B 中沒有的檔案會被**刪除**。

**🚨 警告：使用 `/MIR` 進行雙向同步具有高風險！**

- **檔案刪除**：如果在執行同步前，您在 A 目錄刪除了一個檔案，該檔案也會在 B 目錄被刪除。反之亦然。如果您在兩邊都意外刪除了不同的檔案，同步後這些檔案將會**永久消失**。
- **無版本控制**：Robocopy 不會保留檔案的歷史版本。一旦檔案被覆蓋或刪除，就無法輕易復原。

在設定此類雙向同步任務前，請務必**備份您的重要資料**，並充分了解 `/MIR` 參數的行為。

---

### 使用網路路徑 (UNC 路徑)

本工具完全支援使用網路分享路徑 (UNC, Universal Naming Convention) 作為來源或目標。

設定時唯一要注意的是 JSON 的語法要求。在 JSON 字串中，反斜線 `\` 是一個特殊逸出字元。因此，您必須使用**兩個反斜線 `\\`** 來表示一個實際的反斜線。

**格式**：`\\\\伺服器名稱\\分享資料夾名稱\\路徑`

#### 範例：從網路伺服器備份到本機

**情境**：您希望將網路上 `FileServer` 伺服器中 `SharedDocs` 分享資料夾的內容，單向同步到本機的 `D:\Backup\SharedDocs`。

**`sync_config.json` 設定**：

```json
{
  "Name": "從檔案伺服器備份",
  "Source": "\\\\FileServer\\SharedDocs",
  "Destination": "D:\\Backup\\SharedDocs",
  "robocopyOptions": {
    "listOnly": false,
    "mirror": true,
    "logPath": "./robocopy_logs/",
    "logTee": true,
    "extraArgs": [
      "/R:3",
      "/W:5"
    ]
  }
}
```

**設定解析**：

- **`"Source": "\\\\FileServer\\SharedDocs"`**：這是正確的 UNC 路徑格式。`\\` 被 JSON 解析為一個 `\`，所以 PowerShell 腳本最終會正確地讀取到 `\\FileServer\SharedDocs`。
- **權限**：請確保執行此 PowerShell 腳本的使用者帳戶具有讀取來源網路路徑和寫入目標路徑的權限。如果沒有，Robocopy 將會因為權限不足而失敗。
