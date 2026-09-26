#Requires AutoHotkey v2.0
#SingleInstance Force

SCRCPY_LAUNCHER := "E:\app\scrcpy-win64-v3.3.1\scrcpy_audible_launcher.exe"
ADB_EXE := "E:\app\scrcpy-win64-v3.3.1\adb.exe"

; Existing shortcuts
^!v::Run '"' SCRCPY_LAUNCHER '"'
^!b::Run "E:\app\multimonitortool-x64\dual\dual.vbs"
^!m::Run "E:\app\multimonitortool-x64\single\single.vbs"
^!n::Run "E:\app\multimonitortool-x64\single2\single2.vbs"
^!x::Run "E:\app\ComfyUI_windows_portable_nvidia\ComfyUI_windows_portable\start_comfyui.bat"

; Only while the real scrcpy mirror window is foreground:
; Ctrl+Tab -> Android APP_SWITCH
; Space    -> Android MEDIA_PLAY_PAUSE
#HotIf WinActive("ahk_exe scrcpy.exe")

^Tab::
{
    global ADB_EXE
    RunWait '"' ADB_EXE '" shell input keyevent 187', , "Hide"
    KeyWait "Tab"
}

$Space::
{
    global ADB_EXE
    RunWait '"' ADB_EXE '" shell input keyevent 85', , "Hide"
    KeyWait "Space"
}

#HotIf
