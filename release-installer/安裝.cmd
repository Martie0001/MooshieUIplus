@echo off
chcp 65001 >nul
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Install-MooshieUIplus.ps1"
echo.
pause
