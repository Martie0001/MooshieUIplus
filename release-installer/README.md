# MooshieUIplus B｜Windows 免編譯模組管理器

**適用 Windows x64、官方 MooshieUI 2.3.49。** 這是整合模組的 EXE 替換包，並非可在空白電腦直接安裝 ComfyUI 的完整安裝器。

## 首次使用：從模組管理器安裝

1. 先安裝並確認官方 **MooshieUI 2.3.49** 可正常啟動，且已有可運作的 ComfyUI 後端。
2. 將整個 B ZIP 解壓縮到任意資料夾。**不要只複製模組管理器檔案**，需保留 payload、manifest、安裝器的相對位置。
3. 雙擊根目錄 **`啟動模組管理.cmd`**。首次點選「選擇程式」，指定原本安裝的 `comfyui-desktop.exe`。
4. 關閉 MooshieUI，點選「安裝／更新本地套件」，核對提示後確認。
5. 管理器會檢查相容版本及 SHA256，由安裝器備份原始 EXE，成功後才替換。原始模型、設定與輸出不會被修改。

## 後續從 GitHub Releases 更新

1. 開啟同一個 **`啟動模組管理.cmd`**，按下「檢查 GitHub 更新」。
2. 只搜尋公開、非預先發行，且與目前已安裝 **MooshieUI 主程式版本相同**的 B 版。
3. 有相容發布版時，關閉 MooshieUI，按下「安裝發布版」並再次確認。
4. 管理器會從 `Martie0001/MooshieUIplus` 的 GitHub Release 下載 B ZIP、核對檔案大小與可用的 GitHub SHA256 digest、核對 ZIP 內 EXE SHA256、備份原版，再部署。
5. **不會背景自動更新或跨 MooshieUI 版本升級。** GitHub 尚未建立 Release 時會顯示沒有可用發布版，這是正常結果。

> 目前四個模組共用同一個編譯後 EXE；不能將管理器的選單誤認為可獨立熱插拔的 ComfyUI custom nodes。發布版更新 EXE，不會自動替換已開啟的模組管理器本身；要更新管理器介面請重新下載新版 B ZIP。

## 備份與還原

- 管理器「還原備份」使用與目前 EXE 位置相符的最新備份。
- 備份在 `%LOCALAPPDATA%\MooshieUIplus\history\exe-backups`；不要刪除這個資料夾。
- 舊版相容入口 `安裝.cmd`、`還原.cmd` 仍保留。
- 更新與檢查紀錄在 `%LOCALAPPDATA%\MooshieUIplus\temp`。
- MooshieUI 執行中時安裝器會拒絕替換；失敗時由既有安裝器嘗試從本次備份回復。

## 編譯環境與功能依賴

- **B 版不需要** Node.js、npm、Git、Rust/Cargo、Visual Studio C++ Build Tools 或 Windows SDK。
- WebView2 與 ComfyUI 後端仍是 MooshieUI 本身正常執行的前提。
- **Prompt Generator** 的獨立服務、外部 TAG 原始資料與 Ollama 不在 ZIP 內，須另行配置。
- **Creative Tools** 部分功能需要對應的 ComfyUI 節點與 ControlNet 權重。
- B ZIP 不含任何使用者 LoRA、模型權重、個人路徑或分類資料。

開發者可另下載同一發布版中的 **A 完整整合原始碼包**，依其說明安裝建置工具並編譯。

本套件基於上游 MooshieUI 2.3.49（AGPL-3.0）。請閱讀 `LICENSE`、`NOTICE.md`。公開發布前仍須確認 TAG 中英詞庫的再散布權利。尚未完成其他電腦的完整 GUI／生圖驗收，不應宣稱全部功能都已驗收通過。

GitHub：<https://github.com/Martie0001/MooshieUIplus>。**目前只是發布候選，沒有授權上傳。**
