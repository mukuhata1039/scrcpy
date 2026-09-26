using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

internal static class Program
{
    private const string AppId = "Mukuhata.ScrcpyAudible";
    private const uint WM_SETICON = 0x0080;
    private const int ICON_SMALL = 0;
    private const int ICON_BIG = 1;
    private const uint IMAGE_ICON = 1;
    private const uint LR_LOADFROMFILE = 0x0010;
    private const uint SW_SHOWNORMAL = 1;

    // Windows 11 DWM title-bar customization.
    private const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
    private const int DWMWA_BORDER_COLOR = 34;
    private const int DWMWA_CAPTION_COLOR = 35;
    private const int DWMWA_TEXT_COLOR = 36;

    private const int GWL_EXSTYLE = -20;
    private const int GCLP_HICON = -14;
    private const int GCLP_HICONSM = -34;
    private const int WS_EX_DLGMODALFRAME = 0x00000001;
    private const uint SWP_NOSIZE = 0x0001;
    private const uint SWP_NOMOVE = 0x0002;
    private const uint SWP_NOZORDER = 0x0004;
    private const uint SWP_NOACTIVATE = 0x0010;
    private const uint SWP_FRAMECHANGED = 0x0020;

    private const int SM_CMONITORS = 80;
    private const uint MONITOR_DEFAULTTONEAREST = 0x00000002;
    private const uint MONITORINFOF_PRIMARY = 0x00000001;

    private const string WindowTitle = "Scrcpy";
    private const int AndroidTitlePollMs = 300;

    private static PROPERTYKEY PKEY_AppUserModel_ID =
        new PROPERTYKEY(
            new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"),
            5
        );

    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            SetCurrentProcessExplicitAppUserModelID(AppId);

            string baseDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
            string launcherExe = Process.GetCurrentProcess().MainModule.FileName;
            string iconPath = Path.Combine(baseDir, "scrcpy_audible.ico");

            if (args.Any(a => string.Equals(a, "--create-shortcut", StringComparison.OrdinalIgnoreCase)))
            {
                CreateShortcut(baseDir, launcherExe, iconPath);
                return 0;
            }

            bool createdNew;
            using (var mutex = new Mutex(true, @"Local\ScrcpyAudibleLauncher", out createdNew))
            {
                if (!createdNew)
                    return 0;

                return RunScrcpy(baseDir, iconPath);
            }
        }
        catch (Exception ex)
        {
            MessageBoxW(
                IntPtr.Zero,
                ex.ToString(),
                "scrcpy Audible Launcher",
                0x10
            );
            return 1;
        }
    }

    private static void SendAndroidPause(string baseDir)
    {
        try
        {
            string adbExe = Path.Combine(baseDir, "adb.exe");
            if (!File.Exists(adbExe))
                return;

            var psi = new ProcessStartInfo
            {
                FileName = adbExe,
                Arguments = "shell input keyevent 127",
                WorkingDirectory = baseDir,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };

            using (Process p = Process.Start(psi))
            {
                if (p != null)
                    p.WaitForExit(3000);
            }
        }
        catch
        {
            // Closing scrcpy should never be blocked by a failed pause command.
        }
    }

    private static int RunScrcpy(string baseDir, string iconPath)
    {
        string scrcpyExe = Path.Combine(baseDir, "scrcpy.exe");
        string noConsoleVbs = Path.Combine(baseDir, "scrcpy-noconsole.vbs");
        string bridgePy = Path.Combine(baseDir, "scrcpy_media_bridge.py");
        string windowStatePath = Path.Combine(baseDir, "scrcpy_window_state_v5.txt");
        string mainMonitorPath = Path.Combine(baseDir, "scrcpy_main_monitor.txt");
        string appLabelCachePath = Path.Combine(
            baseDir,
            "scrcpy_app_label_cache.txt"
        );

        if (!File.Exists(scrcpyExe))
            throw new FileNotFoundException("scrcpy.exe が見つかりません。", scrcpyExe);

        if (!File.Exists(noConsoleVbs))
            throw new FileNotFoundException("scrcpy-noconsole.vbs が見つかりません。", noConsoleVbs);

        if (!File.Exists(bridgePy))
            throw new FileNotFoundException("scrcpy_media_bridge.py が見つかりません。", bridgePy);

        StartBridgeHidden(baseDir, bridgePy);

        // Persistent Android package -> human-readable app label cache.
        // Once an app name has been resolved, later launches can show it
        // immediately without querying Android or Google Play again.
        Dictionary<string, string> appLabelCache =
            LoadPersistentAppLabelCache(appLabelCachePath);

        var before = new HashSet<int>(
            Process.GetProcessesByName("scrcpy").Select(p =>
            {
                try { return p.Id; }
                finally { p.Dispose(); }
            })
        );

        string options =
            "--max-size=1100 " +
            "--turn-screen-off " +
            "--stay-awake";

        int savedX;
        int savedY;
        int savedWidth;
        int savedHeight;

        bool haveSavedWindowState = TryLoadWindowState(
            windowStatePath,
            out savedX,
            out savedY,
            out savedWidth,
            out savedHeight
        );

        if (haveSavedWindowState)
        {
            // Size is safe to give to scrcpy.  Position is restored later with
            // SetWindowPos using the actual OUTER window coordinates.
            options +=
                " --window-width=" + savedWidth +
                " --window-height=" + savedHeight;
        }
        else
        {
            // First launch: keep the original default position.
            options +=
                " --window-x=0" +
                " --window-y=100";
        }

        var vbsStart = new ProcessStartInfo
        {
            FileName = "wscript.exe",
            Arguments = "//B //Nologo \"" + noConsoleVbs + "\" " + options,
            WorkingDirectory = baseDir,
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden
        };

        Process.Start(vbsStart);

        Process scrcpy = WaitForNewScrcpy(before, TimeSpan.FromSeconds(15));
        if (scrcpy == null)
            throw new InvalidOperationException("scrcpy.exe の起動を確認できませんでした。");

        int scrcpyPid = scrcpy.Id;
        IntPtr lastHwnd = IntPtr.Zero;
        DateTime iconRefreshUntil = DateTime.UtcNow.AddSeconds(12);
        int lastWindowX = 0;
        int lastWindowY = 100;
        int lastClientWidth = 0;
        int lastClientHeight = 0;
        bool haveLastWindowPosition = false;

        string preferredMainMonitor = TryLoadMainMonitor(mainMonitorPath);

        // Learn the user's "main" display from Windows' primary display whenever
        // two or more displays are active.  This lets us distinguish:
        //   1) main only
        //   2) main + mobile
        //   3) mobile only
        // even though both 1) and 3) have only one active monitor.
        if (string.IsNullOrEmpty(preferredMainMonitor) &&
            GetSystemMetrics(SM_CMONITORS) >= 2)
        {
            preferredMainMonitor = GetCurrentPrimaryMonitorDevice();
            TrySaveMainMonitor(mainMonitorPath, preferredMainMonitor);
        }

        bool previousMainActive =
            !string.IsNullOrEmpty(preferredMainMonitor) &&
            IsMonitorDeviceActive(preferredMainMonitor);

        DateTime restoreMainDisplayAt = DateTime.MinValue;
        DateTime nextPreferredStateSaveAt = DateTime.MinValue;
        bool initialSavedPlacementApplied = false;

        DateTime nextAndroidTitlePollAt = DateTime.MinValue;
        string lastAndroidTitle = null;

        try
        {
            // Do not read HasExited / ExitCode from the Process object here.
            // On some Windows/.NET combinations a Process object obtained via
            // GetProcessesByName() can throw InvalidOperationException during
            // shutdown. Poll by PID instead.
            while (IsProcessAlive(scrcpyPid))
            {
                IntPtr hwnd = FindTopLevelWindow(scrcpyPid);

                if (hwnd != IntPtr.Zero)
                {
                    if (hwnd != lastHwnd || DateTime.UtcNow < iconRefreshUntil)
                    {
                        ApplyWindowIdentity(hwnd, iconPath);
                        lastHwnd = hwnd;
                    }

                    if (DateTime.UtcNow >= nextAndroidTitlePollAt)
                    {
                        string packageName =
                            TryGetForegroundAndroidPackage(baseDir);

                        string title = ResolveAndroidAppTitle(
                            baseDir,
                            packageName,
                            appLabelCache,
                            appLabelCachePath
                        );

                        if (!string.Equals(
                            title,
                            lastAndroidTitle,
                            StringComparison.Ordinal))
                        {
                            SetWindowTextW(hwnd, title);
                            lastAndroidTitle = title;
                        }

                        nextAndroidTitlePollAt =
                            DateTime.UtcNow.AddMilliseconds(
                                AndroidTitlePollMs
                            );
                    }

                    int currentMonitorCount = GetSystemMetrics(SM_CMONITORS);

                    // If we do not yet know which physical display is the user's
                    // "main", learn it from Windows' primary display in dual-screen
                    // mode.  In single-screen mode we deliberately do NOT learn,
                    // because that one screen might be the mobile monitor.
                    if (string.IsNullOrEmpty(preferredMainMonitor) &&
                        currentMonitorCount >= 2)
                    {
                        preferredMainMonitor =
                            GetCurrentPrimaryMonitorDevice();

                        TrySaveMainMonitor(
                            mainMonitorPath,
                            preferredMainMonitor
                        );

                        previousMainActive =
                            !string.IsNullOrEmpty(preferredMainMonitor);
                    }

                    bool currentMainActive =
                        !string.IsNullOrEmpty(preferredMainMonitor) &&
                        IsMonitorDeviceActive(preferredMainMonitor);

                    // On startup, restore the saved position only if the user's
                    // main display is active.  If we started in mobile-only mode,
                    // leave the window on the mobile display until main returns.
                    if (!initialSavedPlacementApplied &&
                        haveSavedWindowState &&
                        currentMainActive)
                    {
                        RestoreWindowOuterState(
                            hwnd,
                            savedX,
                            savedY,
                            savedWidth,
                            savedHeight
                        );

                        initialSavedPlacementApplied = true;
                        nextPreferredStateSaveAt =
                            DateTime.UtcNow.AddMilliseconds(1200);
                    }

                    // Detect the important transition by monitor identity, not by
                    // monitor count.  This covers BOTH:
                    //   mobile-only -> main+mobile  (1 -> 2 monitors)
                    //   mobile-only -> main-only    (1 -> 1 monitors)
                    if (!previousMainActive && currentMainActive)
                    {
                        restoreMainDisplayAt =
                            DateTime.UtcNow.AddMilliseconds(900);
                    }

                    previousMainActive = currentMainActive;

                    if (restoreMainDisplayAt != DateTime.MinValue &&
                        DateTime.UtcNow >= restoreMainDisplayAt &&
                        currentMainActive)
                    {
                        int restoreX;
                        int restoreY;
                        int restoreWidth;
                        int restoreHeight;

                        if (TryLoadWindowState(
                            windowStatePath,
                            out restoreX,
                            out restoreY,
                            out restoreWidth,
                            out restoreHeight))
                        {
                            RestoreWindowOuterState(
                                hwnd,
                                restoreX,
                                restoreY,
                                restoreWidth,
                                restoreHeight
                            );
                        }
                        else
                        {
                            RECT currentClientRect;
                            if (GetClientRect(hwnd, out currentClientRect))
                            {
                                int currentWidth =
                                    currentClientRect.Right - currentClientRect.Left;
                                int currentHeight =
                                    currentClientRect.Bottom - currentClientRect.Top;

                                RestoreWindowOuterState(
                                    hwnd,
                                    0,
                                    100,
                                    currentWidth,
                                    currentHeight
                                );
                            }
                        }

                        restoreMainDisplayAt = DateTime.MinValue;
                        nextPreferredStateSaveAt =
                            DateTime.UtcNow.AddMilliseconds(1000);
                    }

                    RECT currentOuterRect;
                    if (GetWindowRect(hwnd, out currentOuterRect))
                    {
                        int x = currentOuterRect.Left;
                        int y = currentOuterRect.Top;

                        if (x > -30000 && y > -30000 &&
                            x < 30000 && y < 30000)
                        {
                            // Store the real Win32 OUTER-window top-left.
                            // This avoids SDL/client-area/title-bar coordinate drift.
                            lastWindowX = x;
                            lastWindowY = y;
                            haveLastWindowPosition = true;
                        }
                    }

                    RECT clientRect;
                    if (GetClientRect(hwnd, out clientRect))
                    {
                        int width = clientRect.Right - clientRect.Left;
                        int height = clientRect.Bottom - clientRect.Top;

                        if (width >= 200 && height >= 200)
                        {
                            lastClientWidth = width;
                            lastClientHeight = height;
                        }
                    }

                    // Save the "preferred" window state only while two or more
                    // displays are active AND scrcpy is on the Windows primary
                    // display.  Therefore the forced move to the mobile monitor
                    // in mobile-only mode never overwrites the preferred position.
                    if (currentMainActive &&
                        restoreMainDisplayAt == DateTime.MinValue &&
                        DateTime.UtcNow >= nextPreferredStateSaveAt &&
                        IsWindowOnMonitorDevice(hwnd, preferredMainMonitor) &&
                        haveLastWindowPosition &&
                        lastClientWidth > 0 &&
                        lastClientHeight > 0)
                    {
                        TrySaveWindowState(
                            windowStatePath,
                            lastWindowX,
                            lastWindowY,
                            lastClientWidth,
                            lastClientHeight
                        );

                        nextPreferredStateSaveAt =
                            DateTime.UtcNow.AddMilliseconds(700);
                    }
                }

                Thread.Sleep(300);
            }

            // Do not overwrite the preferred state while Windows is in
            // mobile-monitor-only mode.  The loop above already saves the state
            // whenever scrcpy is on the primary display in a multi-monitor setup.
            if (!string.IsNullOrEmpty(preferredMainMonitor) &&
                IsMonitorDeviceActive(preferredMainMonitor) &&
                lastHwnd != IntPtr.Zero &&
                IsWindowOnMonitorDevice(lastHwnd, preferredMainMonitor) &&
                haveLastWindowPosition &&
                lastClientWidth > 0 &&
                lastClientHeight > 0)
            {
                TrySaveWindowState(
                    windowStatePath,
                    lastWindowX,
                    lastWindowY,
                    lastClientWidth,
                    lastClientHeight
                );
            }

            // The mirror process is now gone. Explicitly PAUSE Android media.
            // KEYCODE_MEDIA_PAUSE = 127, so an already-paused Audible session
            // will remain paused.
            SendAndroidPause(baseDir);

            return 0;
        }
        finally
        {
            scrcpy.Dispose();
        }
    }

    private static string TryLoadMainMonitor(string path)
    {
        try
        {
            if (!File.Exists(path))
                return null;

            string value = File.ReadAllText(path).Trim();
            return string.IsNullOrEmpty(value) ? null : value;
        }
        catch
        {
            return null;
        }
    }

    private static void TrySaveMainMonitor(string path, string deviceName)
    {
        try
        {
            if (!string.IsNullOrEmpty(deviceName))
                File.WriteAllText(path, deviceName);
        }
        catch
        {
            // Learning the monitor identity is optional.
        }
    }

    private static string GetCurrentPrimaryMonitorDevice()
    {
        string primary = null;

        EnumDisplayMonitors(
            IntPtr.Zero,
            IntPtr.Zero,
            (IntPtr hMonitor, IntPtr hdcMonitor, ref RECT monitorRect, IntPtr data) =>
            {
                MONITORINFOEX info = new MONITORINFOEX();
                info.cbSize = Marshal.SizeOf(typeof(MONITORINFOEX));

                if (GetMonitorInfoExW(hMonitor, ref info) &&
                    (info.dwFlags & MONITORINFOF_PRIMARY) != 0)
                {
                    primary = info.szDevice;
                    return false;
                }

                return true;
            },
            IntPtr.Zero
        );

        return primary;
    }

    private static bool IsMonitorDeviceActive(string deviceName)
    {
        if (string.IsNullOrEmpty(deviceName))
            return false;

        bool found = false;

        EnumDisplayMonitors(
            IntPtr.Zero,
            IntPtr.Zero,
            (IntPtr hMonitor, IntPtr hdcMonitor, ref RECT monitorRect, IntPtr data) =>
            {
                MONITORINFOEX info = new MONITORINFOEX();
                info.cbSize = Marshal.SizeOf(typeof(MONITORINFOEX));

                if (GetMonitorInfoExW(hMonitor, ref info) &&
                    string.Equals(
                        info.szDevice,
                        deviceName,
                        StringComparison.OrdinalIgnoreCase))
                {
                    found = true;
                    return false;
                }

                return true;
            },
            IntPtr.Zero
        );

        return found;
    }

    private static bool IsWindowOnMonitorDevice(
        IntPtr hwnd,
        string deviceName
    )
    {
        try
        {
            if (string.IsNullOrEmpty(deviceName))
                return false;

            IntPtr monitor =
                MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);

            if (monitor == IntPtr.Zero)
                return false;

            MONITORINFOEX info = new MONITORINFOEX();
            info.cbSize = Marshal.SizeOf(typeof(MONITORINFOEX));

            if (!GetMonitorInfoExW(monitor, ref info))
                return false;

            return string.Equals(
                info.szDevice,
                deviceName,
                StringComparison.OrdinalIgnoreCase
            );
        }
        catch
        {
            return false;
        }
    }

    private static void RestoreWindowOuterState(
        IntPtr hwnd,
        int outerX,
        int outerY,
        int clientWidth,
        int clientHeight
    )
    {
        try
        {
            // Stage 1: move first, without resizing.
            // This lets Windows apply the destination monitor's DPI/frame metrics.
            SetWindowPos(
                hwnd,
                IntPtr.Zero,
                outerX,
                outerY,
                0,
                0,
                SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
            );

            Thread.Sleep(120);

            RECT windowRect;
            RECT clientRect;

            if (GetWindowRect(hwnd, out windowRect) &&
                GetClientRect(hwnd, out clientRect))
            {
                int currentOuterWidth =
                    windowRect.Right - windowRect.Left;
                int currentOuterHeight =
                    windowRect.Bottom - windowRect.Top;

                int currentClientWidth =
                    clientRect.Right - clientRect.Left;
                int currentClientHeight =
                    clientRect.Bottom - clientRect.Top;

                int horizontalNonClient =
                    currentOuterWidth - currentClientWidth;
                int verticalNonClient =
                    currentOuterHeight - currentClientHeight;

                int desiredOuterWidth =
                    clientWidth + horizontalNonClient;
                int desiredOuterHeight =
                    clientHeight + verticalNonClient;

                // Stage 2: restore the client size while anchoring the OUTER
                // top-left at the exact saved coordinate.
                SetWindowPos(
                    hwnd,
                    IntPtr.Zero,
                    outerX,
                    outerY,
                    desiredOuterWidth,
                    desiredOuterHeight,
                    SWP_NOZORDER | SWP_NOACTIVATE
                );
            }

            // SDL3/aspect-ratio enforcement and a per-monitor DPI change may
            // adjust the frame a few pixels after the resize.  Correct position
            // one last time, but do not touch size.
            Thread.Sleep(120);

            SetWindowPos(
                hwnd,
                IntPtr.Zero,
                outerX,
                outerY,
                0,
                0,
                SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
            );
        }
        catch
        {
            // Display restoration is a convenience feature only.
        }
    }

    private static bool TryLoadWindowState(
        string path,
        out int x,
        out int y,
        out int width,
        out int height
    )
    {
        x = 0;
        y = 100;
        width = 0;
        height = 0;

        try
        {
            if (!File.Exists(path))
                return false;

            string[] parts = File.ReadAllText(path)
                .Trim()
                .Split(',');

            // Compatibility inside the v2 state file:
            // a 2-value form is still accepted as "width,height".
            if (parts.Length == 2)
            {
                int oldWidth;
                int oldHeight;

                if (!int.TryParse(parts[0], out oldWidth) ||
                    !int.TryParse(parts[1], out oldHeight))
                {
                    return false;
                }

                if (oldWidth < 200 || oldHeight < 200 ||
                    oldWidth > 10000 || oldHeight > 10000)
                {
                    return false;
                }

                x = 0;
                y = 100;
                width = oldWidth;
                height = oldHeight;
                return true;
            }

            // v5 format: "outerX,outerY,clientWidth,clientHeight".
            if (parts.Length != 4)
                return false;

            int parsedX;
            int parsedY;
            int parsedWidth;
            int parsedHeight;

            if (!int.TryParse(parts[0], out parsedX) ||
                !int.TryParse(parts[1], out parsedY) ||
                !int.TryParse(parts[2], out parsedWidth) ||
                !int.TryParse(parts[3], out parsedHeight))
            {
                return false;
            }

            if (parsedX <= -30000 || parsedY <= -30000 ||
                parsedX >= 30000 || parsedY >= 30000 ||
                parsedWidth < 200 || parsedHeight < 200 ||
                parsedWidth > 10000 || parsedHeight > 10000)
            {
                return false;
            }

            x = parsedX;
            y = parsedY;
            width = parsedWidth;
            height = parsedHeight;
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static void TrySaveWindowState(
        string path,
        int x,
        int y,
        int width,
        int height
    )
    {
        try
        {
            File.WriteAllText(
                path,
                x.ToString() + "," +
                y.ToString() + "," +
                width.ToString() + "," +
                height.ToString()
            );
        }
        catch
        {
            // Remembering the window state is optional.
        }
    }

    private static string TryGetForegroundAndroidPackage(
        string baseDir
    )
    {
        string adbExe = Path.Combine(baseDir, "adb.exe");

        if (!File.Exists(adbExe))
            return null;

        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = adbExe,
                Arguments = "shell dumpsys window",
                WorkingDirectory = baseDir,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };

            using (Process p = Process.Start(psi))
            {
                if (p == null)
                    return null;

                string output = p.StandardOutput.ReadToEnd();
                p.WaitForExit(2000);

                if (string.IsNullOrEmpty(output))
                    return null;

                string[] lines = output.Replace("\r", "")
                    .Split('\n');

                // Prefer the actual current focus line.
                foreach (string line in lines)
                {
                    if (line.IndexOf(
                        "mCurrentFocus",
                        StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        string packageName =
                            ExtractPackageFromWindowLine(line);

                        if (!string.IsNullOrEmpty(packageName))
                            return packageName;
                    }
                }

                // Fallback used by some Android/OEM versions.
                foreach (string line in lines)
                {
                    if (line.IndexOf(
                        "mFocusedApp",
                        StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        string packageName =
                            ExtractPackageFromWindowLine(line);

                        if (!string.IsNullOrEmpty(packageName))
                            return packageName;
                    }
                }
            }
        }
        catch
        {
            // If ADB/device is temporarily unavailable, keep a safe fallback.
        }

        return null;
    }

    private static string ExtractPackageFromWindowLine(
        string line
    )
    {
        if (string.IsNullOrEmpty(line))
            return null;

        Match match = Regex.Match(
            line,
            @"([A-Za-z0-9_][A-Za-z0-9._]*)/[A-Za-z0-9_.$]+"
        );

        if (!match.Success || match.Groups.Count < 2)
            return null;

        return match.Groups[1].Value;
    }

    private static string ResolveAndroidAppTitle(
        string baseDir,
        string packageName,
        Dictionary<string, string> appLabelCache,
        string appLabelCachePath
    )
    {
        if (string.IsNullOrEmpty(packageName))
            return WindowTitle;

        string cached;
        if (appLabelCache != null &&
            appLabelCache.TryGetValue(packageName, out cached) &&
            !string.IsNullOrWhiteSpace(cached))
        {
            return cached;
        }

        // First try to resolve the human-readable label directly from Android.
        string label = TryGetAndroidAppLabel(
            baseDir,
            packageName
        );

        // Some ROMs (including this OPPO/Android 13 setup) expose only the
        // package id.  In that case, automatically ask Google Play for the
        // public app title.  No user-maintained package/name table is required.
        if (string.IsNullOrWhiteSpace(label))
        {
            label = TryGetPlayStoreAppLabel(packageName);
        }

        if (string.IsNullOrWhiteSpace(label))
        {
            // Last-resort fallback for sideloaded/system apps that expose no
            // label through ADB and have no Google Play listing.
            return packageName;
        }

        label = label.Trim();

        if (appLabelCache != null)
        {
            appLabelCache[packageName] = label;
            SavePersistentAppLabelCache(
                appLabelCachePath,
                appLabelCache
            );
        }

        return label;
    }

    private static Dictionary<string, string> LoadPersistentAppLabelCache(
        string path
    )
    {
        var result = new Dictionary<string, string>(
            StringComparer.OrdinalIgnoreCase
        );

        try
        {
            if (!File.Exists(path))
                return result;

            foreach (string rawLine in File.ReadAllLines(path, Encoding.UTF8))
            {
                string line = rawLine.Trim();

                if (line.Length == 0 || line.StartsWith("#"))
                    continue;

                int tab = line.IndexOf('\t');
                if (tab <= 0 || tab >= line.Length - 1)
                    continue;

                string packageName =
                    line.Substring(0, tab).Trim();

                string label =
                    line.Substring(tab + 1).Trim();

                if (!Regex.IsMatch(
                    packageName,
                    @"^[A-Za-z0-9_][A-Za-z0-9._]*$"))
                {
                    continue;
                }

                if (string.IsNullOrWhiteSpace(label))
                    continue;

                result[packageName] = label;
            }
        }
        catch
        {
            // A corrupt/missing cache should never stop scrcpy.
        }

        return result;
    }

    private static void SavePersistentAppLabelCache(
        string path,
        Dictionary<string, string> cache
    )
    {
        if (cache == null)
            return;

        try
        {
            var lines = cache
                .OrderBy(pair => pair.Key, StringComparer.OrdinalIgnoreCase)
                .Select(pair =>
                    pair.Key + "\t" +
                    pair.Value.Replace("\r", " ").Replace("\n", " ")
                )
                .ToArray();

            File.WriteAllLines(
                path,
                lines,
                new UTF8Encoding(false)
            );
        }
        catch
        {
            // Cache persistence is optional.
        }
    }

    private static string TryGetAndroidAppLabel(
        string baseDir,
        string packageName
    )
    {
        if (string.IsNullOrWhiteSpace(packageName))
            return null;

        // Package names come from our own foreground-app regex, so this is only
        // a final sanity check before placing the value in an adb command line.
        if (!Regex.IsMatch(
            packageName,
            @"^[A-Za-z0-9_][A-Za-z0-9._]*$"))
        {
            return null;
        }

        // 1) Some Android/OEM package-manager shells expose a direct label command.
        // If present, this is the cleanest path.
        string output = RunAdbCapture(
            baseDir,
            "shell cmd package get-app-label " + packageName,
            2000
        );

        string directLabel = CleanPossibleLabel(output, packageName);
        if (!string.IsNullOrEmpty(directLabel))
            return directLabel;

        // 2) ROMs differ in dumpsys formatting. Try the known human-readable
        // label fields before falling back to the current task description.
        output = RunAdbCapture(
            baseDir,
            "shell dumpsys package " + packageName,
            2500
        );

        string label = ExtractLabelFromPackageDump(output);
        if (!string.IsNullOrEmpty(label))
            return label;

        // 3) The currently visible Android task may expose a resolved task label.
        // This is queried only once per newly-seen app because results are cached.
        output = RunAdbCapture(
            baseDir,
            "shell dumpsys activity activities",
            3000
        );

        label = ExtractCurrentTaskLabel(output, packageName);
        if (!string.IsNullOrEmpty(label))
            return label;

        // 4) Alternate activity dump used by some Android versions/OEM builds.
        output = RunAdbCapture(
            baseDir,
            "shell dumpsys activity top",
            3000
        );

        label = ExtractCurrentTaskLabel(output, packageName);
        if (!string.IsNullOrEmpty(label))
            return label;

        // No hard-coded app-name table and no user-maintained file.
        // If Android does not expose a resolved label for this app, package name
        // is the truthful final fallback.
        return null;
    }

    private static string TryGetPlayStoreAppLabel(
        string packageName
    )
    {
        if (string.IsNullOrWhiteSpace(packageName))
            return null;

        if (!Regex.IsMatch(
            packageName,
            @"^[A-Za-z0-9_][A-Za-z0-9._]*$"))
        {
            return null;
        }

        try
        {
            // .NET Framework on current Windows supports TLS 1.2 here.
            ServicePointManager.SecurityProtocol |=
                SecurityProtocolType.Tls12;

            string url =
                "https://play.google.com/store/apps/details?id=" +
                Uri.EscapeDataString(packageName) +
                "&hl=ja&gl=JP";

            string html;

            using (var client = new WebClient())
            {
                client.Encoding = Encoding.UTF8;
                client.Headers[HttpRequestHeader.UserAgent] =
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
                    "AppleWebKit/537.36 Chrome/120 Safari/537.36";
                client.Headers[HttpRequestHeader.AcceptLanguage] =
                    "ja,en-US;q=0.8,en;q=0.6";

                html = client.DownloadString(url);
            }

            if (string.IsNullOrWhiteSpace(html))
                return null;

            // Open Graph title is much more stable than Play's visual DOM.
            Match match = Regex.Match(
                html,
                @"<meta[^>]+property\s*=\s*[""']og:title[""'][^>]+content\s*=\s*[""']([^""']+)[""']",
                RegexOptions.IgnoreCase
            );

            if (!match.Success)
            {
                // Attribute order may be reversed.
                match = Regex.Match(
                    html,
                    @"<meta[^>]+content\s*=\s*[""']([^""']+)[""'][^>]+property\s*=\s*[""']og:title[""']",
                    RegexOptions.IgnoreCase
                );
            }

            string label = null;

            if (match.Success)
            {
                label = WebUtility.HtmlDecode(
                    match.Groups[1].Value
                );
            }
            else
            {
                // Fallback to <title> if Google changes the meta markup.
                Match titleMatch = Regex.Match(
                    html,
                    @"<title[^>]*>(.*?)</title>",
                    RegexOptions.IgnoreCase |
                    RegexOptions.Singleline
                );

                if (titleMatch.Success)
                {
                    label = WebUtility.HtmlDecode(
                        Regex.Replace(
                            titleMatch.Groups[1].Value,
                            @"\s+",
                            " "
                        )
                    );
                }
            }

            if (string.IsNullOrWhiteSpace(label))
                return null;

            label = CleanGooglePlayTitle(label);

            return IsPlausibleHumanLabel(label, packageName)
                ? label
                : null;
        }
        catch
        {
            // Network failure or a package with no Play Store listing.
            return null;
        }
    }

    private static string CleanGooglePlayTitle(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;

        string result = Regex.Replace(
            value.Trim(),
            @"\s+",
            " "
        );

        string[] suffixes = new[]
        {
            " - Google Play のアプリ",
            " – Google Play のアプリ",
            " - Apps on Google Play",
            " – Apps on Google Play",
            " - Google Play",
            " – Google Play"
        };

        foreach (string suffix in suffixes)
        {
            if (result.EndsWith(
                suffix,
                StringComparison.OrdinalIgnoreCase))
            {
                result = result.Substring(
                    0,
                    result.Length - suffix.Length
                ).Trim();

                break;
            }
        }

        return result;
    }

    private static string RunAdbCapture(
        string baseDir,
        string arguments,
        int timeoutMs
    )
    {
        string adbExe = Path.Combine(baseDir, "adb.exe");

        if (!File.Exists(adbExe))
            return null;

        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = adbExe,
                Arguments = arguments,
                WorkingDirectory = baseDir,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };

            using (Process p = Process.Start(psi))
            {
                if (p == null)
                    return null;

                string stdout = p.StandardOutput.ReadToEnd();
                string stderr = p.StandardError.ReadToEnd();

                if (!p.WaitForExit(timeoutMs))
                {
                    try { p.Kill(); } catch { }
                    return null;
                }

                if (!string.IsNullOrWhiteSpace(stdout))
                    return stdout.Trim();

                if (!string.IsNullOrWhiteSpace(stderr))
                    return stderr.Trim();
            }
        }
        catch
        {
            // ADB may be momentarily busy while scrcpy reconnects.
        }

        return null;
    }

    private static string CleanPossibleLabel(
        string value,
        string packageName
    )
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;

        string line = value
            .Replace("\r", "")
            .Split('\n')
            .Select(s => s.Trim())
            .FirstOrDefault(s => s.Length > 0);

        if (string.IsNullOrWhiteSpace(line))
            return null;

        string lower = line.ToLowerInvariant();

        if (lower.Contains("unknown command") ||
            lower.StartsWith("error") ||
            lower.StartsWith("exception") ||
            lower.StartsWith("securityexception") ||
            lower.StartsWith("usage:") ||
            lower.StartsWith("package manager") ||
            lower.Contains("not found"))
        {
            return null;
        }

        if (string.Equals(
            line,
            packageName,
            StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        // Some implementations prefix the result.
        Match prefixed = Regex.Match(
            line,
            @"^(?:application\s+label|app\s*label|label)\s*[:=]\s*(.+)$",
            RegexOptions.IgnoreCase
        );

        if (prefixed.Success)
            line = prefixed.Groups[1].Value.Trim();

        line = TrimLabelQuotes(line);

        return IsPlausibleHumanLabel(line, packageName)
            ? line
            : null;
    }

    private static string ExtractLabelFromPackageDump(string output)
    {
        if (string.IsNullOrWhiteSpace(output))
            return null;

        string[] patterns = new[]
        {
            @"(?im)^\s*Application\s+Label\s*:\s*(.+?)\s*$",
            @"(?im)^\s*application-label(?:-[A-Za-z0-9_-]+)?\s*:\s*(.+?)\s*$",
            @"(?im)^\s*appLabel\s*=\s*(.+?)\s*$",
            @"(?im)\bnonLocalizedLabel\s*=\s*(.*?)\s+icon=0x[0-9a-f]+"
        };

        foreach (string pattern in patterns)
        {
            Match m = Regex.Match(output, pattern);

            if (!m.Success)
                continue;

            string candidate = TrimLabelQuotes(
                m.Groups[1].Value.Trim()
            );

            if (!string.IsNullOrWhiteSpace(candidate) &&
                !string.Equals(
                    candidate,
                    "null",
                    StringComparison.OrdinalIgnoreCase) &&
                !candidate.StartsWith("0x", StringComparison.OrdinalIgnoreCase))
            {
                return candidate;
            }
        }

        return null;
    }

    private static string ExtractCurrentTaskLabel(
        string output,
        string packageName
    )
    {
        if (string.IsNullOrWhiteSpace(output))
            return null;

        // Prefer a taskDescription near the foreground package occurrence.
        int packageIndex = output.IndexOf(
            packageName,
            StringComparison.OrdinalIgnoreCase
        );

        if (packageIndex >= 0)
        {
            int start = Math.Max(0, packageIndex - 2500);
            int length = Math.Min(
                output.Length - start,
                6000
            );

            string nearby = output.Substring(start, length);

            string candidate =
                ExtractTaskDescriptionLabel(nearby);

            if (!string.IsNullOrEmpty(candidate))
                return candidate;
        }

        // The top/resumed task is usually printed first.
        return ExtractTaskDescriptionLabel(output);
    }

    private static string ExtractTaskDescriptionLabel(string output)
    {
        if (string.IsNullOrWhiteSpace(output))
            return null;

        Match m = Regex.Match(
            output,
            @"taskDescription:\s*label=""([^""]*)""",
            RegexOptions.IgnoreCase
        );

        if (!m.Success)
            return null;

        string label = TrimLabelQuotes(
            m.Groups[1].Value.Trim()
        );

        if (string.IsNullOrWhiteSpace(label) ||
            string.Equals(
                label,
                "null",
                StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return label;
    }

    private static string TrimLabelQuotes(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;

        string result = value.Trim();

        if (result.Length >= 2)
        {
            char first = result[0];
            char last = result[result.Length - 1];

            if ((first == '\'' && last == '\'') ||
                (first == '"' && last == '"'))
            {
                result = result.Substring(
                    1,
                    result.Length - 2
                ).Trim();
            }
        }

        return result;
    }

    private static bool IsPlausibleHumanLabel(
        string value,
        string packageName
    )
    {
        if (string.IsNullOrWhiteSpace(value))
            return false;

        if (value.Length > 200)
            return false;

        if (string.Equals(
            value,
            "null",
            StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        if (string.Equals(
            value,
            packageName,
            StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return true;
    }

    private static void StartBridgeHidden(string baseDir, string bridgePy)
    {
        string args = "-3.11 \"" + bridgePy + "\"";

        var candidates = new[] { "pyw.exe", "py.exe" };

        foreach (string exe in candidates)
        {
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = exe,
                    Arguments = args,
                    WorkingDirectory = baseDir,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden
                };
                Process.Start(psi);
                return;
            }
            catch
            {
                // Try next candidate.
            }
        }

        throw new InvalidOperationException(
            "Python 3.11 を起動できませんでした。py.exe / pyw.exe を確認してください。"
        );
    }

    private static Process WaitForNewScrcpy(HashSet<int> before, TimeSpan timeout)
    {
        DateTime deadline = DateTime.UtcNow + timeout;

        while (DateTime.UtcNow < deadline)
        {
            Process[] list = Process.GetProcessesByName("scrcpy");
            try
            {
                Process candidate = list
                    .Where(p => !before.Contains(p.Id))
                    .OrderByDescending(p =>
                    {
                        try { return p.StartTime; }
                        catch { return DateTime.MinValue; }
                    })
                    .FirstOrDefault();

                if (candidate != null)
                {
                    foreach (Process p in list)
                    {
                        if (p.Id != candidate.Id)
                            p.Dispose();
                    }
                    return candidate;
                }
            }
            catch
            {
                foreach (Process p in list)
                    p.Dispose();
            }

            Thread.Sleep(150);
        }

        return null;
    }

    private static bool IsProcessAlive(int pid)
    {
        try
        {
            using (Process p = Process.GetProcessById(pid))
            {
                // Accessing ProcessName also confirms that the PID still refers
                // to a live process object.
                string name = p.ProcessName;
                return string.Equals(name, "scrcpy", StringComparison.OrdinalIgnoreCase);
            }
        }
        catch (ArgumentException)
        {
            // No process with this PID.
            return false;
        }
        catch (InvalidOperationException)
        {
            return false;
        }
    }

    private static IntPtr FindTopLevelWindow(int pid)
    {
        IntPtr found = IntPtr.Zero;

        EnumWindows((hwnd, lParam) =>
        {
            uint windowPid;
            GetWindowThreadProcessId(hwnd, out windowPid);

            if (windowPid == (uint)pid && IsWindowVisible(hwnd))
            {
                found = hwnd;
                return false;
            }

            return true;
        }, IntPtr.Zero);

        return found;
    }

    private static void ApplyWindowIdentity(IntPtr hwnd, string iconPath)
    {
        SetWindowAppId(hwnd, AppId);
        ApplyWindowAppearance(hwnd);

        HideCaptionIcon(hwnd);
    }

    private static void HideCaptionIcon(IntPtr hwnd)
    {
        try
        {
            // scrcpy/SDL keeps its own window/class icon.
            // Clear BOTH the per-window icons and the window-class icons,
            // then force Windows to rebuild the non-client frame.
            SendMessageW(hwnd, WM_SETICON, (IntPtr)ICON_SMALL, IntPtr.Zero);
            SendMessageW(hwnd, WM_SETICON, (IntPtr)ICON_BIG, IntPtr.Zero);

            SetClassLongPtrW(hwnd, GCLP_HICON, IntPtr.Zero);
            SetClassLongPtrW(hwnd, GCLP_HICONSM, IntPtr.Zero);

            int exStyle = GetWindowLongW(hwnd, GWL_EXSTYLE);
            SetWindowLongW(
                hwnd,
                GWL_EXSTYLE,
                exStyle | WS_EX_DLGMODALFRAME
            );

            SetWindowPos(
                hwnd,
                IntPtr.Zero,
                0,
                0,
                0,
                0,
                SWP_NOMOVE
                | SWP_NOSIZE
                | SWP_NOZORDER
                | SWP_NOACTIVATE
                | SWP_FRAMECHANGED
            );
        }
        catch
        {
            // Cosmetic only.
        }
    }

    private static void ApplyWindowAppearance(IntPtr hwnd)
    {
        try
        {
            // Keep the normal Windows title bar (drag/minimize/maximize/close),
            // but make it visually match the dark Audible window.
            int darkMode = 1;

            // RGB #071822 (COLORREF is 0x00BBGGRR).
            int captionColor = ColorRef(7, 24, 34);
            int borderColor = captionColor;
            int textColor = ColorRef(255, 255, 255);

            DwmSetWindowAttribute(
                hwnd,
                DWMWA_USE_IMMERSIVE_DARK_MODE,
                ref darkMode,
                sizeof(int)
            );

            DwmSetWindowAttribute(
                hwnd,
                DWMWA_CAPTION_COLOR,
                ref captionColor,
                sizeof(int)
            );

            DwmSetWindowAttribute(
                hwnd,
                DWMWA_TEXT_COLOR,
                ref textColor,
                sizeof(int)
            );

            DwmSetWindowAttribute(
                hwnd,
                DWMWA_BORDER_COLOR,
                ref borderColor,
                sizeof(int)
            );
        }
        catch
        {
            // Cosmetic only: never block scrcpy if unsupported.
        }
    }

    private static int ColorRef(byte r, byte g, byte b)
    {
        return r | (g << 8) | (b << 16);
    }

    private static void SetWindowAppId(IntPtr hwnd, string appId)
    {
        Guid iid = typeof(IPropertyStore).GUID;
        IPropertyStore store;

        int hr = SHGetPropertyStoreForWindow(hwnd, ref iid, out store);
        if (hr != 0 || store == null)
            return;

        PROPVARIANT pv = PROPVARIANT.FromString(appId);

        try
        {
            store.SetValue(ref PKEY_AppUserModel_ID, ref pv);
            store.Commit();
        }
        finally
        {
            pv.Clear();
        }
    }

    private static void CreateShortcut(string baseDir, string launcherExe, string iconPath)
    {
        string shortcutPath = Path.Combine(baseDir, "scrcpy_audible.lnk");

        object obj = new CShellLink();
        IShellLinkW link = (IShellLinkW)obj;

        link.SetPath(launcherExe);
        link.SetWorkingDirectory(baseDir);
        link.SetDescription("scrcpy Audible");

        // Taskbar / pinned shortcut icon: use the original scrcpy.exe icon.
        string scrcpyExe = Path.Combine(baseDir, "scrcpy.exe");
        if (File.Exists(scrcpyExe))
            link.SetIconLocation(scrcpyExe, 0);
        else
            link.SetIconLocation(iconPath, 0);

        link.SetShowCmd(SW_SHOWNORMAL);

        IPropertyStore store = (IPropertyStore)obj;
        PROPVARIANT pv = PROPVARIANT.FromString(AppId);

        try
        {
            store.SetValue(ref PKEY_AppUserModel_ID, ref pv);
            store.Commit();

            IPersistFile persist = (IPersistFile)obj;
            persist.Save(shortcutPath, true);
        }
        finally
        {
            pv.Clear();
        }
    }

    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    private delegate bool MonitorEnumProc(
        IntPtr hMonitor,
        IntPtr hdcMonitor,
        ref RECT lprcMonitor,
        IntPtr dwData
    );

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SetCurrentProcessExplicitAppUserModelID(string AppID);

    [DllImport("shell32.dll")]
    private static extern int SHGetPropertyStoreForWindow(
        IntPtr hwnd,
        ref Guid riid,
        [MarshalAs(UnmanagedType.Interface)] out IPropertyStore ppv
    );

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(
        IntPtr hWnd,
        out uint lpdwProcessId
    );

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int nIndex);

    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromWindow(
        IntPtr hwnd,
        uint dwFlags
    );

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool EnumDisplayMonitors(
        IntPtr hdc,
        IntPtr lprcClip,
        MonitorEnumProc lpfnEnum,
        IntPtr dwData
    );

    [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "GetMonitorInfoW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetMonitorInfoExW(
        IntPtr hMonitor,
        ref MONITORINFOEX lpmi
    );

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetWindowRect(
        IntPtr hWnd,
        out RECT lpRect
    );

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool ClientToScreen(
        IntPtr hWnd,
        ref POINT lpPoint
    );

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetClientRect(
        IntPtr hWnd,
        out RECT lpRect
    );

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr LoadImageW(
        IntPtr hInst,
        string name,
        uint type,
        int cx,
        int cy,
        uint fuLoad
    );

    [DllImport("user32.dll")]
    private static extern IntPtr SendMessageW(
        IntPtr hWnd,
        uint Msg,
        IntPtr wParam,
        IntPtr lParam
    );

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowLongW(
        IntPtr hWnd,
        int nIndex
    );

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int SetWindowLongW(
        IntPtr hWnd,
        int nIndex,
        int dwNewLong
    );

    [DllImport("user32.dll", EntryPoint = "SetClassLongPtrW", SetLastError = true)]
    private static extern IntPtr SetClassLongPtrW(
        IntPtr hWnd,
        int nIndex,
        IntPtr dwNewLong
    );

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int X,
        int Y,
        int cx,
        int cy,
        uint uFlags
    );

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetWindowTextW(
        IntPtr hWnd,
        string lpString
    );

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(
        IntPtr hwnd,
        int dwAttribute,
        ref int pvAttribute,
        int cbAttribute
    );

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int MessageBoxW(
        IntPtr hWnd,
        string text,
        string caption,
        uint type
    );

    [DllImport("ole32.dll")]
    private static extern int PropVariantClear(ref PROPVARIANT pvar);

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct MONITORINFOEX
    {
        public int cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string szDevice;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct PROPERTYKEY
    {
        public Guid fmtid;
        public uint pid;

        public PROPERTYKEY(Guid fmtid, uint pid)
        {
            this.fmtid = fmtid;
            this.pid = pid;
        }
    }

    [StructLayout(LayoutKind.Explicit, Size = 16)]
    private struct PROPVARIANT
    {
        [FieldOffset(0)]
        public ushort vt;

        [FieldOffset(8)]
        public IntPtr pointerValue;

        public static PROPVARIANT FromString(string value)
        {
            PROPVARIANT pv = new PROPVARIANT();
            pv.vt = 31; // VT_LPWSTR
            pv.pointerValue = Marshal.StringToCoTaskMemUni(value);
            return pv;
        }

        public void Clear()
        {
            PropVariantClear(ref this);
        }
    }

    [ComImport]
    [Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IPropertyStore
    {
        void GetCount(out uint cProps);
        void GetAt(uint iProp, out PROPERTYKEY pkey);
        void GetValue(ref PROPERTYKEY key, out PROPVARIANT pv);
        void SetValue(ref PROPERTYKEY key, ref PROPVARIANT pv);
        void Commit();
    }

    [ComImport]
    [Guid("00021401-0000-0000-C000-000000000046")]
    private class CShellLink
    {
    }

    [ComImport]
    [Guid("000214F9-0000-0000-C000-000000000046")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IShellLinkW
    {
        void GetPath(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile,
            int cchMaxPath,
            IntPtr pfd,
            uint fFlags
        );

        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);

        void GetDescription(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName,
            int cchMaxName
        );

        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);

        void GetWorkingDirectory(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir,
            int cchMaxPath
        );

        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);

        void GetArguments(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs,
            int cchMaxPath
        );

        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);

        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(uint iShowCmd);

        void GetIconLocation(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath,
            int cchIconPath,
            out int piIcon
        );

        void SetIconLocation(
            [MarshalAs(UnmanagedType.LPWStr)] string pszIconPath,
            int iIcon
        );

        void SetRelativePath(
            [MarshalAs(UnmanagedType.LPWStr)] string pszPathRel,
            uint dwReserved
        );

        void Resolve(IntPtr hwnd, uint fFlags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }
}
