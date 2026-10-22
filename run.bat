@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
echo.
if errorlevel 1 (
  echo Setup stopped. Read the error above. No firmware flashing was attempted.
)
pause
