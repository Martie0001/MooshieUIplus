# GitHub 發布與後續更新規則

## 版本與範圍

本儲存庫管理 MooshieUIplus source-level 模組、Windows B 版模組管理器與對應的原始碼發行包。上游為 MooshieUI，請依 `NOTICE.md`、`LICENSE` 及 Release 中的 A 原始碼包確認授權資訊。

**每次完成實際模組更新、通過必要驗收並決定對外發布時，應同步更新 GitHub 原始碼與 A/B 發布資產。** 不可只更新本機模組而將 GitHub 標成最新版，亦不可只替換 B EXE 卻不提供對應 A 原始碼。

## 版本號規則

- MooshieUIplus 使用 `MAJOR.MINOR.PATCH`，自 `0.1.0` 開始。功能擴充提升 MINOR；向下相容的缺陷修復提升 PATCH；重大不相容變動提升 MAJOR。版本不得因為只執行重複測試而增加。
- 官方 MooshieUI 版本另標示（目前為 `2.3.49`）；各模組維持既有 `dev/version.json`，只有該模組功能實際變更時更新。
- 每次發布必須更新 `CHANGELOG.md`，分別列出「新增」「修復」「已知問題」及「實際驗證」。Windows 管理器顯示自己的產品版號與模組版次，不把上游版本誤作套件版號。
- 歷史 RC 標籤不重命名、不覆蓋；新版本使用新的 GitHub Release 標籤及 A/B 資產。

## 同步順序

1. 確認正式 MooshieUI 主版本與改動範圍，不跨版覆蓋；保留本機原始模型、設定及輸出。
2. 更新模組來源並完成必要建置、目標功能與安裝／還原測試，未測試部分明確列為「未驗證」。
3. 建立同一上游版本的 **A 整合原始碼 ZIP**、**B 已編譯 Windows ZIP**、**Manager 小型 ZIP（含 `MooshieUIplus-Manager.exe`）** 與 **B 更新資訊 JSON**。B `sourcePackage` 必須指向 A ZIP，`payloadSha256` 符合 EXE；更新資訊需對應本次 B ZIP、EXE、Node.js 可攜 runtime、原始授權檔、管理器 `MooshieUIplus-Manager.exe` 與各檔 SHA256。
4. 確認檔案不包含模型權重、使用者私有設定、個人資料、金鑰、密碼或暫存歷史；檢查第三方素材授權及 README／NOTICE。
5. 將新的 `module-manager/`、四個模組來源、`release-installer/`、`README.md`、`LICENSE`、`NOTICE.md` 同步到 GitHub 預設分支。
6. 在 GitHub 建立新的版本標籤，附上同一輪 A／B ZIP、Manager 小型 ZIP、B 更新資訊 JSON。列出實際測試範圍、已知限制與 SHA256；不得覆蓋舊 Release。
7. 以 GitHub 實際 API 重新讀取 commit、Release 與附件，確認對外可見且 A/B 對應正確，才回報「已發布」。

**不得在沒有實際上傳證據時宣稱 GitHub 已同步。** 正式管理器的「檢查 GitHub 並更新」先讀取小型 JSON，比對 EXE／管理器雜湊；相同版本不抓 ZIP，只有管理器變更下載 Manager ZIP，有 EXE 變更才下載 B ZIP。下載包透過 SHA256 驗證並保留快取；安裝必須有使用者確認，不靜默升版。管理器程式更新後重新開啟視窗即生效，正式 EXE 更新前自動備份。

## A 與 B 的差異

- A：供開發者編譯的完整原始碼（需要 Node/npm、Git、Rust、C++ Build Tools、Windows SDK）。
- B：供已安裝並能啟動相容 MooshieUI/ComfyUI 的一般使用者，提供圖形化管理器及已編譯 EXE，不需要編譯工具。
- 模組目前嵌入共用 EXE，**不是四個可分開安裝的熱插拔外掛**。

## 尚待確認的第三方資料

TAG 中英對照來源包含由本地詞庫整理的條目，再散布授權尚未完全核實。此限制必須持續明示，不得以本文件或 AGPL 字樣取代第三方資料本身的授權確認。
