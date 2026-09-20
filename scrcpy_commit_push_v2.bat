@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "REPO=E:\app\scrcpy-win64-v3.3.1"
set "REMOTE=https://github.com/mukuhata1039/scrcpy.git"

echo.
echo ============================================================
echo  scrcpy - Commit + Push
echo ============================================================
echo Repository:
echo %REPO%
echo.

if not exist "%REPO%" (
    echo ERROR: Repository folder was not found.
    echo %REPO%
    pause
    exit /b 1
)

cd /d "%REPO%"

rem ------------------------------------------------------------
rem First-run setup
rem ------------------------------------------------------------
if not exist ".git" (
    echo Git repository is not initialized.
    echo Initializing now...
    echo.

    git init
    if errorlevel 1 (
        echo ERROR: git init failed.
        pause
        exit /b 1
    )

    git branch -M main
    if errorlevel 1 (
        echo ERROR: Failed to set branch to main.
        pause
        exit /b 1
    )
)

rem ------------------------------------------------------------
rem Ensure origin points to the backup repository
rem ------------------------------------------------------------
git remote get-url origin >nul 2>nul
if errorlevel 1 (
    echo Configuring origin...
    git remote add origin "%REMOTE%"
    if errorlevel 1 (
        echo ERROR: Failed to add origin.
        pause
        exit /b 1
    )
) else (
    for /f "delims=" %%R in ('git remote get-url origin') do set "CURRENT_REMOTE=%%R"
    if /I not "!CURRENT_REMOTE!"=="%REMOTE%" (
        echo Updating origin URL...
        git remote set-url origin "%REMOTE%"
        if errorlevel 1 (
            echo ERROR: Failed to update origin.
            pause
            exit /b 1
        )
    )
)

rem ------------------------------------------------------------
rem Detect current branch
rem ------------------------------------------------------------
for /f "delims=" %%B in ('git branch --show-current') do set "BRANCH=%%B"
if not defined BRANCH (
    set "BRANCH=main"
    git branch -M main >nul 2>nul
)

rem ------------------------------------------------------------
rem Show changes
rem ------------------------------------------------------------
echo Current changes:
echo ------------------------------------------------------------
git status --short
echo ------------------------------------------------------------
echo.

set "STATUS_FILE=%TEMP%\scrcpy_git_status_%RANDOM%_%RANDOM%.txt"
git status --porcelain > "%STATUS_FILE%"
for %%A in ("%STATUS_FILE%") do set "STATUS_SIZE=%%~zA"
del "%STATUS_FILE%" >nul 2>nul

rem ------------------------------------------------------------
rem Commit only when there are local file changes
rem ------------------------------------------------------------
if not "%STATUS_SIZE%"=="0" (
    set "MSG="
    set /p "MSG=Commit message: "

    if not defined MSG (
        echo ERROR: Commit message cannot be empty.
        pause
        exit /b 1
    )

    echo.
    echo Staging all changes...
    git add -A
    if errorlevel 1 (
        echo ERROR: git add failed.
        pause
        exit /b 1
    )

    echo.
    echo Committing...
    git commit -m "!MSG!"
    if errorlevel 1 (
        echo ERROR: git commit failed.
        pause
        exit /b 1
    )
) else (
    echo No file changes to commit.
    echo Checking for unpushed commits...
)

rem ------------------------------------------------------------
rem Always try to push
rem ------------------------------------------------------------
echo.
echo Pushing...
git push
if errorlevel 1 (
    echo.
    echo Normal push failed. Trying to set upstream...
    git push -u origin "!BRANCH!"
    if errorlevel 1 (
        echo.
        echo ERROR: git push failed.
        echo Local commits are still safe on this PC.
        pause
        exit /b 1
    )
)

echo.
echo ============================================================
echo  DONE
echo ============================================================
git log -1 --oneline
echo.
pause

endlocal
