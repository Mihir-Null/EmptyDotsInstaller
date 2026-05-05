# dotfiles-installer — Architecture

## Project intent

Turn Mihir's Windows desktop environment (wezterm + yasb + komorebi + AHK + a chosen code editor + Flow Launcher) into a portable, beginner-friendly installer with a PowerShell TUI walkthrough. Friends run one script, pick their preferences, and get a working tiling desktop.

---

## whkd analysis (RETIRED)

**Finding**: `whkd` is installed (v0.2.10) but has never been the active hotkey system. `komorebi.json` has `"whkd": false`, no whkd process is running, and `AutoHotkey64` IS running — the live system is `komorebi.ahk` (AHK v2). The `whkdrc` is dead legacy config.

**Decision**: Drop whkd from the installer entirely. Template `komorebi.ahk` for keybinding customization. AHK is still included in the app list since `komorebi.ahk` depends on it.

---

## Repo layout

```
dotfiles-installer/
├── install.ps1                   # Entry point — bootstrap + TUI orchestration
├── configs/                      # Template config files ({{PLACEHOLDER}} tokens)
│   ├── wezterm/
│   │   └── wezterm.lua
│   ├── yasb/
│   │   ├── config.yaml
│   │   └── styles.css
│   ├── komorebi/
│   │   ├── komorebi.json
│   │   ├── komorebi.bar.json
│   │   ├── komorebi.ahk         # AHK v2 — primary keybinding config
│   │   └── applications.json
│   ├── vscodium/
│   │   └── settings.json        # VS Code-family settings: font + color theme
│   ├── zed/
│   │   └── settings.json        # Zed settings: font + minimal theme
│   └── flow-launcher/
│       └── Settings.json
├── themes/                       # Theme definitions (PowerShell data files)
│   ├── catppuccin-mocha.psd1
│   ├── nord.psd1
│   ├── tokyo-night.psd1
│   └── gruvbox.psd1
├── src/                          # PowerShell modules (imported by install.ps1)
│   ├── TUI.psm1                  # Console TUI engine
│   ├── Install-Apps.psm1         # winget app installer
│   ├── Install-Font.psm1         # Nerd Font downloader + Windows installer
│   ├── Apply-Theme.psm1          # Template engine — renders {{}} tokens
│   ├── Deploy-Configs.psm1       # Backup existing + copy rendered configs
│   └── Post-Install.psm1         # Taskbar and Flow Launcher plugin finishing steps
└── ARCHITECTURE.md
```

---

## Components

### 1 — TUI.psm1 (TUI Engine)

**Responsibility**: All user-facing console interaction. Zero knowledge of config files or themes.

**Interface** (functions exported):
```
Show-Header [title]
Show-Menu -Title [str] -Options [array] -Descriptions [array]  → [int] index
Show-MultiMenu -Title [str] -Options [array]                   → [bool[]] selected
Read-TextInput -Prompt [str] -Default [str]                    → [str]
Show-Progress -Activity [str] -Step [int] -Total [int]
Show-ColorSwatch -HexColor [str]
Write-Success / Write-Info / Write-Warn / Write-Step
```

**Implementation notes**:
- Uses `[System.Console]::ReadKey()` for arrow/space/enter input — no external packages
- ANSI escape sequences via `$PSStyle` (PS 7.2+) with fallback to raw `\e[` codes for PS 5.1
- Box-drawing characters for menus and headers
- `Show-ColorSwatch` renders a 3-line colored block next to the theme name so users can preview accent colors visually before choosing

---

### 2 — Install-Apps.psm1 (App Installer)

**Responsibility**: Detect which target apps are installed; offer to install missing ones via winget.

**Apps managed** (whkd removed — replaced by AHK's komorebi.ahk):
| App | winget ID |
|-----|-----------|
| WezTerm | `wez.wezterm` |
| YASB | `AmN.yasb` |
| Komorebi | `LGUG2Z.komorebi` |
| AutoHotkey v2 | `AutoHotkey.AutoHotkey` |
| Visual Studio Code | `Microsoft.VisualStudioCode` |
| VSCodium | `VSCodium.VSCodium` |
| Zed | `Zed.Zed` |
| Cursor | `Anysphere.Cursor` |
| Flow Launcher | `Flow-Launcher.Flow-Launcher` |

**Interface**:
```
Get-InstalledApps              → [hashtable] { appName → $true/$false }
Install-App -WingetId [str]    → [bool] success
```

**Detection strategy**: `winget list --id <id> --exact` exit code 0 = installed.

---

### 3 — Install-Font.psm1 (Nerd Font Installer)

**Responsibility**: Download a chosen Nerd Font from the Nerd Fonts GitHub release and install it system-wide.

**Fonts offered**:
| Display name | GitHub release filename |
|---|---|
| JetBrains Mono (recommended) | `JetBrainsMono.zip` |
| Fira Code | `FiraCode.zip` |
| Cascadia Code | `CascadiaCode.zip` |
| Hack | `Hack.zip` |
| GohuFont (current) | `Gohu.zip` |
| Iosevka | `Iosevka.zip` |

**Interface**:
```
Install-NerdFont -FontName [str]   → [bool] success
```

**Process**: Download zip from latest Nerd Fonts release → extract to temp → copy TTF/OTF to `C:\Windows\Fonts` → register each file in `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts`.

**Requires elevation** (writes to `C:\Windows\Fonts`). The bootstrap in `install.ps1` handles self-elevation.

---

### 4 — Apply-Theme.psm1 (Template Engine)

**Responsibility**: Take a resolved `$UserConfig` hashtable and render all template files in `configs/` into a temp output directory by replacing `{{PLACEHOLDER}}` tokens.

**Interface**:
```
Invoke-ApplyTheme -UserConfig [hashtable] -SourceDir [str] -OutputDir [str]
```

#### Complete token reference

**wezterm.lua**
| Token | Meaning | Example values |
|---|---|---|
| `{{WEZTERM_COLOR_SCHEME}}` | Built-in wezterm scheme name | `"Catppuccin Mocha"` |
| `{{FONT_FAMILY}}` | Font display name | `"JetBrainsMono Nerd Font"` |
| `{{FONT_SIZE}}` | Numeric point size | `14` |
| `{{WEZTERM_BG_OPACITY}}` | Window background opacity | `0.65`, `1.0` |
| `{{WEZTERM_BACKDROP}}` | Win32 system backdrop | `"Disable"`, `"Acrylic"`, `"Mica"` |
| `{{MAX_FPS}}` | Max render FPS | `60`, `144` |
| `{{WEZTERM_DEFAULT_SHELL}}` | Default shell command | `{ "wsl.exe", "--cd", "~" }`, `{ "pwsh.exe" }` |

**yasb/styles.css**
| Token | Meaning |
|---|---|
| `{{CSS_ROOT_BLOCK}}` | Entire `:root { ... }` block, replaced wholesale per theme |
| `{{CSS_FONT_FAMILY}}` | Font name in `* { font-family }` |
| `{{CSS_FONT_SIZE}}` | Font size in `* { font-size }` |

> The `:root` block replacement approach means each theme's `.psd1` carries a pre-written CSS variable block containing all color tokens (`--mauve`, `--red`, `--container-border-radius`, etc.) — no per-variable patching needed.

**yasb/config.yaml**
| Token | Meaning | Example values |
|---|---|---|
| `{{BAR_HEIGHT}}` | Bar height in px | `36`, `45`, `54` |
| `{{BAR_POSITION}}` | Bar screen edge | `"top"`, `"bottom"` |
| `{{WEATHER_API_KEY}}` | weatherapi.com key | `"abc123..."` or `""` |
| `{{WEATHER_LOCATION}}` | Weather location string | `"New York, NY, USA"` |
| `{{YASB_CLOCK_TIMEZONES}}` | Clock timezone list | `["EST","UTC"]` |

**komorebi/komorebi.json**
| Token | Meaning | Example values |
|---|---|---|
| `{{BORDER_COLOR_SINGLE}}` | Focused window border | `"#cba6f7"` |
| `{{BORDER_COLOR_STACK}}` | Stacked window border | `"#a6e3a1"` |
| `{{BORDER_COLOR_MONOCLE}}` | Monocle border | `"#f38ba8"` |
| `{{BORDER_COLOR_UNFOCUSED}}` | Unfocused border | `"#808080"` |
| `{{GAP_SIZE}}` | workspace + container padding px | `0`, `4`, `8`, `16` |
| `{{BORDER_WIDTH}}` | Border thickness px | `2`, `4`, `6` |
| `{{BORDER_STYLE}}` | Corner style | `"Square"`, `"Rounded"` |
| `{{ANIMATION_ENABLED}}` | Enable window animations | `true`, `false` |
| `{{ANIMATION_DURATION}}` | Animation ms | `0`, `150`, `250`, `400` |
| `{{STACKBAR_BG}}` | Stacked tab bar background | `"#141414"` |

**komorebi/komorebi.ahk**
| Token | Meaning |
|---|---|
| `{{AHK_MOD}}` | Primary modifier in AHK syntax (`!` alt, `#` win, `^!` ctrl+alt) |
| `{{AHK_MOD_SHIFT}}` | Modifier + shift (`!+`, `#+`, `^!+`) |
| `{{AHK_MOVE_MOD}}` | Directional movement modifier; Shift only for layouts whose move/focus keys overlap |
| `{{SEL_L}}` / `{{SEL_R}}` / `{{SEL_U}}` / `{{SEL_D}}` | Focus/select direction keys |
| `{{MOV_L}}` / `{{MOV_R}}` / `{{MOV_U}}` / `{{MOV_D}}` | Move-window direction keys |

**vscodium/settings.json** (deployed to the selected VS Code-family editor)
| Token | Meaning |
|---|---|
| `{{VSCODIUM_THEME}}` | Workbench color theme name |
| `{{FONT_FAMILY}}` | Editor + terminal font family |
| `{{FONT_SIZE}}` | Editor font size |
| `{{VSCODIUM_WSL_SETTINGS}}` | WSL terminal settings snippet (if WSL detected) |

**zed/settings.json**
| Token | Meaning |
|---|---|
| `{{ZED_THEME}}` | Zed theme name |
| `{{FONT_FAMILY}}` | Editor + terminal font family |
| `{{FONT_SIZE}}` | Editor + terminal font size |

**Implementation**: Pure `[string]::Replace` per token — does NOT parse Lua/JSON/YAML/CSS. Comments and formatting are preserved as-is.

---

### 5 — Deploy-Configs.psm1 (Backup + Deploy)

**Responsibility**: Back up the user's existing configs, then copy the rendered output files to their correct system locations.

**Interface**:
```
Backup-Configs -BackupRoot [str]    → [str] backupPath
Deploy-Configs -SourceDir [str]     → [void]
```

**Deployment map**:
| Rendered source | Destination |
|---|---|
| `configs/wezterm/wezterm.lua` | `~\.config\wezterm\wezterm.lua` |
| `configs/yasb/config.yaml` | `~\.config\yasb\config.yaml` |
| `configs/yasb/styles.css` | `~\.config\yasb\styles.css` |
| `configs/komorebi/komorebi.json` | `~\.config\komorebi\komorebi.json` |
| `configs/komorebi/komorebi.bar.json` | `~\.config\komorebi\komorebi.bar.json` |
| `configs/komorebi/komorebi.ahk` | `~\.config\komorebi\komorebi.ahk` |
| `configs/komorebi/applications.json` | `~\.config\komorebi\applications.json` |
| `configs/vscodium/settings.json` | Selected editor: VS Code, VSCodium, or Cursor |
| `configs/zed/settings.json` | Selected editor: Zed |
| `configs/flow-launcher/Settings.json` | `~\AppData\Roaming\FlowLauncher\Settings\Settings.json` |

**Backup**: Copies each destination (if it exists) to `~\.config-backup-<timestamp>\` before overwriting. Prints the backup path so users can recover if needed.

---

### 6 — install.ps1 (Entry Point + TUI Walkthrough)

**Responsibility**: Bootstrap, import modules, run the full TUI walkthrough, assemble `$UserConfig`, invoke all installer components in order.

#### TUI walkthrough screens

```
[1]  Welcome          ASCII art header, brief description of what's being installed
[2]  Code Editor      Single-select: VS Code / VSCodium / Zed / Cursor
[3]  Apps             Multi-select: which apps to install (pre-checked = not yet installed)
[4]  Theme            Single-select with live color swatch preview
                        • Catppuccin Mocha  • Nord  • Tokyo Night  • Gruvbox
[5]  Font             Single-select: 6 Nerd Font options
[6]  Shell            Single-select: WSL / PowerShell 7 / cmd (for wezterm default)
[7]  Look & Feel      Single-select groups:
                        • Transparency: Solid / Glass (Acrylic) / Frosted (Mica)
                        • Bar position: Top / Bottom
                        • Bar height: Compact (36px) / Normal (45px) / Tall (54px)
                        • Widget corners: Sharp / Slight / Rounded / Pill
                        • Window gaps: None (0px) / Tight (4px) / Comfortable (8px) / Loose (16px)
                        • Borders: Square / Rounded, Thin/Normal/Thick
                        • Animations: Off / Fast / Medium / Slow
[8]  Keybindings      Two sub-choices:
                        Modifier: Alt (default) / Super (Win key — fewer browser conflicts) / Ctrl+Alt
                        Layout:   Left-hand / Split keyboard / Vim HJKL
                          Left-hand   — Alt+WASD = focus, Alt+Shift+WASD = move (all left)
                          Split       — Alt+WASD = move window, Alt+OKL; = focus window
                          Vim HJKL    — Alt+HJKL = focus, Alt+WASD = move
[9]  Personal         Text inputs (all optional/skippable):
                        • Weather location (e.g. "New York, NY, USA")
                        • Weather API key (free at weatherapi.com — link shown)
                        • Clock timezones (e.g. EST, UTC)
[10] Confirm          Full summary of all choices, Enter to install / Esc to go back
[11] Installing       Live progress — each step shows name + spinner + ✓ / ✗
[12] Post-install     Optional Flow Launcher plugin commands copied for `pm install`
[13] Done             Success message, restart tips, backup path shown
```

#### Bootstrap logic

- Requires PowerShell 5.1+ — exits with a friendly message if older
- Self-elevates to admin via `Start-Process -Verb RunAs` if not already elevated (needed for font install to `C:\Windows\Fonts`)
- If user declines UAC: proceeds without font install, notes what was skipped
- `$ErrorActionPreference = 'Stop'` with `try/catch` around each phase — one failure doesn't abort everything

---

## Theme definitions (`.psd1` format)

Each theme file is a PowerShell data file (`Import-PowerShellDataFile`):

```powershell
@{
    Name              = "Catppuccin Mocha"
    WeztermScheme     = "Catppuccin Mocha"     # must match wezterm built-in name exactly
    VscodiumTheme     = "Catppuccin Mocha"     # VSCodium marketplace theme name
    BorderSingle      = "#cba6f7"              # mauve — focused window
    BorderStack       = "#a6e3a1"              # green — stacked
    BorderMonocle     = "#f38ba8"              # red   — monocle
    StackbarBg        = "#1e1e2e"              # base
    CssRootBlock      = @"
:root {
    --mauve: #cba6f7;
    --red: #f38ba8;
    --yellow: #f9e2af;
    --blue: #89b4fa;
    --teal: #94e2d5;
    --lavender: #b4befe;
    --maroon: #eba0ac;
    --frostdark: rgba(30, 30, 46, 0.85);
    --white: rgba(205, 214, 244, 0.9);
    --frostwhite: rgba(205, 214, 244, 0.9);
    --frostglass: rgba(205, 214, 244, 0.15);
    --frostgray: rgba(108, 112, 134, 0.7);
    --darkfrost: rgba(49, 50, 68, 0.8);
    --gray: rgb(58, 60, 82);
    --mantle: rgba(24, 24, 37, 0.8);
    --transparent: transparent;
    --container-padding: 0 16px;
    --container-border-radius: {{CORNER_RADIUS}};
}
"@
}
```

Note `{{CORNER_RADIUS}}` inside the CSS block — the corner radius is a user-choice that gets injected even within the theme's CSS root block.

**Corner radius values** (mapped from TUI choice):
| TUI Label | Value |
|---|---|
| Sharp | `0px` |
| Slight | `6px` |
| Rounded | `12px` |
| Pill | `20px` |

---

## Keybinding presets

### AHK modifier mapping
| TUI Choice | AHK modifier prefix |
|---|---|
| Alt (default) | `!` |
| Super (Win key) | `#` |
| Ctrl+Alt | `^!` |

### Direction key sets
| Preset | SEL (focus) L/D/U/R | MOV (move) L/D/U/R |
|---|---|---|
| Left-hand (current) | a / s / w / d | a / s / w / d |
| Split keyboard | k / oem_1 / o / l | a / s / w / d |
| Vim HJKL | h / j / k / l | a / s / w / d |

> `oem_1` is AHK's code for semicolon (`;`) — necessary because `;` is a comment character in AHK.
> In split mode: **O** = up, **K** = left, **L** = right, **;** = down forms a spatial diamond on the right side of the keyboard, mirroring the WASD cluster on the left.

### AHK template snippet (illustrating token usage)
```ahk
; Focus windows
{{AHK_MOD}}{{SEL_L}}:: Komorebic("focus left")
{{AHK_MOD}}{{SEL_D}}:: Komorebic("focus down")
{{AHK_MOD}}{{SEL_U}}:: Komorebic("focus up")
{{AHK_MOD}}{{SEL_R}}:: Komorebic("focus right")

; Move windows
{{AHK_MOVE_MOD}}{{MOV_L}}:: Komorebic("move left")
{{AHK_MOVE_MOD}}{{MOV_D}}:: Komorebic("move down")
{{AHK_MOVE_MOD}}{{MOV_U}}:: Komorebic("move up")
{{AHK_MOVE_MOD}}{{MOV_R}}:: Komorebic("move right")

; Resize (always Win+directions for coarse, always Win+WASD for fine)
<#Right:: Komorebic("resize-axis horizontal increase 0.05")
<#Left::  Komorebic("resize-axis horizontal decrease 0.05")
<#Up::    Komorebic("resize-axis vertical decrease 0.05")
<#Down::  Komorebic("resize-axis vertical increase 0.05")
```

### Personal items stripped from komorebi.ahk template
These are removed from the shared template with comments explaining what they were:
- Named workspaces (`Comms`, `ToDo`) — user-specific, documented with instructions
- App launchers kept as sensible defaults: Win+Q = wezterm, Win+E = explorer
- Firefox launcher commented out (friends may not use Firefox)

---

## VSCodium settings (minimal)

The installed `settings.json` sets only:
- `workbench.colorTheme` → matched to chosen theme
- `editor.fontFamily` → chosen Nerd Font  
- `editor.fontSize` → chosen font size
- `terminal.integrated.fontFamily` → same Nerd Font
- `editor.fontLigatures` → `true`
- A comment block with instructions to install Remote-WSL extension if WSL is detected

No other editor preferences are deployed (no personal keybindings, extensions list, etc.).

---

## What's intentionally excluded

| Item | Why | What friends do instead |
|---|---|---|
| Monitor display IDs (`display_index_preferences`) | Hardware-specific | Add via `komorebic display-index-preferences` after install |
| WSL distro launch entries in wezterm | Personal (NixOS, Arch) | Commented template showing how to add theirs |
| SSH host entries in wezterm | Personal | Commented template |
| Named workspaces in AHK | Personal (Comms, ToDo) | Commented template |
| Weather widget | Optional | Skipped if no API key provided |
| whkd config | Retired — not in use | N/A |

---

## Component status

| Component | Status |
|---|---|
| ARCHITECTURE.md | ✅ Done |
| configs/ (template files) | ✅ Done |
| themes/ (.psd1 files) | ✅ Done |
| TUI.psm1 | ✅ Done |
| Apply-Theme.psm1 | ✅ Done |
| Install-Apps.psm1 | ✅ Done |
| Install-Font.psm1 | ✅ Done |
| Deploy-Configs.psm1 | ✅ Done |
| install.ps1 | ✅ Done |
| End-to-end verification | ✅ Verified (dry-run, all 39 tokens resolved, no leftovers) |
