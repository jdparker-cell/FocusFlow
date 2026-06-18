param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("start", "focus-reels", "stop")]
    [string]$Action
)

$ErrorActionPreference = "Stop"
$statePath = Join-Path $PSScriptRoot "window-state.json"

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class FocusFlowNative {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr processId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool attach);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd,
        uint Msg,
        IntPtr wParam,
        IntPtr lParam,
        uint flags,
        uint timeout,
        out IntPtr result
    );

    public static void SendMediaCommand(IntPtr target, int command) {
        if (target == IntPtr.Zero || !IsWindow(target)) return;
        const uint WM_APPCOMMAND = 0x0319;
        IntPtr result;
        SendMessageTimeout(
            target,
            WM_APPCOMMAND,
            IntPtr.Zero,
            new IntPtr(command << 16),
            0x0002,
            1000,
            out result
        );
    }

    public static void Activate(IntPtr target) {
        if (target == IntPtr.Zero || !IsWindow(target)) return;

        IntPtr foreground = GetForegroundWindow();
        uint currentThread = GetCurrentThreadId();
        uint targetThread = GetWindowThreadProcessId(target, IntPtr.Zero);
        uint foregroundThread = foreground == IntPtr.Zero
            ? 0
            : GetWindowThreadProcessId(foreground, IntPtr.Zero);

        try {
            if (foregroundThread != 0 && foregroundThread != currentThread)
                AttachThreadInput(currentThread, foregroundThread, true);
            if (targetThread != 0 && targetThread != currentThread)
                AttachThreadInput(currentThread, targetThread, true);

            ShowWindowAsync(target, 3);
            BringWindowToTop(target);
            SetForegroundWindow(target);
        }
        finally {
            if (targetThread != 0 && targetThread != currentThread)
                AttachThreadInput(currentThread, targetThread, false);
            if (foregroundThread != 0 && foregroundThread != currentThread)
                AttachThreadInput(currentThread, foregroundThread, false);
        }
    }
}
"@

if ($Action -eq "start") {
    $window = [FocusFlowNative]::GetForegroundWindow()
    if ($window -eq [IntPtr]::Zero) {
        throw "Could not identify the active prompt window."
    }

    $spotifyWindow = Get-Process -Name "Spotify" -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Select-Object -First 1

    @{
        hwnd = $window.ToInt64()
        spotifyDesktopHwnd = if ($spotifyWindow) {
            $spotifyWindow.MainWindowHandle.ToInt64()
        } else {
            0
        }
        capturedAt = (Get-Date).ToUniversalTime().ToString("o")
    } | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8

    if ($spotifyWindow) {
        [FocusFlowNative]::SendMediaCommand($spotifyWindow.MainWindowHandle, 47)
    }
    exit 0
}

if ($Action -eq "focus-reels") {
    $chromeWindow = Get-Process -Name "chrome" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.MainWindowHandle -ne 0 -and
            $_.MainWindowTitle -match "Instagram|Reels"
        } |
        Select-Object -First 1

    if (-not $chromeWindow) {
        $chromeWindow = Get-Process -Name "chrome" -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne 0 } |
            Select-Object -First 1
    }

    if ($chromeWindow) {
        [FocusFlowNative]::Activate($chromeWindow.MainWindowHandle)
    }
    exit 0
}

if (-not (Test-Path -LiteralPath $statePath)) {
    exit 0
}

$saved = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
[long]$spotifyDesktopHwnd = if ($saved.spotifyDesktopHwnd) {
    $saved.spotifyDesktopHwnd
} else {
    0
}

if ($spotifyDesktopHwnd -ne 0) {
    [FocusFlowNative]::SendMediaCommand([IntPtr]::new($spotifyDesktopHwnd), 46)
}

$chromeWindow = Get-Process -Name "chrome" -ErrorAction SilentlyContinue |
    Where-Object {
        $_.MainWindowHandle -ne 0 -and
        $_.MainWindowTitle -match "Instagram|Reels"
    } |
    Select-Object -First 1
if ($chromeWindow) {
    [FocusFlowNative]::SendMediaCommand($chromeWindow.MainWindowHandle, 47)
}

[FocusFlowNative]::Activate([IntPtr]::new([long]$saved.hwnd))
