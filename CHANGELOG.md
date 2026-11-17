# MooshieUIplus｜版本與修正紀錄

> 本檔只記錄已實際開發的功能及已確認的問題。未通過測試、尚未修復的項目不得標示完成。

## 版本規則

- **MooshieUIplus 版本**：`MAJOR.MINOR.PATCH`，目前為 `0.2.2`（翻譯區 Ollama 模型選擇與同步；不代表其他模組全部驗收通過）。
- **官方 MooshieUI 版本**：獨立標示上游版本，目前適配 `2.3.49`。
- **模組版本**：沿用各模組 `dev/version.json`，僅在該模組實際有變更時提升；沒有修改的模組不虛增版次。
- **GitHub Release**：每次發布使用新的、不可覆寫的標籤；標籤與下載包必須對應同一份測試過的程式碼及修正紀錄。
- **驗收**：區分「原始碼已修改」、「本地測試通過」、「已發布 GitHub」與「使用者電腦驗證」；不得互相代替。

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
