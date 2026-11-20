param(
  [ValidateSet("Check","Update")][string]$Action = "Check",
  [Parameter(Mandatory=$true)][string]$AppExe,
  [string]$ManagerRoot = "",
  [string]$ResultFile = "",
  [string]$TempRoot = ""
)
$ErrorActionPreference = "Stop"
# Windows PowerShell 5.1 on older, supported Windows configurations may otherwise negotiate obsolete TLS.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$repo = "Martie0001/MooshieUIplus"
$headers = @{ "User-Agent"="MooshieUIplus-Manager"; "Accept"="application/vnd.github+json" }
$appExe = (Resolve-Path -LiteralPath $AppExe).Path
if ([IO.Path]::GetFileName($appExe) -ne "comfyui-desktop.exe") { throw "必須選擇 comfyui-desktop.exe。" }
$baseVersion = (Get-Item -LiteralPath $appExe).VersionInfo.ProductVersion
if (-not $baseVersion) { throw "無法辨識目前 MooshieUI 版本。" }
if (-not $ManagerRoot) { $ManagerRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
$ManagerRoot = (Resolve-Path -LiteralPath $ManagerRoot).Path
$exeHash = (Get-FileHash -LiteralPath $appExe -Algorithm SHA256).Hash
$cacheRoot = Join-Path $env:LOCALAPPDATA "MooshieUIplus\cache\releases"
if (-not $TempRoot) { $TempRoot = Join-Path $env:LOCALAPPDATA "MooshieUIplus\temp" }
$stateFile = Join-Path $env:LOCALAPPDATA "MooshieUIplus\installed-release.json"
$releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases?per_page=30" -Headers $headers -TimeoutSec 25
$selected = $null
foreach ($release in ($releases | Sort-Object -Property published_at -Descending)) {
  if ($release.draft -or $release.prerelease) { continue }
  foreach ($asset in @($release.assets)) {
    if ($asset.name -match '^MooshieUIplus-B-Windows-(\d+\.\d+\.\d+)(?:-[A-Za-z0-9._-]+)?\.zip$') {
      $offeredBase = [string]$Matches[1]
      $approvedUpgrade = ($offeredBase -eq "2.3.51" -and $baseVersion -in @("2.3.49","2.3.50")) -or ($offeredBase -eq "2.4.0" -and $baseVersion -eq "2.3.51") -or ($offeredBase -eq "2.4.4" -and $baseVersion -in @("2.3.51","2.4.0"))
      if ($offeredBase -eq $baseVersion -or $approvedUpgrade) {
        $selected = [pscustomobject]@{ release=$release; asset=$asset; targetBaseVersion=$offeredBase }
        break
      }
    }
  }
  if ($selected) { break }
}
if (-not $selected) {
  $result = [ordered]@{ status="none"; action=$Action; baseVersion=$baseVersion; message="GitHub 尚無適用 MooshieUI $baseVersion 的正式整合包。" }
  if ($ResultFile) { $result | ConvertTo-Json | Set-Content -LiteralPath $ResultFile -Encoding UTF8 }
  Write-Output $result.message
  exit 0
}
$release = $selected.release
$fullAsset = $selected.asset
$targetBaseVersion = [string]$selected.targetBaseVersion
$tag = [string]$release.tag_name
$sidecarName = [IO.Path]::GetFileNameWithoutExtension([string]$fullAsset.name) + ".update.json"
$sidecarAsset = @($release.assets | Where-Object { $_.name -eq $sidecarName } | Select-Object -First 1)
$managerAsset = $null
$updateInfo = $null
$needsExe = $true
$needsManager = $true
$needsRuntime = $false
$needsNodes = $false
if ($sidecarAsset.Count -eq 1) {
  $sidecarUrl = [string]$sidecarAsset[0].browser_download_url
  if ($sidecarUrl -notmatch '^https://github\.com/Martie0001/MooshieUIplus/releases/download/') {
    throw "GitHub 更新資訊來源不符，拒絕下載。"
  }
  $response = Invoke-WebRequest -Uri $sidecarUrl -Headers $headers -UseBasicParsing -TimeoutSec 30
  $response.RawContentStream.Position = 0
  $reader = [IO.StreamReader]::new($response.RawContentStream,[Text.Encoding]::UTF8)
  try { $updateInfo = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
  if ($updateInfo.schemaVersion -ne 1 -or $updateInfo.mooshieuiVersion -ne $targetBaseVersion -or
      $updateInfo.package -ne $fullAsset.name -or
      [string]$updateInfo.payloadSha256 -notmatch '^[a-fA-F0-9]{64}$') {
    throw "GitHub 更新資訊版本或校驗資料有誤。"
  }
  $needsExe = $exeHash -ne [string]$updateInfo.payloadSha256
  if ($updateInfo.promptRuntimeSha256) {
    $runtimeDir = Join-Path (Split-Path -Parent $appExe) "MooshieUIplus\PromptGenerator"
    foreach ($item in @(
      [pscustomobject]@{name="node.exe";hash=[string]$updateInfo.promptRuntimeSha256},
      [pscustomobject]@{name="NODE-LICENSE.txt";hash=[string]$updateInfo.promptRuntimeLicenseSha256}
    )) {
      if ($item.hash -notmatch '^[a-fA-F0-9]{64}$') { throw "GitHub 更新資料缺少 Node.js 執行元件雜湊。" }
      $target = Join-Path $runtimeDir $item.name
      if (-not (Test-Path -LiteralPath $target) -or
          (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $item.hash) {
        $needsRuntime = $true
      }
    }
  }
  if ($updateInfo.comfyNodeFiles) {
    $assetsDir = Join-Path (Split-Path -Parent $appExe) 'MooshieUIplus\ComfyNodes'
    foreach ($entry in $updateInfo.comfyNodeFiles.PSObject.Properties) {
      if ([string]$entry.Value -notmatch '^[a-fA-F0-9]{64}$') { throw 'GitHub 更新資訊缺少 ComfyUI 節點 SHA256。' }
      $target = Join-Path $assetsDir $entry.Name
      if (-not (Test-Path -LiteralPath $target) -or
          (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne [string]$entry.Value) {
        $needsNodes = $true
      }
    }
    $launcher = Join-Path (Split-Path -Parent $appExe) 'ensure_backend.ps1'
    if ([string]$updateInfo.ensureBackendSha256 -notmatch '^[a-fA-F0-9]{64}$' -or
        -not (Test-Path -LiteralPath $launcher) -or
        (Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash -ne [string]$updateInfo.ensureBackendSha256) {
      $needsNodes = $true
    }
  }
  $needsManager = $false
  $allowedFiles = @("MooshieUIplus-Manager.exe","Install-MooshieUIplus.ps1","Release-Update.ps1","模組管理器.ps1","啟動模組管理.vbs")
  foreach ($name in $allowedFiles) {
    $expected = [string]$updateInfo.managerFiles.$name
    if ($expected -notmatch '^[a-fA-F0-9]{64}$') { throw "更新資訊缺少管理器檔案雜湊：$name" }
    $localFile = Join-Path $ManagerRoot $name
    if (-not (Test-Path -LiteralPath $localFile) -or
        (Get-FileHash -LiteralPath $localFile -Algorithm SHA256).Hash -ne $expected) {
      $needsManager = $true
    }
  }
  if ($needsManager -and -not $needsExe -and -not $needsRuntime -and -not $needsNodes) {
    $managerAssetName = [string]$updateInfo.managerAsset
    $managerAsset = @($release.assets | Where-Object { $_.name -eq $managerAssetName } | Select-Object -First 1)
    if ($managerAsset.Count -ne 1 -or $managerAssetName -notmatch '^MooshieUIplus-Manager-[a-zA-Z0-9._-]+\.zip$') {
      throw "GitHub 發布版缺少獨立管理器更新包。"
    }
    $managerAsset = $managerAsset[0]
  }
} else {
  # Releases without an update sidecar can use a previously verified installed-state record.
  if (Test-Path -LiteralPath $stateFile) {
    $state = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($state.appExe -eq $appExe -and $state.release -eq $tag -and
        $state.exeSha256 -eq $exeHash) {
      $needsExe = $false
      $needsManager = $false
    }
  }
}
$result = [ordered]@{
  status = if ($needsExe -or $needsManager -or $needsRuntime -or $needsNodes) { "available" } else { "current" }
  action = $Action
  baseVersion = $baseVersion
  targetBaseVersion = $targetBaseVersion
  release = $tag
  assetName = [string]$fullAsset.name
  needsExe = $needsExe
  needsManager = $needsManager
  needsRuntime = $needsRuntime
  needsNodes = $needsNodes
  message = if ($needsExe -or $needsManager -or $needsRuntime -or $needsNodes) { "GitHub 有相容更新：$tag" } else { "已是最新版本：$tag，不需下載。" }
}
if ($Action -eq "Check" -or $result.status -eq "current") {
  if ($ResultFile) { $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ResultFile -Encoding UTF8 }
  Write-Output $result.message
  exit 0
}
if (($needsExe -or $needsRuntime -or $needsNodes) -and (Get-Process -Name "comfyui-desktop" -ErrorAction SilentlyContinue)) {
  throw "MooshieUI 仍在執行，請關閉後再替換 EXE。"
}
# On protected directories, request UAC before any file replacement. A declined UAC is a visible failure.
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
$protectedRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432) |
  Where-Object { $_ } | Select-Object -Unique
$protectedDestination = $false
foreach ($base in $protectedRoots) {
  $prefix = [IO.Path]::GetFullPath($base).TrimEnd('\') + '\'
  if ((($needsExe -or $needsRuntime -or $needsNodes) -and $appExe.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) -or
      ($needsManager -and $ManagerRoot.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase))) {
    $protectedDestination = $true
    break
  }
}
if ($protectedDestination -and -not $isAdmin) {
  Write-Output "更新位置需要系統管理員權限，將顯示 Windows UAC 確認。"
  $command = @("-NoProfile", "-STA", "-ExecutionPolicy", "Bypass", "-File",
    ('"' + $MyInvocation.MyCommand.Path + '"'), "-Action", "Update",
    "-AppExe", ('"' + $appExe + '"'), "-ManagerRoot", ('"' + $ManagerRoot + '"'))
  if ($ResultFile) { $command += @("-ResultFile", ('"' + $ResultFile + '"')) }
  if ($TempRoot) { $command += @("-TempRoot", ('"' + $TempRoot + '"')) }
  try {
    $elevated = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $command -PassThru -Wait -ErrorAction Stop
  } catch {
    throw "未取得更新所需管理員權限（UAC 可能遭拒）：$($_.Exception.Message)。未安裝更新。"
  }
  if ($elevated.ExitCode -ne 0) { throw "系統管理員更新失敗（退出碼：$($elevated.ExitCode)），請檢查更新日誌。" }
  exit 0
}
$asset = if ($managerAsset) { $managerAsset } else { $fullAsset }
$assetUrl = [string]$asset.browser_download_url
if ($assetUrl -notmatch '^https://github\.com/Martie0001/MooshieUIplus/releases/download/') {
  throw "GitHub 回傳的下載網址不符，已停止。"
}
if (-not [string]$asset.digest -or [string]$asset.digest -notmatch '^sha256:([a-fA-F0-9]{64})$') {
  throw "GitHub 更新附件沒有 SHA256 digest，拒絕安裝。"
}
$assetSha = $Matches[1]
New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
$cacheFile = Join-Path $cacheRoot ("{0}-{1}" -f $asset.id, $asset.name)
$useCache = Test-Path -LiteralPath $cacheFile
if ($useCache) {
  $useCache = (Get-Item -LiteralPath $cacheFile).Length -eq [long]$asset.size -and
    (Get-FileHash -LiteralPath $cacheFile -Algorithm SHA256).Hash -eq $assetSha
}
if ($useCache) {
  Write-Output "使用已驗證的本地更新包快取，不重新下載：$($asset.name)"
} else {
  $incoming = Join-Path $cacheRoot ("download-" + [guid]::NewGuid().ToString("N") + ".zip")
  Write-Output "首次下載新發布版：$($asset.name)"
  Invoke-WebRequest -Uri $assetUrl -Headers $headers -UseBasicParsing -OutFile $incoming -TimeoutSec 240
  if ((Get-Item -LiteralPath $incoming).Length -ne [long]$asset.size -or
      (Get-FileHash -LiteralPath $incoming -Algorithm SHA256).Hash -ne $assetSha) {
    throw "GitHub 更新包大小或 SHA256 校驗失敗。"
  }
  Move-Item -LiteralPath $incoming -Destination $cacheFile -Force
}
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null
$unpacked = Join-Path $TempRoot ("release-" + [guid]::NewGuid().ToString("N"))
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($cacheFile)
try {
  foreach ($entry in $archive.Entries) {
    $name = $entry.FullName.Replace("\", "/")
    if ($name.StartsWith("/") -or $name -match '(^|/)\.\.(/|$)' -or $name -match '^[a-zA-Z]:') {
      throw "ZIP 內含不安全的相對路徑。"
    }
  }
} finally { $archive.Dispose() }
Expand-Archive -LiteralPath $cacheFile -DestinationPath $unpacked
$manifest = $null
if ($needsExe -or $needsRuntime -or $needsNodes) {
  $manifestPath = Join-Path $unpacked "manifest.json"
  $payload = Join-Path $unpacked "payload\comfyui-desktop.exe"
  if (-not (Test-Path -LiteralPath $manifestPath) -or -not (Test-Path -LiteralPath $payload)) {
    throw "發布版缺少預編譯 EXE 或安裝資訊。"
  }
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($manifest.mooshieuiVersion -ne $targetBaseVersion -or
      -not $manifest.payloadSha256 -or
      (Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash -ne $manifest.payloadSha256) {
    throw "預編譯 EXE 版本或 SHA256 不符合。"
  }
  if ($updateInfo -and $manifest.payloadSha256 -ne $updateInfo.payloadSha256) {
    throw "GitHub 更新資料與 EXE 雜湊不一致。"
  }
}
if ($updateInfo) {
  foreach ($name in @("MooshieUIplus-Manager.exe","Install-MooshieUIplus.ps1","Release-Update.ps1","模組管理器.ps1","啟動模組管理.vbs")) {
    $scriptFile = Join-Path $unpacked $name
    if (-not (Test-Path -LiteralPath $scriptFile) -or
        (Get-FileHash -LiteralPath $scriptFile -Algorithm SHA256).Hash -ne [string]$updateInfo.managerFiles.$name) {
      throw "管理器更新檔缺失或雜湊不符：$name"
    }
  }
}
if ($needsExe -or $needsRuntime -or $needsNodes) {
  # Use the verified installer from this release: an older manager may not know about portable runtime files.
  $installer = Join-Path $unpacked "Install-MooshieUIplus.ps1"
  & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $installer -AppExe $appExe -PackageRoot $unpacked
  if ($LASTEXITCODE -ne 0) { throw "預編譯 EXE 安裝失敗。"}
}
if ($updateInfo) {
  if ($needsManager) {
    $managerBackup = Join-Path $env:LOCALAPPDATA ("MooshieUIplus\history\manager-backups\" + (Get-Date -Format "yyyyMMdd-HHmmss-fff"))
    New-Item -ItemType Directory -Path $managerBackup -Force | Out-Null
    $managerNames = @("MooshieUIplus-Manager.exe","Install-MooshieUIplus.ps1","Release-Update.ps1","模組管理器.ps1","啟動模組管理.vbs")
    foreach ($name in $managerNames) {
      $target = Join-Path $ManagerRoot $name
      if (Test-Path -LiteralPath $target) { Copy-Item -LiteralPath $target -Destination (Join-Path $managerBackup $name) }
    }
    try {
      foreach ($name in $managerNames) {
        $target = Join-Path $ManagerRoot $name
        Copy-Item -LiteralPath (Join-Path $unpacked $name) -Destination $target -Force
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne [string]$updateInfo.managerFiles.$name) {
          throw "管理器更新後 SHA256 不一致：$name"
        }
      }
    } catch {
      foreach ($name in $managerNames) {
        $target = Join-Path $ManagerRoot $name
        $saved = Join-Path $managerBackup $name
        if (Test-Path -LiteralPath $saved) { Copy-Item -LiteralPath $saved -Destination $target -Force }
      }
      throw "管理器更新失敗，已還原先前備份：" + $_.Exception.Message
    }
    Write-Output "模組管理器已更新，重新開啟視窗後生效。"
  }
  $targetHash = [string]$updateInfo.payloadSha256
} else {
  $targetHash = [string]$manifest.payloadSha256
}
if ((Get-FileHash -LiteralPath $appExe -Algorithm SHA256).Hash -ne $targetHash) { throw "安裝後 EXE 雜湊不符合。"}
New-Item -ItemType Directory -Path (Split-Path -Parent $stateFile) -Force | Out-Null
[ordered]@{appExe=$appExe;release=$tag;exeSha256=$targetHash;updatedAt=(Get-Date).ToString("o")} |
  ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8
$result.status = "updated"
$result.message = "整合版已更新至 $tag，已驗證 EXE 與管理器（如有更新請重開管理器）。"
if ($ResultFile) { $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ResultFile -Encoding UTF8 }
Write-Output $result.message
