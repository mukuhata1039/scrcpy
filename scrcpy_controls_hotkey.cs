using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

internal static class ScrcpyControlsHotkey
{
    private const uint WM_HOTKEY = 0x0312;
    private const uint PM_REMOVE = 0x0001;
    private const uint MOD_ALT = 0x0001;
    private const uint MOD_CONTROL = 0x0002;
    private const uint MOD_SHIFT = 0x0004;
    private const uint MOD_NOREPEAT = 0x4000;
    private const uint KEYEVENTF_KEYUP = 0x0002;
    private const byte VK_LMENU = 0xA4;
    private const byte VK_LSHIFT = 0xA0;
    private const byte VK_O = 0x4F;
    private const int VK_MENU = 0x12;
    private const int VK_SHIFT = 0x10;
    private const uint VK_TAB = 0x09;
    private const int TOGGLE_ID = 0x5344;
    private const int APP_SWITCH_ID = 0x5345;
    private const int SCREEN_ON_ID = 0x5346;

    [STAThread]
    private static int Main()
    {
        bool createdNew;
        using (var mutex = new Mutex(true, @"Local\ScrcpyAudibleControlsHotkey", out createdNew))
        {
            if (!createdNew)
                return 0;

            using (Process scrcpy = WaitForScrcpy(TimeSpan.FromSeconds(30)))
            {
                if (scrcpy == null)
                    return 0;

                Run(scrcpy);
            }
        }

        return 0;
    }

    private static Process WaitForScrcpy(TimeSpan timeout)
    {
        DateTime deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            Process[] processes = Process.GetProcessesByName("scrcpy");
            if (processes.Length > 0)
            {
                for (int i = 1; i < processes.Length; i++)
                    processes[i].Dispose();
                return processes[0];
            }

            Thread.Sleep(50);
        }

        return null;
    }

    private static void Run(Process scrcpy)
    {
        bool registered = false;
        bool phoneScreenOff = true; // The launcher starts scrcpy with --turn-screen-off.
        string adb = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "adb.exe");
        MSG ignored;
        PeekMessageW(out ignored, IntPtr.Zero, 0, 0, 0);

        try
        {
            while (IsAlive(scrcpy))
            {
                bool foreground = IsForegroundProcess(scrcpy.Id);
                if (foreground && !registered)
                {
                    // Register all together. On failure, release any partial registration.
                    bool toggle = RegisterHotKey(IntPtr.Zero, TOGGLE_ID, MOD_ALT | MOD_NOREPEAT, VK_O);
                    bool appSwitch = RegisterHotKey(IntPtr.Zero, APP_SWITCH_ID,
                        MOD_CONTROL | MOD_NOREPEAT, VK_TAB);
                    bool screenOn = RegisterHotKey(IntPtr.Zero, SCREEN_ON_ID,
                        MOD_ALT | MOD_SHIFT | MOD_NOREPEAT, VK_O);
                    registered = toggle && appSwitch && screenOn;
                    if (!registered)
                    {
                        if (toggle) UnregisterHotKey(IntPtr.Zero, TOGGLE_ID);
                        if (appSwitch) UnregisterHotKey(IntPtr.Zero, APP_SWITCH_ID);
                        if (screenOn) UnregisterHotKey(IntPtr.Zero, SCREEN_ON_ID);
                    }
                }
                else if (!foreground && registered)
                {
                    UnregisterAll();
                    registered = false;
                }

                MSG msg;
                while (PeekMessageW(out msg, IntPtr.Zero, WM_HOTKEY, WM_HOTKEY, PM_REMOVE))
                {
                    if (!registered || msg.message != WM_HOTKEY ||
                        !IsForegroundProcess(scrcpy.Id))
                        continue;

                    int id = unchecked((int)msg.wParam.ToUInt64());
                    if (id == APP_SWITCH_ID)
                    {
                        SendAndroidAppSwitch(adb);
                    }
                    else if (id == TOGGLE_ID || id == SCREEN_ON_ID)
                    {
                        // Unregister while forwarding the key to scrcpy to avoid recursion.
                        UnregisterAll();
                        registered = false;
                        // Wait for the physical shortcut to finish so the
                        // injected shortcut cannot be mistaken for a repeat.
                        while (IsAlive(scrcpy) &&
                            (KeyIsDown(VK_O) || KeyIsDown(VK_MENU) || KeyIsDown(VK_SHIFT)))
                            Thread.Sleep(10);
                        if (IsAlive(scrcpy) && IsForegroundProcess(scrcpy.Id))
                        {
                            bool turnOn = id == SCREEN_ON_ID || phoneScreenOff;
                            ForwardScrcpyScreenShortcut(turnOn);
                            phoneScreenOff = !turnOn;
                        }
                        Thread.Sleep(30);
                    }
                }

                Thread.Sleep(10);
            }
        }
        finally
        {
            if (registered)
                UnregisterAll();
        }
    }

    private static void ForwardScrcpyScreenShortcut(bool turnOn)
    {
        // scrcpy's default shortcut modifier is left Alt.
        keybd_event(VK_LMENU, 0, 0, UIntPtr.Zero);
        if (turnOn) keybd_event(VK_LSHIFT, 0, 0, UIntPtr.Zero);
        keybd_event(VK_O, 0, 0, UIntPtr.Zero);
        keybd_event(VK_O, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        if (turnOn) keybd_event(VK_LSHIFT, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        keybd_event(VK_LMENU, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    private static bool KeyIsDown(int vk)
    {
        return (GetAsyncKeyState(vk) & 0x8000) != 0;
    }

    private static void SendAndroidAppSwitch(string adb)
    {
        if (!File.Exists(adb))
            return;

        try
        {
            var start = new ProcessStartInfo(adb, "shell input keyevent 187");
            start.UseShellExecute = false;
            start.CreateNoWindow = true;
            start.WindowStyle = ProcessWindowStyle.Hidden;
            using (Process process = Process.Start(start))
            {
                // Do not block the keyboard thread while adb connects.
            }
        }
        catch
        {
            // ADB may briefly disconnect during USB reconnect or sleep recovery.
        }
    }

    private static bool IsAlive(Process process)
    {
        try { return !process.HasExited; }
        catch { return false; }
    }

    private static bool IsForegroundProcess(int pid)
    {
        IntPtr window = GetForegroundWindow();
        if (window == IntPtr.Zero)
            return false;
        uint foregroundPid;
        GetWindowThreadProcessId(window, out foregroundPid);
        return foregroundPid == (uint)pid;
    }

    private static void UnregisterAll()
    {
        UnregisterHotKey(IntPtr.Zero, TOGGLE_ID);
        UnregisterHotKey(IntPtr.Zero, APP_SWITCH_ID);
        UnregisterHotKey(IntPtr.Zero, SCREEN_ON_ID);
    }

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint modifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int vk);

    [DllImport("user32.dll")]
    private static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extraInfo);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool PeekMessageW(
        out MSG message, IntPtr hWnd, uint min, uint max, uint remove);

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT { public int X; public int Y; }

    [StructLayout(LayoutKind.Sequential)]
    private struct MSG
    {
        public IntPtr hwnd;
        public uint message;
        public UIntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public POINT pt;
        public uint lPrivate;
    }
}
