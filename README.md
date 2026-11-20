# MooshieUIplus v0.3.6｜MooshieUI 2.4.4 整合模組

本專案將 **LoRA Manager、TAG Manager、Prompt Generator、Creative Tools** 以 source-level 方式整合進 [MooshieUI](https://github.com/Mooshieblob1/MooshieUI)。它們不是可單獨熱插拔的 ComfyUI 外掛。

**目前版本：MooshieUIplus 0.3.6／MooshieUI 2.4.4。** Creative Tools 0.5.0 為「功能不完全（待開發）」。已完成本機建置、啟動和必要節點載入檢查；尚未完成跨電腦乾淨安裝與所有繪圖功能的 GUI 驗收。更新細節見 [CHANGELOG.md](CHANGELOG.md)。

## 下載與安裝

| 下載檔 | 適用對象 | 說明 |
| --- | --- | --- |
| `MooshieUIplus-B-Windows-2.4.4-v0.3.6.zip` | Windows 一般使用者 | **推薦**，免編譯整合包；含桌面整合 EXE、完整 2.4.4 節點包、可攜 Prompt Generator runtime、圖形模組管理器 |
| `MooshieUIplus-Manager-2.4.4-v0.3.6.zip` | 已有整合版、只需更新管理器 | 較小的 Windows 管理器／啟動器包，需與現有 MooshieUI 一起使用 |
| `MooshieUIplus-A-Source-2.4.4-v0.3.6.zip` | 開發者 | 與發布 EXE 對應的完整整合原始碼及模組、授權與安裝腳本 |
| `MooshieUIplus-B-Windows-2.4.4-v0.3.6.update.json` | 管理器自動更新 | 版本、檔案 SHA256 與節點清單，供更新器自動校驗 |

所有發布檔案在 [GitHub Releases](https://github.com/Martie0001/MooshieUIplus/releases)。

### 一般使用者

1. 先安裝並確認官方 MooshieUI／ComfyUI 可以使用，再下載 **B Windows ZIP** 並**完整解壓縮**。
2. 雙擊 **`MooshieUIplus-Manager.exe`**。這是正式圖形啟動器；**不需要**使用 `.vbs`、CMD 或 PowerShell，也**不能只拿單獨 EXE**。
3. 選擇已安裝 MooshieUI 的 `comfyui-desktop.exe`。關閉 MooshieUI 後執行「本地套件安裝」。安裝器會驗證版本和 SHA256，備份舊 EXE，安裝對應節點與啟動器。
4. 以後在圖形管理器按「檢查 GitHub 並更新」。沒有變更就不下載整包；管理器和完整套件分開更新，已驗證的下載檔可重用。

**從舊版升級：** 0.3.4 或更早管理器可能無法識別 2.4.4 跨版更新。請先下載 0.3.6 的 **Manager ZIP**（或完整 B ZIP）手動更新管理器，再由新版更新器檢查。0.3.6 安裝器支援從 MooshieUI 2.3.51 或 2.4.0 升至 2.4.4；更舊的上游版本請先升級到受支援版本，不會直接任意覆蓋。

圖形管理器需要 Windows 10／11 的 .NET Framework 4.x（WPF）與 Windows PowerShell 5.1，MooshieUI 主視窗另需 WebView2。使用者**不需要**安裝 Rust、C++ Build Tools 或 Node.js。管理器 EXE 未數位簽章，可能出現 Windows SmartScreen 提示；只使用可信任的 GitHub Release。

**Prompt Generator：** 已附帶 Node.js runtime，但 AI 翻譯、生成與模型選擇**仍需自行安裝及啟動 [Ollama](https://ollama.com/download)**，至少準備一個聊天模型。

### 開發者

A ZIP 內的 `source/` 是對應 MooshieUI 2.4.4 的完整整合程式碼，而非過時的 2.3.x 開發工作樹。請在支援的 Windows 開發環境安裝 Node.js/npm、Rust/Cargo（MSVC）、Visual Studio C++ Build Tools 和 Windows SDK，於 `source/` 執行：

```powershell
npm ci
.\node_modules\.bin\tauri.cmd build --no-bundle --ci
```

如需原始碼補丁，`module-manager/integrated-2.4.4.patch` 對應官方 MooshieUI v2.4.4。舊版 `integrated-2.4.0.patch` 等只供歷史參考，不應套到 2.4.4。

### 節點及使用者資料

2.4.4 必須載入官方所列的 **28 個 ComfyUI 節點類別**。B 包內含 **31 個節點／相依與授權檔案**，包含 `kolors_support`。啟動器 `ensure_backend.ps1` 會核對當版 `comfy-nodes.json`、檔案雜湊及 ComfyUI 的 `/object_info`；單看 HTTP 200 不算通過。安裝與修復前會檢查佇列，避免繪圖中擅自重啟。

模型權重、LoRA、生成圖片、Profile 及使用者分類不隨包提供，也不應由升版流程任意覆蓋。

## 模組版本與限制

- **LoRA Manager 1.5.0**：分類瀏覽、服裝、多重類型、資訊管理
- **TAG Manager 1.0.1**：TAG 中文對照
- **Prompt Generator 1.1.2**：本地提示詞／翻譯整合，需額外 Ollama
- **Creative Tools 0.5.0**：部分功能已實作，**功能不完全（待開發）**
- **Module Manager 0.3.6**：圖形啟動、相容更新、節點完整性檢查、備份與還原

上游 MooshieUI 與自訂整合程式碼的授權及第三方聲明請見 [LICENSE](LICENSE) 和 [NOTICE.md](NOTICE.md)。發布及版本管理規範見 [PUBLISHING.md](PUBLISHING.md)。
