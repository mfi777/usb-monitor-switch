# usb-monitor-switch

Turn a simple USB sharing switch into a lightweight KVM-style setup by automatically switching your monitor input when the USB devices move between computers.

`usb-monitor-switch` uses PowerShell and the Windows DDC/CI API to detect when a shared USB hub becomes available on a computer and then switches the monitor to the input assigned to that computer.

No additional monitor-control software is required.

## How it works

The setup assumes two computers share the same:

- Monitor
- Keyboard
- Mouse
- USB sharing switch

Example:

```text
                ┌───────────────┐
PC 1 ── HDMI ──▶│               │
                │    Monitor    │
PC 2 ── DP ────▶│               │
                └───────────────┘

PC 1 ────────┐
             │
             ▼
       ┌─────────────┐
       │ USB Sharing │──── Keyboard
       │   Switch    │──── Mouse
       └─────────────┘
             ▲
             │
PC 2 ────────┘
```

When the button on the USB sharing switch is pressed:

```text
USB switches to PC 2
        ↓
Windows detects the shared USB hub
        ↓
PowerShell detects that the hub appeared
        ↓
Monitor input is changed through DDC/CI
        ↓
Monitor switches to PC 2
```

This effectively turns a basic USB sharing switch into a simple KVM-like solution.

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or newer
- A monitor supporting DDC/CI
- A USB sharing switch
- Both computers connected to different monitor inputs

Tested with:

- Dell S2721DGF
- UGREEN USB Sharing Switch 2 in 4 out, Model US216

Other monitors and USB switches should also work if they expose similar functionality.

## Files

### `usb-watch.ps1`

Continuously checks whether the shared USB hub is connected to the current computer.

When the hub changes from disconnected to connected, it launches `monitor-input.ps1`.

### `monitor-input.ps1`

Uses the Windows `Dxva2.dll` DDC/CI API to send VCP commands directly to the monitor.

VCP code:

```text
0x60 = Input Source
```

Typical input values:

| Input | VCP value |
|---|---:|
| DisplayPort 1 | 15 |
| DisplayPort 2 | 16 |
| HDMI 1 | 17 |
| HDMI 2 | 18 |

Values may vary between monitor models.

## Configuration

The monitor input is selected based on the Windows computer name.

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
PC-ONE → HDMI1
PC-TWO → DisplayPort
```

Change the computer names and VCP values to match your setup.

You can check the current computer name with:

```powershell
$env:COMPUTERNAME
```

## Finding the USB device

The watcher needs an identifiable USB device that appears when the USB sharing switch connects to the computer.

List currently connected USB and HID devices:

```powershell
Get-PnpDevice -PresentOnly |
Where-Object {
    $_.Class -in @("HIDClass","Keyboard","Mouse","USB")
} |
Select-Object Status, Class, FriendlyName, InstanceId
```

Run the command before and after switching the USB sharing switch.

Look for a device that disappears when the switch moves away and reappears when it returns.

For example:

```text
USB\VID_05E3&PID_0610
```

Configure this in `usb-watch.ps1`:

```powershell
$DevicePattern = "USB\VID_05E3&PID_0610*"
```

## Running manually

Start the watcher with:

```powershell
powershell.exe -ExecutionPolicy Bypass -File C:\Scripts\usb-watch.ps1
```

Leave the PowerShell window open and press the button on the USB switch.

When the shared USB hub appears on the computer, the monitor should automatically switch to that computer's video input.

## Start automatically at logon

You can create a Scheduled Task so the watcher starts automatically when the user logs in.

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
    -Description "Monitors the shared USB hub and switches the monitor input automatically."
```

Check the task:

```powershell
Get-ScheduledTask -TaskName "USB Monitor Switch"
```

Start it manually:

```powershell
Start-ScheduledTask -TaskName "USB Monitor Switch"
```

Check its status:

```powershell
Get-ScheduledTaskInfo -TaskName "USB Monitor Switch"
```

## Notes

This project does not control the USB sharing switch itself.

Instead, it detects when the shared USB devices become available on a computer and uses that event to switch the monitor input.

The result is similar to a KVM switch:

```text
One physical button
       ↓
USB changes computer
       ↓
Monitor follows automatically
```

## Security

No third-party monitor control utility is required.

Monitor switching is performed directly through the Windows DDC/CI API using:

```text
Dxva2.dll
```

This keeps the solution self-contained and makes the complete PowerShell implementation auditable.

## Limitations

- The monitor must support DDC/CI.
- VCP input values may differ between monitor manufacturers.
- Some monitors may not expose input switching correctly through DDC/CI.
- The USB device identifier must be adjusted to match the user's USB switch or connected hub.
- The watcher currently polls for the USB device instead of using a native PnP event subscription.

## Tested hardware

| Device | Model |
|---|---|
| Monitor | Dell S2721DGF |
| USB sharing switch | UGREEN US216 |
| Operating system | Windows |

## License

Use, modify, and distribute as you see fit.
