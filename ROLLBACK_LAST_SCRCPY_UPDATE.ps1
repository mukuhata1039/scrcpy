$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path -LiteralPath $Root).Path
$Pointer = Join-Path $Root "LAST_SCRCPY_BACKUP.txt"

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 1
}

if (-not (Test-Path -LiteralPath $Pointer)) {
    Fail "LAST_SCRCPY_BACKUP.txt was not found. No automatic rollback target is known."
}

$Backup = (Get-Content -LiteralPath $Pointer -Raw).Trim()
if (-not (Test-Path -LiteralPath $Backup)) {
    Fail "Backup folder does not exist: $Backup"
}

if (Get-Process -Name "scrcpy" -ErrorAction SilentlyContinue) {
    Fail "scrcpy is running. Close the mirror window first."
}

Write-Host "This will restore:"
Write-Host "  $Backup"
Write-Host "to:"
Write-Host "  $Root"
Write-Host ""
$answer = Read-Host "Type YES to continue"
if ($answer -ne "YES") {
    Write-Host "Cancelled."
    exit 0
}

# Remove files introduced by v4.1 that were not in the old folder,
# then restore the backup exactly enough for this application folder.
# We deliberately limit cleanup to known official v4.1-only runtime files.
$v41Only = @(
    "SDL3.dll",
    "avcodec-62.dll",
    "avformat-62.dll",
    "avutil-60.dll",
    "swresample-6.dll",
    "disconnected.png",
    "scrcpy.png",
    "LICENSE.txt"
)

foreach ($name in $v41Only) {
    $p = Join-Path $Root $name
    if (Test-Path -LiteralPath $p) {
        Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
    }
}

& robocopy.exe $Backup $Root /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ /NFL /NDL /NJH /NJS /NP | Out-Null
$code = $LASTEXITCODE
if ($code -gt 7) {
    Fail "Rollback copy failed. Robocopy exit code: $code"
}

Write-Host ""
Write-Host "Rollback completed." -ForegroundColor Green
Read-Host "Press Enter to close"
