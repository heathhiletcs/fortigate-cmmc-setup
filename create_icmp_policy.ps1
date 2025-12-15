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

function Wait-ForPrompt {
    param([int]$timeout = 3000)
    $port.ReadTimeout = $timeout
    $response = ""
    try {
        $response = $port.ReadExisting()
    } catch {}
    return $response
}

try {
    Write-Host 'Opening COM3...' -ForegroundColor Green
    $port.Open()
    Start-Sleep -Seconds 1

    # Send enter and wait for response
    $port.WriteLine('')
    Start-Sleep -Seconds 2
    $response = Wait-ForPrompt

    Write-Host "Initial response: $response" -ForegroundColor Gray

    # Handle login if needed
    if ($response -match "login:") {
        Write-Host "Logging in..." -ForegroundColor Cyan
        $port.WriteLine('admin')
        Start-Sleep -Seconds 1
        Wait-ForPrompt | Out-Null

        $port.WriteLine('GWMObv1Y7m_wiP!-')
        Start-Sleep -Seconds 2
        $response = Wait-ForPrompt
    }

    # Handle login banner - press 'a' to accept
    if ($response -match "Press 'a' to accept") {
        Write-Host "Accepting login banner..." -ForegroundColor Cyan
        $port.Write('a')
        Start-Sleep -Seconds 2
        Wait-ForPrompt | Out-Null
    }

    Write-Host "`n=== Creating firewall address object ===" -ForegroundColor Cyan

    $port.WriteLine('config firewall address')
    Start-Sleep -Milliseconds 500

    $port.WriteLine('edit "ISP-Network-204.186.63.0"')
    Start-Sleep -Milliseconds 500

    $port.WriteLine('set subnet 204.186.63.0 255.255.255.192')
    Start-Sleep -Milliseconds 500

    $port.WriteLine('set comment "ISP ICMP monitoring subnet"')
    Start-Sleep -Milliseconds 500

    $port.WriteLine('next')
    Start-Sleep -Milliseconds 500

    $port.WriteLine('end')
    Start-Sleep -Seconds 1
    $response = Wait-ForPrompt
    Write-Host $response -ForegroundColor Gray

    Write-Host "`n=== Creating firewall policy ===" -ForegroundColor Cyan

    $port.WriteLine('config firewall policy')
    Start-Sleep -Milliseconds 500

    $port.WriteLine('edit 0')
    Start-Sleep -Milliseconds 500

    $port.WriteLine('set name "Allow-ICMP-to-ISP-Network"')
    Start-Sleep -Milliseconds 300

    $port.WriteLine('set srcintf "internal1.4" "internal1.3" "internal1.5" "internal1.6" "dmz"')
    Start-Sleep -Milliseconds 300

    $port.WriteLine('set dstintf "wan1.847"')
    Start-Sleep -Milliseconds 300

    $port.WriteLine('set srcaddr "all"')
    Start-Sleep -Milliseconds 300

    $port.WriteLine('set dstaddr "ISP-Network-204.186.63.0"')
    Start-Sleep -Milliseconds 300

    $port.WriteLine('set action accept')
    Start-Sleep -Milliseconds 300

    $port.WriteLine('set schedule "always"')
    Start-Sleep -Milliseconds 300

    $port.WriteLine('set service "PING"')
    Start-Sleep -Milliseconds 300

    $port.WriteLine('set nat enable')
    Start-Sleep -Milliseconds 300

    $port.WriteLine('set comments "Allow ICMP to ISP monitoring network"')
    Start-Sleep -Milliseconds 300

    $port.WriteLine('next')
    Start-Sleep -Milliseconds 500

    $port.WriteLine('end')
    Start-Sleep -Seconds 2
    $response = Wait-ForPrompt
    Write-Host $response -ForegroundColor Gray

    Write-Host "`n=== Verifying configuration ===" -ForegroundColor Cyan

    $port.WriteLine('show firewall address ISP-Network-204.186.63.0')
    Start-Sleep -Seconds 2
    $response = Wait-ForPrompt
    Write-Host $response -ForegroundColor White

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
