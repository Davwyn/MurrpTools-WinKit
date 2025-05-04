# Position Window code
# Load the required assembly for screen dimensions
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class WinAPI {
    [DllImport("user32.dll")]
    public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);
    
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
}
"@

# Get screen width and height dynamically
$screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
$screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height

# Define window size
$windowWidth = 500
$windowHeight = 370

# Calculate bottom-right position
$x = $screenWidth - $windowWidth - 40  # Near Right edge
$y = $screenHeight - $windowHeight  # Bottom edge

# Get all processes with main window handles
$windows = @(Get-Process | Where-Object { $_.MainWindowHandle -ne 0 })

foreach ($proc in $windows) {
    $hWnd = $proc.MainWindowHandle
    $procID = 0
    [WinAPI]::GetWindowThreadProcessId($hWnd, [ref]$procID)

    # Get the actual window title
    $title = New-Object System.Text.StringBuilder 256
    [WinAPI]::GetWindowText($hWnd, $title, $title.Capacity)

    if ($title.ToString() -match "MurrpTools Launcher") {
        [WinAPI]::SetWindowPos($hWnd, [IntPtr]::Zero, $x, $y, $windowWidth, $windowHeight, 0x0040)
        break
    }
}
# End Position Window code

function Maximize-Window {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();
    }
"@

    $hwnd = [Win32]::GetForegroundWindow()
    [Win32]::ShowWindow($hwnd, 3) # 3 is the code for SW_MAXIMIZE
}

function Restore-Window {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();
    }
"@

    $hwnd = [Win32]::GetForegroundWindow()
    [Win32]::ShowWindow($hwnd, 1) # 1 is the code for SW_SHOWNORMAL
}

foreach( $drive in [System.IO.DriveInfo]::GetDrives() ) {
    $HarvestDriversSource = Join-Path -Path $drive.RootDirectory -ChildPath 'Harvest_Drivers.ps1' -Resolve -ErrorAction 'SilentlyContinue';
    if( $HarvestDriversSource ) {
        break
    }
}

function Disable-Win11Requirements {
    reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f
    reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f
    reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f
}
$MurrpToolsVersion = Get-ItemProperty -Path "HKCU:\\MurrpTools" -Name "MurrpToolsVersion" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "MurrpToolsVersion"
# Define the header text
$Header = "MurrpTools Launcher Menu`nMurrpTools Version: $MurrpToolsVersion"

# Get all .lnk files in Quick Launch and Start Menu directories
$QuickLaunch = Get-ChildItem -Path "X:\Windows\System32\config\systemprofile\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch" -Filter *.lnk
if ($QuickLaunch) {
    $QuickLaunch = $QuickLaunch | Where-Object { $_.Name -ne "Start Menu.lnk" }
}

$StartMenu = Get-ChildItem -Path "X:\Windows\System32\config\systemprofile\AppData\Roaming\Microsoft\Windows\Start Menu" -Filter *.lnk

# Reorder specific items to the top if they exist
$priorityOrder = @("Install Windows with MurrpTools.lnk", "Install Windows without tools.lnk", "PowerShell.lnk", "Explorer++.lnk", "Restart Computer.lnk")
$QuickLaunch = @(
    $priorityOrder | ForEach-Object {
        $priorityItem = $_
        $item = $QuickLaunch | Where-Object { $_.Name -eq "$priorityItem" }
        if ($item) { $item }
    }
) + ($QuickLaunch | Where-Object { $priorityOrder -notcontains $_.Name })

$QuickLaunchAdditions = [ordered]@{}

$QuickLaunchAdditions["Bypass Windows 11 Requirements for Generic Setup"] = "Disable-Win11Requirements"
if ($HarvestDriversSource) {$QuickLaunchAdditions["Harvest Drivers"] = $HarvestDriversSource}
if (Test-Path "$env:SystemRoot\System32\BitLockerUtility.ps1") {$QuickLaunchAdditions["BitLocker Utility"] = "$env:SystemRoot\System32\BitLockerUtility.ps1"}
$QuickLaunchAdditions["Notepad"] = "notepad.exe"
$QuickLaunchAdditions["Maximize This Menu"] = "Maximize-Window"
$QuickLaunchAdditions["Window This Menu"] = "Restore-Window"

# Combine Quick Launch items with additional items
$QuickLaunch = $QuickLaunch + @($QuickLaunchAdditions.GetEnumerator() | ForEach-Object {
    New-Object PSObject -Property @{
        Name = $_.Key
        FullName = $_.Value
        IsCommand = $true
    }
})

function Show-Menu {
    param (
        [string]$MenuHeader,
        [array]$MenuItems,
        [string]$BackOption = ""
    )
    $host.UI.RawUI.WindowTitle = "MurrpTools Launcher"
    Clear-Host
    Write-Host $Header -ForegroundColor Green
    Write-Host "====================" -ForegroundColor Cyan
    Write-Host $MenuHeader -ForegroundColor Yellow
    Write-Host "====================" -ForegroundColor Cyan

    for ($i = 0; $i -lt $MenuItems.Count; $i++) {
        $displayName = $MenuItems[$i].Name -replace '\.lnk$', ''
        Write-Host "$($i + 1). $displayName"
    }

    if ($BackOption) {
        Write-Host "0. $BackOption"
    }

    Write-Host "====================" -ForegroundColor Cyan
    $selection = Read-Host "Please select an option"
    return $selection
}

function Launch-Item {
    param (
        [string]$ItemPath,
        [bool]$IsCommand = $false
    )

    if ($IsCommand) {
        Invoke-Expression $ItemPath
    } else {
        Start-Process -FilePath $ItemPath -WindowStyle Maximized
    }
}

while ($true) {
    $selection = Show-Menu -MenuHeader "Quick Launch" -MenuItems $QuickLaunch -BackOption "Start Menu..."

    if ([int]::TryParse($selection, [ref]$null)) {
        $selection = [int]$selection

        if ($selection -eq 0) {
            $subSelection = Show-Menu -MenuHeader "Start Menu" -MenuItems $StartMenu -BackOption "Quick Launch..."

            if ([int]::TryParse($subSelection, [ref]$null)) {
                $subSelection = [int]$subSelection

                if ($subSelection -eq 0) {
                    continue
                } elseif ($subSelection -le $StartMenu.Count) {
                    Launch-Item -ItemPath $StartMenu[$subSelection - 1].FullName
                } else {
                    Write-Host "Invalid selection. Please try again."
                    Start-Sleep 1
                }
            } else {
                Write-Host "Invalid selection. Please try again."
                Start-Sleep 1
            }
        } elseif ($selection -le $QuickLaunch.Count) {
            $selectedItem = $QuickLaunch[$selection - 1]
            Launch-Item -ItemPath $selectedItem.FullName -IsCommand $selectedItem.PSObject.Properties.Match("IsCommand").Count -gt 0
        } else {
            Write-Host "Invalid selection. Please try again."
            Start-Sleep 1
        }
    } else {
        Write-Host "Invalid selection. Please try again."
        Start-Sleep 1
    }
}