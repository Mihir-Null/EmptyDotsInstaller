# Install-Font.psm1 — Nerd Font downloader and Windows font installer
# Requires elevation (writes to C:\Windows\Fonts).

Set-StrictMode -Version Latest

$Script:FontManifest = [ordered]@{
    'JetBrains Mono'  = @{ ZipName = 'JetBrainsMono.zip'; DisplayName = 'JetBrainsMono Nerd Font' }
    'Fira Code'       = @{ ZipName = 'FiraCode.zip';       DisplayName = 'FiraCode Nerd Font' }
    'Cascadia Code'   = @{ ZipName = 'CascadiaCode.zip';   DisplayName = 'CaskaydiaCove Nerd Font' }
    'Hack'            = @{ ZipName = 'Hack.zip';            DisplayName = 'Hack Nerd Font' }
    'GohuFont'        = @{ ZipName = 'Gohu.zip';            DisplayName = 'GohuFont 14 Nerd Font' }
    'Iosevka'         = @{ ZipName = 'Iosevka.zip';         DisplayName = 'Iosevka Nerd Font' }
}

function Get-FontManifest { return $Script:FontManifest }

function Install-NerdFont {
    <#
    .SYNOPSIS
        Downloads and installs a Nerd Font by its manifest key name.
        Returns the font display name on success, $null on failure.
    #>
    param([Parameter(Mandatory)] [string] $FontName)

    if (-not $Script:FontManifest.Contains($FontName)) {
        Write-Error "Unknown font: $FontName"
        return $null
    }

    $entry   = $Script:FontManifest[$FontName]
    $zipName = $entry.ZipName
    $display = $entry.DisplayName

    # Resolve latest release URL from Nerd Fonts GitHub
    $releaseApi = 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest'
    $tempDir    = Join-Path $env:TEMP "NerdFont_$(New-Guid)"
    $zipPath    = Join-Path $tempDir $zipName

    try {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        Write-Host "    Fetching latest Nerd Fonts release info..." -NoNewline
        $release = Invoke-RestMethod -Uri $releaseApi -ErrorAction Stop
        $asset   = $release.assets | Where-Object { $_.name -eq $zipName } | Select-Object -First 1

        if (-not $asset) {
            # Fall back to direct URL with latest tag
            $tag        = $release.tag_name
            $downloadUrl= "https://github.com/ryanoasis/nerd-fonts/releases/download/$tag/$zipName"
        } else {
            $downloadUrl = $asset.browser_download_url
        }
        Write-Host " ok"

        Write-Host "    Downloading $FontName ($zipName)..." -NoNewline
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        Write-Host " ok"

        Write-Host "    Extracting..." -NoNewline
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        Write-Host " ok"

        # Install each font file
        $fontsDir = "$env:SystemRoot\Fonts"
        $regPath  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        $fonts    = Get-ChildItem $tempDir -Include '*.ttf','*.otf' -Recurse |
                    Where-Object { $_.Name -notmatch 'WindowsCompatible' }

        Write-Host "    Installing $($fonts.Count) font files..." -NoNewline
        foreach ($f in $fonts) {
            $dest = Join-Path $fontsDir $f.Name
            Copy-Item $f.FullName -Destination $dest -Force

            # Register in registry so apps see it immediately
            $regName = $f.BaseName + ' (TrueType)'
            Set-ItemProperty -Path $regPath -Name $regName -Value $f.Name -ErrorAction SilentlyContinue
        }
        Write-Host " ok"

        return $display
    } catch {
        Write-Host " FAILED: $_" -ForegroundColor Red
        return $null
    } finally {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function Install-NerdFont, Get-FontManifest
