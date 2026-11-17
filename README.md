# MooshieUIplus｜MooshieUI 2.3.49 擴充模組

這個專案整合以下功能：LoRA 分類瀏覽／資訊管理、TAG 中文提示、Prompt Generator 介面、Creative Tools（參考圖、擴圖、姿勢、後製／漫畫）。**這些功能是編譯進 MooshieUI 的 source-level 擴充，不是 ComfyUI 的 custom_nodes。**

## 下載哪個檔案？

| 版本 | 對象 | 建置工具 | 安裝方式 |
| --- | --- | --- | --- |
| **B：Windows 免編譯模組管理器** | 一般使用者 | 不需要 Node.js、Rust、Git 或 C++ Build Tools | 安裝原版 MooshieUI 2.3.49，解壓 ZIP，執行「啟動模組管理.cmd」 |
| **A：完整整合原始碼包** | 開發者、想修改功能的使用者 | 需要 Node.js/npm、Git、Rust/Cargo、Visual Studio C++ Build Tools、Windows SDK | 用隨附原始碼編譯，或將模組套用到乾淨的官方 2.3.49 原始碼 |

**請勿把兩個 ZIP 當成適用不同版本的程式。兩者均只支援 MooshieUI 2.3.49。** 下載最新版 MooshieUI 並不代表此套件已適配。

## B：一般使用者安裝（推薦）

1. 安裝官方 MooshieUI **2.3.49**，確認程式與 ComfyUI 後端可正常啟動。
2. 下載 GitHub Release 內的 **B Windows ZIP**，完整解壓縮到任意資料夾，例如 `C:\AI\MooshieUIplus`。
3. 雙擊 **`啟動模組管理.cmd`**，首次按「選擇程式」，指定已安裝的 `comfyui-desktop.exe`。
4. 關閉 MooshieUI，再由管理器按「安裝／更新本地套件」。
5. 管理器先核對版本及 SHA256、備份原本 EXE，成功才替換；不修改個人 `data`、模型、後端與設定。
6. 日後可按「檢查 GitHub 更新」，只尋找同版 MooshieUI 的正式 B Release；有相容發布版才啟用「安裝發布版」，並要求使用者確認。
7. 可以按「還原備份」復原，備份保存在 `%LOCALAPPDATA%\MooshieUIplus\history\exe-backups`。原有 `安裝.cmd`、`還原.cmd` 仍保留。

B 版不需要編譯工具，但仍需要可正常使用的官方 MooshieUI 2.3.49 與 ComfyUI 後端。本套件不是完整 ComfyUI 安裝程式，也**不會自動跨版更新**。四個模組共用同一個已編譯 EXE，並非可以獨立熱插拔的外掛。

## A：開發者與原始碼安裝

1. 取得 A ZIP 並解壓，內含 `source/`（2.3.49 對應完整整合原始碼）、`module-manager/` 與四個模組。
2. 在 `source/` 執行 `npm ci`，確認 Node.js LTS、Git、Rust/Cargo（MSVC）、Visual Studio 2022 C++ Build Tools、Windows SDK 已安裝。
3. 於 Windows 執行 `module-manager/啟動模組管理.cmd`，選擇官方 2.3.49 的 `comfyui-desktop.exe` 與 ZIP 內的 `source/`。關閉 MooshieUI 後，使用「覆蓋安裝」。
4. 模組管理器會備份目前 EXE、核對版本、整合、編譯並在成功後部署；備份可由管理器復原。

也可先下載**乾淨官方 2.3.49 原始碼**，執行：

```powershell
node .\module-manager\install-clean.mjs "C:\path\to\mooshieui-2.3.49-source"
```

上述指令要在解壓後的 MooshieUIplus 套件根目錄執行；`install-clean.mjs` 僅修改使用者指定的原始碼樹，不修改正式 EXE 或個人資料。務必使用版本相符、未經修改的官方原始碼。A ZIP 已自帶整合完成的原始碼，通常不必再執行這一步。

## 模型路徑與分類

**不需要把 LoRA 放入模組資料夾。** LoRA 使用 MooshieUI／ComfyUI 原有的模型設定與額外模型路徑；資料夾與模型清單動態讀取。分類與資訊儲存在每台電腦自己的 MooshieUI 資料目錄 `addons/lora-manager/`，不會把發佈者的分類或本機路徑帶到別人電腦。

## 已知依賴與限制

- **Prompt Generator** 目前只是 MooshieUI 整合介面，獨立服務、外部 TAG 原始資料與 Ollama **不隨 ZIP 提供**。需另行配置 `MOOSHIEUI_PROMPT_SERVICE` 或在 MooshieUI app data 下提供 `addons/prompt-generator/desktop/service.cjs`。
- **Creative Tools** 的部分功能需要 ComfyUI 對應 ControlNet 節點與權重；缺少模型時功能可能無法執行。
- 本套件基於上游 MooshieUI 2.3.49／AGPL-3.0。請閱讀隨附 `LICENSE`、`NOTICE.md` 及對應完整原始碼；公開發布前仍需確認 TAG 資料的再散布權利。
- 未在他人電腦完成全套圖像生成功能驗收時，不應宣稱所有功能都已通過實機測試。

## GitHub

原始碼：<https://github.com/Martie0001/MooshieUIplus>。發布候選內容準備完成後，需經專案持有人確認才上傳 GitHub 或建立 Release。
