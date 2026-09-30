using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

internal static class Program
{
    private const uint WM_HOTKEY = 0x0312;
    private const uint PM_REMOVE = 0x0001;
    private const uint MOD_NOREPEAT = 0x4000;
    private const uint VK_SPACE = 0x20;
    private const int HOTKEY_ID = 0x5343;

    [STAThread]
    private static int Main()
    {
        bool createdNew;

        using (var mutex = new Mutex(
            true,
            @"Local\ScrcpyAudibleSpaceHotkey",
            out createdNew))
        {
            if (!createdNew)
                return 0;

            Process scrcpy = WaitForScrcpy(TimeSpan.FromSeconds(30));
            if (scrcpy == null)
                return 0;

            try
            {
                return Run(scrcpy);
            }
            finally
            {
                scrcpy.Dispose();
            }
        }
    }

    private static Process WaitForScrcpy(TimeSpan timeout)
    {
        DateTime deadline = DateTime.UtcNow + timeout;

        while (DateTime.UtcNow < deadline)
        {
            Process[] list = Process.GetProcessesByName("scrcpy");

            try
            {
                if (list.Length > 0)
                {
                    Process selected = list[0];

                    for (int i = 1; i < list.Length; i++)
                        list[i].Dispose();

                    return selected;
                }
            }
            finally
            {
                if (list.Length == 0)
                {
                    // Nothing to dispose.
                }
            }

            Thread.Sleep(50);
        }

        return null;
    }

    private static int Run(Process scrcpy)
    {
        int scrcpyPid = scrcpy.Id;
        string commandPath = Path.Combine(
            Path.GetTempPath(),
            "scrcpy_audible_space_command.txt"
        );

        bool registered = false;

        // RegisterHotKey(NULL, ...) posts WM_HOTKEY to this thread.
        // Calling PeekMessage once creates the thread message queue.
        MSG ignored;
        PeekMessageW(out ignored, IntPtr.Zero, 0, 0, 0);

        try
        {
            while (IsAlive(scrcpy))
            {
                bool scrcpyForeground = IsForegroundProcess(scrcpyPid);

                if (scrcpyForeground && !registered)
                {
                    registered = RegisterHotKey(
                        IntPtr.Zero,
                        HOTKEY_ID,
                        MOD_NOREPEAT,
                        VK_SPACE
                    );
                }
                else if (!scrcpyForeground && registered)
                {
                    UnregisterHotKey(IntPtr.Zero, HOTKEY_ID);
                    registered = false;
                }

                MSG msg;
                while (PeekMessageW(
                    out msg,
                    IntPtr.Zero,
                    WM_HOTKEY,
                    WM_HOTKEY,
                    PM_REMOVE))
                {
                    if (msg.message == WM_HOTKEY &&
                        msg.wParam.ToUInt64() == (ulong)HOTKEY_ID &&
                        IsForegroundProcess(scrcpyPid))
                    {
                        SendPlayPause(commandPath);
                    }
                }

                Thread.Sleep(10);
            }
        }
        finally
        {
            if (registered)
                UnregisterHotKey(IntPtr.Zero, HOTKEY_ID);
        }

        return 0;
    }

    private static bool IsAlive(Process process)
    {
        try
        {
            return !process.HasExited;
        }
        catch
        {
            return false;
        }
    }

    private static bool IsForegroundProcess(int processId)
    {
        IntPtr hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero)
            return false;

        uint pid;
        GetWindowThreadProcessId(hwnd, out pid);
        return pid == (uint)processId;
    }

    private static void SendPlayPause(string commandPath)
    {
        // The existing Python bridge polls this file every 10 ms.
        // Each "1" becomes Android KEYCODE_MEDIA_PLAY_PAUSE (85).
        for (int attempt = 0; attempt < 3; attempt++)
        {
            try
            {
                File.AppendAllText(
                    commandPath,
                    "1\n",
                    Encoding.ASCII
                );
                return;
            }
            catch (IOException)
            {
                Thread.Sleep(3);
            }
            catch
            {
                return;
            }
        }
    }

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(
        IntPtr hWnd,
        out uint lpdwProcessId
    );

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool RegisterHotKey(
        IntPtr hWnd,
        int id,
        uint fsModifiers,
        uint vk
    );

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnregisterHotKey(
        IntPtr hWnd,
        int id
    );

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool PeekMessageW(
        out MSG lpMsg,
        IntPtr hWnd,
        uint wMsgFilterMin,
        uint wMsgFilterMax,
        uint wRemoveMsg
    );

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int X;
        public int Y;
    }

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