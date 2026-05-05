#Requires -Version 5.1
<#
.SYNOPSIS
    EmptyDotFiles installer for the Windows Desktop Environment.
    Installs apps via winget, applies your chosen theme, and deploys configs.

.NOTES
    Run with: powershell -ExecutionPolicy Bypass -File install.ps1
    Or from GitHub: irm https://raw.githubusercontent.com/YOURNAME/dotfiles/main/install.ps1 | iex
#>

[CmdletBinding()]
param(
    [switch] $SkipApps,     # Skip app installation step
    [switch] $SkipFont,     # Skip font download/install
    [switch] $DryRun        # Build rendered configs but don't deploy them
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region ── Bootstrap ───────────────────────────────────────────────────────────

# Resolve script root (works whether called directly or via iex)
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$SrcDir     = Join-Path $ScriptRoot 'src'
$ConfigsDir = Join-Path $ScriptRoot 'configs'
$ThemesDir  = Join-Path $ScriptRoot 'themes'
$TempOut    = Join-Path $env:TEMP "emptydotfiles-out-$(New-Guid)"

# Import modules
foreach ($mod in @('TUI','Install-Apps','Install-Font','Apply-Theme','Deploy-Configs','Post-Install')) {
    Import-Module (Join-Path $SrcDir "$mod.psm1") -Force
}

# Minimal ANSI color table -- mirrors TUI.psm1 but scoped to this script.
# $PSStyle is PS 7.2+ only; this works on PS 5.1+.
$_ESC = [char]27
$C = @{
    Reset         = "$_ESC[0m"
    BrightBlack   = "$_ESC[90m"
    BrightGreen   = "$_ESC[92m"
    BrightYellow  = "$_ESC[93m"
    BrightCyan    = "$_ESC[96m"
}

#endregion

#region ── Step 1: Welcome ─────────────────────────────────────────────────────

Show-Header
Write-Host "  This installer will set up a complete tiling desktop environment:"
Write-Host "  $($C.BrightCyan)WezTerm · YASB · Komorebi · AutoHotkey · Code editor · Flow Launcher$($C.Reset)"
Write-Host ''
Write-Host "  You'll be asked a few questions to customise the look and feel."
Write-Host "  Everything is reversible -- your current configs are backed up first."
Write-Host ''
Write-Host "  $($C.BrightBlack)Press Enter to begin, or Ctrl+C to exit...$($C.Reset)"
$null = [Console]::ReadKey($true)

#endregion

#region ── Step 2: Code editor ─────────────────────────────────────────────────

$UserConfig = @{}

Write-SectionHeader 'Code Editor' 2 9

$editorKeys = @('VSCode','VSCodium','Zed','Cursor')
$editorIdx = Show-Menu `
    -Title       'Choose your code editor' `
    -Options     @('Visual Studio Code','VSCodium','Zed','Cursor') `
    -Descriptions @('Microsoft VS Code, broadest extension compatibility',
                    'Open-source VS Code build without Microsoft branding',
                    'Fast native editor with minimal generated settings',
                    'AI-focused VS Code-family editor') `
    -Default     1

if ($editorIdx -lt 0) { Write-Host 'Installation cancelled.'; exit 1 }
$UserConfig.CodeEditor = $editorKeys[$editorIdx]

#endregion

#region ── Step 3: App selection ───────────────────────────────────────────────

if (-not $SkipApps) {
    Write-SectionHeader 'App Installation' 3 9

    if (-not (Test-WingetAvailable)) {
        Write-Warn 'winget not found -- skipping app installation.'
        Write-Info 'Install apps manually from https://winget.run or the Microsoft Store.'
        Write-Info 'Then re-run this installer with -SkipApps to configure without installing.'
        Write-Host ''
        $UserConfig.AppsToInstall = @()
    } else {

    Write-Step "Checking which apps are already installed..."
    $installed = Get-InstalledApps
    $manifest  = Get-AppManifest

    $appNames  = @($manifest.Keys | Where-Object {
        -not $manifest[$_].ContainsKey('Category') -or
        $manifest[$_].Category -ne 'CodeEditor' -or
        $_ -eq $UserConfig.CodeEditor
    })
    $appLabels = $appNames | ForEach-Object { $manifest[$_].Label }
    $appDescs  = $appNames | ForEach-Object {
        if ($installed[$_]) { 'already installed' } else { 'will be installed' }
    }
    # Pre-check only the apps NOT already installed
    $preChecked = $appNames | ForEach-Object { -not $installed[$_] }

    Write-Host ''
    $toInstall = Show-MultiMenu `
        -Title       'Which apps should the installer install?' `
        -Options     $appLabels `
        -Descriptions $appDescs `
        -PreChecked   $preChecked

    if ($null -eq $toInstall) { Write-Host 'Installation cancelled.'; exit 1 }
    $UserConfig.AppsToInstall = @()
    for ($i = 0; $i -lt $appNames.Count; $i++) {
        if ($toInstall[$i]) { $UserConfig.AppsToInstall += $appNames[$i] }
    }

    } # end winget-available else
} else {
    $UserConfig.AppsToInstall = @()
}

#endregion

#region ── Step 4: Theme ───────────────────────────────────────────────────────

Write-SectionHeader 'Color Theme' 4 9

$themeFiles  = @('catppuccin-mocha','nord','tokyo-night','gruvbox')
$themeNames  = @('Catppuccin Mocha','Nord','Tokyo Night','Gruvbox Dark')
$themeDescs  = @(
    'Warm purples and pastels on a dark mocha background',
    'Cool arctic blues and greens, icy and calm',
    'Deep blues and purples, inspired by Tokyo city nights',
    'Earthy warm tones -- amber, brown, and muted green'
)
$themeSwatches = @('#cba6f7','#88c0d0','#7aa2f7','#83a598')

$themeIdx = Show-Menu `
    -Title       'Choose a color theme' `
    -Options     $themeNames `
    -Descriptions $themeDescs `
    -SwatchColors $themeSwatches `
    -Default     0

if ($themeIdx -lt 0) { Write-Host 'Installation cancelled.'; exit 1 }
$UserConfig.ThemeFile = $themeFiles[$themeIdx]

#endregion

#region ── Step 5: Font ────────────────────────────────────────────────────────

Write-SectionHeader 'Nerd Font' 5 9

$fontKeys  = @('JetBrains Mono','Fira Code','Cascadia Code','Hack','GohuFont','Iosevka')
$fontDescs = @(
    'Clean, modern, excellent ligatures -- recommended for most setups',
    'Popular coding font with many ligatures, slightly wider',
    'Microsoft open-source font with beautiful cursive italics',
    'Highly legible, zero-ambiguity, designed for terminals',
    'Tiny bitmap-style font, very compact -- current setup',
    'Ultra-narrow, great for dense information display'
)

$fontIdx = Show-Menu `
    -Title       'Choose a Nerd Font' `
    -Options     $fontKeys `
    -Descriptions $fontDescs `
    -Default     0

if ($fontIdx -lt 0) { Write-Host 'Installation cancelled.'; exit 1 }
$UserConfig.FontName   = $fontKeys[$fontIdx]
$UserConfig.FontFamily = (Get-FontManifest)[$fontKeys[$fontIdx]].DisplayName
$UserConfig.FontSize   = 14

#endregion

#region ── Step 6: Shell ───────────────────────────────────────────────────────

Write-SectionHeader 'Default Terminal Shell' 6 9

# Detect WSL and identify the default distro. PowerShell 5.1 can capture
# wsl.exe output with embedded NULs, so normalize those before parsing.
$wslAvailable   = $false
$wslDefaultName = 'default distro'
try {
    $wslText = ((& wsl.exe --list --verbose 2>&1) -join "`n") -replace "`0", ''
    $wslAvailable = ($LASTEXITCODE -eq 0) -and ($wslText -match '\S') -and ($wslText -notmatch 'not recognized|not installed')

    # The default distro line starts with '*'
    if ($wslAvailable) {
        $defaultLine = ($wslText -split "`n") |
                       Where-Object { $_ -match '^\s*\*' } |
                       Select-Object -First 1
        if ($defaultLine -match '^\s*\*\s+(.+?)(\s{2,}|$)') {
            $wslDefaultName = $Matches[1].Trim()
        }
    }
} catch {}

$shellOpts  = @('PowerShell 7', 'cmd')
$shellDescs = @('Modern PowerShell -- works on any Windows machine',
                'Classic Windows command prompt')

if ($wslAvailable) {
    $shellOpts  = @('WSL') + $shellOpts
    $shellDescs = @("Default WSL distro ($wslDefaultName) -- launches whatever wsl.exe opens by default") + $shellDescs
}

$shellIdx = Show-Menu `
    -Title       'What should WezTerm open by default?' `
    -Options     $shellOpts `
    -Descriptions $shellDescs `
    -Default     0

if ($shellIdx -lt 0) { Write-Host 'Installation cancelled.'; exit 1 }
$UserConfig.DefaultShell = $shellOpts[$shellIdx]
$UserConfig.WslDetected  = $wslAvailable

#endregion

#region ── Step 7: Look & Feel ─────────────────────────────────────────────────

Write-SectionHeader 'Look & Feel' 7 9

# Transparency
$bdIdx = Show-Menu `
    -Title       'Window transparency / backdrop' `
    -Options     @('Solid','Glass (Acrylic)','Frosted (Mica)') `
    -Descriptions @('No transparency -- cleanest look',
                    'Frosted acrylic blur behind the terminal window',
                    'Subtle Mica effect -- blends with your wallpaper') `
    -Default     0
$UserConfig.Backdrop = @('Solid','Glass','Frosted')[$bdIdx]

# Bar position
$barPosIdx = Show-Menu `
    -Title       'Status bar position' `
    -Options     @('Top','Bottom') `
    -Descriptions @('Bar sits at the top of the screen (default)',
                    'Bar sits at the bottom, like a traditional taskbar') `
    -Default     0
$UserConfig.BarPosition = @('top','bottom')[$barPosIdx]

# Bar height
$barHIdx = Show-Menu `
    -Title       'Status bar height' `
    -Options     @('Compact (36px)','Normal (45px)','Tall (54px)') `
    -Descriptions @('Slim bar, maximises screen space',
                    'Comfortable default size',
                    'Larger targets, easier to read') `
    -Default     1
$UserConfig.BarHeight = @('Compact','Normal','Tall')[$barHIdx]

# Widget corners
$cornerIdx = Show-Menu `
    -Title       'Widget corner style' `
    -Options     @('Sharp (0px)','Slight (6px)','Rounded (12px)','Pill (20px)') `
    -Descriptions @('No rounding -- geometric and crisp',
                    'Subtle rounding',
                    'Noticeably rounded corners',
                    'Fully rounded pill shape') `
    -Default     3
$UserConfig.CornerRadius = @('Sharp','Slight','Rounded','Pill')[$cornerIdx]

# Window gaps
$gapIdx = Show-Menu `
    -Title       'Window gap size' `
    -Options     @('None (0px)','Tight (4px)','Comfortable (8px)','Loose (16px)') `
    -Descriptions @('No gaps -- maximum screen use',
                    'Small gaps, subtle visual separation (default)',
                    'Comfortable breathing room between windows',
                    'Wide gaps -- clear and spacious') `
    -Default     1
$UserConfig.GapSize = @('None','Tight','Comfortable','Loose')[$gapIdx]

# Border style
$bsIdx = Show-Menu `
    -Title       'Window border style' `
    -Options     @('Square','Rounded') `
    -Descriptions @('Sharp rectangular borders','Soft rounded corner borders') `
    -Default     0
$UserConfig.BorderStyle = @('Square','Rounded')[$bsIdx]

# Border width
$bwIdx = Show-Menu `
    -Title       'Window border width' `
    -Options     @('Thin (2px)','Normal (4px)','Thick (6px)') `
    -Descriptions @('Barely visible','Noticeable but not distracting (default)','Bold, high-contrast borders') `
    -Default     1
$UserConfig.BorderWidth = @('Thin','Normal','Thick')[$bwIdx]

# Animation
$animIdx = Show-Menu `
    -Title       'Window animation speed' `
    -Options     @('Off','Fast (150ms)','Medium (250ms)','Slow (400ms)') `
    -Descriptions @('Instant -- snappiest feel, no animation overhead',
                    'Quick easing -- barely noticeable but smooth (default)',
                    'Smooth easing -- polished feel',
                    'Slow easing -- very deliberate, noticeable') `
    -Default     1
$UserConfig.Animation = @('Off','Fast','Medium','Slow')[$animIdx]

#endregion

#region ── Step 8: Keybindings ─────────────────────────────────────────────────

Write-SectionHeader 'Keybindings' 8 9

$modIdx = Show-Menu `
    -Title       'Primary modifier key' `
    -Options     @('Alt','Super (Win key)','Ctrl+Alt') `
    -Descriptions @('Default -- works everywhere, familiar layout',
                    'Win key -- fewer conflicts with browser shortcuts (recommended if you browse a lot)',
                    'Ctrl+Alt -- rarely conflicts, but awkward to press') `
    -Default     0
$UserConfig.Modifier = @('Alt','Super','Ctrl+Alt')[$modIdx]

$layoutIdx = Show-Menu `
    -Title       'Keybinding layout' `
    -Options     @('Left-hand (WASD)','Split keyboard','Vim (HJKL)') `
    -Descriptions @("Focus: $($UserConfig.Modifier)+WASD  |  Move: $($UserConfig.Modifier)+Shift+WASD  -- all on the left hand",
                    "Focus: $($UserConfig.Modifier)+OKL;  |  Move: $($UserConfig.Modifier)+WASD  -- focus right, move left",
                    "Focus: $($UserConfig.Modifier)+HJKL  |  Move: $($UserConfig.Modifier)+WASD  -- focus right, move left") `
    -Default     0
$UserConfig.KeyLayout = @('Left-hand','Split','Vim')[$layoutIdx]

#endregion

#region ── Step 9: Personal settings ──────────────────────────────────────────

Write-SectionHeader 'Personal Settings (all optional -- press Escape to skip)' 9 9

$weatherLoc = Read-TextInput `
    -Prompt  'Weather location' `
    -Default 'New York, NY, USA' `
    -Hint    'e.g. London, UK or Tokyo, Japan'
$UserConfig.WeatherLocation = $weatherLoc

if ($UserConfig.WeatherLocation) {
    $weatherKey = Read-TextInput `
        -Prompt   'Weather API key' `
        -Hint     'Free key at weatherapi.com -- press Escape to skip weather widget' `
        -IsSecret
    $UserConfig.WeatherKey = $weatherKey
} else {
    $UserConfig.WeatherKey = $null
}

$tzInput = Read-TextInput `
    -Prompt  'Clock timezones' `
    -Default '["UTC"]' `
    -Hint    'YAML list, e.g. ["EST","UTC"] or ["GMT","IST"]'
$UserConfig.ClockTimezones = if ($tzInput) { $tzInput } else { '["UTC"]' }

#endregion

#region ── Step 9: Confirmation ───────────────────────────────────────────────

Show-Header -Subtitle 'Review your choices'

Write-Host "  $($C.BrightYellow)Theme$($C.Reset)          $($UserConfig.ThemeFile)"
Write-Host "  $($C.BrightYellow)Font$($C.Reset)           $($UserConfig.FontName) -> $($UserConfig.FontFamily)"
Write-Host "  $($C.BrightYellow)Editor$($C.Reset)         $($UserConfig.CodeEditor)"
Write-Host "  $($C.BrightYellow)Shell$($C.Reset)          $($UserConfig.DefaultShell)"
Write-Host "  $($C.BrightYellow)Backdrop$($C.Reset)       $($UserConfig.Backdrop)"
Write-Host "  $($C.BrightYellow)Bar$($C.Reset)            $($UserConfig.BarPosition) · $($UserConfig.BarHeight) height"
Write-Host "  $($C.BrightYellow)Corners$($C.Reset)        $($UserConfig.CornerRadius)"
Write-Host "  $($C.BrightYellow)Gaps$($C.Reset)           $($UserConfig.GapSize)"
Write-Host "  $($C.BrightYellow)Borders$($C.Reset)        $($UserConfig.BorderStyle) · $($UserConfig.BorderWidth)"
Write-Host "  $($C.BrightYellow)Animation$($C.Reset)      $($UserConfig.Animation)"
Write-Host "  $($C.BrightYellow)Keybindings$($C.Reset)    $($UserConfig.Modifier) + $($UserConfig.KeyLayout)"
Write-Host "  $($C.BrightYellow)Weather$($C.Reset)        $(if ($UserConfig.WeatherKey) { $UserConfig.WeatherLocation } else { 'disabled' })"
Write-Host "  $($C.BrightYellow)Timezones$($C.Reset)      $($UserConfig.ClockTimezones)"
Write-Host ''

if ($UserConfig.AppsToInstall.Count -gt 0) {
    Write-Host "  $($C.BrightYellow)Apps to install:$($C.Reset)"
    $UserConfig.AppsToInstall | ForEach-Object { Write-Host "    · $_" }
} else {
    Write-Info 'No apps to install.'
}

Write-Host ''
Write-Host "  $($C.BrightBlack)Press Enter to install · Escape to cancel$($C.Reset)"
$confirm = [Console]::ReadKey($true)
if ($confirm.Key -eq 'Escape') { Write-Host 'Installation cancelled.'; exit 0 }

#endregion

#region ── Step 10: Installation ──────────────────────────────────────────────

Show-Header -Subtitle 'Installing...'
$totalSteps = 4
$step       = 0

# ── 10a: Install apps ──────────────────────────────────────────────────────
if ($UserConfig.AppsToInstall.Count -gt 0) {
    $step++
    Show-Progress -Activity 'Installing apps' -Step $step -Total $totalSteps
    Write-Step "Installing $(($UserConfig.AppsToInstall).Count) apps..."
    Initialize-WingetSources | Out-Null
    $failed = @()
    foreach ($app in $UserConfig.AppsToInstall) {
        $ok = Install-App -AppName $app
        if (-not $ok) { $failed += $app }
    }
    if ($failed.Count -gt 0) {
        Write-Warn "Some apps failed to install: $($failed -join ', ')"
        Write-Info "You can install them manually: winget install --id <id>"
    } else {
        Write-Success 'All apps installed'
    }
} else {
    $step++
    Write-Info 'Skipping app installation'
}

# ── 10b: Install font (runs in a separate elevated process) ───────────────
# Font install writes to C:\Windows\Fonts which requires administrator rights.
# Rather than elevating the whole installer (which breaks winget for user-scoped
# apps like YASB), we spawn only this step elevated and wait for it to finish.
if (-not $SkipFont) {
    $step++
    Show-Progress -Activity "Installing $($UserConfig.FontName) Nerd Font" -Step $step -Total $totalSteps
    Write-Step "Downloading and installing $($UserConfig.FontName) (will prompt for admin)..."
    try {
        $helper   = Join-Path $SrcDir 'Install-Font-Elevated.ps1'
        $fontArgs = "-ExecutionPolicy Bypass -NoProfile -File `"$helper`"" +
                    " -FontName `"$($UserConfig.FontName)`" -SrcDir `"$SrcDir`""
        $fontProc = Start-Process powershell -ArgumentList $fontArgs -Verb RunAs -Wait -PassThru
        if ($fontProc.ExitCode -eq 0) {
            Write-Success "Font installed: $($UserConfig.FontFamily)"
        } else {
            Write-Warn 'Font installation failed -- install it manually from https://www.nerdfonts.com'
        }
    } catch {
        Write-Warn "Font elevation cancelled or failed: $_ -- continuing without font"
        Write-Info 'You can install any Nerd Font manually from https://www.nerdfonts.com/font-downloads'
    }
} else {
    $step++
    Write-Info 'Skipping font installation'
}

# ── 10c: Render configs ────────────────────────────────────────────────────
$step++
Show-Progress -Activity 'Generating config files' -Step $step -Total $totalSteps
Write-Step "Rendering config templates..."
New-Item -ItemType Directory -Path $TempOut -Force | Out-Null
try {
    Invoke-ApplyTheme -UserConfig $UserConfig -SourceDir $ConfigsDir -OutputDir $TempOut
    Write-Success "Config files rendered to temp directory"
} catch {
    Write-Fail "Failed to render configs: $_"
    exit 1
}

# ── 10d: Backup + deploy ───────────────────────────────────────────────────
$step++
Show-Progress -Activity 'Backing up and deploying configs' -Step $step -Total $totalSteps

if (-not $DryRun) {
    Write-Step "Backing up existing configs..."
    try {
        $backupPath = Backup-Configs -UserConfig $UserConfig
        if ($backupPath) {
            Write-Success "Backup saved to: $backupPath"
        } else {
            Write-Info 'No existing configs to back up'
        }
    } catch {
        Write-Warn "Backup failed: $_ -- proceeding anyway"
        $backupPath = $null
    }

    Write-Step "Deploying configs..."
    $results = Deploy-Configs -SourceDir $TempOut -UserConfig $UserConfig
    $deployErrors = $results.GetEnumerator() | Where-Object { $_.Value -like 'error:*' }
    $deployErrors | ForEach-Object { Write-Warn "  $($_.Key): $($_.Value)" }
    Write-Success "Configs deployed ($($results.Count - @($deployErrors).Count)/$($results.Count) files)"

    Write-Step "Setting up startup entries..."
    try {
        Set-StartupItems
        Write-Success 'Startup entry configured (Komorebi desktop session)'
    } catch {
        Write-Warn "Startup setup partial: $_"
        Write-Info 'You can add shortcuts to the Startup folder manually'
    }

    if (($UserConfig.AppsToInstall -contains 'YASB') -or (Test-AppInstalled -AppName 'YASB')) {
        Write-Step "Enabling Windows taskbar auto-hide for YASB..."
        try {
            Set-TaskbarAutoHide
            Write-Success 'Windows taskbar auto-hide enabled'
        } catch {
            Write-Warn "Taskbar auto-hide setup failed: $_"
        }
    }
} else {
    Write-Info "Dry run -- rendered configs are in: $TempOut"
}

# Clean up temp dir unless dry run (so user can inspect)
if (-not $DryRun) {
    Remove-Item $TempOut -Recurse -Force -ErrorAction SilentlyContinue
}

#endregion

#region ── Step 11: Optional Flow Launcher plugins ─────────────────────────────

if (-not $DryRun -and (($UserConfig.AppsToInstall -contains 'FlowLauncher') -or (Test-AppInstalled -AppName 'FlowLauncher'))) {
    Show-Header -Subtitle 'Optional Flow Launcher plugins'

    $pluginSuggestions = @(Get-FlowLauncherPluginSuggestions)
    $pluginNames = $pluginSuggestions | ForEach-Object { $_.Name }
    $pluginDescs = $pluginSuggestions | ForEach-Object { $_.Description }
    $preChecked = $pluginSuggestions | ForEach-Object { [bool]$_.Recommended }

    $pluginChoices = Show-MultiMenu `
        -Title       'Select plugin install commands to prepare' `
        -Options     $pluginNames `
        -Descriptions $pluginDescs `
        -PreChecked   $preChecked

    if ($null -ne $pluginChoices) {
        $selectedPlugins = @()
        for ($i = 0; $i -lt $pluginNames.Count; $i++) {
            if ($pluginChoices[$i]) { $selectedPlugins += $pluginSuggestions[$i] }
        }

        if ($selectedPlugins.Count -gt 0) {
            $pluginResult = Publish-FlowLauncherPluginInstructions -Plugins $selectedPlugins
            if ($pluginResult.CopiedToClipboard) {
                Write-Success 'Flow Launcher plugin commands copied to clipboard'
            } else {
                Write-Warn 'Flow Launcher plugin commands could not be copied to clipboard'
            }
            Write-Info 'Open Flow Launcher and run each prepared pm install command.'
            Write-Host ''
            $pluginResult.Commands | ForEach-Object { Write-Host "    $_" }
            Write-Host ''
            Write-Host "  $($C.BrightBlack)Press any key to continue.$($C.Reset)"
            $null = [Console]::ReadKey($true)
        }
    }
}

#endregion

#region ── Step 12: Done ───────────────────────────────────────────────────────

Show-Header -Subtitle 'Installation complete!'

Write-Host "  $($C.BrightGreen)Everything is set up.$($C.Reset)"
Write-Host ''
Write-Host "  $($C.BrightYellow)Next steps:$($C.Reset)"
Write-Host "    1. Sign out and back in (or restart) to apply startup items"
Write-Host "    2. Open WezTerm -- it should start with your new theme and font"
Write-Host "    3. Komorebi starts the whole desktop session: komorebi, YASB, Flow Launcher"
Write-Host ''

if (-not $UserConfig.WeatherKey) {
    Write-Info 'Weather widget is disabled -- get a free key at weatherapi.com'
    Write-Info "Then add it to: $env:USERPROFILE\.config\yasb\config.yaml"
    Write-Host ''
}

Write-Info 'Keybinding cheat sheet:'
$mod = $UserConfig.Modifier
Write-Host "    $mod + 1-6         Switch workspaces"
Write-Host "    $mod + direction   Focus window"
Write-Host "    $mod + Shift + dir Move window"
Write-Host "    Win + Q            Open terminal"
Write-Host "    Win + E            Open file explorer"
Write-Host ''
Write-Host "  $($C.BrightBlack)Press any key to exit.$($C.Reset)"
$null = [Console]::ReadKey($true)

#endregion
