# Bootstrap-Sandbox.ps1
# Installs winget and Windows Terminal inside Windows Sandbox, then launches
# the EmptyDotFiles installer. Run automatically via Sandbox.wsb LogonCommand.

Set-ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = 'Continue'
$progressPreference = 'silentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Desktop = [Environment]::GetFolderPath('Desktop')
$LogPath = Join-Path $Desktop 'EmptyDotFiles-Sandbox-Bootstrap.log'
$StartedTranscript = $false

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isElevated -and -not $env:EMPTYDOTFILES_ELEVATION_ATTEMPTED) {
    Write-Host "Relaunching sandbox bootstrap elevated..."
    $env:EMPTYDOTFILES_ELEVATION_ATTEMPTED = '1'
    $args = "-NoExit -ExecutionPolicy Bypass -NoProfile -File `"C:\Dotfiles\Bootstrap-Sandbox.ps1`""
    try {
        Start-Process powershell.exe -ArgumentList $args -Verb RunAs
        exit
    } catch {
        Write-Host "WARNING: Could not relaunch elevated: $_" -ForegroundColor Yellow
    }
}

try {
    Start-Transcript -Path $LogPath -Force | Out-Null
    $StartedTranscript = $true
} catch {
    Write-Host "WARNING: Could not start transcript: $_" -ForegroundColor Yellow
}

function Update-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $userPath    = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $windowsApps = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    $env:PATH    = @($machinePath, $userPath, $windowsApps) -join ';'
}

function Get-WingetExe {
    Update-ProcessPath

    $fromPath = Get-Command winget.exe -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
    if ($fromPath) { return $fromPath }

    $candidate = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path $candidate) { return $candidate }

    $allUsersCandidate = Get-Item 'C:\Users\*\AppData\Local\Microsoft\WindowsApps\winget.exe' `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($allUsersCandidate) { return $allUsersCandidate }

    return $null
}

function Write-ExceptionDetails {
    param([Parameter(Mandatory)] $ErrorRecord)

    Write-Host ""
    Write-Host "    $($ErrorRecord.Exception.GetType().FullName): $($ErrorRecord.Exception.Message)" -ForegroundColor Yellow

    $inner = $ErrorRecord.Exception.InnerException
    while ($inner) {
        Write-Host "    Inner: $($inner.GetType().FullName): $($inner.Message)" -ForegroundColor Yellow
        $inner = $inner.InnerException
    }
}

function Install-AppxFromUrl {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Url,
        [Parameter(Mandatory)] [string] $FileName
    )

    $path = Join-Path $env:TEMP $FileName
    Write-Host "  [$Name] Downloading..." -NoNewline

    try {
        Invoke-WebRequest -Uri $Url -OutFile $path -UseBasicParsing -ErrorAction Stop
        Write-Host " installing..." -NoNewline
        Add-AppxPackage -Path $path -ErrorAction Stop
        Write-Host " done" -ForegroundColor Green
        return $true
    } catch {
        $message = $_.Exception.ToString()
        if ($message -match '0x80073D06' -or $message -match 'higher version of this package is already installed') {
            Write-Host " already newer" -ForegroundColor Green
            return $true
        }

        Write-Host " FAILED" -ForegroundColor Red
        Write-ExceptionDetails -ErrorRecord $_
        return $false
    }
}

function Install-WingetPackageManagerFallback {
    Write-Host ""
    Write-Host "  [winget] Falling back to direct App Installer bootstrap..." -ForegroundColor Yellow

    $vclibsOk = Install-AppxFromUrl `
        -Name     'VCLibs x64' `
        -Url      'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' `
        -FileName 'VCLibs.appx'

    $xamlOk = Install-AppxFromUrl `
        -Name     'Microsoft.UI.Xaml 2.8' `
        -Url      'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx' `
        -FileName 'UIXaml.appx'

    $appRuntimeOk = Install-AppxFromUrl `
        -Name     'Windows App Runtime 1.8' `
        -Url      'https://aka.ms/Microsoft.WindowsAppRuntime.1.8_x64.msix' `
        -FileName 'Microsoft.WindowsAppRuntime.1.8_x64.msix'

    $appInstallerOk = Install-AppxFromUrl `
        -Name     'App Installer (winget)' `
        -Url      'https://aka.ms/getwinget' `
        -FileName 'AppInstaller.msixbundle'

    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction SilentlyContinue
    } catch {}

    Write-Host "  [winget] Fallback result: VCLibs=$vclibsOk UI.Xaml=$xamlOk AppRuntime1.8=$appRuntimeOk AppInstaller=$appInstallerOk" -ForegroundColor DarkGray

    for ($i = 0; $i -lt 10; $i++) {
        $wingetExe = Get-WingetExe
        if ($wingetExe) {
            Write-Host "  [winget] Found: $wingetExe" -ForegroundColor Green
            return $true
        }

        Start-Sleep -Seconds 1
    }

    Write-Host "  [winget] Fallback completed, but winget.exe is not visible yet" -ForegroundColor Yellow
    return $false
}

function Install-WingetPackageManager {
    if (-not (Get-WingetExe)) {
        Write-Host "  [winget] winget.exe not present; using direct App Installer bootstrap"
        return (Install-WingetPackageManagerFallback)
    }

    Write-Host "  [winget] Installing/repairing package manager..." -NoNewline
    try {
        $progressPreference = 'silentlyContinue'
        Install-PackageProvider -Name NuGet -Force | Out-Null
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
        Import-Module Microsoft.WinGet.Client -Force
        Repair-WinGetPackageManager -AllUsers
        Write-Host " done" -ForegroundColor Green
        return $true
    } catch {
        Write-Host " FAILED" -ForegroundColor Red
        Write-ExceptionDetails -ErrorRecord $_
        return (Install-WingetPackageManagerFallback)
    }
}

function Install-WindowsTerminal {
    $wingetExe = Get-WingetExe
    if (-not $wingetExe) {
        Write-Host "  [Windows Terminal] winget not found, skipping" -ForegroundColor Yellow
        return
    }

    Write-Host "  [Windows Terminal] Installing..." -NoNewline
    try {
        & $wingetExe install --id Microsoft.WindowsTerminal --exact --source winget --silent `
            --accept-package-agreements --accept-source-agreements | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host " done" -ForegroundColor Green
        } else {
            Write-Host " FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
        }
    } catch {
        Write-Host " ERROR: $_" -ForegroundColor Red
    }
}

function Initialize-WingetSources {
    $wingetExe = Get-WingetExe
    if (-not $wingetExe) {
        Write-Host "  [winget] winget not found, cannot initialize sources" -ForegroundColor Yellow
        return
    }

    Write-Host "  [winget] Resetting package sources..." -NoNewline
    try {
        & $wingetExe source reset --force | Out-Null
        $resetExit = $LASTEXITCODE
        & $wingetExe source update | Out-Null
        $updateExit = $LASTEXITCODE

        if ($resetExit -ne 0 -or $updateExit -ne 0) {
            Write-Host " WARNING (reset $resetExit, update $updateExit)" -ForegroundColor Yellow
            return
        }

        Write-Host " done" -ForegroundColor Green
    } catch {
        Write-Host " WARNING: $_" -ForegroundColor Yellow
    }
}

function Wait-WindowsTerminalAlias {
    Write-Host "  [Windows Terminal] Waiting for wt.exe alias..." -NoNewline
    for ($i = 0; $i -lt 12; $i++) {
        Update-ProcessPath
        $wt = Get-Command wt.exe -ErrorAction SilentlyContinue
        if ($wt) {
            Write-Host " ok"
            return
        }

        Start-Sleep -Seconds 1
    }

    Write-Host " not found yet" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Bootstrapping Windows Sandbox ===" -ForegroundColor Cyan
Write-Host "Transcript: $LogPath" -ForegroundColor DarkGray
Write-Host ""

$null = Install-WingetPackageManager

Write-Host "  Waiting for winget registration..." -NoNewline
Start-Sleep -Seconds 4
Write-Host " ok"

Initialize-WingetSources
Install-WindowsTerminal
Wait-WindowsTerminalAlias

Start-Sleep -Seconds 2

# Launch the EmptyDotFiles installer
Write-Host ""
Write-Host "=== Launching EmptyDotFiles Installer ===" -ForegroundColor Cyan
& 'C:\Dotfiles\Install.bat'

if ($StartedTranscript) {
    try { Stop-Transcript | Out-Null } catch {}
}
