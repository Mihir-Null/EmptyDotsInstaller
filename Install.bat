@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "INSTALLER=%SCRIPT_DIR%install.ps1"

:: Use Windows Terminal if available — much nicer experience.
:: Falls back to a plain PowerShell window if wt isn't installed.
where wt.exe >nul 2>&1
if %errorlevel% == 0 (
    wt.exe new-tab --title "EmptyDotFiles Installer" -- powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%INSTALLER%"
) else (
    start "EmptyDotFiles Installer" powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%INSTALLER%"
)

exit /b 0
