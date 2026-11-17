# NOTICE / 第三方授權說明

- MooshieUIplus 基於 MooshieUI 2.3.51（https://github.com/Mooshieblob1/MooshieUI）進行原始碼整合。
- 本次 2.3.51 上游對應 Git commit：`40daf5eb2b2e51a53b04cfd522ea3ad508d1b2c6`。
- 上游程式使用 GNU Affero General Public License v3.0（AGPL-3.0）。隨附 `LICENSE` 並提供對應版本完整整合原始碼；發行修改版 EXE 時應讓使用者能取得該原始碼。
- 自訂模組及整合程式碼採 AGPL-3.0 再散布；若含其他第三方素材，仍須遵守其各自授權。
- Windows 模組管理介面參考 [bsmg/ModAssistant](https://github.com/bsmg/ModAssistant) 的 WPF/XAML 側邊導覽及模組清單版面，原作 Copyright (c) 2019–2020 Assistant，依 MIT License 使用。MIT 授權聲明與全文保留於 `release-installer/模組管理器.ps1`。原 Beat Saber／BeatMods 安裝程式及服務未嵌入 MooshieUIplus。
- 部分 TAG 中文對照可能含來自外部資料的整理條目；**公開發布前仍需確認該資料的原始來源與再散布權利**。本文不宣稱已完成素材授權驗證。
- **B 版附 Node.js 22.18.0 Windows x64 可攜執行檔**，下載自 https://nodejs.org/dist/v22.18.0/ ，按 Node.js 原始 `LICENSE` 與第三方元件條款再散布；完整授權文附於 B ZIP 的 `payload/PromptGenerator/NODE-LICENSE.txt`，安裝後保留在 `MooshieUIplus/PromptGenerator/NODE-LICENSE.txt`。此 Node runtime 僅供 Prompt Generator 使用。
- **Ollama 不隨安裝包提供**；使用 Prompt Generator 的 AI 功能前，使用者需另行安裝、啟動並準備自己的聊天模型，見 https://ollama.com/download 。
- B ZIP 隨附 `MooshieSkinContrast` 所需的 175,140-byte `skin_contrast_1x.safetensors`（1xSkinContrast-High-SuperUltraCompact，CC0-1.0），並在 `payload/ComfyNodes/skin_contrast_1x.LICENSE` 保留授權及來源；同時隨附 Anima ArtStyle 節點與對應授權檔。
- 套件不包含私人 LoRA／基礎生圖模型權重、生成圖片、個人設定、私密路徑或帳號憑證。
