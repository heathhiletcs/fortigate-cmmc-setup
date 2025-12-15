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

try {
    Write-Host 'Opening COM3...' -ForegroundColor Green
    $port.Open()
    Write-Host 'Port opened successfully' -ForegroundColor Green

    # Send a couple of enters to get a prompt
    $port.WriteLine('')
    Start-Sleep -Milliseconds 500
    $port.WriteLine('')
    Start-Sleep -Seconds 1

    # Read any initial output
    $port.ReadTimeout = 1000
    try {
        $initial = $port.ReadExisting()
        if ($initial) {
            Write-Host "Initial response:" -ForegroundColor Cyan
            Write-Host $initial
        }
    } catch {}

    # Send username
    Write-Host 'Sending username: admin' -ForegroundColor Yellow
    $port.WriteLine('admin')
    Start-Sleep -Seconds 1

    # Read response
    try {
        $response = $port.ReadExisting()
        if ($response) {
            Write-Host "After username:" -ForegroundColor Cyan
            Write-Host $response
        }
    } catch {}

    # Send password
    Write-Host 'Sending password...' -ForegroundColor Yellow
    $port.WriteLine('GWMObv1Y7m_wiP!-')
    Start-Sleep -Seconds 2

    # Read response
    try {
        $response = $port.ReadExisting()
        if ($response) {
            Write-Host "After password:" -ForegroundColor Cyan
            Write-Host $response
        }
    } catch {}

    # Send a test command to verify we're logged in
    Write-Host 'Sending command: get system status' -ForegroundColor Yellow
    $port.WriteLine('get system status')
    Start-Sleep -Seconds 2

    try {
        $response = $port.ReadExisting()
        if ($response) {
            Write-Host "Command output:" -ForegroundColor Cyan
            Write-Host $response
        }
    } catch {}

    # Keep connection open for more commands
    Write-Host "`nConnection established. Port left open for additional commands." -ForegroundColor Green

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($port.IsOpen) {
        $port.Close()
        Write-Host 'Port closed' -ForegroundColor Green
    }
}
