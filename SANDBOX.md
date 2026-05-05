# Windows Sandbox Testing

Use this guide to test EmptyDotFiles in Windows Sandbox without modifying the host Windows profile.

## Overview

The repository includes a sandbox configuration:

```text
Sandbox.wsb
```

Opening `Sandbox.wsb` starts Windows Sandbox, mounts this repository, bootstraps winget and Windows Terminal inside the sandbox, then launches the EmptyDotFiles installer.

The sandbox is disposable. Closing it deletes everything inside the sandbox.

## Files

| File | Purpose |
| --- | --- |
| `Sandbox.wsb` | Windows Sandbox configuration |
| `Bootstrap-Sandbox.cmd` | Visible launcher used by the sandbox logon command |
| `Bootstrap-Sandbox.ps1` | Installs winget/Terminal, writes logs, and starts the installer |
| `Install.bat` | Starts `install.ps1`, preferring Windows Terminal if available |

## Start A Sandbox Test

From Windows Explorer, double-click:

```text
Sandbox.wsb
```

The sandbox mounts this repository at:

```text
C:\Dotfiles
```

At sandbox logon, it runs:

```cmd
C:\Dotfiles\Bootstrap-Sandbox.cmd
```

If the bootstrap does not automatically open, run that command manually inside the sandbox.

## What The Bootstrap Does

`Bootstrap-Sandbox.cmd` opens a visible PowerShell window with `-NoExit` so failures remain on screen.

`Bootstrap-Sandbox.ps1` then:

1. Starts a transcript log.
2. Installs or repairs winget.
3. Resets and updates winget sources.
4. Installs Windows Terminal through winget.
5. Waits briefly for the `wt.exe` app execution alias.
6. Runs `C:\Dotfiles\Install.bat`.

The transcript is written to:

```text
C:\Users\WDAGUtilityAccount\Desktop\EmptyDotFiles-Sandbox-Bootstrap.log
```

## Winget Bootstrap Details

The bootstrap first checks whether `winget.exe` is visible. If it is present, it tries:

```powershell
$progressPreference = 'silentlyContinue'
Install-PackageProvider -Name NuGet -Force | Out-Null
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
Import-Module Microsoft.WinGet.Client -Force
Repair-WinGetPackageManager -AllUsers
```

In a clean sandbox, `winget.exe` is usually not present yet, so the bootstrap uses the direct App Installer fallback.

The fallback installs:

```text
VCLibs x64
Microsoft.UI.Xaml 2.8
Windows App Runtime 1.8
App Installer / winget
```

After App Installer is deployed, the bootstrap waits for:

```text
C:\Users\WDAGUtilityAccount\AppData\Local\Microsoft\WindowsApps\winget.exe
```

Then it initializes winget package sources:

```powershell
winget source reset --force
winget source update
```

## Expected Healthy Output

A healthy clean sandbox bootstrap should show output similar to:

```text
=== Bootstrapping Windows Sandbox ===
Transcript: C:\Users\WDAGUtilityAccount\Desktop\EmptyDotFiles-Sandbox-Bootstrap.log

  [winget] winget.exe not present; using direct App Installer bootstrap

  [winget] Falling back to direct App Installer bootstrap...
  [VCLibs x64] Downloading... installing... done
  [Microsoft.UI.Xaml 2.8] Downloading... installing... done
  [Windows App Runtime 1.8] Downloading... installing... done
  [App Installer (winget)] Downloading... installing... done
  [winget] Found: C:\Users\WDAGUtilityAccount\AppData\Local\Microsoft\WindowsApps\winget.exe
  [winget] Resetting package sources... done
  [Windows Terminal] Installing... done
  [Windows Terminal] Waiting for wt.exe alias... ok
```

The installer should launch after that.

## Troubleshooting

### The bootstrap window never opens

Run it manually inside the sandbox:

```cmd
C:\Dotfiles\Bootstrap-Sandbox.cmd
```

If `C:\Dotfiles` does not exist, the mapped folder did not mount. Check the `HostFolder` path in `Sandbox.wsb`.

### The bootstrap opens and immediately closes

Run the `.cmd` launcher, not the `.ps1` directly:

```cmd
C:\Dotfiles\Bootstrap-Sandbox.cmd
```

The `.cmd` uses `powershell.exe -NoExit` so the window should stay open.

### App Installer fails with a missing framework

Read the desktop transcript:

```text
C:\Users\WDAGUtilityAccount\Desktop\EmptyDotFiles-Sandbox-Bootstrap.log
```

If App Installer reports a missing dependency, install that framework before `https://aka.ms/getwinget`. Current known dependencies are already handled by the bootstrap:

```text
VCLibs x64
Microsoft.UI.Xaml 2.8
Windows App Runtime 1.8
```

### VCLibs says a higher version is already installed

That is fine. The bootstrap treats HRESULT `0x80073D06` / "higher version already installed" as success.

### winget exists but all app installs fail

Initialize winget sources:

```powershell
winget source reset --force
winget source update
```

The installer also does this before the app install loop.

### YASB fails to install

The installer uses:

```powershell
winget install --id AmN.yasb --exact --source winget --silent --accept-package-agreements --accept-source-agreements
```

Try the same command manually in the sandbox. If it fails, copy the exact winget output from the sandbox console or transcript.

### Windows Terminal installs but Install.bat opens PowerShell instead

The `wt.exe` app execution alias can appear a few seconds after install. The bootstrap waits briefly, but if it still races, rerun:

```cmd
C:\Dotfiles\Install.bat
```

## Updating The Sandbox Host Path

`Sandbox.wsb` currently maps:

```xml
<HostFolder>C:\Users\Empty\Documents\Claude\Projects\Windows Desktop Environment</HostFolder>
<SandboxFolder>C:\Dotfiles</SandboxFolder>
```

If you move this repo, update `HostFolder` before opening `Sandbox.wsb`.

