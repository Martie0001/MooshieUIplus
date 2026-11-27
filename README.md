# MooshieUIplus v0.3.9｜MooshieUI 2.4.11 整合模組

本版以官方 [MooshieUI](https://github.com/Mooshieblob1/MooshieUI) **v2.4.11** 為基礎，完整保留自製 **LoRA Manager、TAG Manager、Prompt Generator、Creative Tools（包含獨立漫畫、擴圖、姿勢及後製）**。四個模組以 source-level 方式編入共用 EXE，不是可個別熱插拔的 ComfyUI 外掛。

**版本：MooshieUIplus 0.3.9／MooshieUI 2.4.11／Module Manager 0.3.9。** Creative Tools 0.5.0 仍標示「功能不完全（待開發）」，不因官方原生漫畫或擴圖功能存在而自動移除原本的工具。

## 下載與安裝

| 下載檔案 | 用途 |
| --- | --- |
| `MooshieUIplus-B-Windows-2.4.11-v0.3.9.zip` | **一般 Windows 使用者**：完整整合 EXE、配套 ComfyUI 必要節點、可攜提示詞執行元件及 GUI 管理器 |
| `MooshieUIplus-Manager-2.4.11-v0.3.9.zip` | 更新圖形模組管理器，不包含完整整合主程式 |
| `MooshieUIplus-A-Source-2.4.11-v0.3.9.zip` | 對應正式 EXE 的完整上游＋自訂整合原始碼與補丁 |
| `MooshieUIplus-B-Windows-2.4.11-v0.3.9.update.json` | 管理器使用的版本及 SHA256 檢查資訊 |

[GitHub Releases](https://github.com/Martie0001/MooshieUIplus/releases)

### 一般 Windows 使用者

1. 安裝可正常啟動的 MooshieUI／ComfyUI，下載並**完整解壓縮** B Windows ZIP。
2. 雙擊 `MooshieUIplus-Manager.exe`；不使用舊版 VBS／CMD 當作正式啟動入口。
3. 選擇原本的 `comfyui-desktop.exe`，確認沒有進行中的生圖佇列並關閉 MooshieUI，使用「本地套件安裝」；管理器會驗證檔案雜湊、備份舊 EXE 並安裝所需節點。
4. 後續透過「檢查 GitHub 並更新」確認相容版本。若舊管理器辨識不到 v2.4.11，先更新此版 Manager ZIP。

**直接升級範圍：** 已驗證的 v2.4.7 → v2.4.11；其他基底版本不會直接跨版覆蓋。保留使用者模型、LoRA、圖片、設定及個人 Profile。安裝包不包含 ComfyUI／Python／PyTorch 的完整安裝器，也不自動把已安裝 ComfyUI 升至新版；官方本版管理 ComfyUI 目標為 v0.46.2，後端升級應獨立評估。

**運行環境：** Windows 10／11、.NET Framework 4.x／WPF、PowerShell 5.1、WebView2。B 版不需安裝 Git、Rust、Node.js 或 C++ 編譯工具。管理器未附數位簽章，請由本專案 GitHub Release 取得並核對雜湊。

**Prompt Generator：** 已附帶可攜 Node.js runtime，但使用 AI 中文翻譯、生圖提示詞及模型測試功能時，仍需自行安裝、啟動 [Ollama](https://ollama.com/download) 並下載聊天模型。

### 開發者

A Source ZIP 內的 `source/` 是 v2.4.11 完整整合程式碼，`module-manager/integrated-2.4.11.patch` 對應官方相同版號。於 Windows MSVC／Rust、Node.js、Visual Studio C++ Build Tools 與 Windows SDK 環境可執行：

```powershell
npm ci
npm exec -- tauri build --no-bundle
```

### 模組與限制

- **LoRA Manager 1.5.0：** 多重分類、服裝／作品資料夾篩選、資訊管理
- **TAG Manager 1.0.1：** 繁體中文 TAG 對照
- **Prompt Generator 1.1.2：** Ollama 提示詞與翻譯，保留獨立於官方 Prompt Assistant 的使用入口
- **Creative Tools 0.5.0：** 08 參考圖、11 擴圖、22 姿勢、31 後製、40 漫畫，**功能不完全（待開發）**，全部保留
- **Module Manager 0.3.9：** 安裝、更新、備份及還原

B 版搭配當版 `comfy-nodes.json` 的 **28 個必要 ComfyUI 節點**與配套檔案（含 `kolors_support`），啟動器須以 `/object_info` 及 SHA256 校驗，不以 HTTP 200 取代節點驗收。完整生圖、每一個模組的所有 GUI 操作與其他電腦乾淨安裝，若未實際驗證則不宣稱已通過。

授權、第三方資訊與開發紀錄請見 [LICENSE](LICENSE)、[NOTICE.md](NOTICE.md)、[CHANGELOG.md](CHANGELOG.md)、[PUBLISHING.md](PUBLISHING.md)。
