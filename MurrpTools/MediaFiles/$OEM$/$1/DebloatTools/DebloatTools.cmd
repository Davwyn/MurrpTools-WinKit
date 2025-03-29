@echo off
if not exist "%~dp0DebloatTools.ps1" (
  echo Error: DebloatTools.ps1 not found.
  pause
  exit /b 1
)
powershell.exe -ExecutionPolicy Bypass -File "%~dp0DebloatTools.ps1"
