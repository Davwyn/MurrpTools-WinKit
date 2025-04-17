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

.PARAMETER BuildSelf
If specified, the script will copy dependencies to the project directory itself. If both -BuildPath and -BuildSelf are provided, -BuildSelf takes precedence.

.EXAMPLE
PS> .\1 Dependencies and Staging.ps1
Shows the Folder Picker UI to select destination path

.EXAMPLE
PS> .\1 Dependencies and Staging.ps1 -BuildPath "C:\Build"
Copies dependencies to the specified build path

PS> .\1 Dependencies and Staging.ps1 -BuildSelf
Copies dependencies to the project directory itself.

.NOTES
When using the Folder Picker UI:
1. A dialog will appear allowing you to browse and select a destination folder
2. Click 'OK' to confirm your selection
3. The script will proceed with copying files to the selected location
#>

[CmdletBinding()]
param (
    [string]$BuildPath,
    [switch]$BuildSelf
)

$MurrpToolsVersion = "v0.1.7-Alpha"
# Initialize script file path
$ScriptFileName = $MyInvocation.MyCommand.Name
$MurrpToolsScriptPath = Resolve-Path $PSScriptRoot -ErrorAction Stop
$ProjectRootPath = $(Split-Path $MurrpToolsScriptPath -Parent)

# Function Definitions
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
        Write-Host "`nCopying MurrpTools folder to $DestinationPath (excluding $ScriptFileName)..." -ForegroundColor Yellow
        Copy-Item @copyParams -ErrorAction Stop
        Write-Host "`nMurrpTools folder copied." -ForegroundColor Green
    }
    catch {
        Log-Error "Failed to copy MurrpTools folder: $_"
        Pause
        Script-Exit $false
    }
}

function Get-BuildLocation {    
    # If the BuildSelf switch is set, use the script directory as the build path
    if ($BuildSelf -eq $true) {
        $BuildPath = $MurrpToolsScriptPath
    }

    # If BuildPath was provided, use it after validation
    if ($BuildPath) {
        # Resolve the path to handle relative paths and ensure it's absolute
        try {
            $BuildPath = Resolve-Path $BuildPath -ErrorAction Stop
        } catch {
            Log-Error "Path does not exist: $BuildPath"
            Script-Exit $false
        }

        # Verify path exists
        if (-not (Test-Path $BuildPath)) {
            Log-Error "Specified path does not exist"
            Script-Exit $false
        }
        
        # Verify path is not within script directory or subdirectories
        if (($BuildPath.ProviderPath -match [regex]::Escape($ProjectRootPath) -and ($BuildPath.ProviderPath -ne $MurrpToolsScriptPath.ProviderPath)) {
            Log-Error "Path ($BuildPath) cannot be a subdirectory of the project directory."
            Script-Exit $false
        }
        
        if ($BuildPath.ProviderPath -ne $MurrpToolsScriptPath.ProviderPath) {
            #Make MurrpTools directory when not using parent directory
            $BuildPath = Join-Path $BuildPath "MurrpTools"
            #Copy MurrpTools as it's a different location
            Copy-MurrpTools -SourcePath $MurrpToolsScriptPath -DestinationPath $BuildPath
            # Create completion file if location is different from script directory
            Write-CompletionFile -Path $BuildPath
        }
        
        return $BuildPath
    }
    
    # Offer location selection options
    Write-Host "`n`nThis script will copy all dependencies to the MurrpTools project folder, or Murrptools with dependencies installed to a different location." -ForegroundColor Cyan
    Write-Host "`nPlease select one of the options below to prepare MurrpTools for building images."
    Write-Host "Option 1: Use current location ($MurrpToolsScriptPath)"
    Write-Host "Option 2: Select a different using Folder Picker"
    $choice = Read-Host "`nEnter choice (1 or 2)"
    
    if ($choice -eq "1") {
        return $MurrpToolsScriptPath
    }
    elseif ($choice -eq "2") {
        # GUI folder picker
        Add-Type -AssemblyName System.Windows.Forms
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select build location"
        $folderBrowser.ShowNewFolderButton = $true
        
        if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            #Sleep for a moment to allow the dialog to close and folder to be created if the user makes a new folder
            Start-Sleep 2
            #Validate the selected path
            try {
                $selectedPath = Resolve-Path $folderBrowser.SelectedPath -ErrorAction Stop
            } catch {
                Log-Error "Path does not exist: $selectedPath"
                Script-Exit $false
            }
    
            # Verify path exists
            if (-not (Test-Path $selectedPath)) {
                Log-Error "Specified path does not exist"
                Script-Exit $false
            }
            
            # Verify path is not within script directory or subdirectories
            if (($selectedPath.ProviderPath -match [regex]::Escape($ProjectRootPath)) -and ($selectedPath.ProviderPath -ne $MurrpToolsScriptPath.ProviderPath)) {
                Log-Error "Path ($selectedPath) cannot be a subdirectory of the project directory."
                Script-Exit $false
            }
            
            if ($selectedPath.ProviderPath -ne $MurrpToolsScriptPath.ProviderPath) {
                #Make MurrpTools directory when not using parent directory
                $selectedPath = Join-Path $selectedPath "MurrpTools"
                #Copy MurrpTools as it's a different location
                Copy-MurrpTools -SourcePath $MurrpToolsScriptPath -DestinationPath $selectedPath
                # Create completion file if location is different from script directory
                Write-CompletionFile -Path $selectedPath
            }
            
            return $selectedPath
        }
        else {
            Log-Warning "Folder selection was cancelled"
            Script-Exit $false
        }
    }
    else {
        Log-Warning "Invalid selection"
        Script-Exit $false
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
        Log-Error "Failed to create directory $Destination`: $_"
        Script-Exit $false
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
                Copy-Item @copyParams -ErrorAction Stop
                Write-Host "`nCopied $Source`nTo $Destination"
            }
            catch {
                Log-Warning "Failed to copy $Source`: $_"
                $CopyErrors += $Source
            }
        } else {
            Log-Warning "Source $Source does not exist"
            $CopyErrors += $Source
        }
    }
    
    if ($CopyErrors.Count -gt 0) {
        Log-Warning "WARNING: Errors occurred during copying:"
        $CopyErrors
        Log-Warning "------`nAbove source files had issues and could not be copied!"
    }
}

function Expand-Dependencies {
    $7ZipPath = [System.IO.Path]::GetFullPath("$ProjectRootPath\Dependencies\7-Zip\7-Zip\7z.exe"),
    $ArchivePath = [System.IO.Path]::GetFullPath("$ProjectRootPath\Dependencies\Dependencies.7z.001"),
    $ExtractTo = [System.IO.Path]::GetFullPath("$ProjectRootPath\Dependencies")

    if (Test-Path $ArchivePath) {
        Write-Host "`nThe dependencies have not yet been extracted. Press enter to extract them now." -ForegroundColor Yellow
        Pause
        
        Write-Host "`nFound dependencies archive: $ArchivePath. Extracting contents..." -ForegroundColor Yellow
        if (Test-Path $7ZipPath) {
            Write-Host "7-Zip found at: $7ZipPath" -ForegroundColor Green
        } else {
            Log-Error "7-Zip not found at $7ZipPath. This is a required dependency."
            Script-Exit $false
        }
        try {
            # Run 7-Zip to extract the archive using Start-Process with -PassThru
            $process = Start-Process -FilePath $7ZipPath -ArgumentList "x `"$ArchivePath`" -o`"$ExtractTo`" -y" -NoNewWindow -Wait -PassThru
            if ($process.ExitCode -eq 0) {
                Write-Host "`nExtraction completed successfully." -ForegroundColor Green

                # Delete all matching archive parts
                Get-ChildItem -Path $ExtractTo -Filter "Dependencies.7z.*" | ForEach-Object {
                    Remove-Item -Path $_.FullName -Force
                }
                Write-Host "`nCleaned up dependency archives." -ForegroundColor Green
            } else {
                Log-Error "7-Zip extraction failed with exit code $($process.ExitCode)."
                Script-Exit $false
            }
        } catch {
            Log-Error "An error occurred during extraction: $_"
            Script-Exit $false
        }
    } else {
        Write-Host "No archive found at $ArchivePath. Skipping extraction." -ForegroundColor Cyan
    }
}

# Variable Definitions
$BuildSource_Root = @(
    "Dependencies\Microsoft\WinPE_ADK\oscdimg.exe",
    "Dependencies\Microsoft\WinPE_ADK\Win11_WinPE_OCs",
    "Dependencies\Microsoft\WinPE_ADK\Win10_WinPE_OCs"
) | ForEach-Object { Join-Path $ProjectRootPath $_ }

$BuildSource_ProgramFiles = @(
    "Dependencies\7-Zip\7-Zip",
    "Dependencies\PE Network Manager\PENetwork_x64",
    "Dependencies\AOMEI\AOMEIPartAssist",
    "Dependencies\Paehl\checkdisk_64bit",
    "Dependencies\ChrisHall\ChkDskGUI_x64",
    "Dependencies\CPUID\CPUID",
    "Dependencies\Defraggler\Defraggler",
    "Dependencies\JamSoftware\TreeSizeFree-Portable",
    "Dependencies\WinNTSetup\WinNTSetup4",
    "Dependencies\Wipefile\Wipefile",
    "Dependencies\Mozilla\Firefox",
    "Dependencies\VideoLAN\VLC"
) | ForEach-Object { Join-Path $ProjectRootPath $_ }

$BuildSource_System32 = @(
    "Dependencies\Microsoft\System32\*",
    "Dependencies\Dell\CCTK",
    "Dependencies\Explorer++\Explorer++.exe",
    "Dependencies\LaunchBar\LaunchBar_x64.exe",
    "Dependencies\Sysinternals\pslist64.exe",
    "Dependencies\Sysinternals\pskill64.exe",
    "Dependencies\Sysinternals\BGInfo\Bginfo64.exe",
    "Dependencies\CMartinezone\BitLockerUtility\BitLockerUtility.ps1"
) | ForEach-Object { Join-Path $ProjectRootPath $_ }

$BuildSource_DebloatTools = @(
    "Dependencies\PE Network Manager\PENetwork_x64"
) | ForEach-Object { Join-Path $ProjectRootPath $_ }

#Add D.A.R.T components if available
if (Test-Path "$ProjectRootPath\Dependencies\Microsoft\DART") {
    $BuildSource_BootFiles = @(
        "Dependencies\Microsoft\DART\sources",
        "Dependencies\Microsoft\DART\Windows"
    ) | ForEach-Object { Join-Path $ProjectRootPath $_ }
} else {
    $BuildSource_BootFiles = $null
}

# Script Start
Write-Host ""
$border = "-" * 50
Write-Host $border -ForegroundColor Cyan
Write-Host "MurrpTools Dependencies and Staging" -ForegroundColor Green
Write-Host "Version: $MurrpToolsVersion" -ForegroundColor Green
Write-Host $border -ForegroundColor Cyan

#Extract dependencies if they are not already extracted
Expand-Dependencies

Write-Host "`nValidating expected files..." -ForegroundColor Yellow
# Validate all source paths
$missingPaths = @()
$allSourcePaths = $BuildSource_Root + $BuildSource_ProgramFiles + $BuildSource_System32 + $BuildSource_DebloatTools + $BuildSource_BootFiles

foreach ($path in $allSourcePaths) {
    if ($path -and -not (Test-Path $path)) {
        $missingPaths += $path
    }
}

if ($missingPaths.Count -gt 0) {
    Log-Error "ERROR: The following required files/directories are missing:"
    $missingPaths | ForEach-Object { Write-Output " - $_" }
    Log-Error "Please ensure all dependencies are present and try again."
    Script-Exit $false
} else {
    Write-Host "`nBasic file validation passed." -ForegroundColor Green
}

# Get build location
$BuildLocation = Get-BuildLocation
$BuildLocation = Resolve-Path $BuildLocation -ErrorAction Stop

# Define destination paths
$BuildDest_Root = $BuildLocation
$BuildDest_ProgramFiles = Join-Path $BuildLocation "BootFiles\Program Files\"
$BuildDest_System32 = Join-Path $BuildLocation "BootFiles\Windows\System32\"
$BuildDest_DebloatTools = Join-Path $BuildLocation "MediaFiles\`$OEM`$\`$1\DebloatTools"
$BuildDest_BootFiles = Join-Path $BuildLocation "BootFiles\"

# Execute the copy operations
Write-Host "`nCopying dependencies..." -ForegroundColor Yellow

try {
    $verbose = [bool]$PSCmdlet.MyInvocation.BoundParameters["Verbose"]
    # Copy root items
    Copy-Items -Destination $BuildDest_Root -SourcePaths $BuildSource_Root -Verbose:$verbose -ErrorAction Stop    
    # Copy custom program files
    Copy-Items -Destination $BuildDest_ProgramFiles -SourcePaths $BuildSource_ProgramFiles -Verbose:$verbose -ErrorAction Stop
    # Copy system32 files
    Copy-Items -Destination $BuildDest_System32 -SourcePaths $BuildSource_System32 -Verbose:$verbose -ErrorAction Stop
    # Copy Media files
    Copy-Items -Destination $BuildDest_DebloatTools -SourcePaths $BuildSource_DebloatTools -Verbose:$verbose -ErrorAction Stop
    # Copy additional boot files if they exist
    if ($BuildSource_BootFiles) {
        Copy-Items -Destination $BuildDest_BootFiles -SourcePaths $BuildSource_BootFiles -Verbose:$verbose -ErrorAction Stop
    }
} catch {
    Log-Error "Failed to copy dependencies: $_"
    Script-Exit $false
}

Write-Host "`nCopy operations completed. Review any warnings above if any.`n" -ForegroundColor Green
Write-Host $border -ForegroundColor Cyan
Write-Host "`nPlease now navigate to $BuildLocation"
Write-Host "`nAdd any desired Windows PE Drivers to the WinPE_Drivers folder.`nIf you need help finding drivers, check the ReadMe file in that folder."
Write-Host "Once you are ready to build, run the '2 Build Windows Image.ps1' (or .cmd) script."
if (!($BuildPath)) {
    if ($BuildLocation.ProviderPath -ne $MurrpToolsScriptPath.ProviderPath) {
        Write-Host "`nPress any key to open the MurrpTools Build folder..."
        Pause
        Start-Process -FilePath "Explorer.exe" -ArgumentList $BuildLocation
        Script-Exit $true
    } else {
        Script-Exit $true
    }
}