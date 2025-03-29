[CmdletBinding()]
    Param(
        [Switch]$FindOfflineImage
    )

#This will self elevate the script so with a UAC prompt since this script needs to be run as an Administrator in order to function properly.
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Write-Host "You didn't run this script as an Administrator. This script will self elevate to run as an Administrator and continue."
    Start-Sleep 1
    Write-Host "                                               3"
    Start-Sleep 1
    Write-Host "                                               2"
    Start-Sleep 1
    Write-Host "                                               1"
    Start-Sleep 1
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}

function Ask-YesNoQuestion {
    param (
        [string]$Question,
        [string]$DefaultResponse
    )

    while ($true) {
        $response = Read-Host "$Question (Y/N) [Default: $DefaultResponse]"
        if ([string]::IsNullOrWhiteSpace($response)) {
            $response = $DefaultResponse
        }

        switch ($response.ToUpper()) {
            'Y' { return $true }
            'YES' { return $true }
            'N' { return $false }
            'NO' { return $false }
            default { Write-Host "Invalid input. Please enter 'Y' or 'N'." }
        }
    }
}

function Get-WindowsImages {
    $WindowsImages = @()
    
    # Get all drives except X:
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -ne 'X' }
    
    foreach ($drive in $drives) {
        $path = "$($drive.Root)Windows"
        if (Test-Path $path) {
            $WindowsImages += $path
        }
    }
    
    if ($WindowsImages.Count -eq 1) {
        $TargetImage = $null
        $usePath = Ask-YesNoQuestion -Question "`nFound a single Windows installation: $($WindowsImages[0])`nDo you want to use this path for harvesting?" -DefaultResponse "Yes"
        if ($usePath) {
            $TargetImage = $WindowsImages[0]
        } else {
            $TargetImage = $null
        }
    } elseif ($WindowsImages.Count -gt 1) {
        $TargetImage = $null
        $selection = $null
        while ($selection -eq $null) {
            Write-Host "`nMultiple Windows installations found:"
            for ($i = 0; $i -lt $WindowsImages.Count; $i++) {
                Write-Host "$($i + 1): $($WindowsImages[$i])"
            }
            Write-Host "$($WindowsImages.Count + 1): Cancel driver harvesting"
            $imageSelection = Read-Host "`nPlease select the target image by number"
            if ($imageSelection -match '^\d+$' -and $imageSelection -gt 0 -and $imageSelection -le $WindowsImages.Count) {
                $selection = [int]$imageSelection - 1
                $TargetImage = $WindowsImages[$selection]
            } elseif ($imageSelection -eq ($WindowsImages.Count + 1).ToString()) {
                $TargetImage = $null
                break
            } else {
                Write-Host "`nInvalid selection. Please try again."
            }
        }
    } else {
        Write-Host "`n-----------`nWARNING: No Windows installations found for harvesting drivers.`n-----------`nPossibly the drive was encrypted with Bitlocker.`nIf the drive was encrypted with Bitlocker try the command: manage-bde -unlock c: -recoverypassword`nFollowed by the recovery key, or harvest the drivers while Windows is running.`n"
        Pause
        $TargetImage = $null
    }
    return $TargetImage
}

Write-Host "-----------`nDriver Harvester`n-----------"
$HarvesterPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$model = $(get-wmiobject Win32_ComputerSystem).Model
$DriverExportPath = $HarvesterPath + "Drivers\" + $model
Write-Host "The unit model is of this system is $model"
if (Test-Path $DriverExportPath) {
    $ChoiceExportDrivers = Ask-YesNoQuestion -Question "`nThere appears to already be harvested drivers at $DriverExportPath`nWould you like to export drivers anyways?" -DefaultResponse "No"
} else {
    $ChoiceExportDrivers = Ask-YesNoQuestion -Question "`nThere are no drivers exported for this system available.`nAttempt to export drivers to $DriverExportPath?" -DefaultResponse "Yes"
}

if ($ChoiceExportDrivers -eq $true) {
    if ($FindOfflineImage) {
        #Offline Driver Harvesting from ZF WinKit
        $TargetImage = Get-WindowsImages
        if ($TargetImage) {
            $TargetImageRoot = [System.IO.Path]::GetPathRoot($TargetImage)
            Write-Host "`nHarvesting Drivers from $TargetImage ...."
            Export-WindowsDriver -Path $TargetImageRoot -SystemDrive $TargetImageRoot -Destination $DriverExportPath -LogLevel 2
            <# # Get the list of drivers
            $drivers = Get-WindowsDriver -Path $TargetImageRoot -SystemDrive $TargetImageRoot        
            foreach ($driver in $drivers) {
                $driverPath = $driver.OriginalFileName
                # Extract the directory containing the .inf file
                $infDirectory = Split-Path -Path $driverPath -Parent
                # Extract the folder name containing the .inf file
                $folderName = Split-Path -Path $infDirectory -Leaf
                # Combine the folder name with the file name
                $relativePath = Join-Path -Path $folderName -ChildPath (Split-Path -Path $driverPath -Leaf)
                $destination = Join-Path -Path $DriverExportPath -ChildPath $relativePath
                Write-Host "Exporting driver: $driverPath"
                if (!(Test-Path $destination)) {New-Item -Path $destination -ItemType Directory -Force}
                Copy-Item -Path $infDirectory -Destination $destination -Recurse -Force -Verbose
            } #>
            Write-Host "`nExport complete. Exiting..."
            Start-Sleep 2
            Return
        } else {
            Write-Host "`nNo target for harvesting drivers. Exiting..."
            Start-Sleep 2
            Return
        }
    } else {
        #Online Driver Harvesting
        Write-Host "`nHarvesting currently running Windows drivers to $DriverExportPath ..."
        New-Item -ItemType Directory -Force -Path $DriverExportPath
        #Export-WindowsDriver -Online -Destination $DriverExportPath
        & dism /online /export-driver /destination:$DriverExportPath
        Write-Host "`n`nDriver export complete."
        Start-Sleep 4
        Return
    }
} else {
    Write-Host "`nExiting without harvesting drivers..."
    Start-Sleep 2
    Return
}