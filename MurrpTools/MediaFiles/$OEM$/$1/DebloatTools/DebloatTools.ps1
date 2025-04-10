[CmdletBinding()]
param (
    [switch]$OOBE
)

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Script Start
if (-not (Test-Admin)) {
    Write-Error "`nThis script must be run as administrator.`n"
    Pause
    Exit
}
# Load JSON file
Set-Location $PSScriptRoot
$JsonFilePath = Join-Path -Path $PSScriptRoot -ChildPath "DebloatTools.json"
if (-Not (Test-Path $JsonFilePath)) {
    Write-Error "DebloatTools.json not found in the script directory."
    Pause
    exit
}
$Tools = Get-Content -Path $JsonFilePath | ConvertFrom-Json

# Check for internet access
$InternetAccess = Test-Connection -ComputerName "www.github.com" -Count 1 -Quiet

# Validate files and update AvailableOffline property
foreach ($Tool in $Tools) {
    $FilePath = Join-Path -Path $PSScriptRoot -ChildPath $Tool.Filename
    $Tool.AvailableOffline = Test-Path $FilePath
}

# Function to display menu
function Show-Menu {
    Clear-Host
    $Border = "-" * 25
    Write-Host $Border -ForegroundColor Cyan
    Write-Host "Debloat Tools Selection" -ForegroundColor Green
    Write-Host $Border -ForegroundColor Cyan
    Write-Host "You can run Debloat Tools again later by running DebloatTools.cmd or DebloatTools.ps1`nFrom: $PSScriptRoot"
    Write-Host $Border -ForegroundColor Cyan
    Write-Host ""
    # Sort tools, prioritizing "Davwyn's Debloat" if it exists
    $SortedTools = $Tools | Sort-Object { if ($_.Name -eq "Davwyn's Debloater") { 0 } else { 1 } }

    # Display tools
    Write-Host "1. Open Wifi Connection Menu"
    $Index = 2
    foreach ($Tool in $SortedTools) {
        Write-Host "$Index. $($Tool.Name)"
        $Index++
    }

    # Add exit option
    Write-Host "0. Continue Windows Setup"
}

# Function to display tool details and options
function Show-ToolDetails {
    param ($Tool)

    Clear-Host
    $Border = "*" * 50
    Write-Host $Border -ForegroundColor Yellow
    Write-Host "Tool: $($Tool.Name)" -ForegroundColor Green
    Write-Host "Author: $($Tool.Author)" -ForegroundColor Green
    Write-Host "Website: $($Tool.Website)" -ForegroundColor Green
    Write-Host ""
    Write-Host $Tool.Description -ForegroundColor White
    Write-Host $Border -ForegroundColor Yellow
    Write-Host ""

    if ($OOBE -and -not $Tool.OOBESupported) {
        Write-Host "This tool cannot be used during Out-Of-Box Experience. Try running this tool after Windows is finished setting up.`n" -ForegroundColor Red
        Write-Host "`nYou can run the Debloat Tools by running DebloatTools.cmd or DebloatTools.ps1 from the $PSScriptRoot folder.`n"
        Write-Host "0. Back to menu"
    } else {
        # Display options
        if ($InternetAccess) {
            Write-Host "1. Run latest from the internet"
        } else {
            Write-Host "1. -Internet Not Available-" -ForegroundColor DarkGray
        }
        if ($Tool.AvailableOffline) {
            Write-Host "2. Run offline"
        } else {
            Write-Host "2. -Offline File Not Available-" -ForegroundColor DarkGray
        }
        Write-Host "0. Back to menu"
    }
}

function Show-WifiManager {
    function Show-MainMenu {
        Clear-Host
        # Display the main menu for WiFi management
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
                $i = 0
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

    $exitMenu = $false
    while (-not $exitMenu) {
        $choice = Show-MainMenu
        switch ($choice) {
            "1" { Search-And-Connect }
            "2" {
                $ssid = Read-Host "Enter SSID to connect to"
                Connect-To-Wifi -SSID $ssid
            }
            "3" { Disconnect-Wifi }
            "4" { $exitMenu = $true }
            default {
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    }
}

# Main menu loop
do {
    Show-Menu
    $Selection = Read-Host "`nSelect an option"

    if ($Selection -eq 0) {
        break
    }

    # Wifi Menu option
    if ($Selection -eq 1) {
        Show-WifiManager # Call the embedded WiFi Manager function
        continue
    }

    # Ensure selection matches the sorted list
    $SortedTools = $Tools | Sort-Object { if ($_.Name -eq "Davwyn's Debloater") { 0 } else { 1 } }
    if ($Selection -gt 1 -and $Selection -le ($SortedTools.Count + 1)) {
        $SelectedTool = $SortedTools[$Selection - 2] # Adjust for zero-based indexing
    } else {
        Write-Host "Invalid selection. Please try again." -ForegroundColor Red
        Start-Sleep -Seconds 2
        continue
    }

    # Tool details and execution loop
    $ExitToolMenu = $false # Flag to exit the ToolOption menu
    do {
        Show-ToolDetails -Tool $SelectedTool
        $ToolOption = Read-Host "`nSelect an option"

        if ($OOBE -and -not $SelectedTool.OOBESupported) {
            if ($ToolOption -eq 0) { break }
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
        } else {
            switch ($ToolOption) {
                1 {
                    if ($InternetAccess) {
                        # Save the command from the URL to a temporary file
                        $TempScriptPath = [System.IO.Path]::GetTempFileName() + ".ps1"
                        Write-Host "Downloading $($SelectedTool.Name) from the internet..." -ForegroundColor Yellow
                        Invoke-RestMethod -Uri $SelectedTool.URL | Set-Content -Path $TempScriptPath

                        # Execute the temporary script
                        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$TempScriptPath`"" -Wait

                        # Clean up the temporary file
                        Remove-Item -Path $TempScriptPath -Force
                        $ExitToolMenu = $true # Set flag to exit ToolOption menu
                        break
                    } else {
                        Write-Host "Internet access is not available." -ForegroundColor Red
                    }
                }
                2 {
                    if ($SelectedTool.AvailableOffline) {
                        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$($SelectedTool.Filename)`"" -Wait
                        $ExitToolMenu = $true # Set flag to exit ToolOption menu
                        break
                    } else {
                        Write-Host "Offline file not available." -ForegroundColor Red
                    }
                }
                0 {
                    $ExitToolMenu = $true # Set flag to exit ToolOption menu
                    break
                }
                default {
                    Write-Host "Invalid option. Please try again." -ForegroundColor Red
                }
            }
        }

        # Exit the ToolOption menu if the flag is set
        if ($ExitToolMenu) { break }

    } while ($ToolOption -ne 0)

} while ($Selection -ne 0)

Write-Host "Exiting script. Continuing Windows setup..." -ForegroundColor Green
