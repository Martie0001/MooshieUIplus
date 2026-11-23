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

$runtimeFiles = @()
$appRoot = Split-Path -Parent $AppExe
$runtimeTarget = Join-Path $appRoot "MooshieUIplus\PromptGenerator"
$nodeTarget = Join-Path $appRoot "MooshieUIplus\ComfyNodes"
$launcherTarget = Join-Path $appRoot "ensure_backend.ps1"
$nodeFiles = @()
if ($Restore) {
  $last = Get-ChildItem -LiteralPath $backupRoot -Filter "backup.json" -Recurse -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Where-Object {
      $record = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
      $savedExe = Join-Path $_.DirectoryName "comfyui-desktop.exe"
      $record.appExe -eq $AppExe -and (Test-Path -LiteralPath $savedExe) -and
        (Get-FileHash -LiteralPath $savedExe -Algorithm SHA256).Hash -eq $record.originalSha256
    } | Select-Object -First 1
  if (-not $last) { throw "此 MooshieUI 安裝位置沒有可還原的 EXE 備份。" }
  $source = Join-Path $last.DirectoryName "comfyui-desktop.exe"
  $expected = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
} else {
  if (-not (Test-Path -LiteralPath $manifestFile) -or -not (Test-Path -LiteralPath $payload)) {
    throw "安裝包缺少 manifest.json 或整合版執行檔。"
  }
  $manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $approvedUpgrade = ($targetVersion -in @("2.3.49","2.3.50") -and $manifest.mooshieuiVersion -eq "2.3.51") -or ($targetVersion -eq "2.3.51" -and $manifest.mooshieuiVersion -eq "2.4.0") -or ($targetVersion -in @("2.3.51","2.4.0") -and $manifest.mooshieuiVersion -eq "2.4.4") -or ($targetVersion -in @("2.4.0","2.4.4") -and $manifest.mooshieuiVersion -eq "2.4.6") -or ($targetVersion -in @("2.4.4","2.4.6") -and $manifest.mooshieuiVersion -eq "2.4.7")
  if ((-not $approvedUpgrade -and $manifest.mooshieuiVersion -ne $targetVersion) -or
      -not $manifest.payloadSha256 -or
      ((Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash -ne $manifest.payloadSha256)) {
    throw "整合版版本或 SHA256 驗證失敗，未修改任何檔案。"
  }
  if ($manifest.promptRuntimeSha256) {
    $runtimeFiles = @(
      [pscustomobject]@{name="node.exe";hash=[string]$manifest.promptRuntimeSha256},
      [pscustomobject]@{name="NODE-LICENSE.txt";hash=[string]$manifest.promptRuntimeLicenseSha256}
    )
    foreach ($item in $runtimeFiles) {
      $itemSource = Join-Path $packageRoot ("payload\PromptGenerator\" + $item.name)
      if ($item.hash -notmatch '^[a-fA-F0-9]{64}$' -or
          -not (Test-Path -LiteralPath $itemSource) -or
          (Get-FileHash -LiteralPath $itemSource -Algorithm SHA256).Hash -ne $item.hash) {
        throw "Prompt Generator 執行元件遺失或雜湊不符：" + $item.name
      }
    }
  }
  if ($manifest.comfyNodeManifestSha256) {
    $nodeManifest = Join-Path $packageRoot 'payload\ComfyNodes\comfy-nodes.json'
    $launcherSource = Join-Path $packageRoot 'payload\ensure_backend.ps1'
    if (-not (Test-Path -LiteralPath $nodeManifest) -or
        (Get-FileHash -LiteralPath $nodeManifest -Algorithm SHA256).Hash -ne [string]$manifest.comfyNodeManifestSha256 -or
        -not (Test-Path -LiteralPath $launcherSource) -or
        (Get-FileHash -LiteralPath $launcherSource -Algorithm SHA256).Hash -ne [string]$manifest.ensureBackendSha256) {
      throw 'ComfyUI 節點資訊或啟動器檔案校驗失敗。'
    }
    $nodeData = Get-Content -LiteralPath $nodeManifest -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($nodeData.version -ne $manifest.mooshieuiVersion -or @($nodeData.requiredNodes).Count -eq 0) {
      throw 'ComfyUI 節點清單版本錯誤或缺少 requiredNodes，拒絕安裝。'
    }
    $nodeMap = $nodeData.files
    foreach ($entry in $nodeMap.PSObject.Properties) {
      $nodeFiles += [pscustomobject]@{ name=$entry.Name; hash=[string]$entry.Value }
    }
    $nodeFiles += [pscustomobject]@{ name='comfy-nodes.json';hash=[string]$manifest.comfyNodeManifestSha256 }
    foreach ($item in $nodeFiles) {
      if ($item.name -match '(^|[/\\])\.\.($|[/\\])' -or [IO.Path]::IsPathRooted($item.name)) {
        throw ('節點清單包含不安全路徑：' + $item.name)
      }
      $path = Join-Path $packageRoot ('payload\ComfyNodes\' + $item.name)
      if ($item.hash -notmatch '^[a-fA-F0-9]{64}$' -or
          -not (Test-Path -LiteralPath $path) -or
          (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $item.hash) {
        throw ('ComfyUI 節點檔案缺少或 SHA256 不符：' + $item.name)
      }
    }
  }
  $source = $payload
  $expected = [string]$manifest.payloadSha256
}

$currentHash = (Get-FileHash -LiteralPath $AppExe -Algorithm SHA256).Hash
$needsExe = $currentHash -ne $expected
$needsRuntime = $false
foreach ($item in $runtimeFiles) {
  $target = Join-Path $runtimeTarget $item.name
  if (-not (Test-Path -LiteralPath $target) -or
      (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $item.hash) {
    $needsRuntime = $true
  }
}
$needsNodes = $false
foreach ($item in $nodeFiles) {
  $path = Join-Path $nodeTarget $item.name
  if (-not (Test-Path -LiteralPath $path) -or
      (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $item.hash) {
    $needsNodes = $true
  }
}
if ($nodeFiles.Count -gt 0 -and
    (-not (Test-Path -LiteralPath $launcherTarget) -or
     (Get-FileHash -LiteralPath $launcherTarget -Algorithm SHA256).Hash -ne [string]$manifest.ensureBackendSha256)) {
  $needsNodes = $true
}
Write-Output "已確認 MooshieUI $targetVersion，路徑：$AppExe"
if ($VerifyOnly) { Write-Output "驗證完成：版本與安裝包及執行元件檢查通過，未修改正式程式。"; exit 0 }
if (-not $needsExe -and -not $needsRuntime -and -not $needsNodes) {
  Write-Output "EXE 與資源檔案已符合套件；仍需檢查 ComfyUI 實際載入全部必要節點。"
  if (Test-Path -LiteralPath $launcherTarget) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcherTarget -RepairOnly
    if ($LASTEXITCODE -ne 0) { throw 'ComfyUI 必要節點未通過載入驗收。' }
  }
  exit 0
}
if ($needsExe -and (Get-Process -Name "comfyui-desktop" -ErrorAction SilentlyContinue)) {
  throw "MooshieUI 仍在執行中。請先關閉程式再安裝／還原。"
}

# Protected installation locations require a visible UAC consent prompt, not a hidden access-denied failure.
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
$protectedRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432) |
  Where-Object { $_ } | Select-Object -Unique
$protectedTarget = $false
foreach ($base in $protectedRoots) {
  $prefix = [IO.Path]::GetFullPath($base).TrimEnd('\') + '\'
  if ($AppExe.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { $protectedTarget = $true; break }
}
if ($protectedTarget -and -not $isAdmin) {
  Write-Output "目標位於 Program Files，安裝或還原需要 Windows 系統管理員權限，將顯示 UAC 確認。"
  $command = @("-NoProfile", "-STA", "-ExecutionPolicy", "Bypass", "-File",
    ('"' + $MyInvocation.MyCommand.Path + '"'), "-AppExe", ('"' + $AppExe + '"'),
    "-PackageRoot", ('"' + $packageRoot + '"'))
  if ($Restore) { $command += "-Restore" }
  try {
    $elevated = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $command -PassThru -Wait -ErrorAction Stop
  } catch {
    throw "無法取得安裝權限（UAC 可能遭拒）：$($_.Exception.Message)。未修改正式程式。"
  }
  if ($elevated.ExitCode -ne 0) { throw "系統管理員安裝失敗（退出碼：$($elevated.ExitCode)），請檢查 UAC 視窗中的錯誤。" }
  exit 0
}

$backupFolder = Join-Path $backupRoot (Get-Date -Format "yyyyMMdd-HHmmss-fff")
New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
$backupExe = Join-Path $backupFolder "comfyui-desktop.exe"
if ($needsExe) {
  Copy-Item -LiteralPath $AppExe -Destination $backupExe -ErrorAction Stop
  if ((Get-FileHash -LiteralPath $backupExe -Algorithm SHA256).Hash -ne $currentHash) {
    throw "目前執行檔備份驗證失敗，未執行替換。"
  }
  [ordered]@{ appExe=$AppExe; appVersion=$targetVersion; originalSha256=$currentHash; createdAt=(Get-Date).ToString("o") } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backupFolder "backup.json") -Encoding UTF8
}
$runtimePrevious = @{}
if ($needsRuntime) {
  foreach ($item in $runtimeFiles) {
    $target = Join-Path $runtimeTarget $item.name
    if (Test-Path -LiteralPath $target) {
      $saved = Join-Path $backupFolder $item.name
      Copy-Item -LiteralPath $target -Destination $saved -ErrorAction Stop
      $runtimePrevious[$item.name] = $saved
    } else {
      $runtimePrevious[$item.name] = $null
    }
  }
}
$nodePrevious = @{}
if ($needsNodes) {
  foreach ($item in $nodeFiles) {
    $path = Join-Path $nodeTarget $item.name
    if (Test-Path -LiteralPath $path) {
      $saved = Join-Path $backupFolder ('node-' + $item.name)
      New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null
      Copy-Item -LiteralPath $path -Destination $saved -ErrorAction Stop
      $nodePrevious[$item.name] = $saved
    } else { $nodePrevious[$item.name] = $null }
  }
  if (Test-Path -LiteralPath $launcherTarget) {
    $saved = Join-Path $backupFolder 'ensure_backend.ps1'
    Copy-Item -LiteralPath $launcherTarget -Destination $saved -ErrorAction Stop
    $nodePrevious['ensure_backend.ps1'] = $saved
  } else { $nodePrevious['ensure_backend.ps1'] = $null }
}
try {
  if ($needsExe) {
    Copy-Item -LiteralPath $source -Destination $AppExe -Force -ErrorAction Stop
    if ((Get-FileHash -LiteralPath $AppExe -Algorithm SHA256).Hash -ne $expected) {
      throw "安裝後 EXE 校驗失敗。"
    }
  }
  if ($needsNodes) {
    New-Item -ItemType Directory -Path $nodeTarget -Force | Out-Null
    foreach ($item in $nodeFiles) {
      $target = Join-Path $nodeTarget $item.name
      New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
      Copy-Item -LiteralPath (Join-Path $packageRoot ('payload\ComfyNodes\' + $item.name)) -Destination $target -Force -ErrorAction Stop
      if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $item.hash) {
        throw ('ComfyUI 節點包安裝校驗失敗：' + $item.name)
      }
    }
    Copy-Item -LiteralPath (Join-Path $packageRoot 'payload\ensure_backend.ps1') -Destination $launcherTarget -Force -ErrorAction Stop
    if ((Get-FileHash -LiteralPath $launcherTarget -Algorithm SHA256).Hash -ne [string]$manifest.ensureBackendSha256) {
      throw 'ComfyUI 啟動器安裝校驗失敗。'
    }
  }
  if ($needsRuntime) {
    New-Item -ItemType Directory -Path $runtimeTarget -Force | Out-Null
    foreach ($item in $runtimeFiles) {
      $target = Join-Path $runtimeTarget $item.name
      Copy-Item -LiteralPath (Join-Path $packageRoot ("payload\PromptGenerator\" + $item.name)) -Destination $target -Force -ErrorAction Stop
      if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $item.hash) {
        throw "Prompt Generator 執行元件校驗失敗：" + $item.name
      }
    }
  }
} catch {
  if ($needsExe -and (Test-Path -LiteralPath $backupExe)) {
    Copy-Item -LiteralPath $backupExe -Destination $AppExe -Force
  }
  if ($needsRuntime) {
    foreach ($item in $runtimeFiles) {
      $target = Join-Path $runtimeTarget $item.name
      if ($runtimePrevious[$item.name]) {
        Copy-Item -LiteralPath $runtimePrevious[$item.name] -Destination $target -Force
      } elseif (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Force
      }
    }
  }
  if ($needsNodes) {
    foreach ($item in $nodeFiles) {
      $target = Join-Path $nodeTarget $item.name
      if ($nodePrevious[$item.name]) {
        Copy-Item -LiteralPath $nodePrevious[$item.name] -Destination $target -Force
      } elseif (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
    }
    if ($nodePrevious['ensure_backend.ps1']) {
      Copy-Item -LiteralPath $nodePrevious['ensure_backend.ps1'] -Destination $launcherTarget -Force
    } elseif (Test-Path -LiteralPath $launcherTarget) { Remove-Item -LiteralPath $launcherTarget -Force }
  }
  throw "安裝失敗，已還原本次變動：" + $_.Exception.Message
}
if ($needsNodes -and (Test-Path -LiteralPath (Join-Path $appRoot 'data\config.json'))) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcherTarget -RepairOnly
  if ($LASTEXITCODE -ne 0) {
    throw '節點資源已安裝，但 ComfyUI 必要節點尚未載入，尚未通過啟動驗收。'
  }
}
Write-Output "MooshieUIplus 已安裝。Prompt Generator 執行元件位於：$runtimeTarget；使用此功能前仍需安裝並啟動 Ollama."
