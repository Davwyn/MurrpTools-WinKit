<#
.SYNOPSIS
Builds the custom MurrpTools Windows Installation and WinPE image.

.DESCRIPTION
This script creates a customized Windows installation image that combines:
- Windows Installation Media
- Windows RE (Recovery Environment)
- Windows Debloat features
- Recovery and repair tools
- Driver Harvester and Injector

PE drivers from the WinPE_Drivers folder will be integrated into the image to improve hardware compatibility.

.PARAMETER ISOImage
Optional path to a Windows 10/11 installation ISO file. When specified, skips the file picker dialog.

.EXAMPLE
PS> .\2 Build MurrpTools Image.ps1
Launches a file picker to select the Windows ISO interactively

.EXAMPLE
PS> .\2 Build MurrpTools Image.ps1 -ISOImage "C:\ISOs\Win11_23H2.iso"
Uses the specified ISO file without prompting

.NOTES
- Requires Windows 10 22H2 or Windows 11 installation media
- Outputs a MurrpTools.iso file ready for deployment
- WinPE drivers should be placed in the WinPE_Drivers folder
#>
[CmdletBinding()]
param (
    [string]$ISOImage
)

# Script-level variables
$MurrpToolsVersion = "v0.1.9-Alpha"
$MurrpToolsScriptPath = Resolve-Path $PSScriptRoot
$mountDir = Join-Path -Path $MurrpToolsScriptPath -ChildPath "mount"
$bootMediaDir = Join-Path -Path $MurrpToolsScriptPath -ChildPath "BootMedia"
$driversDir = Join-Path -Path $MurrpToolsScriptPath -ChildPath "WinPE_Drivers"
$Script:packageDir = $null
$Script:errorLog = @()
$Script:warningLog = @()
$Script:ISOmountResult = $null
$Script:ISOdriveLetter = $null
$verbose = [bool]$PSCmdlet.MyInvocation.BoundParameters["Verbose"]

function Log-Error {
    param($message)
    $Script:errorLog += $message
    Write-Host "[ERROR] $message" -ForegroundColor Red
}

function Log-Warning {
    param($message)
    $Script:warningLog += $message
    Write-Host "[WARNING] $message" -ForegroundColor Yellow
}

function Script-Exit {
    param(
        [bool]$isSuccess
    )

    Write-Host "`nScript Summary:"
    if ($Script:errorLog.Count -gt 0) {
        Write-Host "Errors encountered:" -ForegroundColor Red
        $Script:errorLog | ForEach-Object { Write-Host "  - $_" }
    }
    if ($Script:warningLog.Count -gt 0) {
        Write-Host "Warnings encountered:" -ForegroundColor Yellow
        $Script:warningLog | ForEach-Object { Write-Host "  - $_" }
    }

    if ($isSuccess) {
        Write-Host "`nScript completed successfully" -ForegroundColor Green
        Pause
        exit 0
    } else {
        Write-Host "`nScript failed" -ForegroundColor Red
        Pause
        exit 1
    }
}

function Cleanup {
    # 1. Check for mounted WIM
    if (Get-ChildItem $mountDir -ErrorAction SilentlyContinue) {
        try {
            Write-Host "Unmounting and discarding changes..."
            Dismount-WindowsImage -Path $mountDir -Discard
            Write-Host "WIM unmounted and changes discarded"
        } catch {
            Log-Error "Failed to unmount WIM: $_"
        }
    }

    # 2. Delete directories with error handling
    $folders = @($mountDir, $bootMediaDir)
    foreach ($folder in $folders) {
        if (Test-Path $folder) {
            try {
                Remove-Item $folder -Recurse -Force -Verbose:$verbose
                Write-Host "Cleaned up folder: $folder"
            } catch {
                Log-Error "Failed to remove $folder - please delete manually"
                Pause
            }
        }
    }

    # 3. Check for mounted ISO
    if ($Script:ISOmountResult) {
        try {
            Dismount-DiskImage -InputObject $Script:ISOmountResult | Out-Null
            $Script:ISOmountResult = $null
            Write-Host "Unmounted ISO image"
        } catch {
            Log-Error "Failed to unmount ISO: $_"
        }
    }
}

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-Directories {    
    try {
        # Create mount directory at script location
        New-Item -ItemType Directory -Path "$MurrpToolsScriptPath\mount" -ErrorAction Stop -Verbose:$verbose | Out-Null
        Write-Host "Mount directory created successfully."
    }
    catch {
        Log-Error "Failed to create mount directory: $_"
        Cleanup
        Script-Exit $false
    }
}

function Validate-ISO {
    param (
        [string]$isoPath
    )
    
    try {
        # Mount ISO
        $null = $mountResult = Mount-DiskImage -ImagePath $isoPath -PassThru
        $driveLetter = ($mountResult | Get-Volume).DriveLetter
        Write-Host "Mounted ISO image to: $driveLetter"

        Start-Sleep -Seconds 1  # Allow mounting to settle

        # Check for installation files
        if (-not (Test-Path "${driveLetter}:\sources\install.wim") -and 
            -not (Test-Path "${driveLetter}:\sources\install.esd")) {
            Dismount-DiskImage -InputObject $mountResult | Out-Null
            throw "ISO does not contain Windows installation files"
        }

        # Check for boot files
        if (-not (Test-Path "${driveLetter}:\bootmgr") -or 
            -not (Test-Path "${driveLetter}:\boot\bcd")) {
            Dismount-DiskImage -InputObject $mountResult | Out-Null
            throw "ISO missing required boot files"
        }

        # Retrieve Windows Image Info
        $windowsImage = if (Test-Path "${driveLetter}:\sources\install.wim") {
            Write-Host "Install WIM Path: ${driveLetter}:\sources\install.wim"
            Get-WindowsImage -ImagePath "${driveLetter}:\sources\install.wim" -Index 1
        } else {
            Write-Host "Install WIM Path: ${driveLetter}:\sources\install.esd"
            Get-WindowsImage -ImagePath "${driveLetter}:\sources\install.esd" -Index 1
        }

        Write-Host "Windows Install Media Version: $($windowsImage.Version)"

        # Define minimum versions for Windows 10 22H2 and Windows 11
        $minVersionWin10 = [Version]"10.0.19041"   # Minimum version for Windows 10 22H2
        $minVersionWin11 = [Version]"10.0.22000"   # Minimum version for Windows 11

        # Convert the version string to a [Version] object
        $currentVersion = [Version]$windowsImage.Version

        # Check if the current version is valid
        if (($currentVersion -lt $minVersionWin10) -and ($currentVersion -lt $minVersionWin11)) {
            Dismount-DiskImage -InputObject $mountResult | Out-Null
            throw "ISO is not 64x Windows 10 22H2 or higher, or Windows 11."
        }

        if (($currentVersion -ge $minVersionWin10) -and ($currentVersion -lt $minVersionWin11)) {
            Write-Host "Windows 10 22H2 detected." -ForegroundColor Green
            $Script:packageDir = Join-Path $MurrpToolsScriptPath "Win10_WinPE_OCs"
        } elseif ($currentVersion -ge $minVersionWin11) {
            Write-Host "Windows 11 or higher detected." -ForegroundColor Green
            $Script:packageDir = Join-Path $MurrpToolsScriptPath "Win11_WinPE_OCs"
        } else {
            Write-Host "Unsupported Windows version detected." -ForegroundColor Red
            Write-Host "Expected version: $minVersionWin10, $minVersionWin11 or higher" -ForegroundColor Red
            Dismount-DiskImage -InputObject $mountResult | Out-Null
            throw "Unsupported Windows version detected."
        }

        return $mountResult, $driveLetter
    }
    catch {
        throw "Invalid ISO: $_"
    }
}

function Copy-WithProgress {
    param (
        [string]$SourcePath,
        [string]$DestinationPath
    )

    try {
        # Get all files to copy
        $files = Get-ChildItem -Path $SourcePath -Recurse -File
        $totalFiles = $files.Count
        $currentFile = 0

        foreach ($file in $files) {
            $currentFile++
            $relativePath = $file.FullName.Substring($SourcePath.Length).TrimStart('\')
            $destinationFile = Join-Path $DestinationPath $relativePath

            # Ensure the destination directory exists
            $destinationDir = Split-Path $destinationFile -Parent
            if (-not (Test-Path $destinationDir)) {
                New-Item -ItemType Directory -Path $destinationDir -Force -Verbose:$verbose | Out-Null
            }

            # Copy the file
            Copy-Item -Path $file.FullName -Destination $destinationFile -Force -Verbose:$verbose

            # Update progress
            Write-Progress -Activity "Copying files..." `
            -Status "Copying $relativePath" `
            -PercentComplete (($currentFile / $totalFiles) * 100)
        }

        Write-Progress -Activity "Copying files..." -Completed
        Write-Host "Copy operation completed successfully."
    }
    catch {
        throw "Failed to copy files: $_"
    }
}

function Build-Image {
    $isoFile = $null
    $Script:ISOmountResult = $null
    
    if ($ISOImage) {
        # Resolve the provided path
        try {
            $ISOImage = Resolve-Path $ISOImage
            Write-Host "ISO Image supplied as: $ISOImage"
        } catch {
            Log-Error "Failed to resolve ISO path: $_"
            Cleanup
            Script-Exit $false
        }
        # Use provided ISO path
        if (-not (Test-Path $ISOImage)) {
            Log-Error "Specified ISO file does not exist: $ISOImage"
            Cleanup
            Script-Exit $false
        }
        $isoFile = Get-Item $ISOImage
    }
    else {
        Write-Host "`nOpening ISO file picker..."
        Start-Sleep 2
        # Show file picker
        Add-Type -AssemblyName System.Windows.Forms
        $filePicker = New-Object System.Windows.Forms.OpenFileDialog
        $filePicker.Filter = "ISO Files (*.iso)|*.iso"
        $filePicker.Title = "Select Windows Installation ISO"
        
        if ($filePicker.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $isoFile = Get-Item $filePicker.FileName
        }
        else {
            Log-Warning "Operation aborted by user."
            Cleanup
            Script-Exit $false
        }
    }

    try {
        # Validate ISO and get mount details
        Write-Host "`nValidating ISO file..."
        $Script:ISOmountResult, $Script:ISOdriveLetter = Validate-ISO $isoFile.FullName

        # Create BootMedia folder
        Write-Host "Creating BootMedia directory"
        if (-not (Test-Path $bootMediaDir)) {
            New-Item -ItemType Directory -Path $bootMediaDir -Verbose:$verbose | Out-Null
        }

        # Copy entire ISO contents to BootMedia
        Write-Host "`nCopying ISO data to BootMedia directory..."
        Copy-WithProgress -SourcePath "${Script:ISOdriveLetter}:" -DestinationPath "$bootMediaDir\" -Recurse
        Write-Host "`nCopied ISO contents to BootMedia folder sucessfully."
    }
    catch {
        Log-Error "Failed to process ISO file: $_"
        Cleanup
        Script-Exit $false
    }
    finally {
        if ($Script:ISOmountResult) {
            Dismount-DiskImage -InputObject $Script:ISOmountResult | Out-Null
            $Script:ISOmountResult = $null
        }
    }
}

function Mount-Wim {
    try {
        $wimFile = "$bootMediaDir\sources\boot.wim"
        Write-Host "`nMounting Boot WIM:`n$wimFile`nto`n$mountDir"
        attrib -R -S $wimFile >$null
        # Take ownership and grant full control
        takeown /F $wimFile /A >$null
        icacls $wimFile /grant Administrators:F >$null
        Mount-WindowsImage -ImagePath $wimFile -Path $mountDir -Index 2 -verbose | Out-Null
        Write-Host "`nWIM mounted successfully."
    }
    catch {
        Log-Error "Failed to mount WIM: $_"
        Cleanup
        Script-Exit $false
    }
}

function Add-Customizations {    
    try {
        Write-Host "`nAdding MurrpTools image customizations..."
        # Remove winpeshl.ini
        Remove-Item "$mountDir\windows\system32\winpeshl.ini" -Force -ErrorAction SilentlyContinue
        
        # Copy custom files with proper attribute handling
        $BootFilesDir = Join-Path $MurrpToolsScriptPath "BootFiles"
        Get-ChildItem -Path $BootFilesDir -Recurse | ForEach-Object {
            $destPath = $_.FullName.Replace($BootFilesDir, $mountDir)
            if (Test-Path $destPath) {
                Write-Host "Destination $destPath exists.`n  Overwriting..."
                # Remove read-only and system attributes
                attrib -R -S $destPath >$null
                # Take ownership and grant full control
                takeown /F $destPath /A >$null
                icacls $destPath /grant Administrators:F >$null
            }
            Copy-Item $_.FullName $destPath -Force -Verbose:$verbose
        }
        
        Write-Host "`nCustomizations added successfully."
    }
    catch {
        Log-Error "Failed to add customizations: $_"
        Cleanup
        Script-Exit $false
    }
}

function Add-Packages {    
    Write-Host "`nAdding image packages from $Script:packageDir`..."
    $packages = @(
        "WinPE-FMAPI.cab",
        "WinPE-EnhancedStorage.cab",
        "en-us\WinPE-EnhancedStorage_en-us.cab",
        "WinPE-FontSupport-WinRE.cab",
        "WinPE-WinReCfg.cab",
        "en-us\WinPE-WinReCfg_en-us.cab",
        "WinPE-SecureStartup.cab",
        "en-us\WinPE-SecureStartup_en-us.cab",
        "WinPE-Dot3Svc.cab",
        "en-us\WinPE-Dot3Svc_en-us.cab",
        "WinPE-WDS-Tools.cab",
        "en-us\WinPE-WDS-Tools_en-us.cab",
        "WinPE-Scripting.cab",
        "en-us\WinPE-Scripting_en-us.cab",
        "WinPE-WMI.cab",
        "en-us\WinPE-WMI_en-us.cab",
        "WinPE-NetFx.cab",
        "en-us\WinPE-NetFx_en-us.cab",
        "WinPE-PowerShell.cab",
        "en-us\WinPE-PowerShell_en-us.cab",
        "WinPE-DismCmdlets.cab",
        "en-us\WinPE-DismCmdlets_en-us.cab",
        "WinPE-SecureBootCmdlets.cab",
        "WinPE-StorageWMI.cab",
        "en-us\WinPE-StorageWMI_en-us.cab",
        "WinPE-HTA.cab",
        "en-us\WinPE-HTA_en-us.cab"
    )
    
    foreach ($package in $packages) {
        $packagePath = Join-Path $Script:packageDir $package
        try {
            Add-WindowsPackage -PackagePath $packagePath -Path $mountDir
            Write-Host "Added package: $package"
        }
        catch {
            Log-Error "Failed to add package $package`: $_"
            Cleanup
            Script-Exit $false
        }
    }
    Write-Host "`nPackages added successfully."
}

function Add-Services {    
    Write-Host "`nAdding MurrpTools services..."
    $startnetPath = "$mountDir\windows\system32\STARTNET.CMD"
    $appendFile = "$MurrpToolsScriptPath\ExtendedStartnetCommands.append"
    
    try {
        if (-not (Test-Path $appendFile)) {
            throw "ExtendedStartnetCommands.append not found at $appendFile"
        }
        
        Add-Content -Path $startnetPath -Value "`n" -Encoding ASCII
        Add-Content -Path $startnetPath -Value (Get-Content -Path $appendFile) -Encoding ASCII
        Write-Host "Services configuration added successfully."
    }
    catch {
        Log-Error "Failed to configure services: $_"
        Cleanup
        Script-Exit $false
    }
}

function Add-Drivers {    
    Write-Host "`nAdding Windows PE Drivers provided by user..."
    #Rename any Autorun.inf file to Autorun.inf.disabled to prevent Add-WindowsDriver from failing
    Get-ChildItem -Path $driversDir -Recurse -Filter "Autorun.inf" | ForEach-Object {
        Rename-Item -Path $_.FullName -NewName "Autorun.inf.disabled" -Force -Verbose:$verbose
    }
    # Add drivers to the mounted WIM
    try {
        Add-WindowsDriver -Driver $driversDir -Recurse -Path $mountDir -Verbose | Out-Host
        Write-Host "`nDrivers added successfully."
    }
    catch {
        Log-Error "Failed to add drivers: $_"
        Cleanup
        Script-Exit $false
    }
}

function Set-ScratchSpace {
    Write-Host "`nSetting WinPE Scratch Space to 512MB..."
    try {
        Start-Process "dism.exe" -ArgumentList "/image:$mountDir /Set-ScratchSpace:512" -Wait -NoNewWindow
        Write-Host "`nScratch space set successfully."
    }
    catch {
        Log-Error "Failed to set scratch space: $_"
        Cleanup
        Script-Exit $false
    }
}

function Commit-Wim {
    try {
        Write-Host "`nApplying changes to Boot.wim file..."
        Dismount-WindowsImage -Path $mountDir -Save
        Write-Host "`nWIM changes applied successfully."
    }
    catch {
        Log-Error "Failed to unmount WIM: $_"
        Script-Exit $false
    }
}

function Add-MediaFiles {
    try {
        Write-Host "`nAdding MurrpTools media files..."        
        # Copy custom files with proper attribute handling
        $MediaFilesDir = Join-Path $MurrpToolsScriptPath "MediaFiles"
        Get-ChildItem -Path $MediaFilesDir -Recurse | ForEach-Object {
            $destPath = $_.FullName.Replace($MediaFilesDir, $bootMediaDir)
            if (Test-Path $destPath) {
                Write-Host "Destination $destPath exists. Overwriting it..."
                # Remove read-only and system attributes
                attrib -R -S $destPath >$null
                # Take ownership and grant full control
                takeown /F $destPath /A >$null
                icacls $destPath /grant Administrators:F >$null
            }
            Copy-Item $_.FullName $destPath -Force -Verbose:$verbose
        }        
        Write-Host "`nMurrpTools media files added successfully."
    }
    catch {
        Log-Error "Failed to add media files: $_"
        Cleanup
        Script-Exit $false
    }
}

function Add-DebloatTools {
    Write-Host "`nAdding Debloat Tools..."

    $debloatToolsFile = Join-Path $MurrpToolsScriptPath "DebloatTools.json"
    $setupDir = Join-Path  $bootMediaDir "`$OEM`$\`$1\DebloatTools"
    $outputJsonPath = Join-Path $setupDir "DebloatTools.json"

    if (-not (Test-Path $debloatToolsFile)) {
        Log-Error "DebloatTools.json not found at $debloatToolsFile"
        Cleanup
        Script-Exit $false
    }

    if (-not (Test-Path $setupDir)) {
        New-Item -ItemType Directory -Path $setupDir -Force -Verbose:$verbose | Out-Null
    }

    try {
        $debloatTools = Get-Content -Path $debloatToolsFile -Raw | ConvertFrom-Json
        $updatedTools = @()

        foreach ($tool in $debloatTools) {
            $toolName = $tool.Name
            $toolUrl = $tool.Url
            $toolFilename = $tool.Filename
            $toolScriptPath = Join-Path $setupDir "$toolFilename"

            Write-Host "`nFetching script for tool: $toolName`nFrom: $toolUrl"

            try {
                # Download the script
                Invoke-RestMethod -Uri $toolUrl -OutFile $toolScriptPath

                # Validate the script
                if ((Get-Content -Path $toolScriptPath -TotalCount 20 | ForEach-Object { $_.Trim() }) -match '^<#|^\s*function|^\s*\[CmdletBinding\(\)?\]') {
                    Write-Host "Successfully downloaded and validated script for $toolName"
                    $tool | Add-Member -MemberType NoteProperty -Name "AvailableOffline" -Value $true -Force
                } else {
                    Write-Warning "Downloaded script for $toolName is not a valid PowerShell script"
                    $tool | Add-Member -MemberType NoteProperty -Name "AvailableOffline" -Value $false -Force
                    if (Test-Path $toolScriptPath) {
                        Remove-Item $toolScriptPath -Force -Verbose:$verbose
                    }
                }
            } catch {
                Log-Warning "Failed to download or validate script for $toolName`: $_"
                if (Test-Path $toolScriptPath) {
                    Remove-Item $toolScriptPath -Force -Verbose:$verbose
                }
                $tool | Add-Member -MemberType NoteProperty -Name "AvailableOffline" -Value $false -Force
            }

            $updatedTools += $tool
        }

        # Write updated DebloatTools.json
        $updatedTools | ConvertTo-Json -Depth 10 | Set-Content -Path $outputJsonPath -Encoding UTF8
        Write-Host "`nDebloat Tools configuration updated successfully."
    } catch {
        Log-Error "Failed to add Debloat Tools: $_"
        Cleanup
        Script-Exit $false
    }
}

function Build-MurrpToolsISO {
    try {
        Write-Host "`nBuilding MurrpTools ISO Image..."
        $oscdimg = Join-Path $MurrpToolsScriptPath "oscdimg.exe"
        $MurrpToolsISOPath = Join-Path $MurrpToolsScriptPath "MurrpTools.iso"
        if (Test-Path $MurrpToolsISOPath) { 
            Write-Host "Removing existing MurrpTools.iso file"
            Remove-Item $MurrpToolsISOPath -Force -ErrorAction Stop -Verbose:$verbose
        }
        if (!(Test-Path $oscdimg)) {
            throw "$oscdimg is missing. Unable to create ISO file."
        }
        Start-Process -FilePath $oscdimg -ArgumentList "-bootdata:2#p0,e,b`"$bootMediaDir\boot\etfsboot.com`"#pEF,e,b`"$bootMediaDir\efi\Microsoft\boot\efisys.bin`" -o -m -u2 -udfver102 -lMurrpTools_$MurrpToolsVersion `"$bootMediaDir`" `"MurrpTools_$MurrpToolsVersion.iso`"" -Wait -NoNewWindow -ErrorAction Stop -Verbose:$verbose
        Write-Host "`nMurrpTools_$MurrpToolsVersion.iso built at $MurrpToolsISOPath`n"
    }
    catch {
        Log-Error "Failed to add media files: $_"
        Cleanup
        Script-Exit $false
    }
}

# Main script execution
if (-not (Test-Admin)) {
    Log-Error "This script must be run as administrator."
    Script-Exit $false
}

if (!($ISOImage)) {
    Write-Host ""
    $border = "-" * 50
    Write-Host $border -ForegroundColor Cyan
    Write-Host "MurrpTools Image Builder" -ForegroundColor Green
    Write-Host "Version: $MurrpToolsVersion" -ForegroundColor Green
    Write-Host $border -ForegroundColor Cyan
    Write-Host "`nThis script will build a custom MurrpTools 64bit Windows Installation and WinPE image.`n"
    Write-Host "You will need to supply MurrpTools Image builder either a 64bit Windows 10 22H2, or 64bit Windows 11 installation media ISO file or optionally one built using UUP Dump. It must be in ISO format.`n"
    Write-Host "`nPress enter and a selection window will open to select the ISO file."
    Pause
    Write-Host ""
}

try {
    Set-Location $MurrpToolsScriptPath
    Cleanup
    Write-Verbose "Initalize Directories"
    Initialize-Directories
    Write-Verbose "Building Boot Image"
    Build-Image
    Write-Verbose "Add Media Files"
    Add-MediaFiles
    Write-Verbose "Add Debloat Tools"
    Add-DebloatTools
    Write-Verbose "Mount WIM"
    Mount-Wim
    Write-Verbose "Add Customizations"
    Add-Customizations
    Write-Verbose "Add Packages"
    Add-Packages
    Write-Verbose "Configuring Services"
    Add-Services
    Write-Verbose "Add Drivers"
    Add-Drivers
    Write-Verbose "Set Scratchspace"
    Set-ScratchSpace
    Write-Verbose "Unmount WIM"
    Commit-Wim
    Start-Sleep 1
    Write-Verbose "Build MurrpTools ISO"
    Build-MurrpToolsISO
    Start-Sleep 1
    Write-Verbose "Cleanup"
    Cleanup

    Write-Host "`n"
    $border = "*" * 60
    Write-Host $border -ForegroundColor Cyan
    Write-Host "MurrpTools WinPE with customizations has been built successfully." -ForegroundColor Green
    Write-Host "Look for the MurrpTools.iso file located at:`n  $MurrpToolsScriptPath" -ForegroundColor Green
    Write-Host "Use a tool such as Rufus to deploy the ISO image to your flash drive`." -ForegroundColor Green
    Write-Host "Rufus: https://rufus.ie" -ForegroundColor Green
    Write-Host "`n*Reccomended setings for Rufus:`n  Partition scheme: GPT`n  Target System: UEFI`n  File system: NTFS`n  (Unchecked) Create extended label and icon files.`nYou may need to click 'Show Advanced format options' to see all options." -ForegroundColor Magenta
    Write-Host "`nNote: If Rufus prompts with Windows User Experience (eg. Remove Requirements, Disable Bitlocker, etc.)`nPlease uncheck all options. Enabling options could cause MurrpTools to fail loading Debloat Tools.`nMurrpTools will already include those features built-in." -ForegroundColor Yellow
    Write-Host $border -ForegroundColor Cyan
    Write-Host ""
    Pause
}
catch {
    Log-Error "Build failed. Cleaning up..."
    Cleanup
    Script-Exit $false
}
