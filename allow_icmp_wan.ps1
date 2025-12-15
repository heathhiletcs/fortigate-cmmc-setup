$port = New-Object System.IO.Ports.SerialPort
$port.PortName = 'COM3'
$port.BaudRate = 9600
$port.Parity = 'None'
$port.DataBits = 8
$port.StopBits = 'One'
$port.Handshake = 'None'
$port.ReadTimeout = 3000
$port.WriteTimeout = 3000
$port.NewLine = "`r`n"

function Send-Command {
    param($command, [switch]$NoWait)

    Write-Host ">>> $command" -ForegroundColor Yellow
    $port.WriteLine($command)

    if (-not $NoWait) {
        Start-Sleep -Milliseconds 800

        try {
            $port.ReadTimeout = 1000
            $response = $port.ReadExisting()
            if ($response) {
                Write-Host $response -ForegroundColor Gray
            }
        } catch {}
    } else {
        Start-Sleep -Milliseconds 200
    }
}

try {
    Write-Host 'Opening COM3...' -ForegroundColor Green
    $port.Open()
    Start-Sleep -Seconds 1
    try { $port.ReadExisting() | Out-Null } catch {}

    Write-Host "`n=== Creating firewall address object ===" -ForegroundColor Cyan
    Send-Command "config firewall address" -NoWait
    Send-Command "edit `"ISP-Network-204.186.63.0`"" -NoWait
    Send-Command "set subnet 204.186.63.0 255.255.255.192" -NoWait
    Send-Command "set comment `"ISP ICMP monitoring subnet`"" -NoWait
    Send-Command "next" -NoWait
    Send-Command "end"

    Write-Host "`n=== Creating firewall policy for ICMP ===" -ForegroundColor Cyan
    Send-Command "config firewall policy"
    Start-Sleep -Milliseconds 500
    Send-Command "edit 0"
    Start-Sleep -Milliseconds 500

    # Configure the policy
    Send-Command "set name `"Allow-ICMP-to-ISP-Network`"" -NoWait
    Send-Command "set srcintf `"internal1.4`" `"internal1.3`" `"internal1.5`" `"internal1.6`" `"dmz`"" -NoWait
    Send-Command "set dstintf `"wan1.847`"" -NoWait
    Send-Command "set srcaddr `"all`"" -NoWait
    Send-Command "set dstaddr `"ISP-Network-204.186.63.0`"" -NoWait
    Send-Command "set action accept" -NoWait
    Send-Command "set schedule `"always`"" -NoWait
    Send-Command "set service `"PING`"" -NoWait
    Send-Command "set nat enable" -NoWait
    Send-Command "set comments `"Allow ICMP to ISP monitoring network`"" -NoWait
    Send-Command "next" -NoWait
    Send-Command "end"

    Write-Host "`n=== Verifying configuration ===" -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    Send-Command "show firewall address ISP-Network-204.186.63.0"
    Start-Sleep -Seconds 1

    # Show the newly created policy
    Send-Command "show firewall policy | grep -f Allow-ICMP"

    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "ICMP policy configuration complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($port.IsOpen) {
        $port.Close()
        Write-Host "`nPort closed" -ForegroundColor Green
    }
}
