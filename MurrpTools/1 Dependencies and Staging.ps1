<#
.SYNOPSIS
Copies dependencies from the Dependencies folder into the MurrpTools project and offers to stage the project in a different location.

.DESCRIPTION
This script handles copying dependencies for the MurrpTools project. You can either:
- Copy dependencies directly into the project folder
- Copy both the project folder with its dependencies embedded to a new staging location

The script provides a Folder Picker UI to select the destination path. Alternatively, you can specify the path using the -BuildPath parameter.

.PARAMETER BuildPath
Specifies the destination path for the build. If not provided, a Folder Picker UI will be shown to select the path.

.EXAMPLE
PS> .\1 Dependencies and Staging.ps1
Shows the Folder Picker UI to select destination path

.EXAMPLE
PS> .\1 Dependencies and Staging.ps1 -BuildPath "C:\Build"
Copies dependencies to the specified build path

.NOTES
When using the Folder Picker UI:
1. A dialog will appear allowing you to browse and select a destination folder
2. Click 'OK' to confirm your selection
3. The script will proceed with copying files to the selected location
#>

[CmdletBinding()]
param (
    [string]$BuildPath
)

$MurrpToolsVersion = "0.1 Alpha"
# Initialize script file path
$ScriptFileName = $MyInvocation.MyCommand.Name

# Function Definitions
function Write-CompletionFile {
    param (
        [string]$Path
    )
    $completionFile = Join-Path $Path "1 Dependencies and Staging Complete.txt"
    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -ErrorAction Stop | Out-Null
    }
    "Dependencies and Staging step is already complete." | Out-File $completionFile
}

function Copy-MurrpTools {
    param (
        [string]$SourcePath,
        [string]$DestinationPath,
        [bool]$Verbose = $false
    )
    
    $copyParams = @{
        Path = "$SourcePath"
        Destination = $DestinationPath
        Recurse = $true
        Force = $true
        Exclude = $ScriptFileName,"1 Dependencies and Staging.cmd"
    }
    if ($Verbose) { $copyParams['Verbose'] = $true }
    
    try {
        Copy-Item @copyParams
        Write-Host "`nCopied MurrpTools folder to $DestinationPath (excluding $ScriptFileName)"
    }
    catch {
        Write-Error "Failed to copy MurrpTools folder: $_"
        Pause
        exit 1
    }
}

function Get-BuildLocation {
    $sourcePath = $PSScriptRoot
    
    # If BuildPath was provided, use it after validation
    if ($BuildPath) {
        # Handle current directory notation
        if ($BuildPath -eq "." -or $BuildPath -eq ".\") {
            $BuildPath = $sourcePath
        }
        
        # Verify path exists
        if (-not (Test-Path $BuildPath)) {
            Write-Error "Specified path does not exist"
            exit 1
        }
        
        # Verify path is not within script directory or subdirectories
        if ($BuildPath -like "$sourcePath*" -and $BuildPath -ne $sourcePath) {
            Write-Error "Path cannot be a subdirectory of the script directory"
            exit 1
        }
        
        
        Copy-MurrpTools -SourcePath $sourcePath -DestinationPath $BuildPath
        
        # Create completion file if location is different from script directory
        if ($BuildPath -ne $sourcePath) {
            Write-CompletionFile -Path $(Join-Path $BuildPath "MurrpTools")
        }
        
        return $(Join-Path $BuildPath "MurrpTools")
    }
    
    # Offer location selection options
    Write-Host "Option 1: Use current location ($sourcePath)"
    Write-Host "Option 2: Select a different using Folder Picker"
    $choice = Read-Host "`nEnter choice (1 or 2)"
    
    if ($choice -eq "1") {
        return $sourcePath
    }
    elseif ($choice -eq "2") {
        # GUI folder picker
        Add-Type -AssemblyName System.Windows.Forms
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select build location"
        $folderBrowser.ShowNewFolderButton = $true
        
        if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $selectedPath = $folderBrowser.SelectedPath
            #Sleep for a moment to allow the dialog to close and folder to be created if the user makes a new folder
            Start-Sleep 2
            
            
            Copy-MurrpTools -SourcePath $sourcePath -DestinationPath $selectedPath
            
            # Create completion file if location is different from script directory
            if ($selectedPath -ne $sourcePath) {
                Write-CompletionFile -Path $(Join-Path $selectedPath "MurrpTools")
            }
            
            return $selectedPath
        }
        else {
            Write-Warning "Folder selection was cancelled"
            exit 1
        }
    }
    else {
        Write-Warning "Invalid selection"
        exit 1
    }
}

function Copy-Items {
    param (
        [string]$Destination,
        [array]$SourcePaths,
        [bool]$Verbose = $false
    )
    
    # Create destination directory if it doesn't exist
    try {
        if (-not (Test-Path $Destination)) {
            New-Item -ItemType Directory -Path $Destination -ErrorAction Stop | Out-Null
        }
    }
    catch {
        Write-Error "Failed to create directory $Destination`: $_"
        exit 1
    }

    $CopyErrors = @()
    foreach ($Source in $SourcePaths) {
        if (Test-Path $Source) {
            try {
                $copyParams = @{
                    Path = $Source
                    Destination = $Destination
                    Recurse = $true
                    Force = $true
                }
                if ($Verbose) { $copyParams['Verbose'] = $true }
                Copy-Item @copyParams
                Write-Host "Copied $Source to $Destination"
            }
            catch {
                Write-Warning "Failed to copy $Source`: $_"
                $CopyErrors += $Source
            }
        } else {
            Write-Warning "Source $Source does not exist"
            $CopyErrors += $Source
        }
    }
    
    if ($CopyErrors.Count -gt 0) {
        Write-Warning "WARNING: Errors occurred during copying:"
        $CopyErrors
        Write-Warning "------`nAbove source files had issues and could not be copied!"
    }
}

# Variable Definitions
$parentDir = Split-Path $PSScriptRoot -Parent

$BuildSource_Root = @(
    "Dependencies\Microsoft\WinPE_ADK\oscdimg.exe",
    "Dependencies\Microsoft\WinPE_ADK\Win11_WinPE_OCs"
) | ForEach-Object { Join-Path $parentDir $_ }

$BuildSource_ProgramFiles = @(
    "Dependencies\7-Zip\7-Zip",
    "Dependencies\AOMEI\AOMEIPartAssist",
    "Dependencies\Paehl\checkdisk_64bit",
    "Dependencies\ChrisHall\ChkDskGUI_x64",
    "Dependencies\CPUID\CPUID",
    "Dependencies\Defraggler\Defraggler",
    "Dependencies\JamSoftware\TreeSizeFree-Portable",
    "Dependencies\WinNTSetup\WinNTSetup4",
    "Dependencies\Wipefile\Wipefile"
) | ForEach-Object { Join-Path $parentDir $_ }

$BuildSource_System32 = @(
    "Dependencies\Microsoft\System32\*",
    "Dependencies\Dell\CCTK",
    "Dependencies\Explorer++\Explorer++.exe",
    "Dependencies\LaunchBar\LaunchBar_x64.exe",
    "Dependencies\Sysinternals\pslist64.exe",
    "Dependencies\Sysinternals\pskill64.exe",
    "Dependencies\Sysinternals\BGInfo\Bginfo64.exe"
) | ForEach-Object { Join-Path $parentDir $_ }

# Script Start
Write-Host "Validating expected files..."
# Validate all source paths
$missingPaths = @()
$allSourcePaths = $BuildSource_Root + $BuildSource_ProgramFiles + $BuildSource_System32

foreach ($path in $allSourcePaths) {
    if ($path -and -not (Test-Path $path)) {
        $missingPaths += $path
    }
}

if ($missingPaths.Count -gt 0) {
    Write-Error "ERROR: The following required files/directories are missing:"
    $missingPaths | ForEach-Object { Write-Output " - $_" }
    Write-Error "Please ensure all dependencies are present and try again."
    exit 1
} else {
    Write-Host "`nBasic file validation passed."
}

Write-Host ""
$border = "-" * 50
Write-Host $border -ForegroundColor Cyan
Write-Host "MurrpTools Dependencies and Staging" -ForegroundColor Green
Write-Host "Version: $MurrpToolsVersion" -ForegroundColor Green
Write-Host $border -ForegroundColor Cyan
Write-Host "`nThis script will copy all dependencies to the MurrpTools project folder, or Murrptools with dependencies installed to a different location."
Write-Host "`nPlease select one of the options below to prepare MurrpTools for building images."

# Get build location
$BuildLocation = Get-BuildLocation

# Define destination paths
$BuildDest_Root = $BuildLocation
$BuildDest_ProgramFiles = Join-Path $BuildLocation "BootFiles\Program Files\"
$BuildDest_System32 = Join-Path $BuildLocation "BootFiles\Windows\System32\"

# Execute the copy operations
Write-Host "`nCopying dependencies..."

$verbose = [bool]$PSCmdlet.MyInvocation.BoundParameters["Verbose"]

# Copy root items
Copy-Items -Destination $BuildDest_Root -SourcePaths $BuildSource_Root -Verbose:$verbose

# Copy custom program files
Copy-Items -Destination $BuildDest_ProgramFiles -SourcePaths $BuildSource_ProgramFiles -Verbose:$verbose

# Copy system32 files
Copy-Items -Destination $BuildDest_System32 -SourcePaths $BuildSource_System32 -Verbose:$verbose

Write-Host "`nCopy operations completed. Review any warnings above if any.`n"
Write-Host $border -ForegroundColor Cyan
Write-Host "`nPlease now naivate to $BuildLocation"
Write-Host "`nAdd any desired Windows PE Drivers to the WinPE_Drivers folder.`nIf you need help finding drivers, check the ReadMe file in that folder."
Write-Host "Once you are ready to build, run the '2 Build Windows Image.ps1' (or .cmd) script."
if (!($BuildPath)) {
    if ($BuildLocation -ne $PSScriptRoot) {
        Write-Host "`nPress any key to open the MurrpTools Build folder..."
        Pause
        Start-Process -FilePath "Explorer.exe" -ArgumentList $BuildLocation
    } else {
        Write-Host "`nPress any key to continue..."
        Pause
    }
}