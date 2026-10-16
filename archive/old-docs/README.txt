scrcpy Audible - one taskbar icon

Files to place in:
  E:\app\scrcpy-win64-v3.3.1\

  setup_one_icon.py
  setup_one_icon.bat
  scrcpy_audible.ico
  scrcpy_media_bridge.py

One-time setup:
1. Put all four files above in the same folder as scrcpy.exe and adb.exe.
2. Double-click setup_one_icon.bat.
3. It creates:
     scrcpy_audible.exe
     scrcpy_audible.lnk
4. Replace/recompile your resident AutoHotkey executable using:
     AutoHotkey_Script001_v2_FINAL.ahk
5. Unpin the old VBS/wscript icon from the taskbar.
6. Right-click scrcpy_audible.lnk
   -> Show more options
   -> Pin to taskbar.

After that:
- The pinned item targets scrcpy_audible.exe directly, so the running mirror belongs
  to the same taskbar item instead of appearing as a second app.
- The shortcut uses your custom scrcpy_audible.ico.
- The bridge also applies that icon to the running scrcpy window.
- scrcpy_audible.exe is a GUI-subsystem copy of scrcpy.exe, so it does not open
  the black console window.
- Your resident AutoHotkey script automatically starts the Bluetooth bridge when
  scrcpy_audible.exe starts, whether launched by Ctrl+Alt+V or from the taskbar.
- Space controls Android play/pause only while scrcpy_audible.exe is foreground.
