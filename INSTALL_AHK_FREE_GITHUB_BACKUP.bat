@echo off
setlocal EnableExtensions
cd /d "%~dp0"

title Install AHK-free Space - GitHub backup mode

set "SOURCE=scrcpy_audible_launcher_AHK_FREE.cs"
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
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p = Join-Path (Get-Location) 'scrcpy-noconsole.vbs'; $s = @'`nstrCommand = ""cmd /c scrcpy.exe""`n`nFor Each Arg In WScript.Arguments`n    strCommand = strCommand & "" """""" & replace(Arg, """""", """""""""""""""""""""") & """"""""`nNext`n`nCreateObject(""Wscript.Shell"").Run strCommand, 0, false`n'@; [IO.File]::WriteAllText($p, $s.TrimStart([char]10), (New-Object Text.UTF8Encoding($true)))"
if errorlevel 1 (
    echo ERROR: Failed to restore scrcpy-noconsole.vbs.
    pause
    exit /b 1
)

echo Installing completed launcher source...
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
    echo Use GitHub to restore the previous version if needed.
    pause
    exit /b 1
)

if exist "scrcpy_space_hotkey.exe" del /q "scrcpy_space_hotkey.exe" >nul 2>nul
if exist "scrcpy_space_hotkey.cs"  del /q "scrcpy_space_hotkey.cs"  >nul 2>nul

echo.
echo SUCCESS
echo.
echo Local .bak files were NOT created.
echo GitHub is the backup/history.
echo.
echo Start from your usual "scrcpy_audible" shortcut.
echo.
echo Expected:
echo   scrcpy foreground : Space = Audible Play/Pause
echo   Apex foreground   : Space = normal Apex Space
echo.
pause
endlocal
