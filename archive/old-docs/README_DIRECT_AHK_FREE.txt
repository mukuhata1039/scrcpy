Final direct-launch version

This version is based on the local scrcpy_audible_launcher.cs uploaded by the user.

Changes:
- scrcpy_audible_launcher.exe starts scrcpy.exe directly.
- scrcpy-noconsole.vbs / wscript.exe are no longer used by the launcher.
- Space handling is inside scrcpy_audible_launcher.exe itself.
- No AutoHotkey is required for Space.
- No scrcpy_space_hotkey.exe helper process is required.
- Existing scrcpy_media_bridge.py remains in use for Android MEDIA_PLAY_PAUSE.

Install:
1. Extract all files to:
   E:\app\scrcpy-win64-v3.3.1\
2. Run:
   INSTALL_DIRECT_AHK_FREE.bat
3. Start using the normal scrcpy_audible shortcut.
