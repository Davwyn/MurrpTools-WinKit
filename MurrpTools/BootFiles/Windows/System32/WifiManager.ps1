function Show-MainMenu {
    Clear-Host
    $border = "*" * 50
    Write-Host $border
    Write-Host "WiFi Manager" -ForegroundColor Cyan

    # Get WiFi connection status
    $status = netsh wlan show interfaces | Select-String -Pattern "State\s+:\s+(.*)" | ForEach-Object { $_.Matches.Groups[1].Value }
    $ssid = netsh wlan show interfaces | Select-String -Pattern "SSID\s+:\s+(.*)" | ForEach-Object { $_.Matches.Groups[1].Value }

    # Display status
    if ($status -eq "connected") {
        Write-Host "`nStatus: Connected to SSID '$ssid'" -ForegroundColor Yellow
    } else {
        Write-Host "`nStatus: Not connected to any WiFi network" -ForegroundColor Red
    }

    # Display menu options
    Write-Host $border
    Write-Host "1. Search for WiFi and connect"
    Write-Host "2. Connect to WiFi by SSID"
    Write-Host "3. Disconnect from current WiFi"
    Write-Host "4. Exit"
    $choice = Read-Host "Select an option (1-4)"
    return $choice
}

function Search-And-Connect {
    while ($true) {
        Clear-Host
        Write-Host "Scanning for WiFi networks..." -ForegroundColor Yellow
        $networks = netsh wlan show networks | Select-String -Pattern "SSID\s+\d+\s+:\s+(.*)" | ForEach-Object { $_.Matches.Groups[1].Value } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if (-not $networks) {
            Write-Host "No WiFi networks found." -ForegroundColor Red
        } else {
            $i = 0 # Initialize the counter outside the loop
            foreach ($network in $networks) {
                Write-Host "$i. $network"
                $i++
            }
        }
        Write-Host "$($networks.Count). Refresh list"
        Write-Host "$($networks.Count + 1). Back to main menu"
        $selection = Read-Host "Select a network (0-$($networks.Count + 1))"
        if ($selection -eq $networks.Count) { continue }
        if ($selection -eq $networks.Count + 1) { break }
        if ($selection -lt 0 -or $selection -ge $networks.Count) {
            Write-Host "Invalid selection." -ForegroundColor Red
            Start-Sleep -Seconds 2
            continue
        }
        $ssid = $networks[$selection]
        Connect-To-Wifi -SSID $ssid

        # Exit the loop after a successful connection
        break
    }
}

function Connect-To-Wifi {
    param (
        [string]$SSID
    )
    while ($true) {
        $password = Read-Host "Enter password for SSID '$SSID'" -AsSecureString
        $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))

        # Create a temporary WiFi profile XML
        $profileXml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$SSID</name>
    <SSIDConfig>
        <SSID>
            <name>$SSID</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$plainPassword</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@

        $tempProfilePath = "$env:TEMP\$SSID.xml"
        $profileXml | Out-File -FilePath $tempProfilePath -Encoding UTF8

        # Add the profile and connect
        netsh wlan add profile filename="$tempProfilePath" user=current | Out-Null
        netsh wlan connect name=$SSID | Out-Null

        Start-Sleep -Seconds 5
        $status = netsh wlan show interfaces | Select-String -Pattern "State\s+:\s+(.*)" | ForEach-Object { $_.Matches.Groups[1].Value }
        if ($status -eq "connected") {
            Write-Host "`nSuccessfully connected to $SSID." -ForegroundColor Green
            Remove-Item -Path $tempProfilePath -Force
            Start-Sleep 3
            break
        } else {
            Write-Host "`nFailed to connect. Incorrect password or other issue." -ForegroundColor Red
            $retry = Read-Host "Retry? (Y/N)"
            if ($retry -notmatch "^[Yy]$") {
                Remove-Item -Path $tempProfilePath -Force
                Start-Sleep 3
                break
            }
        }
    }
}

function Disconnect-Wifi {
    Write-Host "`nDisconnecting from current WiFi..." -ForegroundColor Yellow
    netsh wlan disconnect
    Write-Host "`nDisconnected." -ForegroundColor Green
    Start-Sleep 3
}

$exitMenu = $false # Variable to control the main menu loop

while (-not $exitMenu) {
    $choice = Show-MainMenu
    switch ($choice) {
        "1" { Search-And-Connect }
        "2" {
            $ssid = Read-Host "Enter SSID to connect to"
            Connect-To-Wifi -SSID $ssid
        }
        "3" { Disconnect-Wifi }
        "4" { $exitMenu = $true } # Set the variable to true to exit the loop
        default {
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}
