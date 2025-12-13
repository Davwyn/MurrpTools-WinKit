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

$MurrpToolsVersion = "v1.2.1"

function Exit-Script {
    param(
        [bool]$isSuccess
    )
    if (-not $isSuccess) {
        Write-Host "`nAn error occurred. Initiating cleanup..." -ForegroundColor Yellow
        Cleanup
    }

    Write-Host "`nScript Summary:"
    if ($Script:errorLog.Count -gt 0) {
        Write-Host "Errors encountered:" -ForegroundColor Red
        $Script:errorLog | ForEach-Object { Write-Host "  - $_" }
    }
    if ($Script:warningLog.Count -gt 0) {
        Write-Host "Warnings encountered:" -ForegroundColor Yellow
        $Script:warningLog | ForEach-Object { Write-Host "  - $_" }
    }
    
    if (Get-PSDrive -Name "BuildDrive" -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name "BuildDrive" -Force -ErrorAction SilentlyContinue
    }

    if ($isSuccess) {
        Write-Host "`nScript completed successfully" -ForegroundColor Green
        if ($ISOImage) {
            Write-Host "`nScript will exit in 5 seconds..." -ForegroundColor Green
            Start-Sleep -Seconds 5
            exit 0
        } else {
            Read-Host -Prompt "Press enter to continue..."
            exit 0
        }
    } else {
        Write-Host "`nScript failed" -ForegroundColor Red
        Read-Host -Prompt "Press enter to continue..."
        exit 1
    }
}

function Join-PathImproved {
    param (
        [string]$Path1,
        [string]$Path2
    )
    try {
        $CombinedPath = [System.IO.Path]::Combine($Path1, $Path2) # Must use this instead of Join-Path because Microsoft PowerShell's internal commands are garbage.
        Write-Verbose "Combined path: $CombinedPath"
        return $CombinedPath
    } catch {
        Write-ErrorLog "Failed to combine paths: $_"
        Exit-Script $false
    }
}

# Script-level variables
$MurrpToolsScriptPath = Resolve-Path -Path $PSScriptRoot
$mountDir = Join-PathImproved -Path1 $MurrpToolsScriptPath -Path2 "mount"
$bootMediaDir = Join-PathImproved -Path1 $MurrpToolsScriptPath -Path2 "BootMedia"
$driversDir = Join-PathImproved -Path1 $MurrpToolsScriptPath -Path2 "WinPE_Drivers"
$Script:packageDir = $null
$Script:errorLog = @()
$Script:warningLog = @()
$Script:ISOmountResult = $null
$Script:ISOdriveLetter = $null
$verbose = [bool]$PSCmdlet.MyInvocation.BoundParameters["Verbose"]

# Check if the operating system is Windows and refuse to run if not
if ($env:OS -notlike "*Windows*") {
    Write-Host "This script is designed to run only on Windows operating systems." -ForegroundColor Yellow
    Write-Host "Please use a Windows system and try again." -ForegroundColor Yellow
    Read-Host -Prompt "Press enter to continue..."
    exit 1
}

function Write-ErrorLog {
    param($message)
    $Script:errorLog += $message
    Write-Host "[ERROR] $message" -ForegroundColor Red
}

function Write-WarningLog {
    param($message)
    $Script:warningLog += $message
    Write-Host "[WARNING] $message" -ForegroundColor Yellow
}

function Cleanup {
    # 1. Check for mounted WIM
    if (Get-ChildItem $mountDir -ErrorAction SilentlyContinue) {
        try {
            Write-Host "Unmounting and discarding changes..."
            Dismount-WindowsImage -Path $mountDir -Discard
            Write-Host "WIM unmounted and changes discarded"
        } catch {
            Write-ErrorLog "Failed to unmount WIM: $_"
        }
    }

    # 2. Delete directories with error handling
    $folders = @($mountDir, $bootMediaDir)
    foreach ($folder in $folders) {
        if (Test-Path -Path $folder) {
            try {
                Remove-Item -Path $folder -Recurse -Force -Verbose:$verbose
                Write-Host "Cleaned up folder: $folder"
            } catch {
                Write-ErrorLog "Failed to remove $folder - please delete manually"
                Read-Host -Prompt "Press enter to continue..."
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
            Write-ErrorLog "Failed to unmount ISO: $_"
        }
    }
}

function Initialize-Directories {    
    try {
        # Create mount directory at script location
        New-Item -ItemType Directory -Path "$MurrpToolsScriptPath\mount" -ErrorAction Stop -Verbose:$verbose | Out-Null
        Write-Host "Mount directory created successfully."
    }
    catch {
        Write-ErrorLog "Failed to create mount directory: $_"
        Exit-Script $false
    }
}

function Get-NormalizedPath {
    param ([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }
    # Strip \\?\ prefix if present
    if ($Path -like "\\?\*") {
        $Path = $Path.Substring(4)
    }
    # Check if it's a root path without trailing backslash
    if ($Path -match '^[a-zA-Z]:$') {
        return $([System.IO.Path]::GetFullPath($Path + "\"))
    }
    # Check if it's a root path like "C:\"
    if ($Path -match '^[a-zA-Z]:\\+$') {
        return $([System.IO.Path]::GetFullPath(($Path.TrimEnd('\')) + "\"))
    }
    return $([System.IO.Path]::GetFullPath($Path.TrimEnd('\')))
}

function Confirm-ValidISO {
    param (
        [string]$isoPath
    )
    
    try {
        # Normalize the ISO path
        $isoPath = Get-NormalizedPath $isoPath

        # Mount ISO
        $null = $mountResult = Mount-DiskImage -ImagePath $isoPath -PassThru
        $driveLetter = ($mountResult | Get-Volume).DriveLetter
        Write-Host "Mounted ISO image to: $driveLetter"

        Start-Sleep -Seconds 1  # Allow mounting to settle

        # Check for installation files
        if (-not (Test-Path -Path "${driveLetter}:\sources\install.wim") -and 
            -not (Test-Path -Path "${driveLetter}:\sources\install.esd")) {
            Dismount-DiskImage -InputObject $mountResult | Out-Null
            throw "ISO does not contain Windows installation files"
        }

        # Check for boot files
        if (-not (Test-Path -Path "${driveLetter}:\bootmgr") -or 
            -not (Test-Path -Path "${driveLetter}:\boot\bcd")) {
            Dismount-DiskImage -InputObject $mountResult | Out-Null
            throw "ISO missing required boot files"
        }

        # Retrieve Windows Image Info
        $windowsImage = if (Test-Path -Path "${driveLetter}:\sources\install.wim") {
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
            $Script:packageDir = Join-PathImproved -Path1 $MurrpToolsScriptPath -Path2 "Win10_WinPE_OCs"
        } elseif ($currentVersion -ge $minVersionWin11) {
            Write-Host "Windows 11 or higher detected." -ForegroundColor Green
            $Script:packageDir = Join-PathImproved -Path1 $MurrpToolsScriptPath -Path2 "Win11_WinPE_OCs"
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
        # Sanitize paths
        $SourcePath = Get-NormalizedPath $SourcePath
        $DestinationPath = Get-NormalizedPath $DestinationPath

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
            if (-not (Test-Path -Path $destinationDir)) {
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
            $ISOImage = Resolve-Path -Path $ISOImage
            Write-Host "ISO Image supplied as: $ISOImage"
        } catch {
            Write-ErrorLog "Failed to resolve ISO path: $_"
            Exit-Script $false
        }
        # Use provided ISO path
        if (-not (Test-Path -Path $ISOImage)) {
            Write-ErrorLog "Specified ISO file does not exist: $ISOImage"
            Exit-Script $false
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
            Write-WarningLog "Operation aborted by user."
            Exit-Script $false
        }
    }

    try {
        # Validate ISO and get mount details
        Write-Host "`nSelected ISO: $($isoFile.FullName)" -ForegroundColor Cyan
        Write-Host "`nValidating ISO file..."
        $Script:ISOmountResult, $Script:ISOdriveLetter = Confirm-ValidISO $isoFile.FullName

        # Create BootMedia folder
        Write-Host "Creating BootMedia directory"
        if (-not (Test-Path -Path $bootMediaDir)) {
            New-Item -ItemType Directory -Path $bootMediaDir -Verbose:$verbose | Out-Null
        }

        # Copy entire ISO contents to BootMedia
        Write-Host "`nCopying ISO data to BootMedia directory..."
        Copy-WithProgress -SourcePath "${Script:ISOdriveLetter}:" -DestinationPath "$bootMediaDir\" -Recurse
        Write-Host "`nCopied ISO contents to BootMedia folder sucessfully."
    }
    catch {
        Write-ErrorLog "Failed to process ISO file: $_"
        Exit-Script $false
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
        $wimFile = Join-PathImproved -Path1 $bootMediaDir -Path2 "sources\boot.wim"
        Write-Host "`nMounting Boot WIM:`n$wimFile`nto`n$mountDir"
        & attrib -R -S $wimFile >$null
        # Take ownership and grant full control
        & takeown /F $wimFile /A >$null
        & icacls $wimFile /grant "*S-1-5-32-544:F" /Q
        Mount-WindowsImage -ImagePath $wimFile -Path $mountDir -Index 2 -verbose | Out-Null
        Write-Host "`nWIM mounted successfully."
    }
    catch {
        Write-ErrorLog "Failed to mount WIM: $_"
        Exit-Script $false
    }
}

function Add-Customizations {    
    try {
        Write-Host "`nAdding MurrpTools image customizations..."
        # Normalize paths
        $BootFilesDir = Get-NormalizedPath (Join-Path $MurrpToolsScriptPath "BootFiles")
        $mountDir = Get-NormalizedPath $mountDir

        # Remove winpeshl.ini
        Remove-Item -Path "$mountDir\windows\system32\winpeshl.ini" -Force -ErrorAction SilentlyContinue
        
        # Copy custom files with proper attribute handling
        Get-ChildItem -Path $BootFilesDir -Recurse | ForEach-Object {
            $destPath = $_.FullName.Replace($BootFilesDir, $mountDir)
            if (Test-Path -Path $destPath) {
                Write-Host "Destination $destPath exists.`n  Overwriting..."
                # Remove read-only and system attributes
                & attrib -R -S $destPath >$null
                # Take ownership and grant full control
                & takeown /F $destPath /A >$null
                & icacls $destPath /grant "*S-1-5-32-544:F" /Q
            }
            Copy-Item -Path $_.FullName -Destination $destPath -Force -Verbose:$verbose
        }
        
        Write-Host "`nCustomizations added successfully."
    }
    catch {
        Write-ErrorLog "Failed to add customizations: $_"
        Exit-Script $false
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
            Write-ErrorLog "Failed to add package $package`: $_"
            Exit-Script $false
        }
    }
    Write-Host "`nPackages added successfully."
}

function Add-Services {    
    Write-Host "`nAdding MurrpTools services..."
    $startnetPath = "$mountDir\windows\system32\STARTNET.CMD"
    $appendFile = "$MurrpToolsScriptPath\ExtendedStartnetCommands.append"
    
    try {
        if (-not (Test-Path -Path $appendFile)) {
            throw "ExtendedStartnetCommands.append not found at $appendFile"
        }
        
        Add-Content -Path $startnetPath -Value "`n" -Encoding ASCII
        Add-Content -Path $startnetPath -Value (Get-Content -Path $appendFile) -Encoding ASCII
        Write-Host "Services configuration added successfully."
    }
    catch {
        Write-ErrorLog "Failed to configure services: $_"
        Exit-Script $false
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
        Write-Host ""
        if (-not $ISOImage) {
            Write-Warning "Failed to add some drivers due to the following error: $_"
            Write-Host "`nIt is typical for some drivers to fail to be added. If most drivers above succeeded, you can choose to continue.`nOtherwise if no drivers were added there might be something wrong.`n"
            $ContinueOnError = Read-Host "Would you like to continue with what drivers were added? (Y/N)"
            if ($ContinueOnError -notin @("Y", "y", "Yes", "yes")) {
                Write-ErrorLog "Operation aborted by user due to driver addition failure."
                Exit-Script $false
            } else {
                Write-Host "Continuing with current drivers..." -ForegroundColor Yellow
                Start-Sleep 2
            }
        } else {
            Write-Warning "Failed to add some drivers due to the following error: $_"
            Write-Host "Continuing current drivers..." -ForegroundColor Yellow
            Start-Sleep 5
        }
    }
}

function Set-ScratchSpace {
    Write-Host "`nSetting WinPE Scratch Space to 512MB..."
    try {
        Start-Process "dism.exe" -ArgumentList "/image:`"$mountDir`" /Set-ScratchSpace:512" -Wait -NoNewWindow -ErrorAction Stop
        Write-Host "`nScratch space set successfully."
    }
    catch {
        Write-ErrorLog "Failed to set scratch space: $_"
        Exit-Script $false
    }
}

function Publish-WIMFile {
    try {
        Write-Host "`nApplying changes to Boot.wim file..."
        Dismount-WindowsImage -Path $mountDir -Save -ErrorAction Stop
        Write-Host "`nWIM changes applied successfully."
    }
    catch {
        Write-ErrorLog "Failed to unmount WIM: $_"
        Exit-Script $false
    }
}

function Add-MediaFiles {
    try {
        Write-Host "`nAdding MurrpTools media files..."        
        # Copy custom files with proper attribute handling
        $MediaFilesDir = Join-PathImproved -Path1 $MurrpToolsScriptPath -Path2 "MediaFiles"
        Get-ChildItem -Path $MediaFilesDir -Recurse | ForEach-Object {
            $destPath = $_.FullName.Replace($MediaFilesDir, $bootMediaDir)
            if (Test-Path -Path $destPath) {
                Write-Host "Destination $destPath exists. Overwriting it..."
                # Remove read-only and system attributes
                & attrib -R -S $destPath >$null
                # Take ownership and grant full control
                & takeown /F $destPath /A >$null
                & icacls $destPath /grant "*S-1-5-32-544:F" /Q
            }
            Copy-Item -Path $_.FullName -Destination $destPath -Force -Verbose:$verbose
        }
        Write-Host "`nMurrpTools media files added successfully."
    }
    catch {
        Write-ErrorLog "Failed to add media files: $_"
        Exit-Script $false
    }
}

function Add-DebloatTools {
    Write-Host "`nAdding Debloat Tools..."

    $debloatToolsFile = Join-PathImproved -Path1 $MurrpToolsScriptPath -Path2 "DebloatTools.json"
    $setupDir = Join-PathImproved -Path1 $bootMediaDir -Path2 "`$OEM`$\`$1\DebloatTools"
    $outputJsonPath = Join-PathImproved -Path1 $setupDir -Path2 "DebloatTools.json"

    if (-not (Test-Path -Path $debloatToolsFile)) {
        Write-ErrorLog "DebloatTools.json not found at $debloatToolsFile"
        Exit-Script $false
    }

    if (-not (Test-Path -Path $setupDir)) {
        New-Item -ItemType Directory -Path $setupDir -Force -Verbose:$verbose | Out-Null
    }

    try {
        $debloatTools = Get-Content -Path $debloatToolsFile -Raw | ConvertFrom-Json
        $updatedTools = @()

        foreach ($tool in $debloatTools) {
            # Skip tools where "Enabled" is false
            if ($tool.Enabled -ne $true) {
                Write-Host "`nSkipping tool: $($tool.Name) as it is not enabled" -ForegroundColor Yellow
                continue
            }
            $toolName = $tool.Name
            $toolUrl = $tool.DownloadUrl
            $toolFilename = $tool.DownloadFilename
            $toolExecutable = $tool.Executeable
            $toolFolder = $tool.FolderName
            # Validate that all required fields are not null or blank
            if ([string]::IsNullOrWhiteSpace($toolName) -or 
                [string]::IsNullOrWhiteSpace($toolUrl) -or 
                [string]::IsNullOrWhiteSpace($toolFilename) -or 
                [string]::IsNullOrWhiteSpace($toolExecutable) -or 
                [string]::IsNullOrWhiteSpace($toolFolder)) {
                Write-WarningLog "Tool ($toolName) is not valid and has been skipped. Missing required fields for tool."
                continue
            }
            $toolFolderPath = Join-PathImproved -Path1 $setupDir -Path2 "$toolFolder"
            $toolScriptPath = Join-PathImproved -Path1 $setupDir -Path2 "$toolFolder\$toolExecutable"

            Write-Host "`nFetching script for tool: $toolName`nFrom: $toolUrl"
            # Download the script or tool from the download URL
            try {
                # Make folder for the tool
                New-Item -ItemType Directory -Path $toolFolderPath -Force -Verbose:$verbose | Out-Null
                # Download the script
                $destinationPath = Join-Path $toolFolderPath "$toolFilename"
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
                            Write-WarningLog "Failed to download $toolFilename from $toolUrl after $maxAttempts attempts."
                            Write-Host "Marking $toolName as unavailable for offline use."
                            $tool | Add-Member -MemberType NoteProperty -Name "AvailableOffline" -Value $false -Force
                        }
                    } finally {
                        if ($webClient) { $webClient.Dispose() }
                    }
                }
                if (-not $success) {
                    continue
                }
                # If the downloaded file is a .zip, extract its contents
                if ($toolFilename -like "*.zip") {
                    Write-Host "Extracting $toolFilename to $toolFolderPath ..."
                    try {
                        Expand-Archive -Path $destinationPath -DestinationPath $toolFolderPath -Force
                        Write-Host "Extracted $toolFilename successfully."
                        # Optionally, remove the zip file after extraction
                        Remove-Item -Path $destinationPath -Force -Verbose:$verbose
                    } catch {
                        Write-WarningLog "Failed to extract $toolFilename`nTool will not be available offline: $_"
                        continue
                    }
                }
                # Validate the script
                $fileExtension = [System.IO.Path]::GetExtension($toolScriptPath).ToLower()
                if ($fileExtension -eq ".ps1") {
                    if ((Get-Content -Path $toolScriptPath -TotalCount 20 -ErrorAction SilentlyContinue | ForEach-Object { $_.Trim() }) -match '^<#|^\s*function|^\s*\[CmdletBinding\(\)?\]|param') {
                        Write-Host "Successfully downloaded and validated script for $toolName. Marking as available offline." -ForegroundColor Green
                        $tool | Add-Member -MemberType NoteProperty -Name "AvailableOffline" -Value $true -Force
                    } else {
                        Write-WarningLog "Downloaded script for $toolName is not a valid PowerShell script"
                        $tool | Add-Member -MemberType NoteProperty -Name "AvailableOffline" -Value $false -Force
                        if (Test-Path -Path $toolScriptPath) {
                            Remove-Item -Path $toolScriptPath -Force -Verbose:$verbose
                        }
                    }
                } elseif ($fileExtension -in ".exe", ".cmd", ".bat") {
                    Write-Host "Executable file downloaded for $toolName. Marking as available offline." -ForegroundColor Green
                    $tool | Add-Member -MemberType NoteProperty -Name "AvailableOffline" -Value $true -Force
                } else {
                    Write-WarningLog "Downloaded file for $toolName is not a supported type"
                    $tool | Add-Member -MemberType NoteProperty -Name "AvailableOffline" -Value $false -Force
                    if (Test-Path -Path $toolScriptPath) {
                        Remove-Item -Path $toolScriptPath -Force -Verbose:$verbose
                    }
                }
            } catch {
                Write-WarningLog "Failed to download or validate script for $toolName`: $_"
                if (Test-Path -Path $toolFolderPath) {
                    Remove-Item -Path $toolFolderPath -Recurse -Force -Verbose:$verbose
                }
                $tool | Add-Member -MemberType NoteProperty -Name "AvailableOffline" -Value $false -Force
            }

            $updatedTools += $tool
        }

        # Write updated DebloatTools.json
        $updatedTools | ConvertTo-Json -Depth 10 | Set-Content -Path $outputJsonPath -Encoding UTF8
        Write-Host "`nDebloat Tools configuration updated successfully."
    } catch {
        Write-ErrorLog "Failed to add Debloat Tools: $_"
        Exit-Script $false
    }
}

function Build-MurrpToolsISO {
    try {
        Write-Host "`nBuilding MurrpTools ISO Image..."
        $oscdimg = Join-PathImproved -Path1 $MurrpToolsScriptPath -Path2 "oscdimg.exe"
        $ExistingMurrpToolsISO = Get-ChildItem -Path $MurrpToolsScriptPath -Name "MurrpTools*.iso"
        if ($ExistingMurrpToolsISO) { 
            Write-Host "Removing existing MurrpTools ISO file"
            $ExistingMurrpToolsISO | Remove-Item -Force -ErrorAction Stop -Verbose:$verbose
        }
        if (!(Test-Path -Path $oscdimg)) {
            Write-ErrorLog "$oscdimg is missing. Unable to create ISO file."
            Exit-Script $false
        }
        Write-Verbose "MurrpTools ISO Path: $(Join-PathImproved -Path1 $MurrpToolsScriptPath -Path2 "MurrpTools_$MurrpToolsVersion.iso")"
        Write-Verbose "Boot Media Directory: $bootMediaDir"
        # Get the Last Modified date from the install.esd or install.wim file to use as the ISO timestamp
        $InstallWIMPath = Join-PathImproved -Path1 $bootMediaDir -Path2 "sources\install.esd"
        if (-not (Test-Path -Path $InstallWIMPath)) {
            $InstallWIMPath = Join-PathImproved -Path1 $bootMediaDir -Path2 "sources\install.wim"
            if (-not (Test-Path -Path $InstallWIMPath)) {
                Write-ErrorLog "Neither install.esd nor install.wim found in $($bootMediaDir)\sources"
                Exit-Script $false
            }
        }
        Write-Verbose "Install WIM Path: $InstallWIMPath"
        # 1. Get the Modified date of the WIM file
        $WIMMetadata = Get-WindowsImage -ImagePath $InstallWIMPath -Index 1
        # Use ModifiedTime property for ISO timestamp
        $mod = $WIMMetadata.ModifiedTime
        $month = "{0:D2}" -f $mod.Month
        $day = "{0:D2}" -f $mod.Day
        $year = $mod.Year
        $hour = "{0:D2}" -f $mod.Hour
        $minute = "{0:D2}" -f $mod.Minute
        $second = "{0:D2}" -f $mod.Second
        # Compose isotime in MM/YYYY,HH:MM:SS format
        $isotime = "$month/$day/$year,$hour`:$minute`:$second"
        Write-Verbose "ISO Timestamp: $isotime"
        # 2. Build the ISO using oscdimg
        Write-Host "`nCreating ISO file..."
        Start-Process -FilePath $oscdimg -ArgumentList "-bootdata:2#p0,e,b`"$bootMediaDir\boot\etfsboot.com`"#pEF,e,b`"$bootMediaDir\efi\Microsoft\boot\efisys.bin`" -o -m -u2 -udfver102 -t$isotime -lMurrpTools_$MurrpToolsVersion `"$bootMediaDir`" `"MurrpTools_$MurrpToolsVersion.iso`"" -Wait -NoNewWindow -ErrorAction Stop -Verbose:$verbose
        Write-Host "`nMurrpTools_$MurrpToolsVersion.iso built at $MurrpToolsScriptPath`n"
    }
    catch {
        Write-ErrorLog "Failed to add media files: $_"
        Cleanup
        Exit-Script $false
    }
}

# Main script execution

# Verify running as administrator
$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not ($currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
    Write-ErrorLog "This script must be run as administrator."
    Exit-Script $false
}

# Check if Long Path support is enabled
$longPathEnabled = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -ErrorAction SilentlyContinue).LongPathsEnabled -eq 1
if (-not($longPathEnabled)) {
    $maxAllowedLength = 260 - 152
    if ($($MurrpToolsScriptPath.Length) -gt $maxAllowedLength) {
        Write-Warning "MurrpTools is in a directory path that is too long. Windows Long Path support is not enabled, and the total path length exceeds the allowed limit of $maxAllowedLength characters."
        $userResponse = Read-Host "Would you like to enable Long Path support in Windows? This requires administrative privileges and a system restart. (Y/N)"
        if ($userResponse -match '^[Yy]') {
            try {
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -Type DWORD -Force
                Write-Host "Long Path support has been enabled in the Windows registry.`n`n" -ForegroundColor Green
                $border = "-" * 50
                Write-Host $border -ForegroundColor Yellow
                Write-Host "Please restart your computer for the changes to take effect.`nThis is required. Strange script errors will occur if you don't restart!" -ForegroundColor Yellow
                Write-Host $border -ForegroundColor Yellow
                Write-Host "`n`nExiting script. Please rerun the script after restarting your computer." -ForegroundColor Cyan
                Exit-Script $true
            } catch {
                Write-ErrorLog "Failed to enable Long Path support: $_"
                Exit-Script $false
            }
        } else {
            Write-ErrorLog "MurrpTools is in a directory path that is too long, and Long Path support is not enabled. Please enable Long Path support or select a shorter folder path."
            Exit-Script $false
        }
    }
}

# Check if step 1 completion token file exists
$TokenFile = Join-PathImproved $MurrpToolsScriptPath "1 Dependencies and Staging Complete.txt"
if (-not(Test-Path -Path $TokenFile)) {
    $border = "-" * 80
    Write-Host $border -ForegroundColor Yellow
    Write-Host ""
    Write-ErrorLog "Step 1: Dependencies and Staging completion token file not found." -ForegroundColor Red
    Write-Host "`nPlease run '1 Dependencies and Staging.cmd' first to complete the required staging before building the image." -ForegroundColor Yellow
    Write-Host "If you already ran the first script you need to navigate to the MurrpTools folder you created in step 1.`n" -ForegroundColor Yellow
    Write-Host $border -ForegroundColor Yellow
    Exit-Script $false
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
    Read-Host -Prompt "Press enter to continue..."
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
    Publish-WIMFile
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
    Exit-Script $true
}
catch {
    Write-ErrorLog "Build failed. Cleaning up..."
    Cleanup
    Exit-Script $false
}
