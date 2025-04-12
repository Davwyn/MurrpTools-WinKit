@echo off
if not exist "%~dp0Harvest_Drivers.ps1" (
  echo Error: 1 Harvest_Drivers.ps1 not found.
  pause
  exit /b 1
)
powershell.exe -NoExit -ExecutionPolicy Bypass -File "%~dp0Harvest_Drivers.ps1"