# GitHub 發布與後續更新規則

## 版本與範圍

本儲存庫管理 MooshieUIplus source-level 模組、Windows B 版模組管理器與對應的原始碼發行包。上游為 MooshieUI，請依 `NOTICE.md`、`LICENSE` 及 Release 中的 A 原始碼包確認授權資訊。

**每次完成實際模組更新、通過必要驗收並決定對外發布時，應同步更新 GitHub 原始碼與 A/B 發布資產。** 不可只更新本機模組而將 GitHub 標成最新版，亦不可只替換 B EXE 卻不提供對應 A 原始碼。

## 同步順序

1. 確認正式 MooshieUI 主版本與改動範圍，不跨版覆蓋；保留本機原始模型、設定及輸出。
2. 更新模組來源並完成必要建置、目標功能與安裝／還原測試，未測試部分明確列為「未驗證」。
3. 建立相同上游版本的 **A 完整整合原始碼 ZIP** 與 **B 已編譯 Windows ZIP**，B `manifest.json` 的 `sourcePackage` 必須指向本次 A ZIP，`payloadSha256` 必須符合內含 EXE。
4. 確認檔案不包含模型權重、使用者私有設定、個人資料、金鑰、密碼或暫存歷史；檢查第三方素材授權及 README／NOTICE。
5. 將新的 `module-manager/`、四個模組來源、`release-installer/`、`README.md`、`LICENSE`、`NOTICE.md` 同步到 GitHub 預設分支。
6. 在 GitHub 建立新的、不可重複使用的版本標籤，附上 **同一輪** A/B ZIP，列出真實驗證範圍、已知限制及 SHA256。
7. 以 GitHub 實際 API 重新讀取 commit、Release 與附件，確認對外可見且 A/B 對應正確，才回報「已發布」。

**不得在沒有實際上傳證據時宣稱 GitHub 已同步。** 發布後的更新由 B 版管理器「檢查 GitHub 更新」觸發；使用者仍需明確按下「安裝發布版」，不會靜默升版。模組管理器腳本本身不會在此更新流程中自我覆蓋，如有管理器程式更新，須下載新版 B ZIP。

## A 與 B 的差異

- A：供開發者編譯的完整原始碼（需要 Node/npm、Git、Rust、C++ Build Tools、Windows SDK）。
- B：供已安裝並能啟動相容 MooshieUI/ComfyUI 的一般使用者，提供圖形化管理器及已編譯 EXE，不需要編譯工具。
- 模組目前嵌入共用 EXE，**不是四個可分開安裝的熱插拔外掛**。

## 尚待確認的第三方資料

TAG 中英對照來源包含由本地詞庫整理的條目，再散布授權尚未完全核實。此限制必須持續明示，不得以本文件或 AGPL 字樣取代第三方資料本身的授權確認。
