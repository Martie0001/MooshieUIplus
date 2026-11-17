param(
  [string]$AppExe = "",
  [string]$PackageRoot = "",
  [switch]$VerifyOnly,
  [switch]$Restore
)
$ErrorActionPreference = "Stop"
$packageRoot = if ($PackageRoot) { (Resolve-Path -LiteralPath $PackageRoot).Path } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$payload = Join-Path $packageRoot "payload\comfyui-desktop.exe"
$manifestFile = Join-Path $packageRoot "manifest.json"
$backupRoot = Join-Path $env:LOCALAPPDATA "MooshieUIplus\history\exe-backups"

if (-not $AppExe) {
  $sibling = Join-Path (Split-Path -Parent $packageRoot) "MooshieUI\comfyui-desktop.exe"
  if (Test-Path -LiteralPath $sibling) { $AppExe = $sibling }
}
if (-not $AppExe -or -not (Test-Path -LiteralPath $AppExe)) {
  Add-Type -AssemblyName System.Windows.Forms
  $picker = New-Object System.Windows.Forms.OpenFileDialog
  $picker.Title = "選擇已安裝的 MooshieUI comfyui-desktop.exe"
  $picker.Filter = "MooshieUI 執行檔 (comfyui-desktop.exe)|comfyui-desktop.exe"
  if ($picker.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { throw "未選取 MooshieUI 執行檔，未修改任何檔案。" }
  $AppExe = $picker.FileName
}
$AppExe = (Resolve-Path -LiteralPath $AppExe).Path
if ([IO.Path]::GetFileName($AppExe) -ne "comfyui-desktop.exe") { throw "目標必須是 comfyui-desktop.exe" }
$targetVersion = (Get-Item -LiteralPath $AppExe).VersionInfo.ProductVersion
if (-not $targetVersion) { throw "無法辨識 MooshieUI 版本。" }

if ($Restore) {
  $last = Get-ChildItem -LiteralPath $backupRoot -Filter "backup.json" -Recurse -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Where-Object {
      $record = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
      $savedExe = Join-Path $_.DirectoryName "comfyui-desktop.exe"
      $record.appExe -eq $AppExe -and (Test-Path -LiteralPath $savedExe) -and
        (Get-Item -LiteralPath $savedExe).VersionInfo.ProductVersion -eq $targetVersion
    } | Select-Object -First 1
  if (-not $last) { throw "此 MooshieUI 安裝位置沒有可還原的 EXE 備份。" }
  $source = Join-Path $last.DirectoryName "comfyui-desktop.exe"
  if (-not (Test-Path -LiteralPath $source)) { throw "備份檔案遺失，停止還原。" }
  $expected = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
} else {
  if (-not (Test-Path -LiteralPath $manifestFile) -or -not (Test-Path -LiteralPath $payload)) {
    throw "安裝包缺少 manifest.json 或整合版執行檔。"
  }
  $manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($manifest.mooshieuiVersion -ne $targetVersion -or
      -not $manifest.payloadSha256 -or
      ((Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash -ne $manifest.payloadSha256)) {
    throw "整合版版本或 SHA256 驗證失敗，未修改任何檔案。"
  }
  $source = $payload
  $expected = $manifest.payloadSha256
}

$currentHash = (Get-FileHash -LiteralPath $AppExe -Algorithm SHA256).Hash
Write-Output "已確認 MooshieUI $targetVersion，路徑：$AppExe"
if ($currentHash -eq $expected) { Write-Output "目前執行檔已是指定版本，不需替換。"; exit 0 }
if ($VerifyOnly) { Write-Output "驗證完成：版本與安裝包檢查通過，沒有修改正式程式。"; exit 0 }

if (Get-Process -Name "comfyui-desktop" -ErrorAction SilentlyContinue) {
  throw "MooshieUI 仍在執行中。請先關閉程式再安裝／還原。"
}
$stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
$backupFolder = Join-Path $backupRoot $stamp
New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
$backup = Join-Path $backupFolder "comfyui-desktop.exe"
Copy-Item -LiteralPath $AppExe -Destination $backup -ErrorAction Stop
if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $currentHash) {
  throw "目前執行檔備份驗證失敗，未執行替換。"
}
[ordered]@{ appExe = $AppExe; appVersion = $targetVersion; originalSha256 = $currentHash; createdAt = (Get-Date).ToString("o") } |
  ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backupFolder "backup.json") -Encoding UTF8
try {
  Copy-Item -LiteralPath $source -Destination $AppExe -Force -ErrorAction Stop
  if ((Get-FileHash -LiteralPath $AppExe -Algorithm SHA256).Hash -ne $expected) {
    throw "安裝後執行檔校驗失敗。"
  }
} catch {
  Copy-Item -LiteralPath $backup -Destination $AppExe -Force
  throw "部署失敗，已從本次備份還原原本的 EXE：" + $_.Exception.Message
}
Write-Output "已更新 MooshieUI EXE，舊版備份：$backup。資料夾、模型及個人設定沒有修改。"
