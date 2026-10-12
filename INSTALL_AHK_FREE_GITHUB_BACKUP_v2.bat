@echo off
setlocal EnableExtensions
cd /d "%~dp0"

title Install AHK-free Space - GitHub backup mode v2

set "SOURCE=scrcpy_audible_launcher_AHK_FREE.cs"
set "TARGET=scrcpy_audible_launcher.cs"
set "GOODVBS=scrcpy-noconsole.GOOD.vbs"
set "VBS=scrcpy-noconsole.vbs"
set "EXE=scrcpy_audible_launcher.exe"
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"

if not exist "%SOURCE%" (
    echo ERROR: %SOURCE% was not found.
    pause
    exit /b 1
)

if not exist "%GOODVBS%" (
    echo ERROR: %GOODVBS% was not found.
    pause
    exit /b 1
)

if not exist "scrcpy.exe" (
    echo ERROR: Put these files in E:\app\scrcpy-win64-v3.3.1\
    pause
    exit /b 1
)

if not exist "scrcpy_media_bridge.py" (
    echo ERROR: scrcpy_media_bridge.py was not found.
    pause
    exit /b 1
)

if not exist "scrcpy_audible.ico" (
    echo ERROR: scrcpy_audible.ico was not found.
    pause
    exit /b 1
)

if not exist "%CSC%" (
    echo ERROR: csc.exe was not found.
    pause
    exit /b 1
)

echo Closing current scrcpy processes...
taskkill /F /IM scrcpy_audible_launcher.exe >nul 2>nul
taskkill /F /IM scrcpy.exe >nul 2>nul
taskkill /F /IM scrcpy_space_hotkey.exe >nul 2>nul

echo Restoring known-good scrcpy-noconsole.vbs...
copy /y "%GOODVBS%" "%VBS%" >nul
if errorlevel 1 (
    echo ERROR: Failed to restore %VBS%.
    pause
    exit /b 1
)

echo Installing completed launcher source...
copy /y "%SOURCE%" "%TARGET%" >nul
if errorlevel 1 (
    echo ERROR: Failed to replace %TARGET%.
    pause
    exit /b 1
)

echo Building scrcpy_audible_launcher.exe...
"%CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /win32icon:scrcpy_audible.ico /out:"%EXE%" "%TARGET%"
if errorlevel 1 (
    echo.
    echo BUILD FAILED.
    echo Restore from GitHub if needed.
    pause
    exit /b 1
)

if exist "scrcpy_space_hotkey.exe" del /q "scrcpy_space_hotkey.exe" >nul 2>nul
if exist "scrcpy_space_hotkey.cs"  del /q "scrcpy_space_hotkey.cs"  >nul 2>nul

echo.
echo SUCCESS
echo.
echo No local .bak files were created.
echo GitHub is the backup/history.
echo.
echo Start from your usual scrcpy_audible shortcut.
echo.
echo Expected:
echo   scrcpy foreground : Space = Audible Play/Pause
echo   Apex foreground   : Space = normal Apex Space
echo.
pause
endlocal
