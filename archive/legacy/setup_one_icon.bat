@echo off
setlocal
cd /d "%~dp0"
title scrcpy Audible one-icon setup

where py >nul 2>&1
if errorlevel 1 (
    echo Python launcher "py" was not found.
    pause
    exit /b 1
)

py -3.11 setup_one_icon.py
if errorlevel 1 (
    echo.
    echo Setup failed.
    pause
)
endlocal
