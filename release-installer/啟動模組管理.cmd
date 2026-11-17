@echo off
chcp 65001 >nul
start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0模組管理器.ps1"
exit /b 0
