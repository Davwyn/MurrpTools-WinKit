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

# Validate files and update AvailableOffline property
foreach ($Tool in $Tools) {
    if ($Tool.AvailableOffline) {
        $ToolFolderPath = Join-Path -Path $PSScriptRoot -ChildPath $Tool.FolderName
        $ToolScriptPath = Join-Path -Path $ToolFolderPath -ChildPath $Tool.Executable
        if (-Not (Test-Path $ToolScriptPath)) {
            $Tool.AvailableOffline = $false
        }
    }
}

if ($OOBE) {
    $PENetworkManagerSource = Join-Path -Path $PSScriptRoot -ChildPath 'PENetwork_x64\PENetwork.exe' -Resolve -ErrorAction 'SilentlyContinue'
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
    if ($PENetworkManagerSource) {
        Write-Host "1. Open Network/Wifi Connection Menu"
    } else {
        Write-Host "1. -Wifi Connection Menu Not Available-" -ForegroundColor DarkGray
    }
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
    # Check for internet access
    
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

function Show-NetworkManager {
    Clear-Host
    Write-Host "`nConfigure network settings and click 'OK'."
    Write-Host "`nOpening PE Network Manager..." -ForegroundColor Yellow
    Start-Process "$PENetworkManagerSource" -ArgumentList "/guidisable=31"
    Start-Sleep -Seconds 5
}

# Main menu loop
do {
    Show-Menu
    $Selection = Read-Host "`nSelect an option"

    if ($Selection -eq 0) {
        break
    }

    # Wifi Menu option
    if (($Selection -eq 1) -and ($oobe)) {
        Show-NetworkManager # Open PE Network Manager
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
        $InternetAccess = Test-Connection -ComputerName "www.github.com" -Count 1 -Quiet
        Show-ToolDetails -Tool $SelectedTool
        $ToolOption = Read-Host "`nSelect an option"

        if ($OOBE -and -not $SelectedTool.OOBESupported) {
            if ($ToolOption -eq 0) { break }
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
        } else {
            switch ($ToolOption) {
                1 {
                    if ($InternetAccess) {
                        $toolName = $SelectedTool.Name
                        $toolUrl = $SelectedTool.DownloadUrl
                        $toolFilename = $SelectedTool.DownloadFilename
                        $toolExecutable = $SelectedTool.Executeable
                        $tempFolder = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
                        New-Item -ItemType Directory -Path $tempFolder | Out-Null
                        Write-Host "Downloading $toolName from the internet..." -ForegroundColor Yellow
                        Start-Sleep -Seconds 1
                        # Download the script
                        $destinationPath = Join-Path $tempFolder "$toolFilename"
                        $attempts = 0
                        $maxAttempts = 3
                        $success = $false

                        while ($attempts -lt $maxAttempts -and -not $success) {
                            try {
                                $webClient = New-Object System.Net.WebClient
                                $webClient.DownloadFile($toolUrl, $destinationPath)
                                Write-Host "Downloaded $toolFilename to $destinationPath"
                                $success = $true
                            } catch {
                                $attempts++
                                if ($attempts -lt $maxAttempts) {
                                    Write-Host "Attempt $attempts failed. Retrying in 3 seconds..."
                                    Start-Sleep -Seconds 3
                                } else {
                                    Write-Host "Failed to download $toolFilename from $toolUrl after $maxAttempts attempts." -ForegroundColor Red
                                    Start-Sleep -Seconds 2
                                    return # Go back to the previous menu
                                }
                            } finally {
                                if ($webClient) { $webClient.Dispose() }
                            }
                        }

                        # If the downloaded file is a .zip, extract its contents
                        if ($toolFilename -like "*.zip") {
                            Write-Host "Extracting $toolFilename to $tempFolder ..."
                            try {
                                Expand-Archive -Path $destinationPath -DestinationPath $tempFolder -Force
                                Write-Host "Extracted $toolFilename successfully."
                                # Optionally, remove the zip file after extraction
                                Remove-Item $destinationPath -Force
                            } catch {
                                Write-Host "Failed to extract $toolFilename`: $_" -ForegroundColor Red
                                Start-Sleep -Seconds 2
                                return # Go back to the previous menu
                            }
                        }
                        # Execute the temporary script
                        $fileExtension = [System.IO.Path]::GetExtension($toolExecutable).ToLower()
                        switch ($fileExtension) {
                            ".ps1" {
                                Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$tempFolder\$toolExecutable`"" -Wait
                            }
                            ".exe" {
                                Start-Process -FilePath "$tempFolder\$toolExecutable" -Wait
                            }
                            { $_ -eq ".cmd" -or $_ -eq ".bat" } {
                                Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$tempFolder\$toolExecutable`"" -Wait
                            }
                            default {
                                Write-Host "Unsupported file type: $fileExtension" -ForegroundColor Red
                                Pause
                            }
                        }

                        # Clean up the temporary file
                        Remove-Item -Path $tempFolder -Recurse -Force
                        $ExitToolMenu = $true # Set flag to exit ToolOption menu
                    } else {
                        Write-Host "Internet access is not available." -ForegroundColor Red
                        Start-Sleep -Seconds 2
                    }
                }
                2 {
                    if ($SelectedTool.AvailableOffline) {
                        $toolName = $SelectedTool.Name
                        $toolExecutable = $SelectedTool.Executeable
                        $toolFolderPath = Join-Path -Path $PSScriptRoot -ChildPath $SelectedTool.FolderName
                        $toolScriptPath = Join-Path -Path $toolFolderPath -ChildPath $toolExecutable
                        
                        Write-Host "Starting $toolName from Offline storage..." -ForegroundColor Yellow
                        Start-Sleep -Seconds 1
                        $fileExtension = [System.IO.Path]::GetExtension($toolExecutable).ToLower()
                        switch ($fileExtension) {
                            ".ps1" {
                                Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$($toolScriptPath)`"" -Wait
                            }
                            ".exe" {
                                Start-Process -FilePath "$($toolScriptPath)" -Wait
                            }
                            { $_ -eq ".cmd" -or $_ -eq ".bat" } {
                                Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$($toolScriptPath)`"" -Wait
                            }
                            default {
                                Write-Host "Unsupported file type: $fileExtension" -ForegroundColor Red
                                Pause
                            }
                        }
                        $ExitToolMenu = $true # Set flag to exit ToolOption menu
                        break
                    } else {
                        Write-Host "Offline file not available." -ForegroundColor Red
                        Start-Sleep -Seconds 2
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
