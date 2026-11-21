# Windows standalone replay. The player must keep keyboard focus throughout the run.
param(
    [ValidateSet('accord', 'pursuit')]
    [string]$Route = 'accord',
    [ValidateSet(720, 1080)]
    [int]$Height = 720,
    [string]$Player = (Join-Path $PSScriptRoot '../../Builds/Windows/Kinsei.exe'),
    [string]$Log = (Join-Path ([IO.Path]::GetTempPath()) ("Kinsei-{0}-{1:yyyyMMdd-HHmmssfff}.log" -f $Route, (Get-Date)))
)
$ErrorActionPreference = 'Stop'
$Player = (Resolve-Path -LiteralPath $Player).Path
$Log = [IO.Path]::GetFullPath($Log)
if (Test-Path -LiteralPath $Log) { throw "Choose a new log path: $Log" }
if (-not ('KinseiQaKeys' -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class KinseiQaKeys {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint kind);
    [DllImport("user32.dll")] public static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
}
"@
}
$width = if ($Height -eq 720) { 1280 } else { 1920 }
$arguments = "-screen-fullscreen 0 -screen-width $width -screen-height $Height -kinsei-metrics -logFile `"$Log`""
$game = Start-Process -FilePath $Player -ArgumentList $arguments -PassThru
function Wait-EventLine([string]$Phrase, [int]$Timeout = 6) {
    $deadline = (Get-Date).AddSeconds($Timeout)
    do {
        if ($game.HasExited) { throw "The player exited. See $Log" }
        if ((Test-Path -LiteralPath $Log) -and (Select-String -LiteralPath $Log -SimpleMatch $Phrase -Quiet)) { return }
        Start-Sleep -Milliseconds 50
    } while ((Get-Date) -lt $deadline)
    throw "Timed out waiting for '$Phrase'. See $Log"
}
function Press([byte]$Key, [int]$Milliseconds = 100) {
    if ([KinseiQaKeys]::GetForegroundWindow() -ne $game.MainWindowHandle) { throw 'The game lost keyboard focus.' }
    $scan = [KinseiQaKeys]::MapVirtualKey($Key, 0)
    [KinseiQaKeys]::keybd_event($Key, $scan, 0, [UIntPtr]::Zero)
    try { Start-Sleep -Milliseconds $Milliseconds }
    finally { [KinseiQaKeys]::keybd_event($Key, $scan, 2, [UIntPtr]::Zero) }
    Start-Sleep -Milliseconds 80
}
function Fire-AtSelected {
    foreach ($shot in 1..4) {
        Press 32
        Start-Sleep -Milliseconds 235
    }
}
try {
    Wait-EventLine 'UnloadTime:' 40
    Start-Sleep -Milliseconds 800
    $game.Refresh()
    [void][KinseiQaKeys]::SetForegroundWindow($game.MainWindowHandle)
    Start-Sleep -Milliseconds 200
    Press 13
    Wait-EventLine 'KINSEI start' 15
    Start-Sleep -Seconds 1
    Press 9
    Wait-EventLine 'KINSEI RTS'
    Press ([byte][char]'1')
    Press ([byte][char]'E')
    Wait-EventLine 'order-0-Attend'
    if ($Route -eq 'pursuit') {
        Press ([byte][char]'2')
        Press ([byte][char]'G')
        Wait-EventLine 'order-1-Guard'
    }
    Press 9
    Wait-EventLine 'KINSEI TPS'
    Press ([byte][char]'W') 3550
    Wait-EventLine 'phase-Floor'
    foreach ($target in 1..3) {
        Press ([byte][char]'Q')
        Fire-AtSelected
    }
    Wait-EventLine 'phase-Choice'
    if ($Route -eq 'accord') {
        Press 9
        Start-Sleep -Milliseconds 300
        Press 9
        Press ([byte][char]'W') 920
        Press ([byte][char]'E')
        Wait-EventLine 'KINSEI escort'
        Press ([byte][char]'A') 1200
        Press ([byte][char]'S') 830
        Press ([byte][char]'E')
        Wait-EventLine 'phase-Mirror'
    } else {
        Press ([byte][char]'W') 2540
        Press ([byte][char]'D') 620
        Press ([byte][char]'E')
        Start-Sleep -Milliseconds 400
        Press ([byte][char]'E')
        Wait-EventLine 'phase-Chase'
        Press ([byte][char]'Q')
        Fire-AtSelected
    }
    Wait-EventLine "ending-$Route" 65
    Wait-EventLine 'KINSEI_FRAME'
    (Select-String -LiteralPath $Log -SimpleMatch 'KINSEI_FRAME').Line
    Write-Output "Player log: $Log"
} finally {
    if (-not $game.HasExited) { [void]$game.CloseMainWindow() }
    $game.Dispose()
}

