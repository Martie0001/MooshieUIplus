param(
  [ValidateSet("", "Backup", "Restore", "Overwrite")][string]$Action = "",
  [ValidateSet("all", "lora-browser", "tag-zh-tw", "prompt-generator", "creative-tools")][string]$Module = "all",
  [string]$Snapshot = "",
  [string]$ResultFile = "",
  [string]$ProgressFile = "",
  [switch]$ConfirmVersionOverwrite
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$backupDir = Join-Path $root "history\module-backups"
$settingsFile = Join-Path $root "module-manager\local-settings.json"
$appExe = Join-Path (Split-Path -Parent $root) "MooshieUI\comfyui-desktop.exe"
$source = Join-Path $root "source"
$settings = $null
if (Test-Path -LiteralPath $settingsFile) {
  $settings = Get-Content -LiteralPath $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($settings.appExe) { $appExe = [string]$settings.appExe }
}
# Prefer an already prepared source matching the installed version; never compile an older source.
$runtimeTarget = if (Test-Path -LiteralPath $appExe) { (Get-Item $appExe).VersionInfo.ProductVersion } else { "" }
$preparedSource = Join-Path $root ("temp\source-v" + $runtimeTarget)
if ($runtimeTarget -and (Test-Path -LiteralPath (Join-Path $preparedSource "package.json"))) {
  $preparedVersion = (Get-Content -LiteralPath (Join-Path $preparedSource "package.json") -Raw -Encoding UTF8 | ConvertFrom-Json).version
  if ($preparedVersion -eq $runtimeTarget) {
    $preparedItem = Get-Item -LiteralPath $preparedSource -Force
    $resolvedSource = if ($preparedItem.LinkType -eq "Junction") { [string]@($preparedItem.Target)[0] } else { $preparedSource }
    if (Test-Path -LiteralPath (Join-Path $resolvedSource "package.json")) { $source = $resolvedSource }
  }
}
if ($settings -and $settings.source -and (Test-Path -LiteralPath (Join-Path ([string]$settings.source) "package.json"))) {
  $source = [string]$settings.source
}

# Only the UI setup asks for paths. CLI operations do not invent paths or modify settings.
if ($Action -eq "") {
  Add-Type -AssemblyName System.Windows.Forms
  if (-not (Test-Path -LiteralPath $appExe)) {
    $pickExe = New-Object System.Windows.Forms.OpenFileDialog
    $pickExe.Title = "選擇已安裝的 MooshieUI comfyui-desktop.exe"
    $pickExe.Filter = "MooshieUI 執行檔 (comfyui-desktop.exe)|comfyui-desktop.exe"
    if ($pickExe.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $appExe = $pickExe.FileName }
  }
  $targetVersion = if (Test-Path -LiteralPath $appExe) { (Get-Item $appExe).VersionInfo.ProductVersion } else { "" }
  $sourceVersion = if (Test-Path -LiteralPath (Join-Path $source "package.json")) {
    (Get-Content -LiteralPath (Join-Path $source "package.json") -Raw -Encoding UTF8 | ConvertFrom-Json).version
  } else { "" }
  if ($targetVersion -and $sourceVersion -ne $targetVersion) {
    $pickSource = New-Object System.Windows.Forms.FolderBrowserDialog
    $pickSource.Description = "請選取與 MooshieUI $targetVersion 相同版本的官方原始碼資料夾（包含 package.json）"
    if ($pickSource.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK -and
        (Test-Path -LiteralPath (Join-Path $pickSource.SelectedPath "package.json"))) {
      $source = $pickSource.SelectedPath
    }
  }
  if (Test-Path -LiteralPath $appExe) {
    [ordered]@{ appExe = $appExe; source = $source } |
      ConvertTo-Json | Set-Content -LiteralPath $settingsFile -Encoding UTF8
  }
}
$paths = @(
  "src/lib/components/generation/LoraGallery.svelte",
  "src/lib/components/generation/PromptTextarea.svelte",
  "src/lib/stores/autocomplete.svelte.ts",
  "src/lib/addons/lora-browser",
  "src/lib/addons/tag-zh-tw",
  "src/lib/components/generation/BottomPanel.svelte",
  "src/App.svelte",
  "src/lib/components/gallery/GalleryPage.svelte",
  "src/lib/stores/generation.svelte.ts",
  "src/lib/components/generation/GenerationPage.svelte",
  "src/lib/components/generation/CreativeToolsPanel.svelte",
  "src/lib/components/generation/CreativeComicEditor.svelte",
  "src/lib/components/generation/CreativePoseEditor.svelte",
  "src/lib/utils/creativeOutpaint.ts",
  "src/lib/utils/creativeReference.ts",
  "src/lib/utils/creativePose.ts",
  "src/lib/utils/creativeImage.ts",
  "src/lib/addons/prompt-generator",
  "src-tauri/src/lib.rs",
  "src-tauri/src/commands/mod.rs",
  "src-tauri/src/commands/picture_generator.rs",
  "src-tauri/src/commands/lora_info.rs",
  "src-tauri/src/webserver.rs",
  "src-tauri/src/templates/controlnet.rs"
)

# Checkpoint-based progress. No guessed percentages are reported for compilation.
function Publish-Progress([int]$done, [int]$total, [string]$stage, [string]$detail) {
  if (-not $ProgressFile) { return }
  try {
    [ordered]@{
      completed = $done
      total = $total
      stage = $stage
      detail = $detail
      updatedAt = (Get-Date).ToString("o")
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath $ProgressFile -Encoding UTF8
  } catch {
    Write-Warning ("進度更新失敗：" + $_.Exception.Message)
  }
}

function Get-ModuleFolder([string]$id) {
  switch ($id) {
    "lora-browser" { return "lora-manager" }
    "tag-zh-tw" { return "tag-manager" }
    default { return $id }
  }
}

function Get-ModuleInfo([string]$id) {
  $p = Join-Path (Join-Path $root (Get-ModuleFolder $id)) "dev\version.json"
  if (-not (Test-Path -LiteralPath $p)) { throw "找不到版本資訊：$p" }
  return (Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-Snapshots {
  if (-not (Test-Path $backupDir)) { return @() }
  return @(Get-ChildItem -LiteralPath $backupDir -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName "manifest.json")
  } | Sort-Object Name -Descending)
}

function Assert-AppClosed {
  $process = Get-Process -Name "comfyui-desktop" -ErrorAction SilentlyContinue | Where-Object {
    try { $_.Path -eq $appExe } catch { $false }
  }
  if ($process) { throw "MooshieUI 目前執行中，請先關閉程式，再執行復原或覆蓋。" }
}

function Backup-Modules([string]$reason) {
  New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
  $id = (Get-Date -Format "yyyyMMdd-HHmmss-fff")
  $dest = Join-Path $backupDir $id
  New-Item -Path $dest -ItemType Directory | Out-Null
  if ($Action -eq "Backup") { Publish-Progress 1 4 "備份來源檔案" "備份資料夾已建立；正在複製整合原始碼。" }
  foreach ($rel in $paths) {
    $from = Join-Path $source $rel
    if (-not (Test-Path -LiteralPath $from)) { continue }
    $to = Join-Path $dest ("source\" + ($rel -replace "/", "\"))
    New-Item -Path (Split-Path -Parent $to) -ItemType Directory -Force | Out-Null
    Copy-Item -LiteralPath $from -Destination $to -Recurse -Force
  }
  if ($Action -eq "Backup") { Publish-Progress 2 4 "備份正式程式" "原始碼已複製；正在備份目前的 MooshieUI exe。" }
  if (Test-Path -LiteralPath $appExe) {
    $target = Join-Path $dest "runtime\comfyui-desktop.exe"
    New-Item -Path (Split-Path -Parent $target) -ItemType Directory -Force | Out-Null
    Copy-Item -LiteralPath $appExe -Destination $target
  }
  if ($Action -eq "Backup") { Publish-Progress 3 4 "保存備份資訊" "正式 exe 已複製；正在寫入版本與備份清單。" }
  $info = [ordered]@{
    schemaVersion = 1
    createdAt = (Get-Date).ToString("o")
    reason = $reason
    appVersion = if (Test-Path $appExe) { (Get-Item $appExe).VersionInfo.ProductVersion } else { $null }
    loraBrowserVersion = (Get-ModuleInfo "lora-browser").version
    tagVersion = (Get-ModuleInfo "tag-zh-tw").version
    promptGeneratorVersion = (Get-ModuleInfo "prompt-generator").version
    creativeToolsVersion = (Get-ModuleInfo "creative-tools").version
    paths = $paths
  }
  $info | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $dest "manifest.json") -Encoding UTF8
  if ($Action -eq "Backup") { Publish-Progress 4 4 "備份完成" "備份資料、版本清單及執行檔已寫入。" }
  Write-Host "備份完成：$dest"
  return $dest
}

function Restore-Modules([string]$name) {
  Publish-Progress 0 5 "檢查備份" "正在確認選擇的備份版本與檔案。"
  if (-not $name -or $name -ne [IO.Path]::GetFileName($name)) { throw "無效的備份名稱。" }
  $dest = Join-Path $backupDir $name
  if (-not (Test-Path -LiteralPath (Join-Path $dest "manifest.json"))) { throw "備份不存在或缺少 manifest。" }
  Assert-AppClosed
  $manifest = Get-Content -LiteralPath (Join-Path $dest "manifest.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($manifest.schemaVersion -ne 1) { throw "不支援的備份格式。" }
  Publish-Progress 1 5 "備份現況" "備份檔案有效；正在保存目前版本以便再次復原。"
  Backup-Modules "復原前自動備份" | Out-Null
  Publish-Progress 2 5 "復原原始碼" "目前版本已備份；正在還原整合元件。"
  # Older snapshots did not contain newly introduced module files. Restore only
  # the paths actually captured by that snapshot to avoid deleting live source.
  foreach ($rel in @($manifest.paths)) {
    $from = Join-Path $dest ("source\" + ($rel -replace "/", "\"))
    $to = Join-Path $source $rel
    if (-not (Test-Path -LiteralPath $from)) {
      if (Test-Path -LiteralPath $to) { Remove-Item -LiteralPath $to -Recurse -Force }
      continue
    }
    if (Test-Path -LiteralPath $to -PathType Container) { Remove-Item -LiteralPath $to -Recurse -Force }
    New-Item -Path (Split-Path -Parent $to) -ItemType Directory -Force | Out-Null
    Copy-Item -LiteralPath $from -Destination $to -Recurse -Force
  }
  Publish-Progress 3 5 "復原正式程式" "原始碼已還原；正在復原備份中的 exe。"
  $exe = Join-Path $dest "runtime\comfyui-desktop.exe"
  if (Test-Path -LiteralPath $exe) { Copy-Item -LiteralPath $exe -Destination $appExe -Force }
  Publish-Progress 4 5 "核對復原結果" "已處理執行檔；正在完成復原。"
  Write-Host "復原完成：$name。data 目錄及設定未變更。"
  Publish-Progress 5 5 "復原完成" "原始碼與正式程式已按備份還原。"
}

function Overwrite-Modules([string]$id) {
  Publish-Progress 0 6 "檢查版本與環境" "確認 MooshieUI 已關閉，檢查正式版與原始碼版本。"
  Assert-AppClosed
  $sourcePackage = Join-Path $source "package.json"
  if (-not (Test-Path -LiteralPath $sourcePackage)) { throw "找不到開發原始碼版本資訊。" }
  $sourceVersion = (Get-Content -LiteralPath $sourcePackage -Raw -Encoding UTF8 | ConvertFrom-Json).version
  $runtimeVersion = if (Test-Path -LiteralPath $appExe) { (Get-Item $appExe).VersionInfo.ProductVersion } else { $null }
  if (-not $runtimeVersion) { throw "無法讀取正式 MooshieUI 版本，停止覆蓋以避免誤裝。" }
  if ($sourceVersion -ne $runtimeVersion) {
    throw "禁止降版：正式程式 $runtimeVersion 與待建置原始碼 $sourceVersion 不同。請使用對應官方版本的原始碼。"
  }
  Publish-Progress 1 6 "備份目前版本" "已確認版本風險，正在備份正式 exe 與原始碼。"
  Backup-Modules "覆蓋前自動備份" | Out-Null
  Publish-Progress 2 6 "套用模組" "備份完成；正在將選取的模組套用至原始碼。"
  # All four add-ons share the same compiled EXE. Always reapply them together
  # so rebuilding a selected module cannot silently drop another add-on.
  $installers = @("tag-zh-tw", "prompt-generator", "lora-browser", "creative-tools")
  $personalTag = Join-Path (Split-Path -Parent $root) "module_data\MooshieUI\tag-manager\tags.zh-TW.json"
  if (-not $env:MOOSHIEUI_TAG_DICTIONARY -and (Test-Path -LiteralPath $personalTag)) {
    $env:MOOSHIEUI_TAG_DICTIONARY = $personalTag
  }
  $gallery = Join-Path $source "src\lib\components\generation\LoraGallery.svelte"
  $isClean = -not ((Get-Content -LiteralPath $gallery -Raw -Encoding UTF8).Contains("import LoraFilterBar"))
  if ($isClean) {
    Write-Host "全新官方原始碼：套用 MooshieUI 2.3.49 整合基準補丁。"
    & node (Join-Path $root "module-manager\install-clean.mjs") $source
    if ($LASTEXITCODE -ne 0) { throw "乾淨安裝失敗，已停止建置與覆蓋。" }
  } else {
    foreach ($m in $installers) {
      $script = Join-Path (Join-Path $root (Get-ModuleFolder $m)) "dev\install.mjs"
      if (-not (Test-Path $script)) { throw "缺少安裝腳本：$script" }
      Write-Host "套用模組：$m"
      & node $script $source
      if ($LASTEXITCODE -ne 0) { throw "模組 $m 安裝失敗，已停止建置與覆蓋。" }
    }
  }
  Publish-Progress 3 6 "編譯 MooshieUI" "模組已套用；正在進行前端與 Rust／Tauri 編譯，此階段沒有可靠百分比。"
  $cargoBin = Join-Path $env:USERPROFILE ".cargo\bin"
  if (Test-Path -LiteralPath (Join-Path $cargoBin "cargo.exe")) { $env:PATH = $cargoBin + ";" + $env:PATH }
  $builder = Join-Path $source "node_modules\.bin\tauri.cmd"
  if (-not (Test-Path $builder)) { throw "缺少 Tauri 建置工具：$builder" }
  $buildWithVs = Join-Path $root "module-manager\build-with-vs.cmd"
  if (-not (Test-Path -LiteralPath $buildWithVs)) { throw "缺少 Visual Studio 建置環境啟動器。" }
  Write-Host "建置 MooshieUI（原始碼版本）..."
  Push-Location $source
  try { & $buildWithVs $source; if ($LASTEXITCODE -ne 0) { throw "Tauri 建置失敗；正式程式未覆蓋。" } }
  finally { Pop-Location }
  Publish-Progress 4 6 "檢查建置成品" "編譯完成；確認新的 Windows exe 是否可用。"
  $built = Join-Path $source "src-tauri\target\release\comfyui-desktop.exe"
  if (-not (Test-Path $built)) { throw "沒有找到建置成品：$built" }
  $exeInfo = (Get-Item $built).VersionInfo.ProductVersion
  if (-not $exeInfo) { throw "建置檔缺少版本資訊，停止覆蓋。" }
  Publish-Progress 5 6 "部署正式程式" "建置成品有效；確認程式已關閉並將 exe 覆蓋至安裝目錄。"
  Assert-AppClosed
  Copy-Item -LiteralPath $built -Destination $appExe -Force
  Publish-Progress 6 6 "覆蓋完成" "正式 exe 已替換，未修改 data、模型或設定。"
  Write-Host "覆蓋成功：MooshieUI $exeInfo。未變更 data、模型及設定。"
}

if ($Action -ne "") {
  try {
    switch ($Action) {
      "Backup" { Publish-Progress 0 4 "準備備份" "檢查路徑與備份環境。"; Backup-Modules "手動備份" | Out-Null }
      "Restore" { Restore-Modules $Snapshot }
      "Overwrite" { Overwrite-Modules $Module }
    }
    # Start-Process -PassThru can yield a null ExitCode in Windows PowerShell 5.1.
    # Emit a completion record only after the requested action finishes successfully.
    if ($ResultFile) {
      $result = [ordered]@{
        status = "success"
        action = $Action
        completedAt = (Get-Date).ToString("o")
      }
      $result | ConvertTo-Json | Set-Content -LiteralPath $ResultFile -Encoding UTF8
    }
  } catch {
    Write-Host ("執行失敗：" + $_.Exception.Message) -ForegroundColor Red
    exit 1
  }
  exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object System.Windows.Forms.Form
$form.Text = "MooshieUIplus｜模組管理"
$form.Size = [System.Drawing.Size]::new(720, 670)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = [System.Drawing.Size]::new(680, 630)
$form.Font = [System.Drawing.Font]::new("Microsoft JhengHei", 10)
$form.BackColor = [Drawing.Color]::FromArgb(30, 34, 40)
$form.ForeColor = [Drawing.Color]::White

function Label($text, $x, $y, $w, $h) {
  $c = [System.Windows.Forms.Label]::new()
  $c.Text = $text; $c.SetBounds($x, $y, $w, $h)
  $form.Controls.Add($c); return $c
}
function Button($text, $x, $y, $w, $h) {
  $c = [System.Windows.Forms.Button]::new()
  $c.Text = $text; $c.SetBounds($x, $y, $w, $h)
  $c.BackColor = [Drawing.Color]::FromArgb(53, 60, 73)
  $c.ForeColor = [Drawing.Color]::White
  $c.FlatStyle = "Flat"
  $form.Controls.Add($c); return $c
}

Label "MooshieUIplus 模組管理" 20 20 600 30 | Out-Null
Label "選擇模組" 20 68 110 26 | Out-Null
$picker = New-Object System.Windows.Forms.ComboBox
$picker.SetBounds(130, 65, 540, 28)
$picker.DropDownStyle = "DropDownList"
[void]$picker.Items.Add("全部模組")
[void]$picker.Items.Add("LoRA 瀏覽／資訊管理")
[void]$picker.Items.Add("TAG 中文對照")
[void]$picker.Items.Add("Prompt Generator")
[void]$picker.Items.Add("Creative Tools")
$picker.SelectedIndex = 0
$form.Controls.Add($picker)

$infoBox = New-Object System.Windows.Forms.TextBox
$infoBox.SetBounds(20, 109, 650, 137)
$infoBox.ReadOnly = $true
$infoBox.Multiline = $true
$infoBox.BackColor = [Drawing.Color]::FromArgb(40, 44, 52)
$infoBox.ForeColor = [Drawing.Color]::White
$infoBox.ScrollBars = "Vertical"
$form.Controls.Add($infoBox)

Label "選擇備份版本" 20 266 120 25 | Out-Null
$snapshots = New-Object System.Windows.Forms.ComboBox
$snapshots.SetBounds(145, 263, 385, 28)
$snapshots.DropDownStyle = "DropDownList"
$form.Controls.Add($snapshots)
$reload = Button "更新清單" 540 263 130 30

$backup = Button "備份" 20 320 150 42
$restore = Button "復原" 187 320 150 42
$overwrite = Button "覆蓋安裝" 354 320 150 42
$folder = Button "開啟備份資料夾" 521 320 150 42
$help = Label "備份包含原始碼模組及目前正式 exe；復原會還原整套整合版，不會修改 data/。`r`n覆蓋安裝：先備份 → 套用模組 → 編譯 → 核對版本 → 替換 exe（須關閉 MooshieUI）。" 20 555 650 55
$help.ForeColor = [Drawing.Color]::LightGray

function Selected-Module {
  switch ($picker.SelectedIndex) { 1 { "lora-browser" } 2 { "tag-zh-tw" } 3 { "prompt-generator" } 4 { "creative-tools" } default { "all" } }
}
function Refresh-Info {
  $lora = Get-ModuleInfo "lora-browser"
  $tag = Get-ModuleInfo "tag-zh-tw"
  $pg = Get-ModuleInfo "prompt-generator"
  $creative = Get-ModuleInfo "creative-tools"
  $app = if (Test-Path $appExe) { (Get-Item $appExe).VersionInfo.ProductVersion } else { "未找到" }
  $packageJson = Join-Path $source "package.json"
  $sourceVersion = if (Test-Path -LiteralPath $packageJson) { (Get-Content -LiteralPath $packageJson -Raw -Encoding UTF8 | ConvertFrom-Json).version } else { "未找到" }
  $selected = Selected-Module
  $detail = switch ($selected) {
    "lora-browser" { "$($lora.description)" }
    "tag-zh-tw" { "$($tag.description)" }
    "prompt-generator" { "$($pg.description)" }
    "creative-tools" { "$($creative.description)" }
    default { "LoRA：$($lora.description)`r`nTAG：$($tag.description)`r`nPrompt Generator：$($pg.description)`r`nCreative Tools：$($creative.description)" }
  }
  $compatibilityNote = if ($app -ne $sourceVersion) { "正式版 $app 與目前可用原始碼 $sourceVersion 不一致；禁止以舊版覆蓋。請先準備相同版本原始碼。" } else { "已使用與正式版相同版本的原始碼（模組仍須經建置驗證）。" }
  $infoBox.Text = "正式 MooshieUI：$app`r`n開發原始碼：$sourceVersion`r`nLoRA 套件版本：$($lora.version)`r`nTAG 套件版本：$($tag.version)`r`nPrompt Generator：$($pg.version)`r`nCreative Tools：$($creative.version)`r`n$compatibilityNote`r`n`r`n說明：$detail"
  if ($null -eq $script:workerProcess) { $overwrite.Enabled = $app -eq $sourceVersion }
  $overwrite.Refresh()
}
function Refresh-Backups {
  $snapshots.Items.Clear()
  foreach ($dir in (Get-Snapshots)) { [void]$snapshots.Items.Add($dir.Name) }
  if ($snapshots.Items.Count -gt 0) { $snapshots.SelectedIndex = 0 }
}
# Keep long-running operations separate from the UI thread and hide console windows.
$script:workerProcess = $null
$script:workerOperation = ""
$script:workerLog = ""
$script:workerErrorLog = ""
$script:workerResultFile = ""
$script:workerAction = ""
$script:workerProgressFile = ""
$script:workerStartAt = $null
$script:workerTimer = [System.Windows.Forms.Timer]::new()
$script:workerTimer.Interval = 1000
$overallLabel = Label "整體進度：尚未執行" 20 372 650 20
$overallBar = [System.Windows.Forms.ProgressBar]::new()
$overallBar.SetBounds(20, 393, 650, 18)
$overallBar.Minimum = 0; $overallBar.Maximum = 6; $overallBar.Value = 0
$overallBar.Style = "Blocks"
$form.Controls.Add($overallBar)
$overallDetail = Label "依實際完成步驟更新，並非編譯耗時百分比。" 20 413 650 19
$overallDetail.ForeColor = [Drawing.Color]::LightGray
$phaseLabel = Label "目前步驟：尚未開始" 20 437 650 20
$phaseBar = [System.Windows.Forms.ProgressBar]::new()
$phaseBar.SetBounds(20, 457, 650, 18)
$phaseBar.Style = "Continuous"; $phaseBar.Minimum = 0; $phaseBar.Maximum = 100
$form.Controls.Add($phaseBar)
$activityDetail = Label "執行說明與最新日誌將顯示在這裡。" 20 480 650 38
$activityDetail.ForeColor = [Drawing.Color]::LightGray
$statusLine = Label "就緒｜此視窗不依附任何 CMD" 20 528 650 22
$statusLine.ForeColor = [Drawing.Color]::LightGray
$script:workerTimer.Add_Tick({
  if ($null -eq $script:workerProcess) { $script:workerTimer.Stop(); return }
  $script:workerProcess.Refresh()

  # Read a real checkpoint reported by the worker process.
  $progress = $null
  if ($script:workerProgressFile -and (Test-Path -LiteralPath $script:workerProgressFile)) {
    try {
      $progress = Get-Content -LiteralPath $script:workerProgressFile -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
    } catch {
      # The file may be in the middle of a write; keep the prior UI state.
    }
  }
  if ($progress -and $progress.total -gt 0) {
    $total = [Math]::Max(1, [int]$progress.total)
    $done = [Math]::Max(0, [Math]::Min($total, [int]$progress.completed))
    $overallBar.Maximum = $total
    $overallBar.Value = $done
    $overallLabel.Text = "整體進度：已完成 $done / $total 個步驟"
    $phaseLabel.Text = "目前步驟：$($progress.stage)"
    $activityDetail.Text = [string]$progress.detail
  }

  if (-not $script:workerProcess.HasExited) {
    $elapsed = (Get-Date) - $script:workerStartAt
    $statusLine.Text = ("{0}執行中｜已經過 {1:mm\:ss}" -f $script:workerOperation, $elapsed)
    # The latest build output is contextual information, not a calculated percentage.
    foreach ($path in @($script:workerErrorLog, $script:workerLog)) {
      if (-not (Test-Path -LiteralPath $path)) { continue }
      try {
        $lines = @(Get-Content -LiteralPath $path -Tail 12 -ErrorAction Stop | Where-Object { $_ -match '(Compiling |Finished .*profile|Built application at:|building for production|built in |error:|覆蓋成功|備份完成|套用模組)' })
        if ($lines.Count -gt 0) {
          $recent = [regex]::Replace([string]$lines[-1], '\x1B\[[0-9;]*[A-Za-z]', '').Trim()
          if ($recent.Length -gt 115) { $recent = $recent.Substring(0,115) + '…' }
          if ($recent) { $activityDetail.Text = "現在：$($progress.detail)`r`n最近紀錄：$recent" }
          break
        }
      } catch {
        # Log output is optional; never interrupt an operation for display alone.
      }
    }
    return
  }

  $phaseBar.Style = "Continuous"
  $phaseBar.Value = 100



  $exitCode = $script:workerProcess.ExitCode
  $operation = $script:workerOperation
  $logFile = $script:workerLog
  $errorFile = $script:workerErrorLog
  $resultFile = $script:workerResultFile
  $requestedAction = $script:workerAction
  $script:workerTimer.Stop()
  $script:workerProcess.Dispose()
  $script:workerProcess = $null
  $backup.Enabled = $true
  $restore.Enabled = $true
  $overwrite.Enabled = $true
  Refresh-Backups
  Refresh-Info

  # This PowerShell host can report a null ExitCode for a successfully finished child.
  # An explicit success record, written only after work finishes, is authoritative.
  $completion = $null
  if (Test-Path -LiteralPath $resultFile) {
    try { $completion = Get-Content -LiteralPath $resultFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $completion = $null }
  }
  $operationSucceeded = $completion -and $completion.status -eq "success" -and $completion.action -eq $requestedAction
  if ($null -ne $exitCode -and $exitCode -ne 0) { $operationSucceeded = $false }
  if ($operationSucceeded) {
    $phaseLabel.Text = "目前步驟：$operation 已完成"
    $statusLine.Text = "$operation 已完成"
    [System.Windows.Forms.MessageBox]::Show("$operation 成功。", "MooshieUIplus", "OK", "Information") | Out-Null
  } else {
    $phaseBar.Value = 0
    $phaseLabel.Text = "目前步驟：$operation 失敗"
    $statusLine.Text = "$operation 失敗，請查看錯誤紀錄"
    $errorMessage = if (Test-Path -LiteralPath $errorFile) {
      (Get-Content -LiteralPath $errorFile -Tail 12 -ErrorAction SilentlyContinue) -join [Environment]::NewLine
    } else { "" }
    if (-not $errorMessage -and (Test-Path -LiteralPath $logFile)) {
      $errorMessage = (Get-Content -LiteralPath $logFile -Tail 12 -ErrorAction SilentlyContinue) -join [Environment]::NewLine
    }
    [System.Windows.Forms.MessageBox]::Show(
      "$operation 失敗。`r`n$errorMessage`r`n紀錄：$logFile",
      "MooshieUIplus", "OK", "Error"
    ) | Out-Null
  }
})
function Start-Worker([string]$op, [string]$id, [string]$snap, [bool]$versionConfirmed = $false) {
  if ($null -ne $script:workerProcess) {
    [System.Windows.Forms.MessageBox]::Show("目前已有操作進行中，請等本次操作結束。", "MooshieUIplus") | Out-Null
    return
  }
  $tempDir = Join-Path $root "temp"
  New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
  $stamp = (Get-Date -Format "yyyyMMdd-HHmmss-fff")
  $logFile = Join-Path $tempDir "module-manager-$stamp.log"
  $errorFile = Join-Path $tempDir "module-manager-$stamp.err.log"
  $resultFile = Join-Path $tempDir "module-manager-$stamp.result.json"
  $progressFile = Join-Path $tempDir "module-manager-$stamp.progress.json"
  $args = @("-NoProfile", "-STA", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", ('"' + $PSCommandPath + '"'), "-Action", $op, "-Module", $id)
  if ($snap) { $args += @("-Snapshot", $snap) }
  if ($versionConfirmed) { $args += "-ConfirmVersionOverwrite" }
  $args += @("-ResultFile", ('"' + $resultFile + '"'), "-ProgressFile", ('"' + $progressFile + '"'))
  try {
    $script:workerProcess = Start-Process -FilePath "powershell.exe" -ArgumentList $args -WindowStyle Hidden -RedirectStandardOutput $logFile -RedirectStandardError $errorFile -PassThru
    $script:workerOperation = switch ($op) {
      "Backup" { "備份" }
      "Restore" { "復原" }
      "Overwrite" { "覆蓋安裝" }
    }
    $script:workerLog = $logFile
    $script:workerErrorLog = $errorFile
    $script:workerResultFile = $resultFile
    $script:workerAction = $op
    $script:workerProgressFile = $progressFile
    $script:workerStartAt = Get-Date
    $overallBar.Value = 0
    $overallBar.Maximum = 6
    $overallLabel.Text = "整體進度：準備中"
    $overallDetail.Text = "依實際完成步驟更新，不代表耗時百分比。"
    $phaseLabel.Text = "目前步驟：正在啟動工作程序"
    $phaseBar.Style = "Marquee"
    $phaseBar.MarqueeAnimationSpeed = 35
    $activityDetail.Text = "正在讀取執行日誌…"
    $statusLine.Text = "$($script:workerOperation) 執行中…"
    $backup.Enabled = $false
    $restore.Enabled = $false
    $overwrite.Enabled = $false
    $script:workerTimer.Start()
  } catch {
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "啟動失敗", "OK", "Error") | Out-Null
  }
}
$picker.Add_SelectedIndexChanged({ Refresh-Info })
$reload.Add_Click({ Refresh-Backups })
$backup.Add_Click({ Start-Worker "Backup" "all" "" })
$restore.Add_Click({
  if (-not $snapshots.SelectedItem) { [Windows.Forms.MessageBox]::Show("請先選擇備份版本。") | Out-Null; return }
  $choice = [Windows.Forms.MessageBox]::Show(
    "將以選定備份覆蓋 MooshieUI 原始碼及正式 exe（不修改 data）。復原前會自動備份現況。請先關閉 MooshieUI，確定繼續？",
    "確認復原", [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Warning)
  if ($choice -eq [Windows.Forms.DialogResult]::Yes) { Start-Worker "Restore" "all" ([string]$snapshots.SelectedItem) }
})
$overwrite.Add_Click({
  $installedVersion = (Get-Item -LiteralPath $appExe).VersionInfo.ProductVersion
  $buildVersion = (Get-Content -LiteralPath (Join-Path $source "package.json") -Raw -Encoding UTF8 | ConvertFrom-Json).version
  $mismatch = $installedVersion -ne $buildVersion
  if ($mismatch) { [Windows.Forms.MessageBox]::Show("目前正式版 $installedVersion 與建置來源 $buildVersion 不一致。禁止降版覆蓋。", "版本不一致", "OK", "Warning") | Out-Null; return }
  $warning = ""
  $choice = [Windows.Forms.MessageBox]::Show(
    ($warning + "將重套模組、重新編譯，成功後先備份，再覆蓋正式 exe。請先關閉 MooshieUI。確定繼續？"),
    "確認覆蓋安裝", [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Warning)
  if ($choice -eq [Windows.Forms.DialogResult]::Yes) { Start-Worker "Overwrite" (Selected-Module) "" $mismatch }
})
$folder.Add_Click({ New-Item -Path $backupDir -ItemType Directory -Force | Out-Null; Start-Process explorer.exe $backupDir })
Refresh-Info
Refresh-Backups
[void]$form.ShowDialog()
