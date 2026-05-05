# Install-Apps.psm1 -- winget app detection and installation

Set-StrictMode -Version Latest

$Script:AppManifest = [ordered]@{
    'PowerShell7'   = @{ Id = 'Microsoft.PowerShell';         Label = 'PowerShell 7 (modern shell)' }
    'WezTerm'       = @{ Id = 'wez.wezterm';                  Label = 'WezTerm (terminal)' }
    'YASB'          = @{ Id = 'AmN.yasb';                     Label = 'YASB (status bar)' }
    'Komorebi'      = @{ Id = 'LGUG2Z.komorebi';              Label = 'Komorebi (tiling window manager)' }
    'AutoHotkey'    = @{ Id = 'AutoHotkey.AutoHotkey';        Label = 'AutoHotkey v2 (hotkeys)' }
    'VSCode'        = @{ Id = 'Microsoft.VisualStudioCode';   Label = 'Visual Studio Code (code editor)'; Category = 'CodeEditor' }
    'VSCodium'      = @{ Id = 'VSCodium.VSCodium';            Label = 'VSCodium (code editor)'; Category = 'CodeEditor' }
    'Zed'           = @{ Id = 'Zed.Zed';                      Label = 'Zed (code editor)'; Category = 'CodeEditor' }
    'Cursor'        = @{ Id = 'Anysphere.Cursor';             Label = 'Cursor (code editor)'; Category = 'CodeEditor' }
    'FlowLauncher'  = @{ Id = 'Flow-Launcher.Flow-Launcher';  Label = 'Flow Launcher (app launcher)' }
}

$Script:ExecutableFallbacks = @{
    'YASB'         = @('yasb.exe')
    'FlowLauncher' = @(
        "$env:LOCALAPPDATA\FlowLauncher\Flow.Launcher.exe",
        "$env:LOCALAPPDATA\FlowLauncher\app-*\Flow.Launcher.exe"
    )
}

# Winget path resolution
#
# winget.exe is a per-user Windows Store app installed under:
#   %LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe
#
# When install.ps1 self-elevates to Administrator (needed for font install),
# %LOCALAPPDATA% switches to the Administrator profile where winget is absent.
# We resolve the real path at module-load time by also searching all user
# profiles, so elevated sessions can still invoke winget.

function Script:Resolve-WingetPath {
    # 1. Try PATH first -- works for non-elevated sessions.
    $fromPath = Get-Command winget.exe -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
    if ($fromPath) { return $fromPath }

    # 2. Search every user profile's WindowsApps folder.
    #    Glob returns multiple matches; take the first that exists.
    $candidates = Get-Item 'C:\Users\*\AppData\Local\Microsoft\WindowsApps\winget.exe' `
                      -ErrorAction SilentlyContinue
    if ($candidates) { return @($candidates)[0].FullName }

    # 3. Not found.
    return $null
}

$Script:WingetExe = Script:Resolve-WingetPath
$Script:WingetSourcesReady = $false

function Test-WingetAvailable {
    return ($null -ne $Script:WingetExe)
}

function Initialize-WingetSources {
    if (-not $Script:WingetExe) { return $false }
    if ($Script:WingetSourcesReady) { return $true }

    Write-Host "    Initializing winget sources..." -NoNewline
    try {
        & $Script:WingetExe source reset --force | Out-Null
        $resetExit = $LASTEXITCODE
        & $Script:WingetExe source update | Out-Null
        $updateExit = $LASTEXITCODE

        if ($resetExit -ne 0 -or $updateExit -ne 0) {
            Write-Host " WARNING (reset $resetExit, update $updateExit)" -ForegroundColor Yellow
            return $false
        }

        $Script:WingetSourcesReady = $true
        Write-Host " done" -ForegroundColor Green
        return $true
    } catch {
        Write-Host " WARNING: $_" -ForegroundColor Yellow
        return $false
    }
}

function Get-InstalledApps {
    $result = [ordered]@{}
    foreach ($name in $Script:AppManifest.Keys) {
        $result[$name] = Test-AppInstalled -AppName $name
    }
    return $result
}

function Test-AppInstalled {
    param([Parameter(Mandatory)] [string] $AppName)

    if (-not $Script:AppManifest.Contains($AppName)) {
        Write-Error "Unknown app: $AppName"
        return $false
    }

    if ($Script:WingetExe) {
        $id = $Script:AppManifest[$AppName].Id
        $null = & $Script:WingetExe list --id $id --exact --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0) { return $true }
    }

    if ($Script:ExecutableFallbacks.ContainsKey($AppName)) {
        foreach ($candidate in $Script:ExecutableFallbacks[$AppName]) {
            if ($candidate -like '*.exe' -and $candidate -notlike '*\*') {
                if (Get-Command $candidate -ErrorAction SilentlyContinue) { return $true }
            } elseif (Get-Item $candidate -ErrorAction SilentlyContinue) {
                return $true
            }
        }
    }

    return $false
}

function Install-App {
    param([Parameter(Mandatory)] [string] $AppName)

    if (-not $Script:AppManifest.Contains($AppName)) {
        Write-Error "Unknown app: $AppName"
        return $false
    }

    if (-not $Script:WingetExe) {
        Write-Host " SKIPPED (winget not found)" -ForegroundColor Yellow
        return $false
    }

    $id    = $Script:AppManifest[$AppName].Id
    $label = $Script:AppManifest[$AppName].Label

    try {
        if (-not $Script:WingetSourcesReady) {
            $null = Initialize-WingetSources
        }

        Write-Host "    Installing $label..." -NoNewline
        $proc = Start-Process $Script:WingetExe `
            -ArgumentList "install --id $id --exact --source winget --silent --accept-package-agreements --accept-source-agreements" `
            -Wait -PassThru -WindowStyle Hidden
        if ($proc.ExitCode -eq 0) {
            Write-Host " done" -ForegroundColor Green
            return $true
        } else {
            Write-Host " FAILED (exit $($proc.ExitCode))" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host " ERROR: $_" -ForegroundColor Red
        return $false
    }
}

function Get-AppManifest { return $Script:AppManifest }

Export-ModuleMember -Function Test-WingetAvailable, Get-InstalledApps, Test-AppInstalled, Initialize-WingetSources, Install-App, Get-AppManifest
