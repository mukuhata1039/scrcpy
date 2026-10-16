@echo off
setlocal
cd /d "%~dp0"

echo Closing scrcpy...
taskkill /F /IM scrcpy.exe >nul 2>nul
taskkill /F /IM scrcpy_audible_launcher.exe >nul 2>nul

echo Restoring original scrcpy-noconsole.vbs as plain ASCII...
copy /b /y "%~dp0scrcpy-noconsole.vbs" "E:\app\scrcpy-win64-v3.3.1\scrcpy-noconsole.vbs" >nul

if errorlevel 1 (
    echo ERROR: copy failed.
    pause
    exit /b 1
)

echo.
echo DONE
echo.
echo Start the usual scrcpy_audible shortcut now.
echo.
pause
