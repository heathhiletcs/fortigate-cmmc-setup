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
    $nl = [System.Environment]::NewLine
    Write-Host "$nl>>> $command" -ForegroundColor Yellow

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
    return $fullResponse
}

try {
    $nl = [System.Environment]::NewLine
    Write-Host 'Opening COM3...' -ForegroundColor Green
    $port.Open()
    Start-Sleep -Seconds 1

    # Clear buffer and send enters to get prompt
    try { $port.ReadExisting() | Out-Null } catch {}
    $port.WriteLine('')
    Start-Sleep -Seconds 1

    $response = $port.ReadExisting()
    Write-Host $response

    # Check if we need to login
    if ($response -match "login:") {
        Write-Host "$nl Logging in..." -ForegroundColor Cyan
        $port.WriteLine('admin')
        Start-Sleep -Seconds 1
        $port.ReadExisting() | Out-Null

        $port.WriteLine('GWMObv1Y7m_wiP!-')
        Start-Sleep -Seconds 2
        $port.ReadExisting() | Out-Null
    }

    Write-Host "$nl === Checking firewall address object ===" -ForegroundColor Cyan
    Send-Command "show firewall address ISP-Network-204.186.63.0"

    Write-Host "$nl === Checking firewall policies ===" -ForegroundColor Cyan
    $policyOutput = Send-Command "show firewall policy"

    # Parse and display relevant policies
    if ($policyOutput -match "Allow-ICMP-to-ISP-Network") {
        Write-Host "$nl ICMP policy found!" -ForegroundColor Green
    } else {
        Write-Host "$nl ICMP policy NOT found - may need to create it" -ForegroundColor Red
    }

    Write-Host "$nl ========================================" -ForegroundColor Green
    Write-Host "Verification complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($port.IsOpen) {
        $port.Close()
        Write-Host "$nl Port closed" -ForegroundColor Green
    }
}
