$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Version = "4.1"
$ZipName = "scrcpy-win64-v4.1.zip"
$Url = "https://github.com/Genymobile/scrcpy/releases/download/v4.1/scrcpy-win64-v4.1.zip"
$ExpectedSha256 = "5b12172b3264b2889f4583ee64752ce832e29bc8b1089dca81093459697165db"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path -LiteralPath $Root).Path

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 1
}

Write-Host "============================================"
Write-Host " scrcpy safe updater -> v$Version (win64)"
Write-Host "============================================"
Write-Host ""
Write-Host "Target:"
Write-Host "  $Root"
Write-Host ""

if (-not (Test-Path -LiteralPath (Join-Path $Root "scrcpy.exe"))) {
    Fail "scrcpy.exe was not found. Put this updater inside your current scrcpy folder."
}

# scrcpy must be closed so its EXE/DLLs can be replaced safely.
$runningScrcpy = Get-Process -Name "scrcpy" -ErrorAction SilentlyContinue
if ($runningScrcpy) {
    Fail "scrcpy is running. Close the mirror window first, then run this updater again."
}

# Stop the local adb server if possible so adb.exe can be replaced cleanly.
$CurrentAdb = Join-Path $Root "adb.exe"
if (Test-Path -LiteralPath $CurrentAdb) {
    try {
        & $CurrentAdb kill-server 2>$null | Out-Null
        Start-Sleep -Milliseconds 500
    } catch {
        # Not fatal.
    }
}

$Parent = Split-Path -Parent $Root
$Leaf = Split-Path -Leaf $Root
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Backup = Join-Path $Parent ($Leaf + "_backup_before_v4.1_" + $Stamp)

Write-Host "[1/5] Creating a full backup..."
Write-Host "  $Backup"

New-Item -ItemType Directory -Path $Backup -Force | Out-Null

# Robocopy is used because it is reliable for a whole Windows application folder.
& robocopy.exe $Root $Backup /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ /NFL /NDL /NJH /NJS /NP | Out-Null
$RoboCode = $LASTEXITCODE
if ($RoboCode -gt 7) {
    Fail "Backup failed. Robocopy exit code: $RoboCode"
}

# Remember the backup location for the optional rollback tool.
Set-Content -LiteralPath (Join-Path $Root "LAST_SCRCPY_BACKUP.txt") -Value $Backup -Encoding UTF8

$Temp = Join-Path $env:TEMP ("scrcpy_update_v4.1_" + $PID)
$ZipPath = Join-Path $Temp $ZipName
$ExtractPath = Join-Path $Temp "extract"

try {
    New-Item -ItemType Directory -Path $Temp -Force | Out-Null

    Write-Host "[2/5] Downloading official scrcpy v$Version..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    try {
        Invoke-WebRequest -Uri $Url -OutFile $ZipPath -UseBasicParsing
    } catch {
        Write-Host "  PowerShell download failed; trying curl.exe..."
        $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
        if (-not $curl) {
            throw
        }

        & curl.exe -L --fail --retry 3 --output $ZipPath $Url
        if ($LASTEXITCODE -ne 0) {
            throw "curl.exe failed with exit code $LASTEXITCODE"
        }
    }

    Write-Host "[3/5] Verifying SHA-256..."
    $ActualSha256 = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($ActualSha256 -ne $ExpectedSha256) {
        Fail ("SHA-256 mismatch.`nExpected: $ExpectedSha256`nActual:   $ActualSha256")
    }
    Write-Host "  SHA-256 OK"

    Write-Host "[4/5] Extracting and updating official files..."
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $ExtractPath -Force

    $Source = Join-Path $ExtractPath "scrcpy-win64-v4.1"
    if (-not (Test-Path -LiteralPath (Join-Path $Source "scrcpy.exe"))) {
        Fail "The official archive layout was not recognized."
    }

    # IMPORTANT:
    # Only COPY the official v4.1 files over the existing folder.
    # Do NOT delete anything else. Therefore all custom files remain intact:
    # launcher, Python bridge, AutoHotkey files, ICOs, _old folder, shortcuts, etc.
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Root -Recurse -Force
    }

    Write-Host "[5/5] Checking installed version..."
    $VersionOutput = & (Join-Path $Root "scrcpy.exe") --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Fail "scrcpy.exe was updated, but the version check failed. Your full backup is safe at: $Backup"
    }

    Write-Host ""
    Write-Host "SUCCESS" -ForegroundColor Green
    Write-Host ""
    $VersionOutput | Select-Object -First 8 | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    Write-Host "Your custom files were NOT deleted."
    Write-Host "The old folder was fully backed up here:"
    Write-Host "  $Backup"
    Write-Host ""
    Write-Host "Note: old v3.x DLLs such as SDL2.dll may remain in the folder."
    Write-Host "They are harmless; v4.1 uses SDL3.dll and the new FFmpeg DLL names."
    Write-Host "Do not clean them up yet. First confirm your custom launcher works."
    Write-Host ""
    Read-Host "Press Enter to close"
}
finally {
    if (Test-Path -LiteralPath $Temp) {
        Remove-Item -LiteralPath $Temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
