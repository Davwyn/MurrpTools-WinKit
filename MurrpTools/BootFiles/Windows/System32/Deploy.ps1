foreach( $drive in [System.IO.DriveInfo]::GetDrives() ) {
    $MurrpToolsSource = Join-Path -Path $drive.RootDirectory -ChildPath 'MurrpToolsDebloatUnattend.xml' -Resolve -ErrorAction 'SilentlyContinue';
    if( $MurrpToolsSource ) {
        Write-Host "Located MurrpToolsDebloatUnattend.xml at $MurrpToolsSource"
        $MurrpToolsSource = $(Split-Path -Path $MurrpToolsSource -Parent)
        break
    }
}

foreach( $drive in [System.IO.DriveInfo]::GetDrives() ) {
    $HarvestDriversSource = Join-Path -Path $drive.RootDirectory -ChildPath 'Harvest_Drivers.ps1' -Resolve -ErrorAction 'SilentlyContinue';
    if( $HarvestDriversSource ) {
        Write-Host "Harvest_Drivers.ps1 at $HarvestDriversSource"
        break
    }
}

$MurrpToolsVersion = Get-ItemProperty -Path "HKCU:\\MurrpTools" -Name "MurrpToolsVersion" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "MurrpToolsVersion"

Write-Host ""
$border = "-" * 50
Write-Host $border -ForegroundColor Cyan
Write-Host "MurrpTools Windows Deployer`nMurrpTools Version: $MurrpToolsVersion" -ForegroundColor Green
Write-Host $border -ForegroundColor Cyan
Start-Sleep 3

if ($HarvestDriversSource) {
	& $HarvestDriversSource -FindOfflineImage
	Write-Host "`n"
}

if ($MurrpToolsSource) {
	Start-Sleep 2
	$InstallProcess = Start-Process -FilePath "$env:systemdrive\sources\setup.exe" -ArgumentList "/unattend:$MurrpToolsSource\MurrpToolsDebloatUnattend.xml /noreboot" -Wait -PassThru
    if ($InstallProcess.ExitCode -eq 0) {
        Write-Host "`nInstall completed successfully."
    } else {
        Write-Host "`nInstall process failed with exit code: $($InstallProcess.ExitCode) `nAborting any additional setup."
        Pause
        Return 1
    }
    Start-Sleep 2
    foreach( $drive in [System.IO.DriveInfo]::GetDrives() ) {
        $WinInstallLocation = Join-Path -Path $drive.RootDirectory -ChildPath 'MurrpToolsInstallationLocation' -Resolve -ErrorAction 'SilentlyContinue';
        if( $WinInstallLocation ) {
            Write-Host "`nLocated MurrpToolsInstallationLocation at $WinInstallLocation"
            Remove-Item $WinInstallLocation -Force
            $WinInstallLocation = $(Split-Path -Path $WinInstallLocation -Parent)
            break
        }
    }
    $model = $(get-wmiobject Win32_ComputerSystem).Model
    Write-Host "`nSystem Model Detected: $model"
    if (Test-Path -Path "$MurrpToolsSource\Drivers\$model") {
        Write-Host "`nFound drivers for your system."
        if ($WinInstallLocation) {
            Write-Host "`nInjecting drivers into your new Windows installation..."
            dism /add-driver /image:$WinInstallLocation /driver:"$MurrpToolsSource\Drivers\$model" /Recurse
            Write-Host "`n`nDriver injection should be complete.`nPress enter to restart or close the window to prevent restart.`n"
            Pause
            Write-Host "`nRestarting...`n"
            wpeutil reboot
        } else {
            Write-Warning "Unable to find your Windows installation. Unable to inject drivers into the installation for you."
            Pause
        }
    } else {
        Write-Host "`nNo available drivers detected for your system setup will continue with default Windows drivers.`nPress enter to restart or close the window to prevent restart.`n"
        Pause
        Write-Host "`nRestarting...`n"
        wpeutil reboot
    }
} else {
	"`nCould not find the MurrpToolsDebloatUnattend.xml unable to run the installer with debloat." | Write-Warning
	Pause
}