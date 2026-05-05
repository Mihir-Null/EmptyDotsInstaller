#Requires -Version 5.1
# Install-Font-Elevated.ps1
# Minimal elevated helper -- called by install.ps1 just for font installation.
# Requires administrator rights to write to C:\Windows\Fonts.
# Exit 0 on success, 1 on failure.
param(
    [Parameter(Mandatory)] [string] $FontName,
    [Parameter(Mandatory)] [string] $SrcDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $SrcDir 'Install-Font.psm1') -Force

try {
    $result = Install-NerdFont -FontName $FontName
    exit $(if ($result) { 0 } else { 1 })
} catch {
    Write-Host "Font install error: $_" -ForegroundColor Red
    exit 1
}
