@echo off
title EmptyDotFiles Sandbox Bootstrap

echo.
echo === EmptyDotFiles Sandbox Bootstrap ===
echo.
echo Launching PowerShell bootstrap...
echo A transcript will be written to your sandbox desktop.
echo.

powershell.exe -NoExit -ExecutionPolicy Bypass -NoProfile -File "C:\Dotfiles\Bootstrap-Sandbox.ps1"

echo.
echo Bootstrap process exited with code %ERRORLEVEL%.
echo.
pause
