@echo off
setlocal
set "SOURCE=%~1"
if not defined SOURCE (
  echo ERROR: Source path is required.
  exit /b 2
)
if not exist "%SOURCE%\node_modules\.bin\tauri.cmd" (
  echo ERROR: Tauri build tool is unavailable. Run npm ci in the matching source.
  exit /b 3
)
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VCVARS="
if exist "%VSWHERE%" (
  for /f "usebackq delims=" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VCVARS=%%I\VC\Auxiliary\Build\vcvars64.bat"
)
if not exist "%VCVARS%" (
  echo ERROR: Visual Studio C++ Build Tools were not found.
  exit /b 4
)
call "%VCVARS%" >nul
if errorlevel 1 exit /b 5
set "AWS_LC_SYS_PREBUILT_NASM=1"
set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"
pushd "%SOURCE%"
call "node_modules\.bin\tauri.cmd" build --no-bundle --ci
set "BUILD_EXIT=%ERRORLEVEL%"
popd
exit /b %BUILD_EXIT%
