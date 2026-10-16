scrcpy Audible FINAL v3

IMPORTANT:
Before testing, close the old visible "scrcpy Media Bridge v5" test window.

Install:
1. Copy ALL files in this ZIP to:
   E:\app\scrcpy-win64-v3.3.1\
   and overwrite the old versions.

2. Run:
   BUILD_AND_SETUP.bat

3. Unpin the old scrcpy / VBS taskbar item.

4. Pin the newly created:
   scrcpy_audible.lnk

5. Launch it.

Expected:
- Only the scrcpy mirror window appears.
- No black console.
- No "scrcpy Media Bridge v5" GUI.
- No launcher error dialog.
- Bluetooth headset play/pause works only while scrcpy is foreground.
- The running mirror uses the same custom taskbar identity/icon as the pinned shortcut.

AutoHotkey:
Use AutoHotkey_Script001_v2_FINAL.ahk for the resident hotkey EXE.

New in v4:
- When the scrcpy mirror window is closed, the launcher sends:
    adb shell input keyevent 127
  to Android.
- 127 is MEDIA_PAUSE, not PLAY_PAUSE, so an already-paused Audible session
  will stay paused instead of accidentally starting.


v5 fix:
- Fixed the error dialog that appeared when closing the mirror.
- The launcher no longer reads Process.HasExited / Process.ExitCode from the
  externally discovered scrcpy Process object.
- It now detects scrcpy termination by PID, then sends Android MEDIA_PAUSE (127).


v6:
- Removed --power-off-on-close.
- While mirroring, --turn-screen-off still keeps the physical phone screen off.
- When scrcpy closes, the phone screen is allowed to turn back on normally.
- The existing Android MEDIA_PAUSE-on-close behavior is preserved.
