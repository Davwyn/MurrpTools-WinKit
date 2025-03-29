@echo off
if not exist "%~dp02 Build MurrpTools Image.ps1" (
  echo Error: 2 Build MurrpTools Image.ps1 not found.
  pause
  exit /b 1
)
powershell.exe -ExecutionPolicy Bypass -File "%~dp02 Build MurrpTools Image.ps1"
