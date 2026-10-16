$ErrorActionPreference = "Stop"

$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VbsPath = Join-Path $BaseDir "scrcpy-noconsole.vbs"
$Helper  = Join-Path $BaseDir "scrcpy_space_hotkey.exe"

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $Helper)) {
    Fail "scrcpy_space_hotkey.exe がありません。v3で作成されたEXEを残したまま実行してください。"
}

Get-Process "scrcpy" -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

Get-Process "scrcpy_space_hotkey" -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Milliseconds 300

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
if (Test-Path $VbsPath) {
    Copy-Item $VbsPath "$VbsPath.$stamp.bak" -Force
}

# IMPORTANT:
# The scrcpy launch section below is the exact original launch method
# from the working repository version:
#     strCommand = "cmd /c scrcpy.exe"
# We only add the helper launch AFTER starting scrcpy.
$vbs = @'
strCommand = "cmd /c scrcpy.exe"

For Each Arg In WScript.Arguments
    strCommand = strCommand & " """ & replace(Arg, """", """""""""") & """"
Next

Set shell = CreateObject("Wscript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Keep the original scrcpy launch behavior exactly as it was.
shell.Run strCommand, 0, false

' Start the independent AHK-free Space helper.
baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
helperPath = baseDir & "\scrcpy_space_hotkey.exe"

If fso.FileExists(helperPath) Then
    shell.Run """" & helperPath & """", 0, false
End If
'@

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($VbsPath, $vbs, $utf8Bom)

Write-Host ""
Write-Host "SUCCESS" -ForegroundColor Green
Write-Host ""
Write-Host "scrcpy の起動方法を元の cmd /c scrcpy.exe に戻しました。"
Write-Host "Space helper は scrcpy 起動後に別プロセスで開始します。"
Write-Host ""
Write-Host "次:"
Write-Host "  1. AutoHotkey を終了"
Write-Host "  2. いつもの scrcpy_audible_launcher.exe を起動"
Write-Host "  3. scrcpy が表示されることを確認"
Write-Host "  4. scrcpy を前面にして Space"
Write-Host ""
Write-Host "Backup: $VbsPath.$stamp.bak"
