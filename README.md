# usb-monitor-switch

Turn a basic USB sharing switch into a lightweight KVM-style setup.

`usb-monitor-switch` automatically changes your monitor input when your USB devices are switched between two Windows computers.

It uses:

- PowerShell
- Windows Plug and Play device detection
- DDC/CI monitor control
- The built-in Windows `Dxva2.dll` API

No third-party monitor-control software is required.

## Features

- Automatically follows your USB sharing switch
- Switches between HDMI and DisplayPort
- Uses the monitor's native DDC/CI interface
- No additional executables or drivers
- Works with ordinary USB sharing switches
- Can run automatically at Windows logon
- Fully implemented in PowerShell

## How it works

A typical setup looks like this:

```text
                    ┌───────────────┐
PC 1 ─── HDMI ────> │               │
                    │    Monitor    │
PC 2 ─── DP  ─────> │               │
                    └───────────────┘

PC 1 ──────────┐
               │
               ▼
         ┌─────────────┐
         │ USB Sharing │──── Keyboard
         │   Switch    │──── Mouse
         └─────────────┘
               ▲
               │
PC 2 ──────────┘
```

When the physical button on the USB sharing switch is pressed:

```text
USB devices move to the other PC
            ↓
Windows detects the shared USB hub
            ↓
usb-watch.ps1 detects the connection
            ↓
monitor-input.ps1 is started
            ↓
The monitor input is changed through DDC/CI
```

The result is similar to a traditional KVM switch, even though the USB switch itself does not handle video.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or newer
- A monitor with DDC/CI support
- Two computers connected to different monitor inputs
- A USB sharing switch or similar device
- A USB device or hub that appears/disappears when switching computers

## Tested hardware

The project was initially tested with:

| Device | Model |
|---|---|
| Monitor | Dell S2721DGF |
| USB sharing switch | UGREEN US216 |
| Video inputs | HDMI 1 + DisplayPort |
| Operating system | Windows |

The scripts are not tied specifically to this hardware.

Other USB switches and DDC/CI-compatible monitors should work after adjusting the configuration.

## Project files

### `usb-watch.ps1`

Monitors whether the shared USB hub is connected to the current computer.

When the device changes from disconnected to connected, the script launches:

```text
monitor-input.ps1
```

### `monitor-input.ps1`

Uses the Windows DDC/CI API to change the active monitor input.

Monitor input selection is controlled using VCP code:

```text
0x60 = Input Source
```

Typical VCP values are:

| Input | Value |
|---|---:|
| DisplayPort 1 | 15 |
| DisplayPort 2 | 16 |
| HDMI 1 | 17 |
| HDMI 2 | 18 |

These values are common but may differ depending on the monitor.

## Installation

Create a directory for the scripts:

```powershell
New-Item -ItemType Directory -Path C:\Scripts -Force
```

Place the following files in the directory:

```text
C:\Scripts\usb-watch.ps1
C:\Scripts\monitor-input.ps1
```

## Configure monitor inputs

`monitor-input.ps1` determines which monitor input belongs to each computer based on its Windows computer name.

Example:

```powershell
switch ($env:COMPUTERNAME.ToUpper()) {

    "PC-ONE" {
        $TargetValue = [uint32]17
        $TargetName  = "HDMI1"
    }

    "PC-TWO" {
        $TargetValue = [uint32]15
        $TargetName  = "DP"
    }

    default {
        exit 1
    }
}
```

In this example:

```text
PC-ONE → HDMI 1
PC-TWO → DisplayPort
```

Check the current computer name with:

```powershell
$env:COMPUTERNAME
```

Adjust the computer names and VCP values to match your setup.

## Find the USB trigger device

The watcher needs a USB device that appears when the sharing switch connects to the computer.

Run:

```powershell
Get-PnpDevice -PresentOnly |
Where-Object {
    $_.Class -in @("HIDClass","Keyboard","Mouse","USB")
} |
Select-Object Status, Class, FriendlyName, InstanceId
```

Run it once while the USB switch is connected to the computer.

Then switch USB to the other computer and run it again.

Look for a device that disappears and reappears consistently.

For example:

```text
USB\VID_05E3&PID_0610
```

Configure that device in `usb-watch.ps1`:

```powershell
$DevicePattern = "USB\VID_05E3&PID_0610*"
```

A USB hub is often a better trigger than a keyboard or mouse because it represents the complete switched USB connection.

## Test manually

Start the watcher:

```powershell
powershell.exe -ExecutionPolicy Bypass -File C:\Scripts\usb-watch.ps1
```

Leave the PowerShell window running.

Switch USB to the other computer and back again.

When the USB hub appears on the current computer, the monitor should automatically switch to that computer's configured video input.

## Start automatically at logon

Create a Scheduled Task:

```powershell
$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Scripts\usb-watch.ps1"'

$Trigger = New-ScheduledTaskTrigger -AtLogOn

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask `
    -TaskName "USB Monitor Switch" `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Description "Automatically switches monitor input when the USB sharing switch changes computer."
```

Check the task:

```powershell
Get-ScheduledTask -TaskName "USB Monitor Switch"
```

Start it manually:

```powershell
Start-ScheduledTask -TaskName "USB Monitor Switch"
```

Check runtime information:

```powershell
Get-ScheduledTaskInfo -TaskName "USB Monitor Switch"
```

## DDC/CI

Monitor switching is performed directly through Windows using:

```text
Dxva2.dll
```

The script calls the Windows physical monitor API and sends VCP command `0x60` to change the active input source.

This avoids dependencies such as third-party monitor-control utilities.

Your monitor may also require DDC/CI to be enabled in its on-screen settings.

## Troubleshooting

### The USB device is not detected

Check whether the configured device is currently present:

```powershell
Get-PnpDevice -PresentOnly |
Where-Object {
    $_.InstanceId -like "USB\VID_05E3&PID_0610*"
}
```

If nothing is returned, verify the correct USB VID/PID for your hardware.

### The script runs but the monitor does not switch

Possible causes include:

- DDC/CI is disabled in the monitor menu
- The monitor does not support input switching through DDC/CI
- The configured VCP value is incorrect
- The selected monitor is not the expected physical monitor

Try testing the common VCP values:

```text
15 = DisplayPort 1
16 = DisplayPort 2
17 = HDMI 1
18 = HDMI 2
```

### The wrong input is selected

Update the computer-to-input mapping inside `monitor-input.ps1`.

### The watcher only works on one computer

`usb-watch.ps1` must run on both computers.

Each computer reacts when the shared USB hub becomes connected to it.

## Limitations

- DDC/CI behavior varies between monitor manufacturers.
- VCP input values are not guaranteed to be identical across all monitors.
- The watcher currently polls the USB device state periodically.
- Multiple matching monitors may require additional monitor-selection logic.
- The USB switch itself is not controlled by the script.

## Security

The project does not require additional monitor-control executables.

All monitor control is performed using native Windows APIs, and the complete PowerShell implementation can be reviewed directly.

## License

Consider adding an MIT license if you intend to publish or distribute the project publicly.
