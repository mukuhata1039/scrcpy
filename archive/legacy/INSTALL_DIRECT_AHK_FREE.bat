@echo off
setlocal EnableExtensions
cd /d "%~dp0"

title Install direct scrcpy launch + AHK-free Space

set "SOURCE=scrcpy_audible_launcher_DIRECT_AHK_FREE.cs"
set "TARGET=scrcpy_audible_launcher.cs"
set "EXE=scrcpy_audible_launcher.exe"
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"

if not exist "%SOURCE%" (
    echo ERROR: %SOURCE% was not found.
    pause
    exit /b 1
)

if not exist "scrcpy.exe" (
    echo ERROR: Run this from E:\app\scrcpy-win64-v3.3.1\
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

echo Closing current processes...
taskkill /F /IM scrcpy_audible_launcher.exe >nul 2>nul
taskkill /F /IM scrcpy.exe >nul 2>nul
taskkill /F /IM scrcpy_space_hotkey.exe >nul 2>nul

echo Installing completed source...
copy /y "%SOURCE%" "%TARGET%" >nul
if errorlevel 1 (
    echo ERROR: Could not replace %TARGET%.
    pause
    exit /b 1
)

echo Building scrcpy_audible_launcher.exe...
"%CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /win32icon:scrcpy_audible.ico /out:"%EXE%" "%TARGET%"
if errorlevel 1 (
    echo.
    echo BUILD FAILED.
    echo Restore from GitHub.
    pause
    exit /b 1
)

if exist "scrcpy_space_hotkey.exe" del /q "scrcpy_space_hotkey.exe" >nul 2>nul
if exist "scrcpy_space_hotkey.cs"  del /q "scrcpy_space_hotkey.cs"  >nul 2>nul

echo.
echo SUCCESS
echo.
echo VBS is no longer used by the launcher.
echo No extra Space helper process is used.
echo No AutoHotkey is needed for Space playback control.
echo.
echo Start with your normal "scrcpy_audible" shortcut.
echo.
pause
endlocal
