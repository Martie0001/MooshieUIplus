# MooshieUIplus v0.3.8｜MooshieUI 2.4.7 整合模組

本專案將 **LoRA Manager、TAG Manager、Prompt Generator、Creative Tools** 以 source-level 方式整合進 [MooshieUI](https://github.com/Mooshieblob1/MooshieUI)，並提供 Windows 圖形模組管理器。四個模組共用編譯後的 EXE，並非可獨立熱插拔的 ComfyUI 外掛。

**目前版本：MooshieUIplus 0.3.8／MooshieUI 2.4.7／Module Manager 0.3.8。** Creative Tools 0.5.0 仍為「功能不完全（待開發）」。本機已完成 Release 編譯、Windows 真實視窗啟動及 28／28 ComfyUI 必要節點載入；未完成所有功能逐項生圖與跨電腦乾淨安裝驗收。詳見 [CHANGELOG.md](CHANGELOG.md)。

## 下載檔案

| 檔案 | 用途 |
| --- | --- |
| `MooshieUIplus-B-Windows-2.4.7-v0.3.8.zip` | **一般 Windows 使用者**：整合版 EXE、配套 2.4.7 節點與執行元件，以及圖形管理器；免編譯 |
| `MooshieUIplus-Manager-2.4.7-v0.3.8.zip` | 已安裝整合版、只需更新圖形管理器及更新腳本 |
| `MooshieUIplus-A-Source-2.4.7-v0.3.8.zip` | 開發者：對應 EXE 的完整整合原始碼、版本化補丁及授權資料 |
| `MooshieUIplus-B-Windows-2.4.7-v0.3.8.update.json` | 更新器使用的版本、執行檔與節點 SHA256 清單 |

取得檔案：[GitHub Releases](https://github.com/Martie0001/MooshieUIplus/releases)。

### 一般使用者安裝

1. 先安裝並確定 MooshieUI／ComfyUI 可啟動。下載 B Windows ZIP，**完整解壓縮**。
2. 雙擊 `MooshieUIplus-Manager.exe`（無須自行開啟 VBS、CMD 或 PowerShell；不可只搬移單獨 EXE）。
3. 選擇現有 `comfyui-desktop.exe`，在 MooshieUI 關閉且沒有進行中的生圖佇列時，使用「本地套件安裝」。安裝器會校驗 SHA256、先備份、更新 EXE 及對應 ComfyUI 節點。
4. 日後可透過管理器「檢查並更新」下載相容的新版本。既有舊版管理器如果無法辨識 2.4.7，可先手動下載新版 Manager ZIP，再執行更新。

**安全相容範圍：** 本版安裝器允許 MooshieUI 2.4.4 或 2.4.6 升至 2.4.7；其他版本不會任意跨版覆蓋。保留原本的模型、LoRA、圖片、Profile 與分類設定。

**執行需求：** Windows 10／11、.NET Framework 4.x（WPF）、Windows PowerShell 5.1，以及 MooshieUI 使用的 WebView2。B 版不需安裝 Git、Rust、Node.js 或 C++ Build Tools。管理器 EXE 未做數位簽章，請從本專案 Release 取得並核對雜湊。

**Prompt Generator：** B 版附帶可攜 Node.js runtime，但翻譯、AI 提示詞等功能仍需自行安裝／啟動 [Ollama](https://ollama.com/download) 並準備至少一個聊天模型。

### 開發者

A ZIP 的 `source/` 是 MooshieUI **v2.4.7** 對應的完整整合原始碼，非過時的舊版工作樹。需要 Node.js/npm、Rust/Cargo（Windows MSVC）、Visual Studio C++ Build Tools 與 Windows SDK，可於 `source/` 執行：

```powershell
npm ci
npm exec -- tauri build --no-bundle
```

`module-manager/integrated-2.4.7.patch` 是本版對應上游 v2.4.7 的整合補丁；其他版本的 patch 僅供歷史參考。原生 MooshieUI 2.4.7 新增的多頁漫畫、對話框、備份還原等功能與既有 Creative Tools 並存；Creative Tools 不因此宣稱已開發完成。

### 節點、模組版本與限制

B 版包括 28 個必要的 ComfyUI 節點類別與 31 個配套節點／相依及授權檔案，包含 `kolors_support`；啟動器必須對照 `comfy-nodes.json`、SHA256 及 `/object_info`，不能只因 HTTP 200 就宣稱節點正常。

- LoRA Manager 1.5.0：分類、服裝、多重類型與資訊管理
- TAG Manager 1.0.1：TAG 中文對照
- Prompt Generator 1.1.2：本地提示詞整合，需額外 Ollama
- Creative Tools 0.5.0：**功能不完全（待開發）**
- Module Manager 0.3.8：相容更新、完整性檢查、備份與還原

完整生圖、全部模組 GUI 操作、跨機全新安裝尚未完成測試，不能宣稱通過。另請閱讀 [LICENSE](LICENSE)、[NOTICE.md](NOTICE.md) 及 [PUBLISHING.md](PUBLISHING.md)。
