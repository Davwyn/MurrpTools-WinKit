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

$MurrpToolsVersion = "v1.2.1"

$verbose = [bool]$PSCmdlet.MyInvocation.BoundParameters["Verbose"]

# Check if the operating system is Windows and refuse to run if not
if ($env:OS -notlike "*Windows*") {
    Write-Host "This script is designed to run only on Windows operating systems." -ForegroundColor Yellow
    Write-Host "Please use a Windows system and try again." -ForegroundColor Yellow
    Read-Host -Prompt "Press enter to continue..."
    exit 1
}

function Exit-Script {
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
        if ((!($BuildPath)) -and (!($BuildSelf))) {
            Read-Host -Prompt "Press enter to continue..."
        } else {
            Write-Host "`nScript will exit in 5 seconds..." -ForegroundColor Green
            Start-Sleep -Seconds 5
        }
        exit 0
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
        $CombinedPath = [System.IO.Path]::Combine($Path1,$Path2) #Must use this instead of Join-Path because Microsoft PowerShell's internal commands are garbage.
        Write-Verbose "Combined path: $CombinedPath"
        return $CombinedPath
    } catch {
        Write-ErrorLog "Failed to combine paths: $_"
        Exit-Script $false
    }
}

# Normalize paths for accurate comparison, removing \\?\ prefix if present
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

# Initialize script file path
$ScriptFileName = $MyInvocation.MyCommand.Name
$MurrpToolsScriptPath = (Resolve-Path -Path $PSScriptRoot -ErrorAction Stop | Select-Object -ExpandProperty ProviderPath)
$ProjectRootPath = Split-Path $MurrpToolsScriptPath -Parent

# Function Definitions
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

function Write-CompletionFile {
    param (
        [string]$Path
    )
    $completionFile = Join-PathImproved $Path "1 Dependencies and Staging Complete.txt"
    "Dependencies and Staging step is complete.`nYou can now run `"2 Build MurrpTools Image.cmd`" to build the MurrpTools image." | Out-File $completionFile
}

function Copy-MurrpTools {
    param (
        [string]$SourcePath,
        [string]$DestinationPath,
        [bool]$Verbose = $false
    )

    # Santize paths
    $SourcePath = Get-NormalizedPath $SourcePath
    $DestinationPath = Get-NormalizedPath $DestinationPath
    
    $copyParams = @{
        Path = "$SourcePath"
        Destination = $DestinationPath.TrimEnd('\') + '\'
        Recurse = $true
        Force = $true
        Exclude = $ScriptFileName,"1 Dependencies and Staging.cmd"
        Verbose = $verbose
    }
    
    try {
        Write-Host "`nCopying MurrpTools folder from $SourcePath to $DestinationPath (excluding $ScriptFileName)..." -ForegroundColor Yellow
        Copy-Item @copyParams -ErrorAction Stop
        Write-Host "`nMurrpTools folder copied." -ForegroundColor Green
    }
    catch {
        Write-ErrorLog "Failed to copy MurrpTools folder: $_"
        Read-Host -Prompt "Press enter to continue..."
        Exit-Script $false
    }
}

function Select-BuildLocation {
    param (
        $BuildPath
    )
    
    if (-not (Test-Path -Path $BuildPath -ErrorAction SilentlyContinue)) {
        Write-ErrorLog "Path does not exist: $BuildPath"
        Exit-Script $false
    }
    
    if ($BuildPath -match '^\\\\\?\\') {
        Write-ErrorLog "UNC paths (starting with \\?\) are not supported. Please select a different path."
        Exit-Script $false
    }
    
    # Check if Long Path support is enabled
    $longPathEnabled = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -ErrorAction SilentlyContinue).LongPathsEnabled -eq 1
    if (-not($longPathEnabled)) {
        $maxAllowedLength = 260 - 152
        if ($($BuildPath.Length) -gt $maxAllowedLength) {
            Write-Warning "The selected path is too long. Windows Long Path support is not enabled, and the total path length exceeds the allowed limit of $maxAllowedLength characters."
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
                Write-ErrorLog "The selected path is too long, and Long Path support is not enabled. Please enable Long Path support or select a shorter folder path."
                Exit-Script $false
            }
        }
    }

    # Verify path is not within script directory or subdirectories
    if (($(Get-NormalizedPath $BuildPath) -match [regex]::Escape($(Get-NormalizedPath $ProjectRootPath))) -and ($(Get-NormalizedPath $BuildPath) -ne $(Get-NormalizedPath $MurrpToolsScriptPath))) {
        Write-ErrorLog "Path ($BuildPath) cannot be a subdirectory of the project directory."
        Exit-Script $false
    }
    # If the build path is different from the script directory, copy MurrpTools folder
    if ($(Get-NormalizedPath $BuildPath) -ne $(Get-NormalizedPath $MurrpToolsScriptPath)) {
        # Make MurrpTools directory when not using parent directory
        $BuildPath = Join-PathImproved $BuildPath "MurrpTools"
        # Copy MurrpTools as it's a different location
        Copy-MurrpTools -SourcePath $MurrpToolsScriptPath -DestinationPath $BuildPath
    }
    Write-Host "BuildDrive set to: $BuildPath" -ForegroundColor Magenta
    return $BuildPath
}

function Get-BuildLocation {    
    # If the BuildSelf switch is set, use the script directory as the build path
    if ($BuildSelf -eq $true) {
        $BuildPath = $MurrpToolsScriptPath
        Write-Host "`nUsing current location: $BuildPath" -ForegroundColor Green
    }

    # If BuildPath was provided, use it after validation
    if ($BuildPath) {
        # Resolve the path to handle relative paths and ensure it's absolute        
        return Select-BuildLocation $BuildPath
    }
    
    # Offer location selection options
    Write-Host "`n`nThis script will copy all dependencies to the MurrpTools project folder, or MurrpTools with dependencies installed to a different location." -ForegroundColor Cyan
    Write-Host "`nPlease select one of the options below to prepare MurrpTools for building images."
    Write-Host "Option 1: Use current location ($(Get-NormalizedPath $MurrpToolsScriptPath))"
    Write-Host "Option 2: Select a different using Folder Picker. A new MurrpTools folder will be created there."
    $choice = Read-Host "`nEnter choice (1 or 2)"
    
    if ($choice -eq "1") {
        
        return Select-BuildLocation $MurrpToolsScriptPath
    }
    elseif ($choice -eq "2") {
        # GUI folder picker
        Add-Type -AssemblyName System.Windows.Forms
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select build location"
        $folderBrowser.ShowNewFolderButton = $true

        if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $BuildPath = $folderBrowser.SelectedPath
            if (-not [string]::IsNullOrWhiteSpace($BuildPath)) {
                Write-Host "`nSelected build location: $BuildPath" -ForegroundColor Green
                return Select-BuildLocation $BuildPath
            } else {
                Write-ErrorLog "No valid path was selected. Please try again."
                Exit-Script $false
            }
        } else {
            Write-WarningLog "Folder selection was cancelled"
            Exit-Script $false
        }
    }
    else {
        Write-WarningLog "Invalid selection"
        Exit-Script $false
    }
}

function Copy-Items {
    param (
        [string]$Destination,
        [array]$SourcePaths,
        [bool]$Verbose = $false
    )

    # Sanitize destination path
    $Destination = Get-NormalizedPath $Destination

    # Create destination directory if it doesn't exist
    try {
        if (-not (Test-Path -Path $Destination)) {
            New-Item -ItemType Directory -Path $Destination -ErrorAction Stop -Verbose:$verbose | Out-Null
        }
    }
    catch {
        Write-ErrorLog "Failed to create directory $Destination`: $_"
        Exit-Script $false
    }

    $CopyErrors = @()
    foreach ($Source in $SourcePaths) {
        # Sanitize source path
        $Source = Get-NormalizedPath $Source
        if (Test-Path -Path $Source) {
            try {
                $copyParams = @{
                    Path = $Source
                    Destination = $Destination.TrimEnd('\') + '\'
                    Recurse = $true
                    Force = $true
                    Verbose = $verbose
                }
                Write-Host "`nCopying $Source`nTo $Destination"
                Copy-Item @copyParams -ErrorAction Stop
            }
            catch {
                Write-WarningLog "Failed to copy $Source`: $_"
                $CopyErrors += $Source
            }
        } else {
            Write-WarningLog "Source $Source does not exist"
            $CopyErrors += $Source
        }
    }
    
    if ($CopyErrors.Count -gt 0) {
        Write-ErrorLog "WARNING: Errors occurred during copying:`n$CopyErrors"
        Write-Host "------`nAbove source files had issues and could not be copied!"
    }
}

function Expand-Dependencies {
    $7ZipPath = [System.IO.Path]::GetFullPath("$ProjectRootPath\Dependencies\7-Zip\7-Zip\7z.exe")
    $ArchivePath = [System.IO.Path]::GetFullPath("$ProjectRootPath\Dependencies\Dependencies.7z.001")
    $ExtractTo = [System.IO.Path]::GetFullPath("$ProjectRootPath\Dependencies")

    if (Test-Path -Path $ArchivePath) {
        Write-Host "`nThe dependencies have not yet been extracted. Please wait as they're automatically unpacked." -ForegroundColor Yellow
        Start-Sleep -Seconds 4
        
        Write-Host "`nFound dependencies archive: $ArchivePath. Extracting contents..." -ForegroundColor Yellow
        if (Test-Path -Path $7ZipPath) {
            Write-Host "7-Zip found at: $7ZipPath" -ForegroundColor Green
        } else {
            Write-ErrorLog "7-Zip not found at $7ZipPath. This is a required dependency."
            Exit-Script $false
        }
        try {
            # Run 7-Zip to extract the archive using Start-Process with -PassThru
            $process = Start-Process -FilePath $7ZipPath -ArgumentList "x `"$ArchivePath`" -o`"$ExtractTo`" -y" -NoNewWindow -Wait -PassThru -Verbose:$verbose
            if ($process.ExitCode -eq 0) {
                Write-Host "`nExtraction completed successfully." -ForegroundColor Green

                # Delete all matching archive parts
                Get-ChildItem -Path $ExtractTo -Filter "Dependencies.7z.*" | ForEach-Object {
                    Remove-Item -Path $_.FullName -Force -Verbose:$verbose
                }
                Write-Host "`nCleaned up dependency archives." -ForegroundColor Green
            } else {
                Write-ErrorLog "7-Zip extraction failed with exit code $($process.ExitCode)."
                Exit-Script $false
            }
        } catch {
            Write-ErrorLog "An error occurred during extraction: $_"
            Exit-Script $false
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
) | ForEach-Object { Join-PathImproved $ProjectRootPath $_ }

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
    "Dependencies\VideoLAN\VLC",
    "Dependencies\CrystalMark\Crystal Disk Info"
) | ForEach-Object { Join-PathImproved $ProjectRootPath $_ }

$BuildSource_Windows = @(
    "Dependencies\Microsoft\System32\"
) | ForEach-Object { Join-PathImproved $ProjectRootPath $_ }

$BuildSource_System32 = @(
    "Dependencies\Dell\CCTK",
    "Dependencies\Explorer++\Explorer++.exe",
    "Dependencies\LaunchBar\LaunchBar_x64.exe",
    "Dependencies\Sysinternals\pslist64.exe",
    "Dependencies\Sysinternals\pskill64.exe",
    "Dependencies\Sysinternals\BGInfo\Bginfo64.exe",
    "Dependencies\CMartinezone\BitLockerUtility\BitLockerUtility.ps1",
    "Dependencies\Putty\Putty.exe"
) | ForEach-Object { Join-PathImproved $ProjectRootPath $_ }

$BuildSource_DebloatTools = @(
    "Dependencies\PE Network Manager\PENetwork_x64"
) | ForEach-Object { Join-PathImproved $ProjectRootPath $_ }

# Add D.A.R.T components if available
if (Test-Path -Path "$ProjectRootPath\Dependencies\Microsoft\DART") {
    $BuildSource_BootFiles = @(
        "Dependencies\Microsoft\DART\sources",
        "Dependencies\Microsoft\DART\Windows"
    ) | ForEach-Object { Join-PathImproved $ProjectRootPath $_ }
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

# Verify running as administrator
$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not ($currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
    Write-ErrorLog "This script must be run as administrator."
    Exit-Script $false
}

# Extract dependencies if they are not already extracted
Expand-Dependencies

Write-Host "`nValidating expected files..." -ForegroundColor Yellow
# Validate all source paths
$missingPaths = @()
$allSourcePaths = $BuildSource_Root + $BuildSource_ProgramFiles + $BuildSource_Windows + $BuildSource_System32 + $BuildSource_DebloatTools + $BuildSource_BootFiles

foreach ($path in $allSourcePaths) {
    if ($path -and -not (Test-Path $path)) {
        $missingPaths += $path
    }
}

if ($missingPaths.Count -gt 0) {
    Write-ErrorLog "ERROR: The following required files/directories are missing:"
    $missingPaths | ForEach-Object { Write-Output " - $_" }
    Write-ErrorLog "Please ensure all dependencies are present and try again."
    Exit-Script $false
} else {
    Write-Host "`nBasic file validation passed." -ForegroundColor Green
}

# Get build location
$BuildLocation = Get-BuildLocation

# Define destination paths
Write-Host "`nPreparing to copy dependencies to BuildDrive: $BuildLocation" -ForegroundColor Yellow
$BuildDest_Root = $BuildLocation
$BuildDest_ProgramFiles = Join-PathImproved $BuildLocation "BootFiles\Program Files"
$BuildDest_Windows = Join-PathImproved $BuildLocation "BootFiles\Windows"
$BuildDest_System32 = Join-PathImproved $BuildLocation "BootFiles\Windows\System32"
$BuildDest_DebloatTools = Join-PathImproved $BuildLocation "MediaFiles\`$OEM`$\`$1\DebloatTools"
$BuildDest_BootFiles = Join-PathImproved $BuildLocation "BootFiles"

# Execute the copy operations
Write-Host "`nCopying dependencies..." -ForegroundColor Yellow

try {
    # Copy root items
    Copy-Items -Destination $BuildDest_Root -SourcePaths $BuildSource_Root -Verbose:$verbose -ErrorAction Stop    
    # Copy custom program files
    Copy-Items -Destination $BuildDest_ProgramFiles -SourcePaths $BuildSource_ProgramFiles -Verbose:$verbose -ErrorAction Stop
    # Windows directory files
    Copy-Items -Destination $BuildDest_Windows -SourcePaths $BuildSource_Windows -Verbose:$verbose -ErrorAction Stop
    # Copy system32 files
    Copy-Items -Destination $BuildDest_System32 -SourcePaths $BuildSource_System32 -Verbose:$verbose -ErrorAction Stop
    # Copy Media files
    Copy-Items -Destination $BuildDest_DebloatTools -SourcePaths $BuildSource_DebloatTools -Verbose:$verbose -ErrorAction Stop
    # Copy additional boot files if they exist
    if ($BuildSource_BootFiles) {
        Copy-Items -Destination $BuildDest_BootFiles -SourcePaths $BuildSource_BootFiles -Verbose:$verbose -ErrorAction Stop
    }
} catch {
    Write-ErrorLog "Failed to copy dependencies: $_"
    Exit-Script $false
}

Write-CompletionFile -Path $BuildLocation

Write-Host "`nCopy operations completed. Review any warnings above if any.`n" -ForegroundColor Green
Write-Host $border -ForegroundColor Cyan
Write-Host "`nPlease now navigate to $(Join-PathImproved $($BuildLocation) 'MurrpTools') to continue building your Windows Image."
Write-Host "`nAdd any desired Windows PE Drivers to the WinPE_Drivers folder.`nIf you need help finding drivers, check the ReadMe file in that folder."
Write-Host "`nYou can also enable or disable any desired Debloat Tools by editing the DebloatTools.json file in the MurrpTools folder."
Write-Host "`n`nOnce you are ready to build, run the '2 Build Windows Image.ps1' (or .cmd) script."
if ((!($BuildPath)) -and (!($BuildSelf))) {
    if ($BuildLocation -ne $MurrpToolsScriptPath) {
        Write-Host "`nNote: If you staged MurrpTools to a different location, ensure you run the build script from that location." -ForegroundColor Yellow
        Write-Host "`nPress any key to open the MurrpTools Build folder..."
        Read-Host -Prompt "Press enter to continue..."
        Start-Process -FilePath "Explorer.exe" -ArgumentList $BuildLocation
    }
}
Exit-Script $true