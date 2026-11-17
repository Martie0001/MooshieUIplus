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
  if (-not (Test-Path -LiteralPath $AppExe)) { throw "找不到已安裝的 MooshieUI EXE。" }
  if ($Action -eq "Check" -or $Action -eq "Update") {
    & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $remote -Action $Action -AppExe $AppExe -ResultFile $ResultFile
    if ($LASTEXITCODE -ne 0) { throw "GitHub 發布版操作失敗。" }
  } else {
    $arguments = @("-NoProfile","-STA","-ExecutionPolicy","Bypass","-File",$installer,"-AppExe",$AppExe)
    if ($Action -eq "Restore") { $arguments += "-Restore" }
    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "本地安裝／還原失敗。" }
    [ordered]@{
      status = "success"
      action = $Action
      message = if ($Action -eq "Restore") { "備份已還原。" } else { "整合模組已安裝／更新。" }
    } | ConvertTo-Json | Set-Content -LiteralPath $ResultFile -Encoding UTF8
  }
  exit 0
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object System.Windows.Forms.Form
$form.Text = "MooshieUIplus｜免編譯模組管理器"
$form.Size = [System.Drawing.Size]::new(760, 550)
$form.MinimumSize = [System.Drawing.Size]::new(740, 530)
$form.StartPosition = "CenterScreen"
$form.Font = [System.Drawing.Font]::new("Microsoft JhengHei", 10)
$form.BackColor = [System.Drawing.Color]::FromArgb(30,34,40)
$form.ForeColor = [System.Drawing.Color]::White
function Label([string]$text,[int]$x,[int]$y,[int]$w,[int]$h) {
  $c = New-Object System.Windows.Forms.Label
  $c.Text=$text; $c.SetBounds($x,$y,$w,$h); $form.Controls.Add($c); return $c
}
function Button([string]$text,[int]$x,[int]$y,[int]$w,[int]$h) {
  $c = New-Object System.Windows.Forms.Button
  $c.Text=$text; $c.SetBounds($x,$y,$w,$h)
  $c.BackColor=[System.Drawing.Color]::FromArgb(53,60,73)
  $c.ForeColor=[System.Drawing.Color]::White
  $c.FlatStyle="Flat"; $form.Controls.Add($c); return $c
}
Label "MooshieUIplus｜免編譯模組管理" 22 18 710 36 | Out-Null
Label "LoRA Manager / TAG Manager / Prompt Generator / Creative Tools" 22 60 710 27 | Out-Null
$note=Label "四個模組共用同一個已編譯 EXE，安裝／更新／還原均針對整套模組。" 22 89 710 40
$note.ForeColor=[System.Drawing.Color]::LightGray
Label "選擇已安裝的 MooshieUI comfyui-desktop.exe" 22 135 710 26 | Out-Null
$pathBox=New-Object System.Windows.Forms.TextBox
$pathBox.ReadOnly=$true; $pathBox.SetBounds(22,163,540,29)
$pathBox.BackColor=[System.Drawing.Color]::FromArgb(40,44,52)
$pathBox.ForeColor=[System.Drawing.Color]::White
$form.Controls.Add($pathBox)
$choose=Button "選擇程式" 574 162 155 32
$info=New-Object System.Windows.Forms.TextBox
$info.ReadOnly=$true; $info.Multiline=$true; $info.ScrollBars="Vertical"
$info.SetBounds(22,210,707,110)
$info.BackColor=[System.Drawing.Color]::FromArgb(40,44,52)
$info.ForeColor=[System.Drawing.Color]::White
$form.Controls.Add($info)
$localButton=Button "安裝／更新本地套件" 22 337 224 44
$restoreButton=Button "還原備份" 257 337 145 44
$checkButton=Button "檢查 GitHub 更新" 413 337 179 44
$remoteButton=Button "安裝發布版" 605 337 124 44
$status=Label "就緒" 22 403 707 47
$status.ForeColor=[System.Drawing.Color]::LightGray
$footer=Label "需先有正常運作的官方 MooshieUI 2.3.49。無須 Node、Git、Rust 或 C++ 編譯環境。" 22 465 707 29
$footer.ForeColor=[System.Drawing.Color]::LightGray

$script:worker=$null
$script:workAction=""
$script:workResult=""
$script:workOutput=""
$script:workError=""
$script:checkedRelease=""
function Has-Backup([string]$app) {
  if (-not $app -or -not (Test-Path -LiteralPath $backupRoot)) { return $false }
  foreach ($p in @(Get-ChildItem -LiteralPath $backupRoot -Filter "backup.json" -Recurse -File -ErrorAction SilentlyContinue)) {
    try {
      $record=Get-Content -LiteralPath $p.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($record.appExe -eq $app -and (Test-Path -LiteralPath (Join-Path $p.DirectoryName "comfyui-desktop.exe"))) { return $true }
    } catch {}
  }
  return $false
}
function Refresh-Info {
  $localButton.Enabled=$false; $restoreButton.Enabled=$false; $checkButton.Enabled=$false; $remoteButton.Enabled=$false
  try {
    if (-not (Test-Path $installer) -or -not (Test-Path $payload) -or -not (Test-Path $manifestFile)) {
      $info.Text="套件缺少安裝器、payload 或 manifest。請重新解壓整個 ZIP。"; return
    }
    $manifest=Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.mooshieuiVersion -ne "2.3.49" -or (Get-FileHash $payload -Algorithm SHA256).Hash -ne $manifest.payloadSha256) {
      $info.Text="套件版本或 EXE SHA256 校驗失敗。"; return
    }
    if (-not $pathBox.Text -or -not (Test-Path $pathBox.Text)) {
      $info.Text="整合套件：MooshieUI 2.3.49 / $($manifest.release)" + [Environment]::NewLine + "請先選擇已安裝的主程式。"; return
    }
    $app=$pathBox.Text
    $ver=(Get-Item -LiteralPath $app).VersionInfo.ProductVersion
    if ([IO.Path]::GetFileName($app) -ne "comfyui-desktop.exe" -or $ver -ne "2.3.49") {
      $info.Text="偵測到 MooshieUI $ver，僅支援 2.3.49。"; return
    }
    $same=(Get-FileHash $app -Algorithm SHA256).Hash -eq $manifest.payloadSha256
    $localButton.Enabled=-not $same
    $restoreButton.Enabled=Has-Backup $app
    $checkButton.Enabled=$true
    $remoteButton.Enabled=[bool]$script:checkedRelease
    $state=if ($same) { "已安裝本地整合版" } else { "可安裝／更新本地整合版" }
    $backup=if ($restoreButton.Enabled) { "可還原" } else { "尚無備份" }
    $github=if ($script:checkedRelease) { $script:checkedRelease } else { "尚未檢查" }
    $info.Text="MooshieUI：$ver　｜　套件：$($manifest.release)" + [Environment]::NewLine + "狀態：$state　｜　備份：$backup" + [Environment]::NewLine + "GitHub 發布版：$github"
  } catch { $info.Text="檢查失敗：$($_.Exception.Message)" }
  if ($script:worker) {
    $localButton.Enabled=$false; $restoreButton.Enabled=$false; $checkButton.Enabled=$false; $remoteButton.Enabled=$false
  }
}
$timer=New-Object System.Windows.Forms.Timer
$timer.Interval=900
$timer.Add_Tick({
  if (-not $script:worker) { $timer.Stop(); return }
  $script:worker.Refresh()
  if (-not $script:worker.HasExited) { return }
  $script:worker.Dispose(); $script:worker=$null; $timer.Stop()
  $result=$null
  if (Test-Path $script:workResult) {
    try { $result=Get-Content -LiteralPath $script:workResult -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
  }
  if (-not $result) {
    $errors=if (Test-Path $script:workError) { @(Get-Content $script:workError -ErrorAction SilentlyContinue | Select-Object -Last 12) -join [Environment]::NewLine } else { "" }
    $status.Text="操作失敗。日誌：" + $script:workOutput
    [System.Windows.Forms.MessageBox]::Show("沒有成功記錄。" + [Environment]::NewLine + $errors,"MooshieUIplus","OK","Error") | Out-Null
  } elseif ($script:workAction -eq "Check") {
    $script:checkedRelease=if ($result.status -eq "available") { [string]$result.release } else { "" }
    $status.Text=$result.message
  } else {
    $status.Text=$result.message
    if ($result.status -in @("updated","installed","success")) {
      [System.Windows.Forms.MessageBox]::Show($result.message,"MooshieUIplus","OK","Information") | Out-Null
    }
    if ($script:workAction -eq "Update") { $script:checkedRelease="" }
  }
  $choose.Enabled=$true
  Refresh-Info
})
function Start-Worker([string]$operation) {
  if ($script:worker -or -not $pathBox.Text) { return }
  if ($operation -ne "Check") {
    $question=switch ($operation) {
      "Local" { "備份現有 EXE 並安裝本地整合套件？" }
      "Restore" { "以最近的備份還原 EXE？" }
      "Update" { "下載已發布的相容 B 版，備份後更新 EXE？" }
    }
    if ([System.Windows.Forms.MessageBox]::Show($question + [Environment]::NewLine + "請先關閉 MooshieUI。","確認操作","YesNo","Warning") -ne [System.Windows.Forms.DialogResult]::Yes) { return }
  }
  $temp=Join-Path $env:LOCALAPPDATA "MooshieUIplus\temp"
  New-Item -ItemType Directory -Path $temp -Force | Out-Null
  $stamp=Get-Date -Format "yyyyMMdd-HHmmss-fff"
  $script:workResult=Join-Path $temp "manager-$stamp.result.json"
  $script:workOutput=Join-Path $temp "manager-$stamp.out.log"
  $script:workError=Join-Path $temp "manager-$stamp.err.log"
  $script:workAction=$operation
  $args=@("-NoProfile","-STA","-ExecutionPolicy","Bypass","-File",('"' + $PSCommandPath + '"'),"-Action",$operation,"-AppExe",('"' + $pathBox.Text + '"'),"-ResultFile",('"' + $script:workResult + '"'))
  try {
    $script:worker=Start-Process -FilePath "powershell.exe" -ArgumentList $args -WindowStyle Hidden -RedirectStandardOutput $script:workOutput -RedirectStandardError $script:workError -PassThru
    $status.Text="正在執行 $operation，完成前不會覆蓋其他資料。"
    $choose.Enabled=$false
    Refresh-Info
    $timer.Start()
  } catch { $status.Text="啟動失敗：$($_.Exception.Message)" }
}
$choose.Add_Click({
  $dialog=New-Object System.Windows.Forms.OpenFileDialog
  $dialog.Filter="comfyui-desktop.exe|comfyui-desktop.exe"
  $dialog.Title="選擇已安裝的 MooshieUI 2.3.49"
  if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $pathBox.Text=$dialog.FileName
    $script:checkedRelease=""
    New-Item -ItemType Directory -Path (Split-Path -Parent $settingsFile) -Force | Out-Null
    @{appExe=$dialog.FileName} | ConvertTo-Json | Set-Content -LiteralPath $settingsFile -Encoding UTF8
    Refresh-Info
  }
})
$localButton.Add_Click({ Start-Worker "Local" })
$restoreButton.Add_Click({ Start-Worker "Restore" })
$checkButton.Add_Click({ Start-Worker "Check" })
$remoteButton.Add_Click({ Start-Worker "Update" })
if (Test-Path $settingsFile) {
  try {
    $saved=Get-Content -LiteralPath $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($saved.appExe -and (Test-Path -LiteralPath $saved.appExe)) { $pathBox.Text=[string]$saved.appExe }
  } catch {}
}
Refresh-Info
[void]$form.ShowDialog()
