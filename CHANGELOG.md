# MooshieUIplus｜版本與修正紀錄

> 本檔只記錄已實際開發的功能及已確認的問題。未通過測試、尚未修復的項目不得標示完成。

## 版本規則

- **MooshieUIplus 版本**：`MAJOR.MINOR.PATCH`，目前開發版本為 `0.3.4`（整合 MooshieUI 2.3.51；驗證狀態依下列項目）。
- **官方 MooshieUI 版本**：獨立標示上游版本，目前適配 `2.3.51`。
- **模組版本**：沿用各模組 `dev/version.json`，僅在該模組實際有變更時提升；沒有修改的模組不虛增版次。
- **GitHub Release**：每次發布使用新的、不可覆寫的標籤；標籤與下載包必須對應同一份測試過的程式碼及修正紀錄。
- **驗收**：區分「原始碼已修改」、「本地測試通過」、「已發布 GitHub」與「使用者電腦驗證」；不得互相代替。

## [0.3.4] — 2026-11-17

**緊急修復：正式 EXE 誤以 Tauri 開發模式建置，導致桌面視窗顯示 `localhost` / `ERR_CONNECTION_REFUSED`，無法載入操作介面。**

- v0.3.3 公開 B Windows 套件的 EXE（SHA256：`F74B3A321A55DAEAB9E52A4BE86BA924328FFD1B7AA3893B5668900ED2654157`）的 Cargo 建置輸出含 `cargo:rustc-cfg=dev`；Windows 有視窗不代表功能正常。
- 改用 Tauri 正式建置流程重新產生 EXE，並在封裝時阻止 `cfg(dev)` 建置產物或相同故障雜湊被重新發布。
- 管理器版號提升至 0.3.4；LoRA Manager 1.5.0、TAG Manager 1.0.1、Prompt Generator 1.1.2、Creative Tools 0.5.0 保持不變。
- **實際驗證：** Rust release 建置 ExitCode 0，新 Cargo 建置輸出不含 `cfg(dev)`；本機已備份原版 EXE 並替換，使用 Win32 PrintWindow 直接擷取新 EXE 的真實視窗，確認工作分頁、尺寸、提示詞、生成按鈕已呈現，不再是 `ERR_CONNECTION_REFUSED`。ComfyUI 生圖佇列當時為空；實際生圖與其他電腦乾淨安裝尚未驗證。

## [0.3.3] — 2026-11-17

**適配：MooshieUI 2.3.51｜LoRA Manager 1.5.0｜Manager 0.3.3**

### LoRA 分類與介面
- 新增「服裝」為獨立類型，保留「全部／角色／風格／效果／其他」及原有縮圖、排序、卡片／清單、右側固定資訊區。
- LoRA 先讀取已存使用者分類及本機 ModelSpec TAG，再以既有資料夾慣例補充推定類型；沒有證據時顯示「其他（待分類）」，不將猜測當成模型已驗證屬性。
- LoRA 允許角色＋風格＋服裝等多重類型，同一權重能在多個篩選結果出現；類型與作品資料夾分離為交集篩選，選取類型時預設全部資料夾。
- 直接放在 LoRA／Anima 根目錄的模型歸入虛擬的「LoRA（主目錄）」選項，不變更實體位置；補上 Granblue_Fantasy 與 kancolle 的角色推定慣例。
- 手動資訊管理新增服裝勾選，儲存後通知 LoRA 瀏覽器即時更新分類；不更動模型權重、既有手動分類及原始 TAG。
- 自動分類批次讀取本機 ModelSpec，不為分類額外計算模型 SHA256 或查詢 CivitAI；縮圖維持原本延遲載入。

### 模組管理器與發布
- LoRA Manager 版號更新至 1.5.0，整合套件及 Windows 管理器版號更新至 0.3.3。
- 延用 MooshieUI 2.3.51 及原有下載驗證／備份／還原機制；其餘 TAG、Prompt Generator、Creative Tools 模組版號不變。

### 實際驗證
- 2.3.51 整合樹 Svelte 型別檢查：0 errors（94 warnings）；Vite 前端建置成功。
- LoRA 分類針對多重類型、角色／服裝／風格、資料夾交集、虛擬主目錄與未知類型的單元測試通過。
- 2.3.51 整合補丁反向套用檢查通過；Rust release 編譯成功（6 warnings）。
- Windows A／B／Manager 三包與 update.json 已封裝，B payload SHA256 與版本相符、管理器五檔 hash 完整；安裝器唯讀預檢通過。
- 本機完成正式 EXE、LoRA Manager 1.5.0 與管理器 0.3.3 更新；更新前備份已建立，正式 EXE 與 B 包 SHA256 一致。
- 已重新開啟 MooshieUI 主視窗且可回應、ComfyUI 健康檢查 HTTP 200；尚未進行 LoRA 各分類的真實 GUI 點選與跨機全新安裝驗收。

## [0.3.2] — 2026-11-17

**修復 v0.3.1 GitHub 更新資訊的 Windows 中文檔名 SHA256 解析問題**

- v0.3.1 的更新 JSON 在 Windows PowerShell 5.1 建置時因來源檔編碼錯誤，`模組管理器.ps1` 與 `啟動模組管理.vbs` 的雜湊鍵名亂碼、值為 `null`，導致「檢查 GitHub 並更新」報錯。v0.3.2 改由實際封裝目錄列舉所有五個管理器檔名，再產生 UTF-8 更新資訊，不再以非 BOM 腳本中的中文字面值當鍵名。
- Manager 版本更新為 0.3.2；MooshieUI 主 EXE、ComfyUI 節點程式、模型與使用者設定均不變。
- v0.3.1 Release 保留供歷史追溯，使用者應升至 v0.3.2，避免有缺陷的更新 JSON。

## [0.3.1] — 2026-11-17

**適配：MooshieUI 2.3.51｜節點同步與啟動修復（管理器 0.3.1）**

### 修復

- Windows B 安裝包附帶對應版本的五個 ComfyUI 節點檔案與 SHA256 清單；安裝器同步至應用程式旁的節點包目錄，並在本地設定存在時嘗試安全同步與重載 ComfyUI。
- 本地啟動器同時檢查 HTTP 與 `MooshieMaskDetailer`、`MooshieSkinContrast`、`MooshieAnimaArtStyle`，避免舊後端 HTTP 200 卻缺少新節點時誤判健康。
- 安裝與啟動同步時保留舊版節點備份；只有佇列空閒、且確認 18288 的執行程序屬於所設定的本地 ComfyUI，才會自動重啟。
- GitHub 更新檢查增加節點包與啟動器雜湊差異判斷，EXE 未改變時仍可偵測必要更新，沿用已驗證的更新包快取。

### 實際驗證與限制

- 本機 ComfyUI 0.41.1 已同步三個新節點，重啟後 `/object_info` 實測三者均已載入（1,185 節點）。
- 安裝器與啟動器的 PowerShell 5.1 語法解析已通過；其餘實測以本次建置／安裝驗收結果為準。
- 不改變外部 ComfyUI 模式、模型、LoRA、使用者設定；非本地受管理的其他電腦／遠端 ComfyUI 不會被自動終止或變更。

## [0.3.0] — 2026-11-17

**適配：MooshieUI 2.3.51｜LoRA Manager 1.4.0｜TAG Manager 1.0.1｜Prompt Generator 1.1.2｜Creative Tools 0.5.0｜Manager 0.3.0**

### 新增

- LoRA 保留既有雙排工具列：類型與作品／資料夾同列、排序與更新、搜尋、卡片／清單切換及縮圖大小滑桿。
- LoRA 左側管理區 70%／右側固定瀏覽區 30%；未選模型時空白，選取後才顯示縮圖、強度、Trigger words 與模型資訊。
- 保留 v2.3.51 官方 Model／CLIP 連動、觸發詞自動加入／移除與原生 LoRA 設定；原本獨立 LoRA 資訊管理仍保留。

### 修復

- 將四個原有 source-level 模組整合至 MooshieUI 2.3.51，另外保留 2.3.49 修補檔供歷史版本使用。
- Windows 管理器支援 2.3.49／2.3.50 至 2.3.51 的明確升級路徑，維持備份、SHA256 驗證與還原。

### 已知限制

- 使用者仍需另外安裝並啟動 Ollama，才能使用 Prompt Generator AI 翻譯與生成。
- v0.2.4 舊管理器只能辨識相同上游版本；首次跨版需使用 v0.3.0 的 Manager ZIP 或 B ZIP。
- 四張圖佇列及 rustc CPU 問題未在本次實際生圖驗收前宣稱解決；其他電腦環境尚未實測。

### 實際驗證

- 2.3.51 整合原始碼：Svelte 型別檢查 0 errors；Vite 前端建置成功。
- 完整整合補丁於另一份乾淨的 v2.3.51 原始碼通過 git apply --check。
- Rust／Tauri v2.3.51 正式 EXE 編譯成功，Windows A／B／Manager 三個 ZIP 與更新 JSON 已產出 SHA256；B 安裝器對正式 2.3.49 的跨版唯讀預檢通過。
- 本機升級完成後確認 EXE ProductVersion 2.3.51、SHA256 與 B 包相同，Manager FileVersion 0.3.0.0；MooshieUI 主視窗可啟動並回應，ComfyUI 後端健康檢查 HTTP 200。
- LoRA 實際滑桿／篩選／Trigger words 與多圖佇列尚未完成真實 GUI／生圖驗收；跨機全新安裝及還原分支未實測。


## [0.2.4] — 2026-11-17

**適配：MooshieUI 2.3.49｜Prompt Generator 1.1.2｜Manager 0.2.4**

### 修復

- **UPD-002｜中文檔名 SHA256 中繼資料損壞**：v0.2.3 的新建發布腳本未含 UTF-8 BOM，Windows PowerShell 5.1 將中文檔名誤解碼，產出更新資訊中 `模組管理器.ps1` 和 `啟動模組管理.vbs` 的亂碼鍵名與 `null` 雜湊，導致舊版自動更新停止。v0.2.4 修正建置腳本編碼並要求更新資訊五個管理器檔名與 SHA256 必須完整吻合。
- 管理器顯示版號同步至 0.2.4；保留 v0.2.3 的圖形啟動回報、診斷與 UAC 改善。本版沒有變動共用 MooshieUI EXE 或四個功能模組。
- v0.2.3 既有 Release 保留不覆寫；使用者應選擇 v0.2.4。

### 實際驗證

- 新版檔案編碼與舊版更新器讀取中文檔名的整合測試以本輪實測結果為準；非開發者全新電腦及實際受限帳號仍未驗證。

## [0.2.3] — 2026-11-17

**適配：MooshieUI 2.3.49｜Prompt Generator 1.1.2｜Manager 0.2.3**

### 修復

- Windows 模組管理器 EXE 不再只檢查 PowerShell 子程序有沒有建立：待 WPF 視窗完成首次呈現並回報啟動訊號後，才回傳成功；PowerShell 於啟動期間退出時，顯示實際錯誤與診斷日誌位置。
- 管理器 UI 啟動或執行錯誤寫入 `%LOCALAPPDATA%\MooshieUIplus\temp`；保留原本的圖形介面及單獨 PowerShell 子程序，以免更新時鎖住 Manager EXE。
- 對 `Program Files` 下的 EXE 安裝／還原及管理器更新新增 UAC 提權流程；使用者拒絕提權時顯示明確錯誤，不無聲失敗。
- GitHub 更新器明確使用 TLS 1.2，以降低舊版 Windows PowerShell／.NET 預設 TLS 設定造成的 HTTPS 連線問題。

### 範圍與已知限制

- 本版只更新 Windows 管理器、安裝／更新腳本與發行說明，**共用 MooshieUI EXE 未重新編譯，Prompt Generator 等四個模組版次不變**。
- B ZIP 仍需完整解壓縮，管理器 EXE 不能單獨拿走使用；Windows 仍需 .NET Framework／WPF、PowerShell 5.1，MooshieUI 桌面程式仍需 WebView2。Ollama 必須由使用者另外安裝。
- 企業 GPO 限制、缺少 .NET／WebView2、UAC 拒絕與全新 Windows 電腦的實際情境，尚未取得跨機驗證，不能宣稱通過。

### 實際驗證

- 本機 Windows 11：三支 PowerShell 腳本語法分析各 0 錯誤；Manager EXE 成功編譯；隔離資料夾 `--check` 返回 0、實際啟動 WPF 視窗並收到啟動確認、成功關閉測試視窗；安裝器 `-VerifyOnly` 對 2.3.49 整合包返回 0，未修改正式 EXE。
- 權限不足的真實非管理員帳號、企業 GPO、缺少 .NET／WebView2 與其他電腦的首次安裝**尚未驗證**；UAC 分支本輪只完成程式碼與語法檢查。

## [0.2.2] — 2026-11-17

**適配：MooshieUI 2.3.49｜Prompt Generator 1.1.2｜Manager 0.2.2（版本列表同步）**

### 介面改善

- 翻譯（Ollama）卡片新增模型選單，使用與上方 Prompt Generator 相同的 Ollama 模型清單與設定，任一處選取即雙向同步，不另建第二份模型偏好。
- 如果上方使用手動輸入的自訂模型，翻譯卡片顯示目前模型名稱；仍可透過下拉選擇已安裝模型。
- 切換模型會清除舊翻譯文字，避免誤認結果的模型來源；未選擇模型時，翻譯按鈕停用。

### 範圍

- 本次只修改 Prompt Generator 的前端與版次，不修改 Ollama API、模型、TAG／LoRA、Creative Tools 或使用者設定。
- Ollama 仍需由使用者自行安裝並啟動；其他電腦 UI 操作尚待實機確認。

## [0.2.1] — 2026-11-17

**適配：MooshieUI 2.3.49｜Prompt Generator 1.1.1｜Manager 0.2.1**

### 修復

- **PG-001**：預設永遠使用新 EXE 內建服務，不再自動採用舊資料目錄中的 `addons/prompt-generator/desktop/service.cjs`；仍尊重使用者明確設定的 `MOOSHIEUI_PROMPT_SERVICE` 路徑，不刪除舊檔或模型／設定。
- 將 B 版新安裝器一次安裝整合 EXE、Node.js 可攜 runtime 與授權檔；遠端更新器保留跨版本 SHA256、必要的 manager EXE 校驗。舊版 v0.1.1 自動更新器本身無法回溯修正，舊版使用者請直接以新 B ZIP 的 EXE 管理器執行本地安裝。
- 模組管理器改用 **`MooshieUIplus-Manager.exe`** 雙擊啟動，不需再找 `.vbs`。啟動器在開啟圖形視窗後立即結束，避免更新管理器時 EXE 被鎖定。

### 相容性與限制

- B ZIP 仍保留舊 `.vbs` 檔案供既有更新器辨識與遷移，但**新使用者入口只使用 `MooshieUIplus-Manager.exe`**；舊版 GitHub Release 不覆寫。
- 使用提示詞生成與翻譯必須**另外安裝並啟動 Ollama**，至少有一個可呼叫的聊天模型；TAG 私有資料不隨包提供。
- Windows EXE 管理器為未簽章的 .NET Framework 啟動器，需與隨附管理器腳本放在同一解壓資料夾，非獨立的 MooshieUI／ComfyUI 安裝程式。
- 其他使用者電腦的實機驗證尚未完成，不宣稱所有環境皆可用。

## [0.2.0] — 2026-11-17

**適配：MooshieUI 2.3.49｜Prompt Generator 1.1.0**

### 修復

- **PG-001**：Prompt Generator 服務內建於新編譯 EXE，不再依賴任何 `D:\\prompt_generator`、`H:\\moon` 等固定開發路徑；仍保留既有自訂服務與舊版服務的相容路徑。
- B 版附 Node.js 22.18.0 x64 可攜 runtime（保留原始授權檔，正式安裝由管理器處理），不需要一般使用者另外安裝 Node.js 或編譯工具。
- AGENT 與 Ollama 清單讀取分別處理；Ollama 未啟動時仍可顯示內建規則及保留使用者手動模型名稱。

### 新增

- 可透過 Ollama 取得已安裝聊天模型清單、刷新清單、手動輸入自訂模型 ID，並明確區分已安裝與已透過 `/api/chat` 呼叫測試。
- 沒有第三方 TAG 詞庫時，以內建基本規則產出自然英文提示詞及逐項繁中對照，明確顯示未載入 TAG 的限制。第三方私有 TAG 詞庫不隨 GitHub 公開包發行。
- B 版安裝與 GitHub 更新資訊納入 runtime 完整性校驗及補裝，沿用 EXE 備份／還原規則。

### 必要依賴與限制

- **使用 Prompt Generator 的 AI 生成、翻譯、模型清單或呼叫測試前，必須另外安裝並啟動 Ollama，且至少準備一個聊天模型。** Ollama 不包含在安裝包內。
- 若使用者自行啟用外部 `MOOSHIEUI_PROMPT_SERVICE`，沿用舊服務功能；自訂服務與模型品質不等於全部逐項驗收。
- 第三方 TAG 詞庫仍需使用者自行合法提供；未載入時，不宣稱具有 TAG canonical 查詢能力。

### 實際驗證

- 驗證結果以本版建置及測試實際記錄為準；未測到的其他電腦環境不標示 PASS。

## [0.1.1] — 2026-11-17

**適配：MooshieUI 2.3.49**

### 修復

- **UPD-001｜GitHub 新版選擇錯誤**：原管理器依 Releases API 回傳陣列順序尋找更新，實測會選到舊版 RC5 而略過後發布的 v0.1.0。更新器改為依 `published_at` 降冪選取符合目前 MooshieUI 主版本的正式發布包。

### 未變更

- 四個模組功能、整合 EXE 與既有模組版本皆未更動。
- **PG-001 Prompt Generator 缺少服務仍未修復**；此版不能視為 Prompt Generator 即裝即用。

## [0.1.0] — 2026-11-17

**適配：MooshieUI 2.3.49**

### 本版新增

- 為 MooshieUIplus 建立明確產品版次，於 Windows 模組管理器的標題、側邊欄及關於頁顯示。
- 模組列表加入各模組的版本資訊，不再把整合套件 Release 編號當成各模組版次。
- 建立這份修正紀錄，後續版本固定記載新增、修復、已知問題及必要驗證結果。

### 已有模組版次（取自本次原始碼）

| 模組 | 版本 | 本次是否修改該模組功能 |
| --- | --- | --- |
| LoRA Manager | 1.3.1 | 否 |
| TAG Manager | 1.0.1 | 否 |
| Prompt Generator | 1.0.2 | 否 |
| Creative Tools | 0.5.0 | 否 |

### 已確認、尚未修復的問題

- **PG-001｜Prompt Generator 缺少服務**：有使用者回報 `H:\moon\addons\prompt-generator\desktop\service.cjs` 不存在。已核對目前 `picture_generator.rs`：若未指定 `MOOSHIEUI_PROMPT_SERVICE`，程式會尋找 MooshieUI 資料夾中的 `addons/prompt-generator/desktop/service.cjs`。B 發布包沒有附上該服務；現有服務還依賴 Node.js、Ollama、外部規則及本機 TAG 路徑。**狀態：已定位原因，未修復，未通過跨電腦驗收。**
- **TAG 授權**：部分第三方中英詞庫資料的公開再散布權利尚待確認。

### 驗證狀態

新增版次資訊的語法與 WPF 視窗載入結果，須以本次實際檢查結果為準；Prompt Generator 原功能**不得因版本號變更而標示為 PASS**。

## 歷史版本索引（原發布編號）

下列為已發布的歷史 GitHub 發行版；它們先前採 RC 編號，並非 0.1.0 版次系統。

| 歷史 Release | 已知交付內容 |
| --- | --- |
| `v2.3.49-plus-rc3` | A 整合原始碼、B Windows 免編譯包與初版圖形化模組管理器 |
| `v2.3.49-plus-rc4` | GitHub 更新資訊比對、管理器小型更新包、SHA256 快取 |
| `v2.3.49-plus-rc5` | ModAssistant 風格 WPF 模組管理器，原始編譯功能保留 |
