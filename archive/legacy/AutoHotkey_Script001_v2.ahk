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
; Space -> Android MEDIA_PLAY_PAUSE
; =========================================================

#HotIf WinActive("ahk_exe scrcpy.exe")

$Space::
{
    RunWait '"E:\app\scrcpy-win64-v3.3.1\adb.exe" shell input keyevent 85', , "Hide"
    KeyWait "Space"
}

#HotIf
