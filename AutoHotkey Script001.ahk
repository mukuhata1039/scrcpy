#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================================
; Existing shortcuts
; =========================================================

^!v::Run "E:\app\scrcpy-win64-v3.3.1\scrcpy_audible.vbs"

^!b::Run "E:\app\multimonitortool-x64\dual\dual.vbs"

^!m::Run "E:\app\multimonitortool-x64\single\single.vbs"

^!n::Run "E:\app\multimonitortool-x64\single2\single2.vbs"

^!x::Run "E:\app\ComfyUI_windows_portable_nvidia\ComfyUI_windows_portable\start_comfyui.bat"


; =========================================================
; scrcpy is foreground:
; Space -> hidden bridge -> persistent ADB shell -> Android
; =========================================================

global SCRCPY_SPACE_COMMAND := A_Temp "\scrcpy_audible_space_command.txt"

#HotIf WinActive("ahk_exe scrcpy.exe")

$Space::
{
    global SCRCPY_SPACE_COMMAND

    ; This only writes one tiny line.
    ; It does NOT start adb.exe, cmd.exe, or any black console window.
    try FileAppend("1`n", SCRCPY_SPACE_COMMAND, "UTF-8")

    KeyWait "Space"
}

#HotIf
