$ErrorActionPreference = "Stop"

$BaseDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$VbsPath  = Join-Path $BaseDir "scrcpy-noconsole.vbs"
$Bridge   = Join-Path $BaseDir "scrcpy_media_bridge.py"
$Scrcpy   = Join-Path $BaseDir "scrcpy.exe"
$Icon     = Join-Path $BaseDir "scrcpy_audible.ico"
$CsPath   = Join-Path $BaseDir "scrcpy_space_hotkey.cs"
$Helper   = Join-Path $BaseDir "scrcpy_space_hotkey.exe"

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Write-Host ""
    exit 1
}

if (-not (Test-Path $VbsPath)) { Fail "scrcpy-noconsole.vbs がありません: $VbsPath" }
if (-not (Test-Path $Bridge))  { Fail "scrcpy_media_bridge.py がありません: $Bridge" }
if (-not (Test-Path $Scrcpy))  { Fail "scrcpy.exe がありません: $Scrcpy" }

$bridgeText = [IO.File]::ReadAllText($Bridge)
if ($bridgeText -notmatch "scrcpy_audible_space_command\.txt" -or
    $bridgeText -notmatch "poll_hotkey_commands") {
    Fail "現在の scrcpy_media_bridge.py は command-file 方式に対応していません。"
}

$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) {
    $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe"
}
if (-not (Test-Path $csc)) {
    Fail "Windows C# compiler (csc.exe) が見つかりません。"
}

Write-Host "Closing scrcpy..." -ForegroundColor Cyan
Get-Process "scrcpy" -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process "scrcpy_space_hotkey" -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupVbs = "$VbsPath.$stamp.bak"
Copy-Item $VbsPath $backupVbs -Force

$helperSource = @'
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
'@

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[IO.File]::WriteAllText($CsPath, $helperSource, $utf8Bom)

Write-Host "Building standalone Space helper..." -ForegroundColor Cyan

$compileArgs = @(
    "/nologo",
    "/target:winexe",
    "/platform:anycpu",
    "/optimize+",
    "/out:$Helper"
)

if (Test-Path $Icon) {
    $compileArgs += "/win32icon:$Icon"
}

$compileArgs += $CsPath

& $csc $compileArgs

if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Helper)) {
    Fail "Space helper のビルドに失敗しました。既存ファイルは変更していません。"
}

# Replace ONLY the tiny VBS used to launch scrcpy.
# The original is already backed up above.
$vbs = @'
Set shell = CreateObject("Wscript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
shell.CurrentDirectory = baseDir

' Start the AHK-free Space helper hidden.
shell.Run """" & baseDir & "\scrcpy_space_hotkey.exe""", 0, False

' Start scrcpy hidden, preserving every argument supplied by the existing launcher.
strCommand = """" & baseDir & "\scrcpy.exe"""

For Each Arg In WScript.Arguments
    strCommand = strCommand & " """ & Replace(Arg, """", """""""""") & """"
Next

shell.Run strCommand, 0, False
'@

[IO.File]::WriteAllText($VbsPath, $vbs, $utf8Bom)

Write-Host ""
Write-Host "SUCCESS" -ForegroundColor Green
Write-Host ""
Write-Host "変更した既存ファイルは scrcpy-noconsole.vbs だけです。"
Write-Host "元のVBS: $backupVbs"
Write-Host ""
Write-Host "scrcpy_audible_launcher.cs / exe は変更していません。"
Write-Host ""
Write-Host "TEST:"
Write-Host "  1. AutoHotkey を終了"
Write-Host "  2. いつもの scrcpy_audible_launcher.exe を起動"
Write-Host "  3. scrcpy ウィンドウを前面にする"
Write-Host "  4. Space で Audible の再生/停止"
Write-Host "  5. APEX に戻ると Space hotkey は解除"
Write-Host ""
