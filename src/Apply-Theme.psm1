# Apply-Theme.psm1 — Template engine
# Renders all {{PLACEHOLDER}} tokens in configs/ into a temp output directory.

Set-StrictMode -Version Latest

#region ── Preset tables ───────────────────────────────────────────────────────

# Keybinding presets
# Each entry defines focus keys, movement keys, and whether directional
# movement needs Shift to avoid colliding with focus.
$Script:KeyPresets = @{
    'Left-hand' = @{
        SelL = 'a'; SelD = 's'; SelU = 'w'; SelR = 'd'
        MovL = 'a'; MovD = 's'; MovU = 'w'; MovR = 'd'
        MoveUsesShift = $true
    }
    'Split'     = @{
        # OKL; spatial diamond on right hand — semicolon escaped for AHK v2
        SelL = 'k';  SelD = "``;"  ; SelU = 'o'; SelR = 'l'
        MovL = 'a';  MovD = 's'    ; MovU = 'w'; MovR = 'd'
        MoveUsesShift = $false
    }
    'Vim'       = @{
        SelL = 'h'; SelD = 'j'; SelU = 'k'; SelR = 'l'
        MovL = 'a'; MovD = 's'; MovU = 'w'; MovR = 'd'
        MoveUsesShift = $false
    }
}

# Modifier presets (AHK v2 syntax)
$Script:ModPresets = @{
    'Alt'      = @{ Mod = '!';   ModShift = '!+' }
    'Super'    = @{ Mod = '#';   ModShift = '#+' }
    'Ctrl+Alt' = @{ Mod = '^!';  ModShift = '^!+' }
}

# Gap size presets
$Script:GapPresets = @{
    'None'        = 0
    'Tight'       = 4
    'Comfortable' = 8
    'Loose'       = 16
}

# Corner radius presets (CSS px value)
$Script:CornerPresets = @{
    'Sharp'   = '0px'
    'Slight'  = '6px'
    'Rounded' = '12px'
    'Pill'    = '20px'
}

# Animation presets
$Script:AnimPresets = @{
    'Off'    = @{ Enabled = 'false'; Duration = 0 }
    'Fast'   = @{ Enabled = 'true';  Duration = 150 }
    'Medium' = @{ Enabled = 'true';  Duration = 250 }
    'Slow'   = @{ Enabled = 'true';  Duration = 400 }
}

# Bar height presets
$Script:BarHeightPresets = @{
    'Compact' = 36
    'Normal'  = 45
    'Tall'    = 54
}

# Border width presets
$Script:BorderWidthPresets = @{
    'Thin'   = 2
    'Normal' = 4
    'Thick'  = 6
}

# Wezterm backdrop values
$Script:BackdropPresets = @{
    'Solid'  = @{ Backdrop = 'Disable'; Opacity = 1.0 }
    'Glass'  = @{ Backdrop = 'Acrylic'; Opacity = 0.75 }
    'Frosted'= @{ Backdrop = 'Mica';    Opacity = 0.85 }
}

# Wezterm shell presets
$Script:ShellPresets = @{
    'WSL'           = '{ "wsl.exe", "--cd", "~" }'
    'PowerShell 7'  = '{ "pwsh.exe" }'
    'cmd'           = '{ "cmd.exe" }'
}

# Flow Launcher backdrop mapping (matches Windows backdrop types)
$Script:FlowBackdropMap = @{
    'Solid'   = 'None'
    'Glass'   = 'Acrylic'
    'Frosted' = 'Mica'
}

#endregion

#region ── Token resolver ──────────────────────────────────────────────────────

function Resolve-Tokens {
    <#
    .SYNOPSIS
        Given a UserConfig hashtable, returns a flat token→value hashtable
        suitable for string replacement across all template files.
    #>
    param([Parameter(Mandatory)] [hashtable] $UserConfig)

    $t = $UserConfig  # alias for brevity

    # Load theme definition
    $themeFile = Join-Path (Join-Path $PSScriptRoot '..\themes') "$($t.ThemeFile).psd1"
    $theme     = Import-PowerShellDataFile $themeFile

    # Resolve presets
    $keys    = $Script:KeyPresets[$t.KeyLayout]
    $mod     = $Script:ModPresets[$t.Modifier]
    $gap     = $Script:GapPresets[$t.GapSize]
    $corner  = $Script:CornerPresets[$t.CornerRadius]
    $anim    = $Script:AnimPresets[$t.Animation]
    $barH    = $Script:BarHeightPresets[$t.BarHeight]
    $bw      = $Script:BorderWidthPresets[$t.BorderWidth]
    $bd      = $Script:BackdropPresets[$t.Backdrop]
    $shell   = $Script:ShellPresets[$t.DefaultShell]
    $moveMod = if ($keys.MoveUsesShift) { $mod.ModShift } else { $mod.Mod }

    # Build CSS root block (inject corner radius into the theme's block)
    $cssRoot = $theme.CssRootBlock -replace '{{CORNER_RADIUS}}', $corner

    # VSCodium WSL settings snippet
    $wslSettings = ''
    if ($t.WslDetected) {
        $wslSettings = @'
,
    "remote.WSL.enabled": true,
    "terminal.integrated.defaultProfile.windows": "Ubuntu (WSL)"
'@
    }

    # Weather handling — if no key, use placeholder that won't crash YASB
    $weatherKey      = if ($t.WeatherKey)      { $t.WeatherKey }      else { '' }
    $weatherLocation = if ($t.WeatherLocation) { $t.WeatherLocation } else { 'New York, NY, USA' }
    $clockTimezones  = if ($t.ClockTimezones)  { $t.ClockTimezones }  else { '["UTC"]' }
    $zedTheme        = if ($theme.ContainsKey('ZedTheme')) { $theme.ZedTheme } else { 'One Dark' }

    # Build and return token map
    return @{
        # Wezterm
        'WEZTERM_COLOR_SCHEME'  = $theme.WeztermScheme
        'FONT_FAMILY'           = $t.FontFamily
        'FONT_SIZE'             = $t.FontSize
        'WEZTERM_BG_OPACITY'    = $bd.Opacity.ToString('F2')
        'WEZTERM_BACKDROP'      = $bd.Backdrop
        'MAX_FPS'               = '144'
        'WEZTERM_DEFAULT_SHELL' = $shell

        # YASB / CSS
        'CSS_ROOT_BLOCK'        = $cssRoot
        'CSS_FONT_FAMILY'       = $t.FontFamily
        'CSS_FONT_SIZE'         = '16px'
        'BAR_HEIGHT'            = $barH.ToString()
        'BAR_POSITION'          = $t.BarPosition.ToLower()
        'WEATHER_API_KEY'       = $weatherKey
        'WEATHER_LOCATION'      = $weatherLocation
        'YASB_CLOCK_TIMEZONES'  = $clockTimezones

        # Komorebi
        'BORDER_COLOR_SINGLE'   = $theme.BorderSingle
        'BORDER_COLOR_STACK'    = $theme.BorderStack
        'BORDER_COLOR_MONOCLE'  = $theme.BorderMonocle
        'BORDER_COLOR_UNFOCUSED'= $theme.BorderUnfocused
        'STACKBAR_BG'           = $theme.StackbarBg
        'GAP_SIZE'              = $gap.ToString()
        'BORDER_WIDTH'          = $bw.ToString()
        'BORDER_STYLE'          = $t.BorderStyle
        'ANIMATION_ENABLED'     = $anim.Enabled
        'ANIMATION_DURATION'    = $anim.Duration.ToString()

        # AHK keybindings
        'AHK_MOD'               = $mod.Mod
        'AHK_MOD_SHIFT'         = $mod.ModShift
        'AHK_MOVE_MOD'          = $moveMod
        'SEL_L'                 = $keys.SelL
        'SEL_D'                 = $keys.SelD
        'SEL_U'                 = $keys.SelU
        'SEL_R'                 = $keys.SelR
        'MOV_L'                 = $keys.MovL
        'MOV_D'                 = $keys.MovD
        'MOV_U'                 = $keys.MovU
        'MOV_R'                 = $keys.MovR

        # VSCodium
        'VSCODIUM_THEME'        = $theme.VscodiumTheme
        'VSCODIUM_WSL_SETTINGS' = $wslSettings
        'ZED_THEME'             = $zedTheme

        # Flow Launcher
        'FLOW_THEME'            = $theme.FlowTheme
        'FLOW_BACKDROP'         = $Script:FlowBackdropMap[$t.Backdrop]
    }
}

#endregion

#region ── Template renderer ───────────────────────────────────────────────────

function Invoke-ApplyTheme {
    <#
    .SYNOPSIS
        Renders all template files from $SourceDir into $OutputDir, replacing all
        {{TOKEN}} placeholders with resolved values from $UserConfig.
    #>
    param(
        [Parameter(Mandatory)] [hashtable] $UserConfig,
        [Parameter(Mandatory)] [string]    $SourceDir,
        [Parameter(Mandatory)] [string]    $OutputDir
    )

    $tokens = Resolve-Tokens -UserConfig $UserConfig

    # Walk every file in the source tree
    $files = Get-ChildItem -Path $SourceDir -Recurse -File
    foreach ($file in $files) {
        $relPath  = $file.FullName.Substring($SourceDir.Length).TrimStart('\','/')
        $destPath = Join-Path $OutputDir $relPath
        $destDir  = Split-Path $destPath -Parent

        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        # Read as text and apply all token substitutions
        $content = Get-Content $file.FullName -Raw -Encoding UTF8

        foreach ($key in $tokens.Keys) {
            $content = $content.Replace("{{$key}}", $tokens[$key])
        }

        # Write with UTF8 (no BOM) to avoid issues with AHK / JSON parsers
        [System.IO.File]::WriteAllText($destPath, $content,
            [System.Text.UTF8Encoding]::new($false))
    }
}

#endregion

Export-ModuleMember -Function Invoke-ApplyTheme, Resolve-Tokens
