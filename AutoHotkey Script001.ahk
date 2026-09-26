#Requires AutoHotkey v2.0
#SingleInstance Force

; The scrcpy launcher starts with --turn-screen-off.
lastScrcpyPid := 0
phoneScreenOff := true

#HotIf WinActive("ahk_exe scrcpy.exe")

; On the first press, turn the physical phone screen on.
; Subsequent presses alternate on/off.
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

; Keep the toggle in sync if the original screen-on shortcut is used.
~!+o::
{
    global lastScrcpyPid, phoneScreenOff
    lastScrcpyPid := WinGetPID("A")
    phoneScreenOff := false
}

#HotIf
