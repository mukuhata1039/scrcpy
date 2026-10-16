# -*- coding: utf-8 -*-
from pathlib import Path
import shutil
import struct
import subprocess
import sys

BASE = Path(__file__).resolve().parent
SRC = BASE / "scrcpy.exe"
DST = BASE / "scrcpy_audible.exe"
ICO = BASE / "scrcpy_audible.ico"
LNK = BASE / "scrcpy_audible.lnk"

ARGS = (
    "--max-size=1100 "
    "--window-x=0 "
    "--window-y=100 "
    "--power-off-on-close "
    "--turn-screen-off "
    "--stay-awake"
)

def fail(msg):
    print()
    print("ERROR:", msg)
    input("\nPress Enter to exit...")
    raise SystemExit(1)

def make_gui_copy():
    if not SRC.exists():
        fail(f"{SRC.name} was not found. Put this setup in the scrcpy folder.")

    data = bytearray(SRC.read_bytes())

    if len(data) < 0x100 or data[:2] != b"MZ":
        fail("scrcpy.exe is not a valid PE executable.")

    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if pe + 0x100 > len(data) or data[pe:pe+4] != b"PE\x00\x00":
        fail("Could not find the PE header in scrcpy.exe.")

    optional = pe + 24
    magic = struct.unpack_from("<H", data, optional)[0]
    if magic not in (0x10B, 0x20B):
        fail(f"Unsupported PE optional-header magic: 0x{magic:04X}")

    # IMAGE_OPTIONAL_HEADER.Subsystem is at +0x44 in both PE32 and PE32+.
    subsystem_off = optional + 0x44
    old_subsystem = struct.unpack_from("<H", data, subsystem_off)[0]

    # 2 = IMAGE_SUBSYSTEM_WINDOWS_GUI
    struct.pack_into("<H", data, subsystem_off, 2)

    DST.write_bytes(data)
    print(f"Created: {DST.name}")
    print(f"Subsystem: {old_subsystem} -> 2 (Windows GUI / no console)")

def ps_quote(s):
    return str(s).replace("'", "''")

def make_shortcut():
    if not ICO.exists():
        fail(f"{ICO.name} was not found.")

    ps = f"""
$ws = New-Object -ComObject WScript.Shell
$s = $ws.CreateShortcut('{ps_quote(LNK)}')
$s.TargetPath = '{ps_quote(DST)}'
$s.Arguments = '{ARGS}'
$s.WorkingDirectory = '{ps_quote(BASE)}'
$s.IconLocation = '{ps_quote(ICO)},0'
$s.Description = 'scrcpy Audible'
$s.WindowStyle = 1
$s.Save()
"""
    cp = subprocess.run(
        ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps],
        text=True,
    )
    if cp.returncode != 0 or not LNK.exists():
        fail("Failed to create scrcpy_audible.lnk.")

    print(f"Created: {LNK.name}")

def main():
    print("scrcpy Audible one-icon setup")
    print("=" * 40)
    make_gui_copy()
    make_shortcut()
    print()
    print("DONE")
    print()
    print("Next:")
    print("1. Compile/use AutoHotkey_Script001_v2_FINAL.ahk as your resident AHK.")
    print("2. Unpin the old VBS/wscript shortcut from the taskbar.")
    print("3. Right-click scrcpy_audible.lnk -> Show more options -> Pin to taskbar.")
    print("4. Launch the new pinned icon.")
    input("\nPress Enter to close...")

if __name__ == "__main__":
    main()
