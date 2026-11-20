# MooshieUI local ComfyUI launcher. Keep the external-backend setting intact.
# A healthy HTTP endpoint is not ready until required custom nodes are loaded.
param([switch]$RepairOnly)
$ErrorActionPreference = 'Stop'
$appRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFile = Join-Path $appRoot 'data\config.json'
if (-not (Test-Path -LiteralPath $configFile)) { throw "MooshieUI config missing: $configFile" }
$config = Get-Content -LiteralPath $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
$comfy = [string]$config.comfyui_path
$baseUrl = ([string]$config.server_url).TrimEnd('/')
if ($baseUrl -notmatch '^http://(127\.0\.0\.1|localhost):([0-9]{2,5})$') {
  Write-Output "COMFY_EXTERNAL_BACKEND: $baseUrl (no local node changes)"
  exit 0
}
$port = [int]$Matches[2]
if (-not $comfy -or -not (Test-Path -LiteralPath (Join-Path $comfy 'main.py'))) {
  throw "Local ComfyUI path is invalid: $comfy"
}
$startScript = Join-Path $comfy 'start_comfyui.cmd'
$nodeDir = Join-Path $comfy 'custom_nodes\mooshie-nodes'
$assets = Join-Path $appRoot 'MooshieUIplus\ComfyNodes'
$manifestFile = Join-Path $assets 'comfy-nodes.json'
$logDir = Join-Path (Split-Path -Parent $comfy) 'temp'
if (-not (Test-Path -LiteralPath $manifestFile)) { throw "Missing versioned ComfyUI node manifest: $manifestFile" }
$nodeInfo = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
$required = @($nodeInfo.requiredNodes | Where-Object { $_ -is [string] -and $_.Trim() })
if ($required.Count -eq 0) { throw 'ComfyUI node manifest has no requiredNodes; refusing incomplete verification.' }
function Resolve-NodeDestination([string]$name) {
  $relative = $name.Replace('/', '\')
  if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|\\)\.\.($|\\)') { throw "Unsafe node path: $name" }
  if ($relative.StartsWith('custom_nodes\', [StringComparison]::OrdinalIgnoreCase)) {
    return Join-Path (Join-Path $comfy 'custom_nodes') $relative.Substring(13)
  }
  return Join-Path $nodeDir $relative
}
$mutex = New-Object System.Threading.Mutex($false,'Local\PICTURE_ComfyUI_Start')
$hasLock = $false
function Test-Http {
  try {
    $response = Invoke-WebRequest -Uri ($baseUrl+'/system_stats') -UseBasicParsing -TimeoutSec 3
    return $response.StatusCode -eq 200
  } catch { return $false }
}
function Get-MissingNodes {
  $obj = Invoke-RestMethod -Uri ($baseUrl+'/object_info') -TimeoutSec 15
  $names = @($obj.PSObject.Properties.Name)
  return @($required | Where-Object { $names -notcontains $_ })
}
function Get-Listener {
  return @(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalAddress -in @('127.0.0.1','::1') })
}
function Assert-NoPendingJobs {
  $queue = Invoke-RestMethod -Uri ($baseUrl+'/queue') -TimeoutSec 5
  if (@($queue.queue_running).Count -ne 0 -or @($queue.queue_pending).Count -ne 0) {
    throw 'ComfyUI still has running or queued image generation; node repair deferred.'
  }
}
function Start-LocalComfy {
  if (-not (Test-Path -LiteralPath $startScript)) {
    throw "Cannot start local ComfyUI: missing $startScript"
  }
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  Start-Process -FilePath $env:ComSpec -ArgumentList '/d','/c',$startScript -WorkingDirectory $comfy -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logDir 'comfyui_backend.log') -RedirectStandardError (Join-Path $logDir 'comfyui_backend_error.log') -ErrorAction Stop | Out-Null
  Write-Output 'COMFY_START_REQUESTED'
}
try {
  $hasLock = $mutex.WaitOne([TimeSpan]::FromMinutes(4))
  if (-not $hasLock) { throw 'ComfyUI startup is already being handled by another launcher.' }
  $listening = @(Get-Listener)
  $online = Test-Http
  $missing = if ($online) { @(Get-MissingNodes) } else { @() }

  # A released installer copies the matching node pack beside the application.
  # No pack means a manually managed installation: never manufacture node files.
  $needsSync = $false
  $fileHashes = $null
  if (Test-Path -LiteralPath $manifestFile) {
    $info = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $fileHashes = $info.files
    foreach ($item in $fileHashes.PSObject.Properties) {
      $source = Join-Path $assets $item.Name
      if (-not (Test-Path -LiteralPath $source) -or
          (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne [string]$item.Value) {
        throw "ComfyUI node pack corrupt or incomplete: $($item.Name)"
      }
      $destination = Resolve-NodeDestination $item.Name
      if (-not (Test-Path -LiteralPath $destination) -or
          (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne [string]$item.Value) {
        $needsSync = $true
      }
    }
  }
  if ($online -and $missing.Count -eq 0 -and -not $needsSync) {
    Write-Output 'COMFY_ALREADY_HEALTHY_NODES_OK'
    exit 0
  }
  if ($online) { Assert-NoPendingJobs }
  if ($needsSync) {
    $backup = Join-Path $appRoot ('MooshieUIplus\history\comfy-nodes\'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
    foreach ($item in $fileHashes.PSObject.Properties) {
      $source = Join-Path $assets $item.Name
      $destination = Resolve-NodeDestination $item.Name
      if ((Test-Path -LiteralPath $destination) -and
          (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -eq [string]$item.Value) { continue }
      if (Test-Path -LiteralPath $destination) {
        $saved = Join-Path $backup $item.Name
        New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null
        Copy-Item -LiteralPath $destination -Destination $saved -Force
      }
      New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
      Copy-Item -LiteralPath $source -Destination $destination -Force
      if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne [string]$item.Value) {
        throw "Node file sync failed: $($item.Name)"
      }
    }
    Write-Output 'COMFY_NODE_FILES_SYNCED'
  }
  if ($online) {
    if ($missing.Count -eq 0 -and -not $needsSync) { exit 0 }
    if (-not (Test-Path -LiteralPath $startScript)) {
      throw 'Node files were updated, but this external ComfyUI has no supported restart script.'
    }
    if ($listening.Count -ne 1) { throw 'ComfyUI port ownership ambiguous; refusing automatic restart.' }
    $proc = Get-CimInstance Win32_Process -Filter ('ProcessId='+$listening[0].OwningProcess)
    $parent = if ($proc) { Get-CimInstance Win32_Process -Filter ('ProcessId='+$proc.ParentProcessId) }
    # The supported Windows launcher may have two Python main.py processes as
    # parent/child. Validate the *actual port owner* rather than its parent text.
    if (-not $proc -or
        $proc.CommandLine -notmatch '(?i)(^|\s)main\.py(\s|$)' -or
        $proc.CommandLine -notmatch ('(?i)--port\s+' + [regex]::Escape([string]$port) + '(\s|$)') -or
        $proc.CommandLine -notmatch '(?i)--listen\s+127\.0\.0\.1(\s|$)') {
      throw 'ComfyUI port is owned by an unrecognized process; restart it manually after node sync.'
    }
    $logBackup = Join-Path $appRoot ('MooshieUIplus\history\comfy-startup\'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Path $logBackup -Force | Out-Null
    foreach ($name in @('comfyui_backend.log','comfyui_backend_error.log')) {
      $log = Join-Path $logDir $name
      if (Test-Path -LiteralPath $log) { Copy-Item -LiteralPath $log -Destination (Join-Path $logBackup $name) }
    }
    Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
    for ($i=0; $i -lt 20 -and @(Get-Listener).Count -gt 0; $i++) { Start-Sleep -Milliseconds 500 }
    if (@(Get-Listener).Count -gt 0) { throw 'ComfyUI port still occupied; cannot restart safely.' }
    Write-Output 'COMFY_RESTARTED_FOR_NODE_SYNC'
  } elseif ($listening.Count -gt 0) {
    throw 'ComfyUI port is in use but not healthy.'
  }
  if ($RepairOnly -and -not $online) {
    Write-Output 'COMFY_NODE_FILES_READY_SERVER_OFFLINE'
    exit 0
  }
  Start-LocalComfy
  for ($i=0; $i -lt 120; $i++) {
    if (Test-Http) {
      $stillMissing = @(Get-MissingNodes)
      if ($stillMissing.Count -gt 0) { throw ('ComfyUI started without required nodes: '+($stillMissing -join ', ')) }
      Write-Output 'COMFY_READY_NODES_OK'
      exit 0
    }
    Start-Sleep -Seconds 2
  }
  throw "ComfyUI not ready after restart; check $logDir\comfyui_backend_error.log"
} finally {
  if ($hasLock) { $mutex.ReleaseMutex() }
  $mutex.Dispose()
}
