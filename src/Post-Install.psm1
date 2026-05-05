# Post-Install.psm1 -- desktop finishing touches after config deployment.

Set-StrictMode -Version Latest

$Script:FlowPluginSuggestions = @(
    [pscustomobject]@{
        Name = 'Browser Tabs'
        Author = 'Jeremy Wu'
        Recommended = $true
        Description = 'Search, activate, and close browser tabs'
    },
    [pscustomobject]@{
        Name = 'Clipboard+'
        Author = 'Jack251970'
        Recommended = $true
        Description = 'Search and manage clipboard history'
    },
    [pscustomobject]@{
        Name = 'OpenWindowSearch'
        Author = 'jamsoftwaregmbh'
        Recommended = $true
        Description = 'Switch to currently open windows quickly'
    },
    [pscustomobject]@{
        Name = 'Win Hotkey'
        Author = 'Amin Salah'
        Recommended = $true
        Description = 'Use the left Windows key to trigger Flow Launcher'
    },
    [pscustomobject]@{
        Name = 'WingetFlow'
        Author = 'gdemazeux'
        Recommended = $true
        Description = 'Search, install, update, and uninstall winget packages'
    },
    [pscustomobject]@{
        Name = 'WSL File Search'
        Author = 'Sajxx'
        Recommended = $true
        Description = 'Search files inside WSL from Flow Launcher'
    },
    [pscustomobject]@{
        Name = 'Env'
        Author = 'lurebat'
        Recommended = $false
        Description = 'Inspect and manage environment variables'
    },
    [pscustomobject]@{
        Name = 'Obsidian'
        Author = 'alexandre-v1'
        Recommended = $false
        Description = 'Search Obsidian vault files'
    },
    [pscustomobject]@{
        Name = 'Power Plans'
        Author = 'Till Knollmann'
        Recommended = $false
        Description = 'Switch Windows power plans'
    },
    [pscustomobject]@{
        Name = 'Window Services'
        Author = 'Garulf'
        Recommended = $false
        Description = 'Start and stop Windows services'
    },
    [pscustomobject]@{
        Name = 'Windows Services Manager'
        Author = 'TBM13'
        Recommended = $false
        Description = 'Manage Windows services from Flow Launcher'
    },
    [pscustomobject]@{
        Name = 'Windows Startup'
        Author = 'Garulf'
        Recommended = $false
        Description = 'Control Windows startup programs'
    },
    [pscustomobject]@{
        Name = 'Playnite'
        Author = 'Garulf'
        Recommended = $false
        Description = 'Search and launch a Playnite game library'
    },
    [pscustomobject]@{
        Name = 'SpotifyPremium'
        Author = 'Frank W. (@fow5040)'
        Recommended = $false
        Description = 'Control Spotify Premium from Flow Launcher'
    },
    [pscustomobject]@{
        Name = 'SteamFlow'
        Author = 'keekys'
        Recommended = $false
        Description = 'Launch Steam games and search the Steam store'
    },
    [pscustomobject]@{
        Name = 'Wallpaper Engine Profile Selector'
        Author = 'Garulf'
        Recommended = $false
        Description = 'Change Wallpaper Engine profiles'
    }
)

function Get-FlowLauncherPluginSuggestions {
    return $Script:FlowPluginSuggestions
}

function Script:Get-FlowLauncherPath {
    $paths = @(
        "$env:LOCALAPPDATA\FlowLauncher\Flow.Launcher.exe"
    )

    $versioned = Get-Item "$env:LOCALAPPDATA\FlowLauncher\app-*\Flow.Launcher.exe" `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -ExpandProperty FullName

    $paths += @($versioned)

    foreach ($path in $paths) {
        if (Test-Path $path) { return $path }
    }

    return $null
}

function Publish-FlowLauncherPluginInstructions {
    param([Parameter(Mandatory)] [object[]] $Plugins)

    $commands = @($Plugins | ForEach-Object {
        "pm install $($_.Name) by $($_.Author)"
    })

    $copied = $false
    try {
        Set-Clipboard -Value ($commands -join [Environment]::NewLine)
        $copied = $true
    } catch {
        Write-Warning "Could not copy Flow Launcher plugin commands to clipboard: $_"
    }

    $flowPath = Script:Get-FlowLauncherPath
    if ($flowPath) {
        Start-Process $flowPath -ErrorAction SilentlyContinue
    }

    return [pscustomobject]@{
        Commands = $commands
        CopiedToClipboard = $copied
        FlowLauncherPath = $flowPath
    }
}

function Set-TaskbarAutoHide {
    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    $settings = (Get-ItemProperty -Path $regPath -Name Settings).Settings

    if (-not $settings -or $settings.Count -lt 9) {
        throw 'Taskbar registry settings were not found or had an unexpected format.'
    }

    $settings[8] = $settings[8] -bor 0x01
    Set-ItemProperty -Path $regPath -Name Settings -Value $settings

    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
}

Export-ModuleMember -Function Get-FlowLauncherPluginSuggestions,
                              Publish-FlowLauncherPluginInstructions,
                              Set-TaskbarAutoHide
