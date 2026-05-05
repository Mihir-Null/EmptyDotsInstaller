# EmptyDotFiles Windows Desktop Environment

EmptyDotFiles is a PowerShell installer for a Windows tiling desktop environment built around WezTerm, YASB, Komorebi, AutoHotkey v2, Flow Launcher, and a selectable code editor.

The installer provides a terminal UI for choosing apps, theme, font, shell, bar placement, Komorebi gaps/borders, keybindings, weather settings, and optional Flow Launcher plugins. It renders the config templates in `configs/`, backs up existing config files, deploys the rendered files, and configures startup so Komorebi starts the whole desktop session.

## What It Installs

Core apps:

| App | winget id |
| --- | --- |
| PowerShell 7 | `Microsoft.PowerShell` |
| WezTerm | `wez.wezterm` |
| YASB | `AmN.yasb` |
| Komorebi | `LGUG2Z.komorebi` |
| AutoHotkey v2 | `AutoHotkey.AutoHotkey` |
| Flow Launcher | `Flow-Launcher.Flow-Launcher` |

Code editor options:

| Editor | winget id |
| --- | --- |
| Visual Studio Code | `Microsoft.VisualStudioCode` |
| VSCodium | `VSCodium.VSCodium` |
| Zed | `Zed.Zed` |
| Cursor | `Anysphere.Cursor` |

The installer only offers one code editor at install time. VSCodium is the default choice.

## Repository Layout

```text
.
|-- Install.bat                  # Friendly launcher for install.ps1
|-- install.ps1                  # Main installer and TUI flow
|-- configs/                     # Template config files
|-- src/                         # PowerShell modules used by install.ps1
|-- themes/                      # Theme data files
|-- SANDBOX.md                   # Windows Sandbox testing guide
`-- ARCHITECTURE.md              # Implementation details and token reference
```

## Quick Start

Open PowerShell from this repository directory and run:

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\install.ps1
```

Or double-click:

```text
Install.bat
```

`Install.bat` opens the installer in Windows Terminal if `wt.exe` is available, otherwise it falls back to a normal PowerShell window.

## Installer Options

The installer asks for:

1. Code editor: VS Code, VSCodium, Zed, or Cursor.
2. Apps to install with winget.
3. Color theme: Catppuccin Mocha, Nord, Tokyo Night, or Gruvbox Dark.
4. Nerd Font.
5. WezTerm default shell: WSL, PowerShell 7, or cmd.
6. YASB and Komorebi appearance settings.
7. Komorebi keybinding layout.
8. Whether to add the desktop session to Windows startup.
9. Weather and clock settings.
10. Optional Flow Launcher plugin install commands.

Useful flags:

```powershell
# Skip all winget app installation and only configure files/startup.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\install.ps1 -SkipApps

# Skip Nerd Font installation.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\install.ps1 -SkipFont

# Render configs to a temp directory without deploying them.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\install.ps1 -DryRun
```

## What The Installer Changes

The installer deploys rendered configs to:

| Source template | Destination |
| --- | --- |
| `configs\wezterm\wezterm.lua` | `%USERPROFILE%\.config\wezterm\wezterm.lua` |
| `configs\yasb\config.yaml` | `%USERPROFILE%\.config\yasb\config.yaml` |
| `configs\yasb\styles.css` | `%USERPROFILE%\.config\yasb\styles.css` |
| `configs\komorebi\komorebi.json` | `%USERPROFILE%\.config\komorebi\komorebi.json` |
| `configs\komorebi\komorebi.bar.json` | `%USERPROFILE%\.config\komorebi\komorebi.bar.json` |
| `configs\komorebi\komorebi.ahk` | `%USERPROFILE%\.config\komorebi\komorebi.ahk` |
| `configs\komorebi\applications.json` | `%USERPROFILE%\.config\komorebi\applications.json` |
| `configs\flow-launcher\Settings.json` | `%APPDATA%\FlowLauncher\Settings\Settings.json` |
| `configs\vscodium\settings.json` | VS Code, VSCodium, or Cursor user settings |
| `configs\zed\settings.json` | `%APPDATA%\Zed\settings.json` |

Before overwriting an existing file, the installer backs it up under:

```text
%USERPROFILE%\.config-backup\<timestamp>\
```

Startup setup:

- Removes old separate Startup entries for Komorebi, YASB, KomorebiAHK, and Flow Launcher.
- If enabled during install, creates one startup entry at `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\Komorebi`.
- Points the startup entry at AutoHotkey running `%USERPROFILE%\.config\komorebi\komorebi.ahk`.
- `komorebi.ahk` starts Komorebi, YASB, and Flow Launcher together.
- Closing the desktop session through `Ctrl+Alt+Shift+K` stops Flow Launcher, YASB, and Komorebi.

If YASB is installed, the installer also enables Windows taskbar auto-hide.

## Keybindings

The installer supports three layouts.

| Layout | Focus | Move |
| --- | --- | --- |
| Left-hand | `Mod+WASD` | `Mod+Shift+WASD` |
| Split | `Mod+OKL;` | `Mod+WASD` |
| Vim | `Mod+HJKL` | `Mod+WASD` |

`Mod` is chosen during install:

| Choice | AutoHotkey prefix |
| --- | --- |
| Alt | `!` |
| Super / Win | `#` |
| Ctrl+Alt | `^!` |

Workspace keys:

- `Mod+1` through `Mod+6`: focus workspaces.
- `Win+Shift+1` through `Win+Shift+6`: move window and follow.
- `Mod+Shift+1` through `Mod+Shift+6`: move window silently.

## Launching The Desktop Session

After install, the bundled desktop-session script is deployed to:

```text
%USERPROFILE%\.config\komorebi\komorebi.ahk
```

Run it with AutoHotkey v2:

```powershell
& "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe" "$env:USERPROFILE\.config\komorebi\komorebi.ahk"
```

That one script starts:

```text
komorebi
yasb
Flow Launcher
```

The script checks for already-running `komorebi.exe`, `yasb.exe`, and `Flow.Launcher.exe` before starting them, so rerunning the session launcher does not intentionally duplicate those processes.

To stop the full session, press:

```text
Ctrl+Alt+Shift+K
```

The installer includes a startup screen. Choose `Yes` to add the rendered `komorebi.ahk` session to Windows startup. Choose `No` to leave startup disabled and launch the script manually when needed.

## Testing In Windows Sandbox

See `SANDBOX.md` for the Windows Sandbox test workflow, winget bootstrap details, expected output, and sandbox-specific troubleshooting.

## Troubleshooting

### winget install failures

The app installer resets and updates winget sources before installing apps:

```powershell
winget source reset --force
winget source update
```

It installs packages from the community winget source explicitly:

```powershell
winget install --id <package-id> --exact --source winget --silent --accept-package-agreements --accept-source-agreements
```

YASB specifically uses:

```powershell
winget install --id AmN.yasb --exact --source winget --silent --accept-package-agreements --accept-source-agreements
```

If winget returns `0x8a15003b`, it is usually a source/cache problem. Run:

```powershell
winget source reset --force
winget source update
```

Then retry the install command.

### Komorebi is not visible in Startup Apps

The installer starts the desktop environment through AutoHotkey so one entry controls Komorebi, YASB, and Flow Launcher.

Expected startup locations:

```text
HKCU\Software\Microsoft\Windows\CurrentVersion\Run\Komorebi
```

The target should be AutoHotkey with the rendered script as the argument:

```text
AutoHotkey64.exe "%USERPROFILE%\.config\komorebi\komorebi.ahk"
```

### Flow Launcher plugins

The post-install step prepares plugin commands such as:

```text
pm install Browser Tabs by Jeremy Wu
pm install Clipboard+ by Jack251970
pm install WingetFlow by gdemazeux
pm install WSL File Search by Sajxx
```

Open Flow Launcher and run each `pm install ...` command.

### Browser or terminal did not pick up new config

Restart the app. For startup changes, sign out and back in, or restart Windows.

## Manual Setup

Use this section if you want to build the same desktop environment without running `install.ps1`.

### 1. Install apps

Open PowerShell and initialize winget sources:

```powershell
winget source reset --force
winget source update
```

Install the core apps:

```powershell
winget install --id Microsoft.PowerShell --exact --source winget --accept-package-agreements --accept-source-agreements
winget install --id wez.wezterm --exact --source winget --accept-package-agreements --accept-source-agreements
winget install --id AmN.yasb --exact --source winget --accept-package-agreements --accept-source-agreements
winget install --id LGUG2Z.komorebi --exact --source winget --accept-package-agreements --accept-source-agreements
winget install --id AutoHotkey.AutoHotkey --exact --source winget --accept-package-agreements --accept-source-agreements
winget install --id Flow-Launcher.Flow-Launcher --exact --source winget --accept-package-agreements --accept-source-agreements
```

Install one editor:

```powershell
# Choose one:
winget install --id Microsoft.VisualStudioCode --exact --source winget --accept-package-agreements --accept-source-agreements
winget install --id VSCodium.VSCodium --exact --source winget --accept-package-agreements --accept-source-agreements
winget install --id Zed.Zed --exact --source winget --accept-package-agreements --accept-source-agreements
winget install --id Anysphere.Cursor --exact --source winget --accept-package-agreements --accept-source-agreements
```

### 2. Install a Nerd Font

Install any Nerd Font you want. The installer supports:

```text
JetBrains Mono
Fira Code
Cascadia Code
Hack
GohuFont
Iosevka
```

Manual options:

- Download from `https://www.nerdfonts.com/font-downloads`.
- Extract the font.
- Install the `.ttf` or `.otf` files through Windows font settings.

JetBrains Mono Nerd Font is the safest default for this config set.

### 3. Create config directories

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\wezterm" | Out-Null
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\yasb" | Out-Null
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\komorebi" | Out-Null
New-Item -ItemType Directory -Force "$env:APPDATA\FlowLauncher\Settings" | Out-Null
```

For editor settings, create the destination for your editor:

```powershell
# VS Code
New-Item -ItemType Directory -Force "$env:APPDATA\Code\User" | Out-Null

# VSCodium
New-Item -ItemType Directory -Force "$env:APPDATA\VSCodium\User" | Out-Null

# Cursor
New-Item -ItemType Directory -Force "$env:APPDATA\Cursor\User" | Out-Null

# Zed
New-Item -ItemType Directory -Force "$env:APPDATA\Zed" | Out-Null
```

### 4. Render or copy configs

The safest manual path is to let the installer render configs without deploying them:

```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\install.ps1 -SkipApps -SkipFont -DryRun
```

The installer prints the temp output directory. Copy files from that rendered directory to the destinations listed in "What The Installer Changes".

If you copy templates directly from `configs\`, you must replace all `{{TOKEN}}` placeholders yourself. The full token reference is in `ARCHITECTURE.md`.

### 5. Configure WezTerm default shell

In `%USERPROFILE%\.config\wezterm\wezterm.lua`, set:

```lua
config.default_prog = { "wsl.exe", "--cd", "~" }
```

Other options:

```lua
config.default_prog = { "pwsh.exe" }
config.default_prog = { "cmd.exe" }
```

### 6. Configure startup manually

The recommended manual startup command is:

```text
"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "%USERPROFILE%\.config\komorebi\komorebi.ahk"
```

Add it to the current-user Run key:

```powershell
$ahk = "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
$script = "$env:USERPROFILE\.config\komorebi\komorebi.ahk"
Set-ItemProperty `
  -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
  -Name 'Komorebi' `
  -Value "`"$ahk`" `"$script`""
```

Optionally create a Startup-folder shortcut:

```powershell
$startupDir = [Environment]::GetFolderPath('Startup')
$lnkPath = Join-Path $startupDir 'Komorebi.lnk'
$wsh = New-Object -ComObject WScript.Shell
$link = $wsh.CreateShortcut($lnkPath)
$link.TargetPath = "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
$link.Arguments = "`"$env:USERPROFILE\.config\komorebi\komorebi.ahk`""
$link.WindowStyle = 7
$link.Save()
```

Remove separate YASB or Flow Launcher startup entries if they exist. The AutoHotkey script starts and stops them as part of the Komorebi desktop session.

### 7. Enable taskbar auto-hide manually

If you use YASB, enable Windows taskbar auto-hide:

```powershell
$regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
$settings = (Get-ItemProperty -Path $regPath -Name Settings).Settings
$settings[8] = $settings[8] -bor 0x01
Set-ItemProperty -Path $regPath -Name Settings -Value $settings
Stop-Process -Name explorer -Force
```

Explorer restarts automatically.

### 8. Disable Flow Launcher's own startup

The deployed Flow Launcher settings set:

```json
"StartFlowLauncherOnSystemStartup": false
```

This prevents Flow Launcher from starting separately. Komorebi's AutoHotkey session starts it instead.

### 9. Install Flow Launcher plugins manually

Open Flow Launcher and run plugin manager commands:

```text
pm install Browser Tabs by Jeremy Wu
pm install Clipboard+ by Jack251970
pm install OpenWindowSearch by jamsoftwaregmbh
pm install Win Hotkey by Amin Salah
pm install WingetFlow by gdemazeux
pm install WSL File Search by Sajxx
```

Optional plugins:

```text
pm install Env by lurebat
pm install Obsidian by alexandre-v1
pm install Power Plans by Till Knollmann
pm install Windows Startup by Garulf
pm install Playnite by Garulf
pm install SteamFlow by keekys
```

### 10. Start the desktop session

Run:

```powershell
& "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe" "$env:USERPROFILE\.config\komorebi\komorebi.ahk"
```

The script starts:

```text
komorebi
yasb
Flow Launcher
```

To stop the full desktop session, press:

```text
Ctrl+Alt+Shift+K
```

## Uninstall Or Roll Back

1. Restore configs from:

   ```text
   %USERPROFILE%\.config-backup\<timestamp>\
   ```

2. Remove the startup entries:

   ```powershell
   Remove-ItemProperty `
     -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
     -Name 'Komorebi' `
     -ErrorAction SilentlyContinue

   Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Komorebi.lnk" `
     -ErrorAction SilentlyContinue
   ```

3. Uninstall apps with winget if desired:

   ```powershell
   winget uninstall --id LGUG2Z.komorebi
   winget uninstall --id AmN.yasb
   winget uninstall --id Flow-Launcher.Flow-Launcher
   winget uninstall --id wez.wezterm
   winget uninstall --id AutoHotkey.AutoHotkey
   ```
