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
$stateFile = Join-Path $env:LOCALAPPDATA "MooshieUIplus\installed-release.json"
$backupRoot = Join-Path $env:LOCALAPPDATA "MooshieUIplus\history\exe-backups"
$managerVersion = "0.2.1"
if ($Action) {
  if (-not $AppExe -or -not (Test-Path -LiteralPath $AppExe)) { throw "找不到 MooshieUI 主程式。" }
  if ($Action -in @("Check","Update")) {
    & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $remote -Action $Action -AppExe $AppExe -ManagerRoot $root -ResultFile $ResultFile
    if ($LASTEXITCODE -ne 0) { throw "GitHub 檢查或更新失敗。" }
  } else {
    $arguments = @("-NoProfile","-STA","-ExecutionPolicy","Bypass","-File",$installer,"-AppExe",$AppExe)
    if ($Action -eq "Restore") { $arguments += "-Restore" }
    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "本地安裝或還原失敗。" }
    if ($ResultFile) {
      [ordered]@{
        status = "success"
        action = $Action
        message = if ($Action -eq "Restore") { "已從備份還原 EXE。" } else { "本地整合模組已安裝。" }
      } | ConvertTo-Json | Set-Content -LiteralPath $ResultFile -Encoding UTF8
    }
  }
  exit 0
}
# WPF UI based on ModAssistant's sidebar and grouped version-list layout.
# ModAssistant copyright (c) 2019-2020 Assistant. MIT License.
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms
[xml]$ui = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MooshieUIplus｜模組管理器"
        Width="1020" Height="650" MinWidth="900" MinHeight="520"
        WindowStartupLocation="CenterScreen" FontFamily="Microsoft JhengHei"
        FontSize="13" Background="#F3F5F7" Foreground="#263446">
 <Window.Resources>
  <Style x:Key="nav" TargetType="Button">
   <Setter Property="Height" Value="64"/>
   <Setter Property="Margin" Value="5,5,5,3"/>
   <Setter Property="Background" Value="White"/>
   <Setter Property="BorderBrush" Value="#CCD5DE"/>
   <Setter Property="Cursor" Value="Hand"/>
  </Style>
  <Style x:Key="action" TargetType="Button">
   <Setter Property="Height" Value="39"/>
   <Setter Property="Margin" Value="5,0,0,0"/>
   <Setter Property="Padding" Value="12,3"/>
   <Setter Property="Background" Value="#FFFFFF"/>
   <Setter Property="BorderBrush" Value="#AFBDCC"/>
   <Setter Property="Cursor" Value="Hand"/>
  </Style>
 </Window.Resources>
 <Grid Margin="10">
  <Grid.ColumnDefinitions><ColumnDefinition Width="102"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
  <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="63"/></Grid.RowDefinitions>
  <Border Grid.Column="0" Background="#E8EEF5" BorderBrush="#C6D0DB" BorderThickness="1" Margin="0,0,9,0">
   <DockPanel>
    <TextBlock x:Name="VersionText" DockPanel.Dock="Bottom" FontSize="10" Foreground="#637486"
               TextAlignment="Center" Margin="3,5,3,10" TextWrapping="Wrap" Text="MooshieUIplus"/>
    <StackPanel>
     <Button x:Name="IntroNav" Style="{StaticResource nav}">介紹</Button>
     <Button x:Name="ModsNav" Style="{StaticResource nav}">模組</Button>
     <Button x:Name="AboutNav" Style="{StaticResource nav}">關於</Button>
     <Button x:Name="OptionsNav" Style="{StaticResource nav}">設定</Button>
    </StackPanel>
   </DockPanel>
  </Border>
  <Border Grid.Column="1" Background="White" BorderBrush="#CCD5DE" BorderThickness="1">
   <Grid>
    <StackPanel x:Name="IntroPage" Margin="24" Visibility="Collapsed">
     <TextBlock FontSize="21" FontWeight="SemiBold" Text="MooshieUIplus 模組管理器"/>
     <TextBlock Margin="0,20,0,10" TextWrapping="Wrap" Text="此管理器以 GitHub Releases 發布版本更新整合模組，不需另行安裝編譯環境。"/>
     <TextBlock LineHeight="30" TextWrapping="Wrap" Text="1. 在設定頁選擇 comfyui-desktop.exe。&#10;2. 在模組頁查看整合狀態與版本資訊。&#10;3. 按下「檢查並更新」；有新版時確認後下載安裝。&#10;4. 更新 EXE 前自動備份，可使用還原備份。"/>
     <TextBlock Margin="0,20,0,0" TextWrapping="Wrap" Foreground="#586A7B"
                Text="注意：四個模組目前共用同一支整合 EXE，無法勾選個別安裝。"/>
    </StackPanel>
    <Grid x:Name="ModsPage" Margin="10">
     <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
     <DockPanel Margin="4,7,0,8">
      <TextBlock FontSize="20" FontWeight="SemiBold" Text="模組管理"/>
      <TextBlock x:Name="AppVersionText" Foreground="#60758A" Margin="16,6,0,0" Text="尚未選擇程式"/>
     </DockPanel>
     <TextBlock Grid.Row="1" Margin="4,0,0,8" Foreground="#60758A"
                Text="整合核取欄僅顯示套件狀態，模組不能單獨停用。"/>
     <ListView x:Name="ModList" Grid.Row="2" BorderBrush="#DAE2E9" SelectionMode="Single">
      <ListView.View><GridView>
       <GridViewColumn Header="整合" Width="45">
        <GridViewColumn.CellTemplate><DataTemplate>
         <CheckBox IsChecked="{Binding Verified}" IsEnabled="False" HorizontalAlignment="Center"/>
        </DataTemplate></GridViewColumn.CellTemplate>
       </GridViewColumn>
       <GridViewColumn Header="模組名稱" Width="165" DisplayMemberBinding="{Binding Name}"/>
       <GridViewColumn Header="安裝" Width="95" DisplayMemberBinding="{Binding Installed}"/>
       <GridViewColumn Header="模組版次" Width="95" DisplayMemberBinding="{Binding ModuleVersion}"/>
       <GridViewColumn Header="整合包版次" Width="135" DisplayMemberBinding="{Binding Latest}"/>
       <GridViewColumn Header="說明" Width="260" DisplayMemberBinding="{Binding Description}"/>
      </GridView></ListView.View>
     </ListView>
     <TextBlock Grid.Row="3" Margin="4,10,4,5" Foreground="#667688"
                Text="先比對 GitHub 小型更新資訊；相同版本不重新下載完整 ZIP。"/>
    </Grid>
    <StackPanel x:Name="AboutPage" Margin="24" Visibility="Collapsed">
     <TextBlock FontSize="21" FontWeight="SemiBold" Text="關於 MooshieUIplus"/>
     <TextBlock x:Name="AboutVersion" Margin="0,20,0,8" TextWrapping="Wrap" LineHeight="27"
                Text="版本資訊載入中"/>
     <TextBlock TextWrapping="Wrap" Foreground="#A65237" Margin="0,10,0,0"
                Text="Prompt Generator 已內建可攜服務；使用 AI 生成與翻譯之前，仍需另行安裝並啟動 Ollama，且至少下載一個聊天模型。"/>
     <Button x:Name="ChangelogButton" Width="176" Height="34" HorizontalAlignment="Left"
             Margin="0,12,0,0" Content="查看版本更新紀錄"/>
     <Separator Margin="0,17,0,15"/>
     <TextBlock FontWeight="SemiBold" Text="介面來源及授權"/>
     <TextBlock Margin="0,10,0,0" TextWrapping="Wrap" LineHeight="24"
                Text="版面參考 bsmg/ModAssistant，MIT License，Copyright (c) 2019–2020 Assistant。&#10;模組安裝及更新邏輯為 MooshieUIplus 自行整合，未使用 BeatMods 介面。&#10;MooshieUIplus 原始碼採 AGPL-3.0，請參閱 LICENSE／NOTICE。"/>
     <TextBlock Margin="0,25,0,0" Foreground="#426FA1" Text="github.com/Martie0001/MooshieUIplus"/>
     <TextBlock Margin="0,6,0,0" Foreground="#426FA1" Text="github.com/bsmg/ModAssistant"/>
    </StackPanel>
    <StackPanel x:Name="OptionsPage" Margin="24" Visibility="Collapsed">
     <TextBlock FontSize="21" FontWeight="SemiBold" Text="設定"/>
     <TextBlock Margin="0,24,0,7" FontWeight="SemiBold" Text="MooshieUI 安裝位置"/>
     <DockPanel>
      <Button x:Name="PickButton" DockPanel.Dock="Right" Width="95" Height="34" Margin="8,0,0,0">瀏覽</Button>
      <TextBox x:Name="ExePath" Height="34" IsReadOnly="True" VerticalContentAlignment="Center"
               Background="#F7F9FB" Padding="6,0"/>
     </DockPanel>
     <TextBlock x:Name="Detected" Foreground="#667688" Margin="0,9,0,0" Text="尚未選擇"/>
     <Separator Margin="0,24,0,16"/>
     <TextBlock FontWeight="SemiBold" Text="本地安裝"/>
     <TextBlock Margin="0,9,0,10" TextWrapping="Wrap" Text="完整 B ZIP 解壓後可直接安裝，不需要下載新的 ZIP。"/>
     <Button x:Name="LocalButton" Width="150" HorizontalAlignment="Left" Style="{StaticResource action}" Margin="0" Content="安裝本地套件"/>
     <TextBlock x:Name="LocalStatus" Margin="0,9,0,0" TextWrapping="Wrap" Foreground="#667688" Text="未找到本地安裝包"/>
    </StackPanel>
   </Grid>
  </Border>
  <Grid Grid.Column="1" Grid.Row="1" Margin="0,10,0,0">
   <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
   <Border BorderBrush="#CCD5DE" BorderThickness="1" Background="White" Margin="0,0,5,0" Padding="9">
    <StackPanel>
     <TextBlock x:Name="Status" TextTrimming="CharacterEllipsis" Text="就緒"/>
     <ProgressBar x:Name="Progress" Height="5" Margin="0,6,0,0" IsIndeterminate="True" Visibility="Collapsed"/>
    </StackPanel>
   </Border>
   <Button x:Name="InfoButton" Grid.Column="1" Width="90" Style="{StaticResource action}" Content="模組資訊"/>
   <Button x:Name="RestoreButton" Grid.Column="2" Width="96" Style="{StaticResource action}" Content="還原備份"/>
   <Button x:Name="UpdateButton" Grid.Column="3" Width="145" Style="{StaticResource action}"
           Background="#D9EAF9" FontWeight="SemiBold" Content="檢查並更新"/>
  </Grid>
 </Grid>
</Window>
'@
$reader = [System.Xml.XmlNodeReader]::new($ui)
$window = [Windows.Markup.XamlReader]::Load($reader)
foreach ($n in @("VersionText","IntroNav","ModsNav","AboutNav","OptionsNav","IntroPage","ModsPage","AboutPage","OptionsPage","AboutVersion","ChangelogButton","AppVersionText","ModList","PickButton","ExePath","Detected","LocalButton","LocalStatus","Status","Progress","InfoButton","RestoreButton","UpdateButton")) {
  Set-Variable -Scope Script -Name $n -Value $window.FindName($n)
}
$window.Title = "MooshieUIplus v$managerVersion｜模組管理器"
$AboutVersion.Text = "管理器：v$managerVersion；官方 MooshieUI：2.3.49`n本版修復 Prompt Generator 可攜服務與 Ollama 模型選擇；詳細修正見 GitHub 更新紀錄。`n更新功能：GitHub 版本比對、下載快取、安裝備份、還原。"
$table = New-Object System.Data.DataTable
foreach ($name in @("Name","Installed","Latest","ModuleVersion","Description")) { [void]$table.Columns.Add($name,[string]) }
[void]$table.Columns.Add("Verified",[bool])
foreach ($item in @(
  @("LoRA Manager","1.3.1","LoRA 瀏覽、分類與資訊管理"),
  @("TAG Manager","1.0.1","中英 TAG 對照與提示"),
  @("Prompt Generator","1.1.1","內建可攜提示詞服務、Ollama 模型自訂與測試；需另裝 Ollama"),
  @("Creative Tools","0.5.0","擴圖、姿勢、後製與漫畫工具")
)) {
  $row = $table.NewRow()
  $row["Name"]=$item[0];$row["ModuleVersion"]=$item[1];$row["Description"]=$item[2]
  $row["Installed"]="尚未確認";$row["Latest"]="尚未取得";$row["Verified"]=$false
  $table.Rows.Add($row)
}
$ModList.ItemsSource=$table.DefaultView
$script:appExe=""
$script:worker=$null
$script:actionName=""
$script:resultPath=""
$script:outPath=""
$script:errPath=""
function Has-Backup($app) {
  if (-not $app -or -not (Test-Path -LiteralPath $backupRoot)) { return $false }
  foreach ($f in @(Get-ChildItem -LiteralPath $backupRoot -Filter "backup.json" -Recurse -File -ErrorAction SilentlyContinue)) {
    try {
      $r=Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($r.appExe -eq $app -and (Test-Path -LiteralPath (Join-Path $f.DirectoryName "comfyui-desktop.exe"))) { return $true }
    } catch {}
  }
  return $false
}
function Show-Page([string]$page) {
  foreach ($n in @("Intro","Mods","About","Options")) {
    $panel=Get-Variable -Scope Script -Name ($n+"Page") -ValueOnly
    $nav=Get-Variable -Scope Script -Name ($n+"Nav") -ValueOnly
    $panel.Visibility=if($n -eq $page){"Visible"}else{"Collapsed"}
    $nav.Background=if($n -eq $page){"#C8E1F7"}else{"White"}
  }
}
function Refresh-Info {
  $UpdateButton.IsEnabled=$false;$RestoreButton.IsEnabled=$false;$LocalButton.IsEnabled=$false
  if (-not $script:appExe -or -not (Test-Path -LiteralPath $script:appExe)) {
    $AppVersionText.Text="尚未選擇 MooshieUI 主程式"
    $Detected.Text="尚未選擇"
    foreach($r in $table.Rows){$r["Installed"]="尚未確認";$r["Verified"]=$false}
    return
  }
  $ExePath.Text=$script:appExe
  $version=(Get-Item -LiteralPath $script:appExe).VersionInfo.ProductVersion
  $AppVersionText.Text="主程式：$version｜管理器：v$managerVersion"
  $Detected.Text="目前版本：$version"
  $VersionText.Text="MooshieUIplus v$managerVersion / MooshieUI $version"
  $hash=(Get-FileHash -LiteralPath $script:appExe -Algorithm SHA256).Hash
  $verified=$false
  if(Test-Path -LiteralPath $manifestFile){
    try{
      $m=Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8|ConvertFrom-Json
      $verified=$m.mooshieuiVersion -eq $version -and $m.payloadSha256 -eq $hash
    }catch{}
  }
  if(-not $verified -and (Test-Path -LiteralPath $stateFile)){
    try{
      $s=Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8|ConvertFrom-Json
      $verified=$s.appExe -eq $script:appExe -and $s.exeSha256 -eq $hash
    }catch{}
  }
  $runtimeReady=Test-Path -LiteralPath (Join-Path (Split-Path -Parent $script:appExe) "MooshieUIplus\PromptGenerator\node.exe")
  foreach($r in $table.Rows){
    $ready=$verified -and ($r["Name"] -ne "Prompt Generator" -or $runtimeReady)
    $r["Installed"]=if($ready){"已整合"}elseif($verified -and $r["Name"] -eq "Prompt Generator"){"待補執行元件"}else{"尚未確認"}
    $r["Verified"]=$ready
  }
  $UpdateButton.IsEnabled=Test-Path -LiteralPath $remote
  $RestoreButton.IsEnabled=Has-Backup $script:appExe
  $LocalStatus.Text="未找到本地整合包，可直接使用 GitHub 更新"
  if((Test-Path -LiteralPath $manifestFile) -and (Test-Path -LiteralPath $payload)){
    try{
      $m=Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8|ConvertFrom-Json
      if($m.mooshieuiVersion -eq $version -and (Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash -eq $m.payloadSha256){
        $LocalButton.IsEnabled=$true
        $LocalStatus.Text="已找到本地套件：$($m.release)"
      }else{$LocalStatus.Text="本地套件與 MooshieUI 版本不相容"}
    }catch{$LocalStatus.Text="本地套件資料無法驗證"}
  }
  if($script:worker){$UpdateButton.IsEnabled=$false;$RestoreButton.IsEnabled=$false;$LocalButton.IsEnabled=$false}
}
function Start-Worker([string]$operation) {
  if($script:worker -or -not $script:appExe){return}
  $temp=Join-Path $env:LOCALAPPDATA "MooshieUIplus\temp"
  New-Item -ItemType Directory -Path $temp -Force|Out-Null
  $stamp=Get-Date -Format "yyyyMMdd-HHmmss-fff"
  $script:actionName=$operation
  $script:resultPath=Join-Path $temp "manager-$stamp.result.json"
  $script:outPath=Join-Path $temp "manager-$stamp.out.log"
  $script:errPath=Join-Path $temp "manager-$stamp.err.log"
  $args=@("-NoProfile","-STA","-ExecutionPolicy","Bypass","-File",('"' + $PSCommandPath + '"'),"-Action",$operation,"-AppExe",('"' + $script:appExe + '"'),"-ResultFile",('"' + $script:resultPath + '"'))
  try{
    $script:worker=Start-Process -FilePath "powershell.exe" -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput $script:outPath -RedirectStandardError $script:errPath
    $Status.Text="正在執行：$operation"
    $Progress.Visibility="Visible"
    $PickButton.IsEnabled=$false
    Refresh-Info
    $timer.Start()
  }catch{$Status.Text="啟動失敗：$($_.Exception.Message)"}
}
$timer=New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval=[TimeSpan]::FromMilliseconds(800)
$timer.Add_Tick({
  if(-not $script:worker){$timer.Stop();return}
  $script:worker.Refresh()
  if(-not $script:worker.HasExited){return}
  $code=$script:worker.ExitCode
  $script:worker.Dispose();$script:worker=$null;$timer.Stop()
  $PickButton.IsEnabled=$true;$Progress.Visibility="Collapsed"
  $result=$null
  if(Test-Path -LiteralPath $script:resultPath){try{$result=Get-Content -LiteralPath $script:resultPath -Raw -Encoding UTF8|ConvertFrom-Json}catch{}}
  if($code -ne 0 -or -not $result){
    $errorText=if(Test-Path -LiteralPath $script:errPath){@(Get-Content -LiteralPath $script:errPath|Select-Object -Last 12)-join [Environment]::NewLine}else{""}
    if(-not $errorText -and (Test-Path -LiteralPath $script:outPath)){$errorText=@(Get-Content -LiteralPath $script:outPath|Select-Object -Last 12)-join [Environment]::NewLine}
    $Status.Text="執行失敗，請查看操作日誌。"
    [System.Windows.MessageBox]::Show($errorText,"MooshieUIplus","OK","Error")|Out-Null
  }elseif($script:actionName -eq "Check"){
    $Status.Text=$result.message
    if($result.release){foreach($r in $table.Rows){$r["Latest"]=[string]$result.release}}
    if($result.status -eq "available"){
      $detail=if($result.needsExe){"將下載完整整合 EXE。"}elseif($result.needsRuntime){"將下載 B 套件補齊 Prompt Generator 可攜執行元件。"}else{"只會更新管理器。"}
      if([System.Windows.MessageBox]::Show("找到 $($result.release)：$detail 是否安裝？","確認更新","YesNo","Question") -eq "Yes"){
        Start-Worker "Update";return
      }
    }
  }else{
    $Status.Text=$result.message
    if($result.status -in @("success","updated","installed")){[System.Windows.MessageBox]::Show($result.message,"MooshieUIplus","OK","Information")|Out-Null}
  }
  Refresh-Info
})
$IntroNav.Add_Click({Show-Page "Intro"})
$ModsNav.Add_Click({Show-Page "Mods"})
$AboutNav.Add_Click({Show-Page "About"})
$OptionsNav.Add_Click({Show-Page "Options"})
$ChangelogButton.Add_Click({
  Start-Process "https://github.com/Martie0001/MooshieUIplus/blob/main/CHANGELOG.md"
})
$InfoButton.Add_Click({
  if(-not $ModList.SelectedItem){[System.Windows.MessageBox]::Show("請先選取一個模組。","模組資訊","OK","Information")|Out-Null;return}
  $item=$ModList.SelectedItem
  $message=[string]$item["Name"]+[Environment]::NewLine+[string]$item["Description"]+[Environment]::NewLine+"此模組屬於共用 EXE，不能單獨安裝或停用。"
  [System.Windows.MessageBox]::Show($message,"模組資訊","OK","Information")|Out-Null
})
$PickButton.Add_Click({
  $dialog=New-Object System.Windows.Forms.OpenFileDialog
  $dialog.Title="選取 MooshieUI 主程式"
  $dialog.Filter="MooshieUI 主程式|comfyui-desktop.exe"
  if($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
    $script:appExe=$dialog.FileName
    foreach($r in $table.Rows){$r["Latest"]="尚未取得"}
    New-Item -ItemType Directory -Path (Split-Path -Parent $settingsFile) -Force|Out-Null
    @{appExe=$script:appExe}|ConvertTo-Json|Set-Content -LiteralPath $settingsFile -Encoding UTF8
    Refresh-Info
  }
})
$UpdateButton.Add_Click({Start-Worker "Check"})
$RestoreButton.Add_Click({
  if([System.Windows.MessageBox]::Show("還原最近的 EXE 備份？請先關閉 MooshieUI。","還原備份","YesNo","Warning") -eq "Yes"){Start-Worker "Restore"}
})
$LocalButton.Add_Click({
  if([System.Windows.MessageBox]::Show("安裝本地編譯套件？請先關閉 MooshieUI。","本地安裝","YesNo","Warning") -eq "Yes"){Start-Worker "Local"}
})
if(Test-Path -LiteralPath $settingsFile){
  try{$s=Get-Content -LiteralPath $settingsFile -Raw -Encoding UTF8|ConvertFrom-Json;if($s.appExe -and (Test-Path -LiteralPath $s.appExe)){$script:appExe=[string]$s.appExe}}catch{}
}
if(-not $script:appExe){
  $candidate=Join-Path (Split-Path -Parent (Split-Path -Parent $root)) "MooshieUI\comfyui-desktop.exe"
  if(Test-Path -LiteralPath $candidate){$script:appExe=$candidate}
}
Refresh-Info
Show-Page "Mods"
[void]$window.ShowDialog()
