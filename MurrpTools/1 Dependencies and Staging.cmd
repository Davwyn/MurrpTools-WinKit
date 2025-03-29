@echo off
if not exist "%~dp01 Dependencies and Staging.ps1" (
  echo Error: 1 Dependencies and Staging.ps1 not found.
  pause
  exit /b 1
)
powershell.exe -ExecutionPolicy Bypass -File "%~dp01 Dependencies and Staging.ps1"
