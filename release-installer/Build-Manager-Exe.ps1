param(
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $root "MooshieUIplus-Manager.cs"
$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path -LiteralPath $csc)) {
    throw "找不到 Windows .NET Framework C# 編譯器。只需在開發者電腦建置，B 版使用者不需安裝。"
}
if (-not (Test-Path -LiteralPath $source)) { throw "缺少 MooshieUIplus-Manager.cs" }
$fullOutput = [IO.Path]::GetFullPath($OutputPath)
$parent = Split-Path -Parent $fullOutput
if (-not (Test-Path -LiteralPath $parent)) { throw "輸出資料夾不存在：$parent" }
if (Test-Path -LiteralPath $fullOutput) { throw "拒絕覆蓋既有管理器 EXE：$fullOutput" }
& $csc /nologo /target:winexe /platform:anycpu /optimize+ /r:System.Windows.Forms.dll ("/out:" + $fullOutput) $source
if ($LASTEXITCODE -ne 0) { throw "Manager EXE 編譯失敗" }
Write-Output ("Manager EXE 已建置：" + $fullOutput)
Write-Output ("SHA256: " + (Get-FileHash -LiteralPath $fullOutput -Algorithm SHA256).Hash)
