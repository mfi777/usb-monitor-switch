Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class MonitorControl
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct PHYSICAL_MONITOR
    {
        public IntPtr hPhysicalMonitor;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szPhysicalMonitorDescription;
    }

    public delegate bool MonitorEnumProc(
        IntPtr hMonitor,
        IntPtr hdcMonitor,
        IntPtr lprcMonitor,
        IntPtr dwData
    );

    [DllImport("user32.dll")]
    public static extern bool EnumDisplayMonitors(
        IntPtr hdc,
        IntPtr lprcClip,
        MonitorEnumProc lpfnEnum,
        IntPtr dwData
    );

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(
        IntPtr hMonitor,
        out uint pdwNumberOfPhysicalMonitors
    );

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool GetPhysicalMonitorsFromHMONITOR(
        IntPtr hMonitor,
        uint dwPhysicalMonitorArraySize,
        [Out] PHYSICAL_MONITOR[] pPhysicalMonitorArray
    );

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool SetVCPFeature(
        IntPtr hMonitor,
        byte bVCPCode,
        uint dwNewValue
    );

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool DestroyPhysicalMonitor(
        IntPtr hMonitor
    );
}
"@

switch ($env:COMPUTERNAME.ToUpper()) {

    "IT-PC20DAZE" {
        $TargetValue = [uint32]17
        $TargetName  = "HDMI1"
    }

    "WIN2O5" {
        $TargetValue = [uint32]15
        $TargetName  = "DP"
    }

    default {
        exit 1
    }
}

$Callback = {

    param(
        [IntPtr]$hMonitor,
        [IntPtr]$hdcMonitor,
        [IntPtr]$lprcMonitor,
        [IntPtr]$dwData
    )

    $count = [uint32]0

    if (-not [MonitorControl]::GetNumberOfPhysicalMonitorsFromHMONITOR(
        $hMonitor,
        [ref]$count
    )) {
        return $true
    }

    $monitors = New-Object MonitorControl+PHYSICAL_MONITOR[] $count

    if (-not [MonitorControl]::GetPhysicalMonitorsFromHMONITOR(
        $hMonitor,
        $count,
        $monitors
    )) {
        return $true
    }

    foreach ($monitor in $monitors) {

        [MonitorControl]::SetVCPFeature(
            $monitor.hPhysicalMonitor,
            0x60,
            $TargetValue
        ) | Out-Null

        [MonitorControl]::DestroyPhysicalMonitor(
            $monitor.hPhysicalMonitor
        ) | Out-Null
    }

    return $true

}.GetNewClosure()

[MonitorControl]::EnumDisplayMonitors(
    [IntPtr]::Zero,
    [IntPtr]::Zero,
    $Callback,
    [IntPtr]::Zero
) | Out-Null