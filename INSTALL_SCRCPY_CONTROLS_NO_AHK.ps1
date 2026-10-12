$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $dir 'scrcpy_controls_hotkey.cs'
$helper = Join-Path $dir 'scrcpy_controls_hotkey.exe'
$vbs = Join-Path $dir 'scrcpy-noconsole.vbs'
$scrcpy = Join-Path $dir 'scrcpy.exe'
$adb = Join-Path $dir 'adb.exe'

foreach ($required in @($source, $vbs, $scrcpy, $adb)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "必要なファイルがありません: $required"
    }
}

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $csc)) {
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
if (-not (Test-Path -LiteralPath $csc)) {
    throw 'C# コンパイラ csc.exe がありません。'
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$exeBackup = $null
if (Test-Path -LiteralPath $helper) {
    $exeBackup = "$helper.$stamp.bak"
    Copy-Item -LiteralPath $helper -Destination $exeBackup
}

# Only this new helper is stopped. The existing Space helper is untouched.
Get-Process -Name scrcpy_controls_hotkey -ErrorAction SilentlyContinue |
    Stop-Process -Force

try {
    & $csc /nologo /target:winexe /platform:anycpu /optimize+ "/out:$helper" $source
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $helper)) {
        throw 'Alt+O / Ctrl+Tab 常駐プログラムのビルドに失敗しました。'
    }
}
catch {
    if ($exeBackup) {
        Copy-Item -LiteralPath $exeBackup -Destination $helper -Force
    }
    throw
}

$vbsBytes = [IO.File]::ReadAllBytes($vbs)
$utf8Bom = $vbsBytes.Length -ge 3 -and
    $vbsBytes[0] -eq 0xEF -and $vbsBytes[1] -eq 0xBB -and $vbsBytes[2] -eq 0xBF
$encoding = if ($utf8Bom) {
    [Text.UTF8Encoding]::new($true)
} else {
    [Text.Encoding]::Default
}
$text = if ($utf8Bom) {
    $encoding.GetString($vbsBytes, 3, $vbsBytes.Length - 3)
} else {
    $encoding.GetString($vbsBytes)
}
$newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }

if ($text -notmatch 'scrcpy_controls_hotkey\.exe') {
    $vbsBackup = "$vbs.$stamp.bak"
    Copy-Item -LiteralPath $vbs -Destination $vbsBackup
    $launch = 'CreateObject("Wscript.Shell").Run """" & CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName) & "\scrcpy_controls_hotkey.exe""", 0, False'
    $newText = $text.TrimEnd([char]13, [char]10) + $newline + $launch + $newline
    try {
        [IO.File]::WriteAllText($vbs, $newText, $encoding)
    }
    catch {
        Copy-Item -LiteralPath $vbsBackup -Destination $vbs -Force
        throw
    }
    Write-Host "VBS backup: $vbsBackup"
} else {
    Write-Host 'VBS already launches the controls helper.'
}

Write-Host 'INSTALL COMPLETE'
Write-Host "Installed: $helper"
Write-Host 'The existing Space helper and launcher were not changed.'
Write-Host 'Next: Exit AutoHotkey Script001 from its tray icon, close scrcpy, and launch scrcpy_audible_launcher.exe.'
Write-Host 'Check Space, Alt+O twice, Ctrl+Tab. Then remove Script001 from Windows Startup.'
