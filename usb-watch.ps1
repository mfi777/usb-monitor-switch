$DevicePattern = "USB\VID_05E3&PID_0610*"
$MonitorScript = "C:\Scripts\monitor-input.ps1"

function Test-UgreenConnected {

    $device = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object {
            $_.InstanceId -like $DevicePattern
        } |
        Select-Object -First 1

    return ($null -ne $device)
}

$WasConnected = Test-UgreenConnected

while ($true) {

    Start-Sleep -Milliseconds 750

    $IsConnected = Test-UgreenConnected

    if ($IsConnected -and -not $WasConnected) {

        Start-Sleep -Milliseconds 500

        & $MonitorScript
    }

    $WasConnected = $IsConnected
}