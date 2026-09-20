@echo off
setlocal
cd /d "%~dp0"
title Build scrcpy Audible launcher

set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"

if not exist "%CSC%" (
    echo ERROR: csc.exe was not found.
    pause
    exit /b 1
)

if not exist "scrcpy.exe" (
    echo ERROR: Put these files in the scrcpy folder first.
    pause
    exit /b 1
)

if not exist "scrcpy-noconsole.vbs" (
    echo ERROR: scrcpy-noconsole.vbs was not found.
    pause
    exit /b 1
)

echo Building launcher...
"%CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /win32icon:scrcpy_audible.ico /out:scrcpy_audible_launcher.exe scrcpy_audible_launcher.cs
if errorlevel 1 (
    echo.
    echo BUILD FAILED.
    pause
    exit /b 1
)

echo Creating shortcut...
scrcpy_audible_launcher.exe --create-shortcut

if not exist "scrcpy_audible.lnk" (
    echo.
    echo ERROR: Shortcut creation failed.
    pause
    exit /b 1
)

echo.
echo DONE.
echo.
echo 1. Unpin the old scrcpy/VBS icon from the taskbar.
echo 2. Right-click scrcpy_audible.lnk.
echo 3. Show more options ^> Pin to taskbar.
echo 4. Launch it from the taskbar.
echo.
pause
endlocal
