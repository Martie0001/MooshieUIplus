# MooshieUIplus｜GitHub 模組管理器

Windows 一般使用者不需 Node.js、Rust、Git 或 C++ 編譯環境。此工具需要**先安裝且可啟動的 MooshieUI／ComfyUI**，不是完整主程式安裝器。

## 日常使用（不需 CMD）

1. 下載 B Windows ZIP，解壓縮後直接雙擊 **`啟動模組管理.vbs`**。不必打開 PowerShell 或 CMD。
2. 首次選擇 MooshieUI 的 `comfyui-desktop.exe`，下次會記住選取的位置。
3. 按下 **「檢查 GitHub 並更新」**，管理器會讀取 GitHub Release 更新資訊，比對本機 EXE 與管理器版本。
4. 若已是最新版，顯示結果，不下載完整更新包。若有更新，會顯示確認視窗，確認後再下載／安裝。
5. 若只有管理器改版，優先下載小型管理器 ZIP；若整合 EXE 改版，才下載 B Windows ZIP。下載過的有效 ZIP 保存在本機快取，下次可重用。
6. EXE 更新前會自動備份，必要時按 **「還原備份」**；有新的管理器時重開管理器即可使用新介面。

整合模組包含 LoRA Manager、TAG Manager、Prompt Generator、Creative Tools。**目前模組共用已編譯 EXE，不支援將這四個模組獨立熱插拔。** 版本比對以實際安裝的 MooshieUI 主版本為準，不能跨版本覆蓋。

## 下載量

- **只檢查版本：** 讀取 GitHub Release JSON 與小型更新資訊；不下載 ZIP。
- **相同版本：** 不下載 ZIP。
- **只有管理器程式變更：** 下載小型管理器 ZIP。
- **整合 EXE 變更：** 下載一次完整 B ZIP；該 ZIP 的檔案大小由 Release 實際內容決定。
- **相同 ZIP 重裝：** 優先使用雜湊一致的本機快取。

快取：`%LOCALAPPDATA%\MooshieUIplus\cache\releases`。操作日誌：`%LOCALAPPDATA%\MooshieUIplus\temp`。備份：`%LOCALAPPDATA%\MooshieUIplus\history`。

## 離線安裝

在解壓完整 B Windows ZIP 的資料夾中，管理器會啟用「本地套件安裝」；若是在你已安裝的精簡管理器資料夾中，這項會停用，但 GitHub 直接更新與還原仍可使用。

## A 開發者版本

原始碼包仍保留 `module-manager/module-manager.ps1` 的開發者編譯功能，不受一般使用者免編譯管理器切換影響。

## 限制

- Prompt Generator 的外部服務、TAG 私有資料與 Ollama 不會隨 B ZIP 自動配置。
- Creative Tools 部分功能依賴對應 ComfyUI 節點／模型。
- TAG 詞庫原始來源與再散布權利仍待進一步釐清；請參閱 `NOTICE.md`。
- 未完成其他電腦的完整 UI／生圖驗收，不得宣稱所有功能通過。

GitHub：<https://github.com/Martie0001/MooshieUIplus>
