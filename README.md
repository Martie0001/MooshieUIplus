# MooshieUIplus｜MooshieUI 2.3.51 擴充模組

這個專案整合以下功能：LoRA 分類瀏覽／資訊管理、TAG 中文提示、Prompt Generator 可攜提示詞服務、Creative Tools（參考圖、擴圖、姿勢、後製／漫畫）。**這些功能是編譯進 MooshieUI 的 source-level 擴充，不是 ComfyUI 的 custom_nodes。**

Windows 模組管理器採用參考 [ModAssistant](https://github.com/bsmg/ModAssistant) 的 WPF 模組清單與側邊導覽介面。**一般使用者直接雙擊 `MooshieUIplus-Manager.exe` 啟動**；不再要求使用 `.vbs`、PowerShell 或 CMD。原專案依 MIT 授權，保留著作權聲明與授權全文於管理器程式，並於 NOTICE 中標示來源。

**MooshieUIplus 產品版本從 `0.1.0` 起單獨管理**，與官方 MooshieUI `2.3.51` 及各模組版次分開。歷次新增、修復與未解決問題請見 [`CHANGELOG.md`](CHANGELOG.md)。

## 各模組開發狀態（2026-11-17）

> **狀態說明：**「已發布」代表程式碼與發行包已提供，不等於所有功能都完成實機驗收；「開發中」代表已有部分實作，但仍有待完善或待驗收的功能。以下依目前整合版 `MooshieUIplus v0.3.0 / MooshieUI 2.3.51`、模組版本檔與既有驗收記錄整理，未測項目不標示 PASS。

| 模組 | 模組版本 | 開發狀態 | 已有功能／目前進度 | 後續待辦或限制 |
| --- | --- | --- | --- | --- |
| **LoRA Manager** | `1.4.0` | **開發中（已整合發布）** | 分類／跨資料夾篩選、卡片與清單、縮圖大小調整；新增左側 70% 管理區與右側 30% 固定模型瀏覽區，保留獨立 LoRA 資訊管理 | 2.3.51 版尚未完成完整 GUI 實測：模型點選、Model／CLIP 強度、Trigger words、篩選與縮圖操作需以真實使用結果確認 |
| **TAG Manager** | `1.0.1` | **已整合（持續維護）** | 英文 canonical TAG 與繁體中文別名顯示／搜尋 | 第三方 TAG 詞庫的公開再散布授權尚待確認；私有資料不包含在公開包，跨機環境尚未全面驗收 |
| **Prompt Generator** | `1.1.2` | **開發中（已整合發布）** | 內建可攜提示詞服務、Ollama 模型清單與自訂模型、模型呼叫測試；提示詞生成與翻譯共用模型選擇 | **需使用者另行安裝／啟動 Ollama 並準備聊天模型**；其他電腦的安裝及實際生成／翻譯仍待驗收，無私人 TAG 詞庫時不宣稱具備完整 TAG 查詢 |
| **Creative Tools** | `0.5.0` | **開發中（已整合發布）** | 08 參考圖、11 擴圖、22 姿勢控制、31 後製與 40 漫畫排版／對話框工具的介面及程式已納入整合 | 各功能的模型／節點相容性和 2.3.51 版完整 GUI、生圖及匯出流程尚未全面驗收，詳見下表 |
| **MooshieUIplus Manager** | `0.3.0` | **已發布（持續改善）** | WPF 圖形管理器、GitHub 更新檢查、SHA256 核對、備份與還原機制；本機版本檢查顯示最新 | 其他電腦乾淨安裝、實際還原及受限權限環境尚未完整測試；舊 v0.2.4 管理器首次跨版須手動更換 |

### Creative Tools 子功能

| 功能 | 開發狀態 | 說明 |
| --- | --- | --- |
| **08｜角色／服裝／風格參考** | **開發中** | 已建立整合介面與對應功能程式；不同模型的參考控制能力尚需確認，不能宣稱 Anima 等所有模型均可直接使用 |
| **11｜圖片向外延伸** | **已實作；新版待驗收** | 先前版本的單項實際擴圖曾完成驗收；升至 MooshieUI 2.3.51 後尚未重新完成完整實際生圖驗收 |
| **22｜姿勢控制** | **開發中** | 已有骨架編輯／辨識與工作流交接；姿勢精準度及 Anima 等模型的控制路徑仍待完善 |
| **31｜自動後製** | **開發中／待驗收** | 已有初步後製操作；完整模型組合、結果品質及新版流程仍需實測 |
| **40｜漫畫排版與對話框** | **已實作；待驗收** | 已加入單張、2×2、1×4、4×1 版面、圖片填入、對話框與文字編輯、草稿及 PNG 匯出相關程式；完整操作流程尚未取得新版實機驗收結果 |

**其他待驗證項目：** 四張圖佇列／瞬間 `rustc` CPU 占用問題沒有在本次 v0.3.0 發布時完成真實生圖驗收，因此不列為已修復。完整版本變更與實際驗證記錄請參閱 [CHANGELOG.md](CHANGELOG.md)。

## 下載哪個檔案？

| 版本 | 對象 | 建置工具 | 安裝方式 |
| --- | --- | --- | --- |
| **B：Windows 免編譯模組管理器** | 一般使用者 | 不需要 Node.js、Rust、Git 或 C++ Build Tools | 安裝原版 MooshieUI 2.3.51，完整解壓 ZIP，雙擊「MooshieUIplus-Manager.exe」 |
| **A：完整整合原始碼包** | 開發者、想修改功能的使用者 | 需要 Node.js/npm、Git、Rust/Cargo、Visual Studio C++ Build Tools、Windows SDK | 用隨附原始碼編譯，或將模組套用到乾淨的官方 2.3.51 原始碼 |

**請勿把兩個 ZIP 當成適用不同版本的程式。兩者均以 MooshieUI 2.3.51 為目標；新版管理器允許從現有 2.3.49／2.3.50 經使用者確認升級，並備份舊版 EXE。** 下載最新版 MooshieUI 並不代表此套件已適配。

## B：一般使用者安裝（推薦）

1. 安裝官方 MooshieUI **2.3.51**，確認程式與 ComfyUI 後端可正常啟動。若要使用 **Prompt Generator AI 生成功能**，另外從 [Ollama 官方網站](https://ollama.com/download) 安裝並啟動 Ollama、至少下載一個聊天模型。
2. 下載 GitHub Release 內的 **B Windows ZIP**，完整解壓縮到任意資料夾，例如 `C:\AI\MooshieUIplus`。
3. 雙擊 **`MooshieUIplus-Manager.exe`** 開啟圖形管理器，首次指定已安裝的 `comfyui-desktop.exe`，無須使用 `.vbs`、CMD 或 PowerShell。請完整解壓縮 ZIP，不可只複製管理器 EXE。
4. 需要首次安裝時，關閉 MooshieUI，按「本地套件安裝」，由管理器備份 EXE 後替換。
5. 以後只要按一次 **「檢查 GitHub 並更新」**，有相容新版本時確認即可更新，不必再手動下載新的整包。管理器優先比對小型更新資訊與本機 SHA256，無變更不下載；只有管理器改版時只下載小型包，EXE 改版才下載完整 B ZIP；已驗證 ZIP 會快取重用。
6. 需要還原時，按「還原備份」，備份儲存在 `%LOCALAPPDATA%\MooshieUIplus\history\exe-backups`。

**舊版 v0.2.4（含以前）使用者：** 舊管理器只搜尋與現有 MooshieUI 相同上游版本的 Release，首次跨版請先下載 v0.3.0 的新版 Manager ZIP 或完整 B ZIP，解壓後使用新版管理器執行。

**舊版 v0.1.1／v0.2.0 使用者：** 為避免舊更新器未安裝完整執行元件，建議直接下載最新版 B Windows ZIP、完整解壓後雙擊 `MooshieUIplus-Manager.exe`，選擇原本正在使用的 MooshieUI EXE，透過「本地套件安裝」一次更新 EXE 與 Node runtime。舊更新器仍可用作過渡，但可能需要再執行一次新版管理器更新。

B 版不需要編譯工具；管理器需要 Windows 10／11 上的 .NET Framework 4.x／WPF 與 Windows PowerShell 5.1（附完整管理器腳本，但一般使用者不需自行開啟）。原版 MooshieUI 桌面視窗另需 Edge WebView2 Runtime。EXE 未數位簽章，可能遇到 Windows SmartScreen 提示；請使用本專案 Release 並核對雜湊。管理器啟動失敗會顯示錯誤與日誌位置，`Program Files` 安裝可能顯示 Windows UAC 提權。仍需要可正常使用的官方 MooshieUI 2.3.51 與 ComfyUI 後端。本套件不是完整 ComfyUI 安裝程式；不會在未確認時自行跨版安裝，但新版管理器支援 2.3.49／2.3.50 → 2.3.51。四個模組共用同一個已編譯 EXE，並非可以獨立熱插拔的外掛。

## A：開發者與原始碼安裝

1. 取得 A ZIP 並解壓，內含 `source/`（2.3.51 對應完整整合原始碼）、`module-manager/` 與四個模組。
2. 在 `source/` 執行 `npm ci`，確認 Node.js LTS、Git、Rust/Cargo（MSVC）、Visual Studio 2022 C++ Build Tools、Windows SDK 已安裝。
3. 於 Windows 執行 `module-manager/啟動模組管理.cmd`，選擇官方 2.3.51 的 `comfyui-desktop.exe` 與 ZIP 內的 `source/`。關閉 MooshieUI 後，使用「覆蓋安裝」。
4. 模組管理器會備份目前 EXE、核對版本、整合、編譯並在成功後部署；備份可由管理器復原。

也可先下載**乾淨官方 2.3.51 原始碼**，執行：

```powershell
node .\module-manager\install-clean.mjs "C:\path\to\mooshieui-2.3.51-source"
```

上述指令要在解壓後的 MooshieUIplus 套件根目錄執行；`install-clean.mjs` 僅修改使用者指定的原始碼樹，不修改正式 EXE 或個人資料。務必使用版本相符、未經修改的官方原始碼。A ZIP 已自帶整合完成的原始碼，通常不必再執行這一步。

## 模型路徑與分類

**不需要把 LoRA 放入模組資料夾。** LoRA 使用 MooshieUI／ComfyUI 原有的模型設定與額外模型路徑；資料夾與模型清單動態讀取。分類與資訊儲存在每台電腦自己的 MooshieUI 資料目錄 `addons/lora-manager/`，不會把發佈者的分類或本機路徑帶到別人電腦。

## 已知依賴與限制

- **Prompt Generator 1.1.2** 的基本服務已內建於 B 版整合 EXE，Node.js 可攜執行元件會由安裝器放在 MooshieUI 主程式旁，不需使用者另裝 Node.js。**但 AI 生成功能、翻譯、列出或測試模型必須另行安裝並啟動 [Ollama](https://ollama.com/download)，且至少備妥一個聊天模型。** 私有 TAG 詞庫不會附在公開安裝包；未提供時只能使用不宣稱 TAG 已驗證的自然英文提示詞。開發者可透過 `MOOSHIEUI_PROMPT_SERVICE` 使用原有自訂服務，也可用 `MOOSHIEUI_PROMPT_TAGS` 指定自己合法持有的 TAG JSON。
- **Creative Tools** 的部分功能需要 ComfyUI 對應 ControlNet 節點與權重；缺少模型時功能可能無法執行。
- 本套件基於上游 MooshieUI 2.3.51／AGPL-3.0。請閱讀隨附 `LICENSE`、`NOTICE.md` 及對應完整原始碼；公開發布前仍需確認 TAG 資料的再散布權利。
- 未在他人電腦完成全套圖像生成功能驗收時，不應宣稱所有功能都已通過實機測試。

## GitHub

GitHub 原始碼：<https://github.com/Martie0001/MooshieUIplus>，最新版請使用 [GitHub Releases](https://github.com/Martie0001/MooshieUIplus/releases)。後續每次完成模組更新與必要驗收，都應同步 GitHub 原始碼、A／B ZIP、Manager 小型 ZIP 與更新資訊 JSON；詳細流程參見 `PUBLISHING.md`。
