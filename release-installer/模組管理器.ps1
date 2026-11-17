param(
  [ValidateSet("","Local","Restore","Check","Update")][string]$Action = "",
  [string]$AppExe = "",
  [string]$ResultFile = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$installer = Join-Path $root "Install-MooshieUIplus.ps1"
$remote = Join-Path $root "Release-Update.ps1"
$manifestFile = Join-Path $root "manifest.json"
$payload = Join-Path $root "payload\comfyui-desktop.exe"
$settingsFile = Join-Path $env:LOCALAPPDATA "MooshieUIplus\manager-settings.json"
$backupRoot = Join-Path $env:LOCALAPPDATA "MooshieUIplus\history\exe-backups"

if ($Action) {
  if (-not $AppExe -or -not (Test-Path -LiteralPath $AppExe)) { throw "找不到 MooshieUI 主程式。" }
  if ($Action -in @("Check","Update")) {
    & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $remote -Action $Action -AppExe $AppExe -ManagerRoot $root -ResultFile $ResultFile
    if ($LASTEXITCODE -ne 0) { throw "GitHub 檢查或更新失敗。" }
  } else {
    $args = @("-NoProfile","-STA","-ExecutionPolicy","Bypass","-File",$installer,"-AppExe",$AppExe)
    if ($Action -eq "Restore") { $args += "-Restore" }
    & powershell.exe @args
    if ($LASTEXITCODE -ne 0) { throw "安裝或還原失敗。" }
    if ($ResultFile) {
      [ordered]@{
        status="success"
        action=$Action
        message=if ($Action -eq "Restore") { "已從備份還原 EXE。" } else { "本地整合模組安裝完成。" }
      } | ConvertTo-Json | Set-Content -LiteralPath $ResultFile -Encoding UTF8
    }
  }
  exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object System.Windows.Forms.Form
$form.Text = "MooshieUIplus｜GitHub 模組管理器"
$form.Size = [System.Drawing.Size]::new(750,515)
$form.MinimumSize = [System.Drawing.Size]::new(720,490)
$form.StartPosition = "CenterScreen"
$form.Font = [System.Drawing.Font]::new("Microsoft JhengHei", 10)
$form.BackColor = [System.Drawing.Color]::FromArgb(30,34,40)
$form.ForeColor = [System.Drawing.Color]::White
function Label([string]$t,[int]$x,[int]$y,[int]$w,[int]$h) {
  $c = New-Object System.Windows.Forms.Label
  $c.Text=$t; $c.SetBounds($x,$y,$w,$h); $form.Controls.Add($c); return $c
}
function Button([string]$t,[int]$x,[int]$y,[int]$w,[int]$h) {
  $c = New-Object System.Windows.Forms.Button
  $c.Text=$t; $c.SetBounds($x,$y,$w,$h)
  $c.BackColor=[System.Drawing.Color]::FromArgb(53,60,73)
  $c.ForeColor=[System.Drawing.Color]::White
  $c.FlatStyle="Flat"; $form.Controls.Add($c); return $c
}
Label "MooshieUIplus｜GitHub 模組管理器" 20 15 690 36 | Out-Null
Label "整合套件：LoRA、TAG 中文、Prompt Generator、Creative Tools" 20 55 690 26 | Out-Null
$n=Label "直接查詢 GitHub 更新；未變更不下載。只有管理器更新時下載小型更新包。" 20 87 690 30
$n.ForeColor=[System.Drawing.Color]::LightGray
Label "MooshieUI 安裝位置" 20 132 690 23 | Out-Null
$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.ReadOnly=$true
$pathBox.SetBounds(20,162,535,30)
$pathBox.BackColor=[System.Drawing.Color]::FromArgb(40,44,52)
$pathBox.ForeColor=[System.Drawing.Color]::White
$form.Controls.Add($pathBox)
$pickButton=Button "選取執行檔" 572 160 155 35
$info = New-Object System.Windows.Forms.TextBox
$info.ReadOnly=$true; $info.Multiline=$true; $info.ScrollBars="Vertical"
$info.SetBounds(20,213,707,92)
$info.BackColor=[System.Drawing.Color]::FromArgb(40,44,52)
$info.ForeColor=[System.Drawing.Color]::White
$form.Controls.Add($info)
$githubButton=Button "檢查 GitHub 並更新" 20 325 280 50
$restoreButton=Button "還原備份" 314 325 184 50
$offlineButton=Button "本地套件安裝" 513 325 214 50
$status=Label "就緒" 20 394 707 50
$status.ForeColor=[System.Drawing.Color]::LightGray
$footer=Label "不需要 CMD、Node.js、Rust 或 Git；更新時必須先關閉 MooshieUI。" 20 446 707 26
$footer.ForeColor=[System.Drawing.Color]::LightGray

$script:worker=$null
$script:workerAction=""
$script:resultPath=""
$script:outPath=""
$script:errPath=""
$script:knownRelease=""
function Has-Backup([string]$app) {
  if (-not $app -or -not (Test-Path -LiteralPath $backupRoot)) { return $false }
  foreach ($f in @(Get-ChildItem -LiteralPath $backupRoot -Filter "backup.json" -Recurse -File -ErrorAction SilentlyContinue)) {
    try {
      $r=Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($r.appExe -eq $app -and (Test-Path -LiteralPath (Join-Path $f.DirectoryName "comfyui-desktop.exe"))) { return $true }
    } catch {}
  }
  return $false
}
function Refresh-Info {
  $githubButton.Enabled=$false; $restoreButton.Enabled=$false; $offlineButton.Enabled=$false
  if (-not $pathBox.Text -or -not (Test-Path -LiteralPath $pathBox.Text)) {
    $info.Text="請選擇已安裝的 comfyui-desktop.exe。"; return
  }
  $app=$pathBox.Text
  $version=(Get-Item -LiteralPath $app).VersionInfo.ProductVersion
  if ([IO.Path]::GetFileName($app) -ne "comfyui-desktop.exe" -or -not $version) {
    $info.Text="選取的檔案不是有效的 MooshieUI 主程式。"; return
  }
  $githubButton.Enabled=(Test-Path -LiteralPath $remote)
  $restoreButton.Enabled=Has-Backup $app
  $hasLocal=(Test-Path -LiteralPath $manifestFile) -and (Test-Path -LiteralPath $payload)
  $localState="未提供（可直接從 GitHub 更新）"
  if ($hasLocal) {
    try {
      $manifest=Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($manifest.mooshieuiVersion -eq $version -and $manifest.payloadSha256 -eq (Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash) {
        $offlineButton.Enabled=$true
        $localState="可用（$($manifest.release)）"
      } else { $localState="與目前版本不相容" }
    } catch { $localState="無法驗證" }
  }
  $remoteState=if ($script:knownRelease) { $script:knownRelease } else { "尚未檢查" }
  $backupState=if ($restoreButton.Enabled) { "可還原" } else { "無備份" }
  $info.Text="MooshieUI：$version" + [Environment]::NewLine + "GitHub 更新：$remoteState　｜　備份：$backupState" + [Environment]::NewLine + "本地套件：$localState"
  if ($script:worker) {
    $githubButton.Enabled=$false; $restoreButton.Enabled=$false; $offlineButton.Enabled=$false
  }
}
$timer=New-Object System.Windows.Forms.Timer
$timer.Interval=800
$timer.Add_Tick({
  if (-not $script:worker) { $timer.Stop(); return }
  $script:worker.Refresh()
  if (-not $script:worker.HasExited) { return }
  $script:worker.Dispose()
  $script:worker=$null
  $timer.Stop()
  $result=$null
  if (Test-Path -LiteralPath $script:resultPath) {
    try { $result=Get-Content -LiteralPath $script:resultPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
  }
  $action=$script:workerAction
  $pickButton.Enabled=$true
  if (-not $result) {
    $errors=if (Test-Path -LiteralPath $script:errPath) { @(Get-Content -LiteralPath $script:errPath -ErrorAction SilentlyContinue | Select-Object -Last 12) -join [Environment]::NewLine } else { "" }
    if (-not $errors -and (Test-Path -LiteralPath $script:outPath)) {
      $errors=@(Get-Content -LiteralPath $script:outPath -ErrorAction SilentlyContinue | Select-Object -Last 12) -join [Environment]::NewLine
    }
    $status.Text="操作失敗，請查看日誌。"
    [System.Windows.Forms.MessageBox]::Show($errors,"更新失敗","OK","Error") | Out-Null
  } elseif ($action -eq "Check") {
    $script:knownRelease=[string]$result.message
    $status.Text=$result.message
    if ($result.status -eq "available") {
      $detail=if ($result.needsExe) { "需更新整合 EXE（將下載完整 B 包）。" } else { "僅更新管理器（下載小型更新包）。" }
      $question="找到 $($result.release)。$detail" + [Environment]::NewLine + "是否立即下載並安裝？安裝時請關閉 MooshieUI。"
      if ([System.Windows.Forms.MessageBox]::Show($question,"確認更新","YesNo","Question") -eq [System.Windows.Forms.DialogResult]::Yes) {
        Start-Worker "Update"
        return
      }
    }
  } else {
    $status.Text=$result.message
    if ($result.status -eq "updated" -or $result.status -eq "success") {
      [System.Windows.Forms.MessageBox]::Show($result.message,"MooshieUIplus","OK","Information") | Out-Null
      if ($action -eq "Update") { $script:knownRelease="已更新 $($result.release)" }
    }
  }
  Refresh-Info
})
function Start-Worker([string]$operation) {
  if ($script:worker -or -not $pathBox.Text) { return }
  $folder=Join-Path $env:LOCALAPPDATA "MooshieUIplus\temp"
  New-Item -ItemType Directory -Path $folder -Force | Out-Null
  $stamp=Get-Date -Format "yyyyMMdd-HHmmss-fff"
  $script:resultPath=Join-Path $folder "manager-$stamp.result.json"
  $script:outPath=Join-Path $folder "manager-$stamp.out.log"
  $script:errPath=Join-Path $folder "manager-$stamp.err.log"
  $script:workerAction=$operation
  $args=@("-NoProfile","-STA","-ExecutionPolicy","Bypass","-File",('"' + $PSCommandPath + '"'),"-Action",$operation,"-AppExe",('"' + $pathBox.Text + '"'),"-ResultFile",('"' + $script:resultPath + '"'))
  try {
    $script:worker=Start-Process -FilePath "powershell.exe" -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput $script:outPath -RedirectStandardError $script:errPath
    $status.Text="正在執行 $operation；更新資訊只讀取必要的 GitHub 資料。"
    $pickButton.Enabled=$false
    Refresh-Info
    $timer.Start()
  } catch { $status.Text="無法執行：$($_.Exception.Message)" }
}
$pickButton.Add_Click({
  $dialog=New-Object System.Windows.Forms.OpenFileDialog
  $dialog.Title="選擇已安裝的 MooshieUI comfyui-desktop.exe"
  $dialog.Filter="MooshieUI 執行檔|comfyui-desktop.exe"
  if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $pathBox.Text=$dialog.FileName
    $script:knownRelease=""
    New-Item -ItemType Directory -Path (Split-Path -Parent $settingsFile) -Force | Out-Null
    @{appExe=$dialog.FileName} | ConvertTo-Json | Set-Content -LiteralPath $settingsFile -Encoding UTF8
    Refresh-Info
  }
})
$githubButton.Add_Click({ Start-Worker "Check" })
$restoreButton.Add_Click({
  if ([System.Windows.Forms.MessageBox]::Show("還原最近一份 EXE 備份？請先關閉 MooshieUI。","還原確認","YesNo","Warning") -eq [System.Windows.Forms.DialogResult]::Yes) {
    Start-Worker "Restore"
  }
})
$offlineButton.Add_Click({
  if ([System.Windows.Forms.MessageBox]::Show("使用解壓資料夾內的預編譯 EXE 安裝？請先關閉 MooshieUI。","本地安裝確認","YesNo","Warning") -eq [System.Windows.Forms.DialogResult]::Yes) {
    Start-Worker "Local"
  }
})
if (Test-Path -LiteralPath $settingsFile) {
  try {
    $saved=Get-Content -LiteralPath $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($saved.appExe -and (Test-Path -LiteralPath $saved.appExe)) { $pathBox.Text=[string]$saved.appExe }
  } catch {}
}
if (-not $pathBox.Text) {
  $candidate=Join-Path (Split-Path -Parent (Split-Path -Parent $root)) "MooshieUI\comfyui-desktop.exe"
  if (Test-Path -LiteralPath $candidate) { $pathBox.Text=$candidate }
}
Refresh-Info
[void]$form.ShowDialog()
