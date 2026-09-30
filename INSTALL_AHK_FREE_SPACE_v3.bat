@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL_AHK_FREE_SPACE_v3.ps1"
echo.
pause
