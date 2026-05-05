# Deploy-Configs.psm1 — Backup existing configs, then deploy rendered outputs.

Set-StrictMode -Version Latest

# Maps each rendered config file (relative path under configs/) to its system destination.
$Script:BaseDeployMap = [ordered]@{
    'wezterm\wezterm.lua'             = "$env:USERPROFILE\.config\wezterm\wezterm.lua"
    'yasb\config.yaml'                = "$env:USERPROFILE\.config\yasb\config.yaml"
    'yasb\styles.css'                 = "$env:USERPROFILE\.config\yasb\styles.css"
    'komorebi\komorebi.json'          = "$env:USERPROFILE\.config\komorebi\komorebi.json"
    'komorebi\komorebi.bar.json'      = "$env:USERPROFILE\.config\komorebi\komorebi.bar.json"
    'komorebi\komorebi.ahk'           = "$env:USERPROFILE\.config\komorebi\komorebi.ahk"
    'komorebi\applications.json'      = "$env:USERPROFILE\.config\komorebi\applications.json"
    'flow-launcher\Settings.json'     = "$env:APPDATA\FlowLauncher\Settings\Settings.json"
}

function Script:Get-DeployMap {
    param([hashtable] $UserConfig)

    $map = [ordered]@{}
    foreach ($entry in $Script:BaseDeployMap.GetEnumerator()) {
        $map[$entry.Key] = $entry.Value
    }

    $editor = if ($UserConfig -and $UserConfig.ContainsKey('CodeEditor')) { $UserConfig.CodeEditor } else { 'VSCodium' }
    switch ($editor) {
        'VSCode'   { $map['vscodium\settings.json'] = "$env:APPDATA\Code\User\settings.json" }
        'VSCodium' { $map['vscodium\settings.json'] = "$env:APPDATA\VSCodium\User\settings.json" }
        'Cursor'   { $map['vscodium\settings.json'] = "$env:APPDATA\Cursor\User\settings.json" }
        'Zed'      { $map['zed\settings.json']      = "$env:APPDATA\Zed\settings.json" }
        default    { $map['vscodium\settings.json'] = "$env:APPDATA\VSCodium\User\settings.json" }
    }

    return $map
}

function Backup-Configs {
    <#
    .SYNOPSIS
        Copies every existing destination file to a timestamped backup directory.
        Returns the backup directory path (or $null if nothing was backed up).
    #>
    param(
        [string] $BackupRoot = "$env:USERPROFILE\.config-backup",
        [hashtable] $UserConfig
    )

    $timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = Join-Path $BackupRoot $timestamp
    $backedUp   = 0
    $deployMap  = Script:Get-DeployMap -UserConfig $UserConfig

    foreach ($dest in $deployMap.Values) {
        if (Test-Path $dest) {
            $relDest   = $dest.Replace($env:USERPROFILE, '').TrimStart('\')
            $backupDest= Join-Path $backupPath $relDest
            $backupDir = Split-Path $backupDest -Parent

            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }

            Copy-Item $dest -Destination $backupDest -Force
            $backedUp++
        }
    }

    if ($backedUp -gt 0) { return $backupPath } else { return $null }
}

function Deploy-Configs {
    <#
    .SYNOPSIS
        Copies each rendered file from $SourceDir to its system destination.
        Creates destination directories if they don't exist.
        Returns a hashtable of { relPath → 'ok'|'error: ...' }.
    #>
    param(
        [Parameter(Mandatory)] [string] $SourceDir,
        [hashtable] $UserConfig
    )

    $results = [ordered]@{}
    $deployMap = Script:Get-DeployMap -UserConfig $UserConfig

    foreach ($rel in $deployMap.Keys) {
        $src  = Join-Path $SourceDir $rel
        $dest = $deployMap[$rel]

        try {
            if (-not (Test-Path $src)) {
                $results[$rel] = 'skipped (source not found)'
                continue
            }

            $destDir = Split-Path $dest -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }

            Copy-Item $src -Destination $dest -Force
            $results[$rel] = 'ok'
        } catch {
            $results[$rel] = "error: $_"
        }
    }

    return $results
}

function Add-StartupEntry {
    <#
    .SYNOPSIS
        Adds a .lnk shortcut to the user's Startup folder if it doesn't already exist.
    #>
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $TargetPath,
        [string] $Arguments = ''
    )

    $startupDir = [Environment]::GetFolderPath('Startup')
    $lnkPath    = Join-Path $startupDir "$Name.lnk"

    if (Test-Path $lnkPath) {
        Remove-Item $lnkPath -Force
    }

    $wsh  = New-Object -ComObject WScript.Shell
    $link = $wsh.CreateShortcut($lnkPath)
    $link.TargetPath  = $TargetPath
    $link.Arguments   = $Arguments
    $link.WindowStyle = 7   # minimized
    $link.Save()
}

function Script:Remove-StartupEntry {
    param([Parameter(Mandatory)] [string] $Name)

    $startupDir = [Environment]::GetFolderPath('Startup')
    $lnkPath    = Join-Path $startupDir "$Name.lnk"
    if (Test-Path $lnkPath) {
        Remove-Item $lnkPath -Force
    }
}

function Script:Set-RunStartupEntry {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $TargetPath,
        [string] $Arguments = ''
    )

    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $command = "`"$TargetPath`""
    if ($Arguments) {
        $command = "$command $Arguments"
    }

    New-Item -Path $runKey -Force | Out-Null
    Set-ItemProperty -Path $runKey -Name $Name -Value $command
}

function Script:Remove-RunStartupEntry {
    param([Parameter(Mandatory)] [string] $Name)

    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    Remove-ItemProperty -Path $runKey -Name $Name -ErrorAction SilentlyContinue
}

function Script:Resolve-AutoHotkeyPath {
    $fromPath = Get-Command AutoHotkey64.exe -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
    if ($fromPath) { return $fromPath }

    $fromPath = Get-Command AutoHotkey.exe -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
    if ($fromPath) { return $fromPath }

    foreach ($candidate in @(
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey64.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey.exe"
    )) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }

    return $null
}

function Set-StartupItems {
    <#
    .SYNOPSIS
        Ensures one Komorebi startup entry owns the full desktop session.
    #>
    foreach ($legacy in @('Komorebi','YASB','KomorebiAHK','Flow Launcher','FlowLauncher')) {
        Script:Remove-StartupEntry -Name $legacy
        Script:Remove-RunStartupEntry -Name $legacy
    }

    $komorebiBin = Get-Command komorebic.exe -ErrorAction SilentlyContinue |
                   Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue

    $ahkBin = Script:Resolve-AutoHotkeyPath
    $ahkConfig = "$env:USERPROFILE\.config\komorebi\komorebi.ahk"
    if ($ahkBin -and (Test-Path $ahkConfig)) {
        $arguments = "`"$ahkConfig`""
        Add-StartupEntry -Name 'Komorebi' -TargetPath $ahkBin -Arguments $arguments
        Script:Set-RunStartupEntry -Name 'Komorebi' -TargetPath $ahkBin -Arguments $arguments
    } elseif ($komorebiBin) {
        $komorebiExe = $komorebiBin.Replace('komorebic.exe','komorebi.exe')
        Add-StartupEntry -Name 'Komorebi' -TargetPath $komorebiExe -Arguments 'start --masir'
        Script:Set-RunStartupEntry -Name 'Komorebi' -TargetPath $komorebiExe -Arguments 'start --masir'
    }
}

Export-ModuleMember -Function Backup-Configs, Deploy-Configs, Set-StartupItems
