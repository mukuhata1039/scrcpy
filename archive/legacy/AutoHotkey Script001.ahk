#Requires AutoHotkey v2.0
#SingleInstance Force

SCRCPY_LAUNCHER := "E:\app\scrcpy-win64-v3.3.1\scrcpy_audible_launcher.exe"
ADB_EXE := "E:\app\scrcpy-win64-v3.3.1\adb.exe"

^!v::Run '"' SCRCPY_LAUNCHER '"'
^!b::Run "E:\app\multimonitortool-x64\dual\dual.vbs"
^!m::Run "E:\app\multimonitortool-x64\single\single.vbs"
^!n::Run "E:\app\multimonitortool-x64\single2\single2.vbs"
^!x::Run "E:\app\ComfyUI_windows_portable_nvidia\ComfyUI_windows_portable\start_comfyui.bat"

lastScrcpyPid := 0
phoneScreenOff := true

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

$!o::
{
    global lastScrcpyPid, phoneScreenOff
    currentPid := WinGetPID("A")
    if (currentPid != lastScrcpyPid) {
        lastScrcpyPid := currentPid
        phoneScreenOff := true
    }

    if (phoneScreenOff)
        SendInput "{Blind}{Shift down}o{Shift up}"
    else
        SendInput "{Blind}o"

    phoneScreenOff := !phoneScreenOff
    KeyWait "o"
}

~!+o::
{
    global lastScrcpyPid, phoneScreenOff
    lastScrcpyPid := WinGetPID("A")
    phoneScreenOff := false
}

#HotIf