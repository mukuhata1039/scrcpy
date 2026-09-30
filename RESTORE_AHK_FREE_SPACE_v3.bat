@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$b = Get-ChildItem -LiteralPath '%~dp0' -Filter 'scrcpy-noconsole.vbs.*.bak' ^| Sort-Object LastWriteTime -Descending ^| Select-Object -First 1; if(-not $b){Write-Host 'Backup not found.' -ForegroundColor Red; exit 1}; Copy-Item -LiteralPath $b.FullName -Destination '%~dp0scrcpy-noconsole.vbs' -Force; Get-Process scrcpy_space_hotkey -ErrorAction SilentlyContinue ^| Stop-Process -Force -ErrorAction SilentlyContinue; Write-Host ('Restored: ' + $b.Name) -ForegroundColor Green"
echo.
pause
