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
$runtimeTarget = Join-Path (Split-Path -Parent $AppExe) "MooshieUIplus\PromptGenerator"
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
  $approvedUpgrade = $targetVersion -in @("2.3.49","2.3.50") -and $manifest.mooshieuiVersion -eq "2.3.51"
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
Write-Output "已確認 MooshieUI $targetVersion，路徑：$AppExe"
if (-not $needsExe -and -not $needsRuntime) { Write-Output "目前執行檔與 Prompt Generator 執行元件均已是指定版本。"; exit 0 }
if ($VerifyOnly) { Write-Output "驗證完成：版本與安裝包及執行元件檢查通過，未修改正式程式。"; exit 0 }
if (Get-Process -Name "comfyui-desktop" -ErrorAction SilentlyContinue) {
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
try {
  if ($needsExe) {
    Copy-Item -LiteralPath $source -Destination $AppExe -Force -ErrorAction Stop
    if ((Get-FileHash -LiteralPath $AppExe -Algorithm SHA256).Hash -ne $expected) {
      throw "安裝後 EXE 校驗失敗。"
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
  throw "安裝失敗，已還原本次變動：" + $_.Exception.Message
}
Write-Output "MooshieUIplus 已安裝。Prompt Generator 執行元件位於：$runtimeTarget；使用此功能前仍需安裝並啟動 Ollama。"
