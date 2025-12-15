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
    param($command)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Command: $command" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan

    $port.WriteLine($command)
    Start-Sleep -Seconds 2

    $fullResponse = ""
    $maxIterations = 20
    $iteration = 0

    do {
        try {
            $port.ReadTimeout = 1000
            $response = $port.ReadExisting()
            $fullResponse += $response

            if ($response -match "--More--") {
                $port.Write(" ")
                Start-Sleep -Milliseconds 300
                $iteration++
            } else {
                break
            }
        } catch {
            break
        }
    } while ($iteration -lt $maxIterations)

    Write-Host $fullResponse
}

try {
    Write-Host 'Opening COM3...' -ForegroundColor Green
    $port.Open()

    Start-Sleep -Seconds 1
    try { $port.ReadExisting() | Out-Null } catch {}

    # Get WAN interface MAC address
    Send-Command "get hardware nic wan1"
    Send-Command "diagnose hardware deviceinfo nic wan1"
    Send-Command "get system interface physical wan1"

    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "WAN MAC address retrieval complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($port.IsOpen) {
        $port.Close()
        Write-Host "`nPort closed" -ForegroundColor Green
    }
}
