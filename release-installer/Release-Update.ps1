param(
  [ValidateSet("Check","Update")][string]$Action = "Check",
  [Parameter(Mandatory=$true)][string]$AppExe,
  [string]$ResultFile = "",
  [string]$TempRoot = ""
)
$ErrorActionPreference = "Stop"
$repo = "Martie0001/MooshieUIplus"
$appExe = (Resolve-Path -LiteralPath $AppExe).Path
if ([IO.Path]::GetFileName($appExe) -ne "comfyui-desktop.exe") {
  throw "必須選擇 comfyui-desktop.exe。"
}
$baseVersion = (Get-Item -LiteralPath $appExe).VersionInfo.ProductVersion
if (-not $baseVersion) { throw "無法辨識 MooshieUI 版本。" }
$headers = @{ "User-Agent" = "MooshieUIplus-Release-Manager"; "Accept" = "application/vnd.github+json" }
$releases = @(Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases?per_page=30" -Headers $headers -TimeoutSec 25)
$selected = $null
foreach ($release in $releases) {
  if ($release.draft -or $release.prerelease) { continue }
  foreach ($asset in @($release.assets)) {
    if ($asset.name -match '^MooshieUIplus-B-Windows-(\d+\.\d+\.\d+)(?:-[A-Za-z0-9._-]+)?\.zip$' -and $Matches[1] -eq $baseVersion) {
      $selected = [pscustomobject]@{ release = $release; asset = $asset }
      break
    }
  }
  if ($selected) { break }
}
if (-not $selected) {
  $result = [ordered]@{ status = "none"; action = $Action; baseVersion = $baseVersion; message = "GitHub 尚無適用於 MooshieUI $baseVersion 的正式 B 版 Release。" }
  if ($ResultFile) { $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ResultFile -Encoding UTF8 }
  Write-Output $result.message
  exit 0
}
$release = $selected.release
$asset = $selected.asset
$url = [string]$asset.browser_download_url
if ($url -notmatch '^https://github\.com/Martie0001/MooshieUIplus/releases/download/') {
  throw "GitHub 回傳不符合預期的下載位置，已取消。"
}
$result = [ordered]@{
  status = "available"
  action = $Action
  baseVersion = $baseVersion
  release = [string]$release.tag_name
  assetName = [string]$asset.name
  publishedAt = [string]$release.published_at
  message = "找到相容的正式發布版：$($release.tag_name)"
}
if ($Action -eq "Check") {
  if ($ResultFile) { $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ResultFile -Encoding UTF8 }
  Write-Output $result.message
  exit 0
}
if (-not $TempRoot) { $TempRoot = Join-Path $env:LOCALAPPDATA "MooshieUIplus\temp" }
$session = Join-Path $TempRoot ("release-" + (Get-Date -Format "yyyyMMdd-HHmmss-fff"))
New-Item -ItemType Directory -Path $session -Force | Out-Null
$zipFile = Join-Path $session ([string]$asset.name)
$unpacked = Join-Path $session "unpacked"
Write-Output "下載相容發布版：$($release.tag_name)"
Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -OutFile $zipFile -TimeoutSec 240
if ($asset.size -and (Get-Item -LiteralPath $zipFile).Length -ne [long]$asset.size) {
  throw "下載檔案大小與 GitHub 發布資訊不一致。"
}
if ($asset.digest -and [string]$asset.digest -match '^sha256:([0-9a-fA-F]{64})$') {
  if ((Get-FileHash -LiteralPath $zipFile -Algorithm SHA256).Hash -ne $Matches[1]) {
    throw "下載檔案 SHA256 與 GitHub 發布資訊不一致。"
  }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zipFile)
try {
  foreach ($entry in $archive.Entries) {
    $name = $entry.FullName.Replace("\", "/")
    if ($name.StartsWith("/") -or $name -match '(^|/)\.\.(/|$)' -or $name -match '^[A-Za-z]:') {
      throw "更新 ZIP 內含不安全的路徑，已取消。"
    }
  }
} finally { $archive.Dispose() }
Expand-Archive -LiteralPath $zipFile -DestinationPath $unpacked -Force
$manifestPath = Join-Path $unpacked "manifest.json"
$payloadPath = Join-Path $unpacked "payload\comfyui-desktop.exe"
if (-not (Test-Path -LiteralPath $manifestPath) -or -not (Test-Path -LiteralPath $payloadPath)) {
  throw "發布 ZIP 缺少 manifest.json 或預編譯執行檔。"
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.mooshieuiVersion -ne $baseVersion -or
    -not $manifest.payloadSha256 -or
    ((Get-FileHash -LiteralPath $payloadPath -Algorithm SHA256).Hash -ne $manifest.payloadSha256)) {
  throw "發布版與目前 MooshieUI 版本不相容，或 EXE SHA256 校驗失敗。"
}
$oldHash = (Get-FileHash -LiteralPath $appExe -Algorithm SHA256).Hash
if ($oldHash -eq $manifest.payloadSha256) {
  $result.status = "installed"
  $result.message = "目前已安裝相同的整合版 EXE，不需更新。"
} else {
  $installer = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "Install-MooshieUIplus.ps1"
  & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $installer -AppExe $appExe -PackageRoot $unpacked
  if ($LASTEXITCODE -ne 0) { throw "安裝器回報失敗；未宣稱更新完成。" }
  if ((Get-FileHash -LiteralPath $appExe -Algorithm SHA256).Hash -ne $manifest.payloadSha256) {
    throw "更新後 EXE SHA256 驗證失敗。"
  }
  $result.status = "updated"
  $result.message = "整合模組已更新至 GitHub 發布版：$($release.tag_name)"
}
if ($ResultFile) { $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ResultFile -Encoding UTF8 }
Write-Output $result.message
