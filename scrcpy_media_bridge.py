# -*- coding: utf-8 -*-
import ctypes
from ctypes import wintypes
import logging
import threading
from pathlib import Path
import queue
import shutil
import subprocess
import tempfile
import time
import wave
import tkinter as tk

from winrt.windows.foundation import Uri
from winrt.windows.media.core import MediaSource
from winrt.windows.media.playback import MediaPlayer, MediaPlaybackState


APP_DIR = Path(__file__).resolve().parent
CREATE_NO_WINDOW = 0x08000000
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
ERROR_ALREADY_EXISTS = 183

LOG_PATH = Path(tempfile.gettempdir()) / "scrcpy_audible_bridge.log"
SILENT_WAV = Path(tempfile.gettempdir()) / "scrcpy_audible_bridge_silent.wav"
HOTKEY_COMMAND_PATH = Path(tempfile.gettempdir()) / "scrcpy_audible_space_command.txt"

logging.basicConfig(
    filename=str(LOG_PATH),
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)

events = queue.Queue()

user32 = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

# Only one bridge instance.
kernel32.CreateMutexW.argtypes = [ctypes.c_void_p, wintypes.BOOL, wintypes.LPCWSTR]
kernel32.CreateMutexW.restype = wintypes.HANDLE
_bridge_mutex = kernel32.CreateMutexW(None, False, "Local\\ScrcpyAudibleMediaBridgeFinal")
if not _bridge_mutex or ctypes.get_last_error() == ERROR_ALREADY_EXISTS:
    raise SystemExit(0)

user32.GetForegroundWindow.restype = wintypes.HWND
user32.GetWindowThreadProcessId.argtypes = [
    wintypes.HWND,
    ctypes.POINTER(wintypes.DWORD),
]
user32.GetWindowThreadProcessId.restype = wintypes.DWORD

kernel32.OpenProcess.argtypes = [
    wintypes.DWORD,
    wintypes.BOOL,
    wintypes.DWORD,
]
kernel32.OpenProcess.restype = wintypes.HANDLE

kernel32.QueryFullProcessImageNameW.argtypes = [
    wintypes.HANDLE,
    wintypes.DWORD,
    wintypes.LPWSTR,
    ctypes.POINTER(wintypes.DWORD),
]
kernel32.QueryFullProcessImageNameW.restype = wintypes.BOOL

kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
kernel32.CloseHandle.restype = wintypes.BOOL


def get_foreground_process_path():
    hwnd = user32.GetForegroundWindow()
    if not hwnd:
        return None

    pid = wintypes.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    if not pid.value:
        return None

    handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid.value)
    if not handle:
        return None

    try:
        buf = ctypes.create_unicode_buffer(32768)
        size = wintypes.DWORD(len(buf))
        if not kernel32.QueryFullProcessImageNameW(handle, 0, buf, ctypes.byref(size)):
            return None
        return Path(buf.value)
    finally:
        kernel32.CloseHandle(handle)


def scrcpy_is_foreground():
    path = get_foreground_process_path()
    return bool(path and path.name.lower() == "scrcpy.exe")


def scrcpy_is_running():
    try:
        cp = subprocess.run(
            ["tasklist", "/FI", "IMAGENAME eq scrcpy.exe", "/NH", "/FO", "CSV"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=3,
            creationflags=CREATE_NO_WINDOW,
        )
        return '"scrcpy.exe"' in cp.stdout.lower()
    except Exception:
        return True



# Ctrl+Alt+S: return the OPPO scrcpy window to the lower-left corner of the
# Windows primary monitor work area (the taskbar is excluded).
# This runs inside the existing media bridge, so no launcher EXE rebuild,
# additional program, or startup shortcut is necessary.
WM_HOTKEY = 0x0312
MOD_ALT = 0x0001
MOD_CONTROL = 0x0002
MOD_NOREPEAT = 0x4000
VK_S = 0x53
MOVE_HOTKEY_ID = 0x5345
MONITOR_DEFAULTTOPRIMARY = 1
SW_RESTORE = 9
SWP_NOSIZE = 0x0001
SWP_NOZORDER = 0x0004
SWP_NOACTIVATE = 0x0010


class RECT(ctypes.Structure):
    _fields_ = [(name, ctypes.c_long) for name in ("left", "top", "right", "bottom")]


class POINT(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]


class MONITORINFO(ctypes.Structure):
    _fields_ = [
        ("cbSize", wintypes.DWORD),
        ("rcMonitor", RECT),
        ("rcWork", RECT),
        ("dwFlags", wintypes.DWORD),
    ]


class MSG(ctypes.Structure):
    _fields_ = [
        ("hwnd", wintypes.HWND),
        ("message", wintypes.UINT),
        ("wParam", wintypes.WPARAM),
        ("lParam", wintypes.LPARAM),
        ("time", wintypes.DWORD),
        ("pt", POINT),
        ("lPrivate", wintypes.DWORD),
    ]


user32.RegisterHotKey.argtypes = [wintypes.HWND, ctypes.c_int, wintypes.UINT, wintypes.UINT]
user32.RegisterHotKey.restype = wintypes.BOOL
user32.UnregisterHotKey.argtypes = [wintypes.HWND, ctypes.c_int]
user32.UnregisterHotKey.restype = wintypes.BOOL
user32.GetMessageW.argtypes = [ctypes.POINTER(MSG), wintypes.HWND, wintypes.UINT, wintypes.UINT]
user32.GetMessageW.restype = ctypes.c_int
user32.EnumWindows.argtypes = [ctypes.c_void_p, wintypes.LPARAM]
user32.EnumWindows.restype = wintypes.BOOL
user32.IsWindowVisible.argtypes = [wintypes.HWND]
user32.IsWindowVisible.restype = wintypes.BOOL
user32.MonitorFromPoint.argtypes = [POINT, wintypes.DWORD]
user32.MonitorFromPoint.restype = wintypes.HANDLE
user32.GetMonitorInfoW.argtypes = [wintypes.HANDLE, ctypes.POINTER(MONITORINFO)]
user32.GetMonitorInfoW.restype = wintypes.BOOL
user32.GetWindowRect.argtypes = [wintypes.HWND, ctypes.POINTER(RECT)]
user32.GetWindowRect.restype = wintypes.BOOL
user32.ShowWindow.argtypes = [wintypes.HWND, ctypes.c_int]
user32.ShowWindow.restype = wintypes.BOOL
user32.SetWindowPos.argtypes = [
    wintypes.HWND, wintypes.HWND, ctypes.c_int, ctypes.c_int,
    ctypes.c_int, ctypes.c_int, wintypes.UINT,
]
user32.SetWindowPos.restype = wintypes.BOOL

_WINDOW_ENUM_PROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)


def find_oppo_scrcpy_window():
    # Match the executable in the same directory as this bridge, not unrelated
    # scrcpy instances started from other installations.
    expected = (APP_DIR / "scrcpy.exe").resolve()
    windows = []

    @_WINDOW_ENUM_PROC
    def visit(hwnd, unused):
        if not user32.IsWindowVisible(hwnd):
            return True
        pid = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        if not pid.value:
            return True
        handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid.value)
        if not handle:
            return True
        try:
            name = ctypes.create_unicode_buffer(32768)
            length = wintypes.DWORD(len(name))
            if kernel32.QueryFullProcessImageNameW(handle, 0, name, ctypes.byref(length)):
                if Path(name.value).resolve() == expected:
                    windows.append(hwnd)
        finally:
            kernel32.CloseHandle(handle)
        return True

    user32.EnumWindows(visit, 0)
    # Never move another window if more than one instance is ambiguous.
    return windows[0] if len(windows) == 1 else None


def move_scrcpy_bottom_left():
    hwnd = find_oppo_scrcpy_window()
    if hwnd is None:
        logging.warning("Ctrl+Alt+S: OPPO scrcpy window not uniquely identified")
        return
    monitor = user32.MonitorFromPoint(POINT(0, 0), MONITOR_DEFAULTTOPRIMARY)
    info = MONITORINFO()
    info.cbSize = ctypes.sizeof(info)
    if not monitor or not user32.GetMonitorInfoW(monitor, ctypes.byref(info)):
        logging.warning("Ctrl+Alt+S: primary monitor work area unavailable")
        return

    user32.ShowWindow(hwnd, SW_RESTORE)
    rect = RECT()
    if not user32.GetWindowRect(hwnd, ctypes.byref(rect)):
        return
    # GetWindowRect includes an invisible resize border on Windows 10/11.
    # Align the *visible* DWM frame with the work area instead.
    visible = RECT()
    have_visible = False
    try:
        dwmapi = ctypes.WinDLL("dwmapi")
        dwmapi.DwmGetWindowAttribute.argtypes = [
            wintypes.HWND, wintypes.DWORD, ctypes.c_void_p, wintypes.DWORD,
        ]
        dwmapi.DwmGetWindowAttribute.restype = ctypes.c_long
        DWMWA_EXTENDED_FRAME_BOUNDS = 9
        have_visible = dwmapi.DwmGetWindowAttribute(
            hwnd, DWMWA_EXTENDED_FRAME_BOUNDS,
            ctypes.byref(visible), ctypes.sizeof(visible),
        ) == 0 and visible.right > visible.left and visible.bottom > visible.top
    except OSError:
        pass

    if have_visible:
        x = rect.left + info.rcWork.left - visible.left
        y = rect.top + info.rcWork.bottom - visible.bottom
        # Do not move the visible title bar above the available desktop.
        y = max(y, rect.top + info.rcWork.top - visible.top)
    else:
        height = rect.bottom - rect.top
        x = info.rcWork.left
        y = max(info.rcWork.top, info.rcWork.bottom - height)

    if not user32.SetWindowPos(
        hwnd, None, x, y, 0, 0,
        SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE,
    ):
        logging.error("Ctrl+Alt+S: SetWindowPos failed: %s", ctypes.get_last_error())


def run_move_hotkey():
    # Dedicated thread message queue: RegisterHotKey works even when the
    # scrcpy window is off-screen and has no keyboard focus.
    if not user32.RegisterHotKey(None, MOVE_HOTKEY_ID,
                                 MOD_ALT | MOD_CONTROL | MOD_NOREPEAT, VK_S):
        logging.error("Ctrl+Alt+S could not be registered: %s", ctypes.get_last_error())
        return
    try:
        msg = MSG()
        while user32.GetMessageW(ctypes.byref(msg), None, 0, 0) > 0:
            if msg.message == WM_HOTKEY and msg.wParam == MOVE_HOTKEY_ID:
                try:
                    move_scrcpy_bottom_left()
                except Exception:
                    logging.exception("Ctrl+Alt+S move failed")
    finally:
        user32.UnregisterHotKey(None, MOVE_HOTKEY_ID)


threading.Thread(target=run_move_hotkey, name="ScrcpyMoveHotkey", daemon=True).start()


def ensure_silent_wav():
    if SILENT_WAV.exists():
        return
    with wave.open(str(SILENT_WAV), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(8000)
        wf.writeframes(b"\x00\x00" * (8000 * 10))


ensure_silent_wav()

player = MediaPlayer()
player.is_looping_enabled = True
player.volume = 0.0
player.source = MediaSource.create_from_uri(Uri(SILENT_WAV.as_uri()))

session = player.playback_session
controls = player.system_media_transport_controls
controls.is_play_enabled = True
controls.is_pause_enabled = True
controls.is_enabled = True

adb_path = APP_DIR / "adb.exe"
if not adb_path.exists():
    found = shutil.which("adb")
    adb_path = Path(found) if found else None

# Experimental mode:
# Keep this SMTC/media session registered continuously while scrcpy exists.
# We never enable/disable the session on foreground changes.
armed = False
arm_at = time.monotonic() + 1.0
last_state = None
recovering_player = False

scrcpy_seen = False
scrcpy_missing_polls = 0
state_token = None
adb_shell_proc = None


def on_playback_state_changed(sender, args):
    try:
        events.put(("STATE", sender.playback_state))
    except Exception as exc:
        events.put(("ERROR", repr(exc)))


state_token = session.add_playback_state_changed(on_playback_state_changed)


def ensure_adb_shell():
    global adb_shell_proc

    if adb_path is None:
        logging.error("adb.exe was not found")
        return False

    try:
        if adb_shell_proc is not None and adb_shell_proc.poll() is None:
            return True
    except Exception:
        pass

    adb_shell_proc = None

    try:
        adb_shell_proc = subprocess.Popen(
            [str(adb_path), "shell"],
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1,
            creationflags=CREATE_NO_WINDOW,
        )
        logging.info("Persistent hidden adb shell started")
        return True
    except Exception:
        adb_shell_proc = None
        logging.exception("Failed to start persistent adb shell")
        return False


def close_adb_shell():
    global adb_shell_proc

    proc = adb_shell_proc
    adb_shell_proc = None

    if proc is None:
        return

    try:
        if proc.stdin is not None:
            proc.stdin.close()
    except Exception:
        pass

    try:
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=1)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass


def send_android_play_pause():
    global adb_shell_proc

    if not ensure_adb_shell():
        return

    try:
        adb_shell_proc.stdin.write("input keyevent 85\n")
        adb_shell_proc.stdin.flush()
        return
    except Exception:
        logging.exception("Persistent adb shell write failed; restarting it")
        close_adb_shell()

    # One automatic retry in case USB/ADB was briefly reset.
    if not ensure_adb_shell():
        return

    try:
        adb_shell_proc.stdin.write("input keyevent 85\n")
        adb_shell_proc.stdin.flush()
    except Exception:
        logging.exception("Failed to send Android media key after adb-shell restart")


def activate_bridge():
    # Kept only for compatibility with old code paths.
    # The media session is always enabled in this experimental build.
    return


def deactivate_bridge():
    # Intentionally do nothing.
    # Toggling SMTC registration on focus changes is what we are testing against.
    return


# Hidden Tk event loop: no GUI window is shown.
root = tk.Tk()
root.withdraw()

try:
    player.play()
except Exception:
    logging.exception("Initial player.play() failed")


def poll_foreground():
    # Do NOT change MediaPlayer or SMTC state here.
    # Foreground is checked only when a media-button event actually arrives.
    root.after(250, poll_foreground)


def poll_media_events():
    global armed, last_state, recovering_player

    if not armed and time.monotonic() >= arm_at:
        try:
            last_state = session.playback_state
        except Exception:
            last_state = None
        armed = True

    while True:
        try:
            kind, value = events.get_nowait()
        except queue.Empty:
            break

        if kind == "ERROR":
            logging.error("Media event error: %s", value)
            continue

        state = value

        # Internal PLAYING event generated when we resume the silent player.
        if recovering_player:
            if state == MediaPlaybackState.PLAYING:
                recovering_player = False
            last_state = state
            continue

        if not armed:
            last_state = state
            continue

        if (
            state in (MediaPlaybackState.PLAYING, MediaPlaybackState.PAUSED)
            and state != last_state
        ):
            last_state = state

            # Only forward headset play/pause to Android while scrcpy is foreground.
            if scrcpy_is_foreground():
                send_android_play_pause()

            # A headset "pause" may pause our silent player. Resume it immediately
            # so the Bluetooth audio endpoint/session stays continuously alive.
            if state == MediaPlaybackState.PAUSED:
                try:
                    recovering_player = True
                    player.play()
                except Exception:
                    recovering_player = False
                    logging.exception("Silent player recovery failed")
        else:
            last_state = state

    root.after(40, poll_media_events)



def poll_hotkey_commands():
    # AutoHotkey only appends a tiny line to this temp file.
    # No adb.exe or console process is started when Space is pressed.
    try:
        if HOTKEY_COMMAND_PATH.exists():
            try:
                data = HOTKEY_COMMAND_PATH.read_text(encoding="utf-8", errors="ignore")
            finally:
                try:
                    HOTKEY_COMMAND_PATH.unlink()
                except FileNotFoundError:
                    pass

            count = data.count("1")
            for _ in range(count):
                send_android_play_pause()
    except Exception:
        logging.exception("Failed to process Space hotkey command")

    root.after(10, poll_hotkey_commands)


def poll_scrcpy_lifetime():
    global scrcpy_seen, scrcpy_missing_polls

    running = scrcpy_is_running()

    if running:
        scrcpy_seen = True
        scrcpy_missing_polls = 0
    elif scrcpy_seen:
        scrcpy_missing_polls += 1
        if scrcpy_missing_polls >= 2:
            shutdown()
            return

    root.after(1000, poll_scrcpy_lifetime)


def shutdown():
    close_adb_shell()

    try:
        controls.is_enabled = False
    except Exception:
        pass
    try:
        player.pause()
    except Exception:
        pass
    try:
        if state_token is not None:
            session.remove_playback_state_changed(state_token)
    except Exception:
        pass
    try:
        player.close()
    except Exception:
        pass

    logging.info("Bridge exited")
    root.destroy()


logging.info("Headless bridge started; adb=%s", adb_path)

# Never replay a Space press left over from an older/direct scrcpy session.
try:
    HOTKEY_COMMAND_PATH.unlink()
except FileNotFoundError:
    pass
except Exception:
    logging.exception("Failed to clear stale hotkey command file")

# Warm the hidden adb shell before the first Space press.
ensure_adb_shell()

root.after(100, poll_foreground)
root.after(40, poll_media_events)
root.after(10, poll_hotkey_commands)
root.after(500, poll_scrcpy_lifetime)
root.mainloop()
