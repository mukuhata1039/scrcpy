@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0ROLLBACK_LAST_SCRCPY_UPDATE.ps1"
endlocal
