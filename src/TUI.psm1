# TUI.psm1 — Pure-PowerShell console UI engine
# No external dependencies. Requires PS 5.1+.
# Uses ANSI escape codes and [System.Console] for input.

Set-StrictMode -Version Latest

#region ── ANSI helpers ────────────────────────────────────────────────────────

# In PS 7.2+ $PSStyle is available; fall back to raw escape sequences.
$Script:ESC = [char]27

function Script:Ansi([string]$code) { "$Script:ESC[$code" }

# Colors (foreground)
$Script:C = @{
    Reset      = Script:Ansi '0m'
    Bold       = Script:Ansi '1m'
    Dim        = Script:Ansi '2m'
    Black      = Script:Ansi '30m'
    Red        = Script:Ansi '31m'
    Green      = Script:Ansi '32m'
    Yellow     = Script:Ansi '33m'
    Blue       = Script:Ansi '34m'
    Magenta    = Script:Ansi '35m'
    Cyan       = Script:Ansi '36m'
    White      = Script:Ansi '37m'
    BrightBlack   = Script:Ansi '90m'
    BrightRed     = Script:Ansi '91m'
    BrightGreen   = Script:Ansi '92m'
    BrightYellow  = Script:Ansi '93m'
    BrightBlue    = Script:Ansi '94m'
    BrightMagenta = Script:Ansi '95m'
    BrightCyan    = Script:Ansi '96m'
    BrightWhite   = Script:Ansi '97m'
}

# Background colors
$Script:BG = @{
    Reset   = Script:Ansi '49m'
    Black   = Script:Ansi '40m'
    Red     = Script:Ansi '41m'
    Green   = Script:Ansi '42m'
    Yellow  = Script:Ansi '43m'
    Blue    = Script:Ansi '44m'
    Magenta = Script:Ansi '45m'
    Cyan    = Script:Ansi '46m'
    White   = Script:Ansi '47m'
}

function Script:HexToAnsi([string]$hex, [bool]$bg = $false) {
    # Convert #RRGGBB to ANSI 24-bit color escape
    $hex = $hex.TrimStart('#')
    $r   = [Convert]::ToInt32($hex.Substring(0,2), 16)
    $g   = [Convert]::ToInt32($hex.Substring(2,2), 16)
    $b   = [Convert]::ToInt32($hex.Substring(4,2), 16)
    $mode = if ($bg) { 48 } else { 38 }
    Script:Ansi "${mode};2;${r};${g};${b}m"
}

#endregion

#region ── Cursor helpers ──────────────────────────────────────────────────────

function Script:CursorUp([int]$n = 1)    { Script:Ansi "${n}A" }
function Script:CursorDown([int]$n = 1)  { Script:Ansi "${n}B" }
function Script:ClearLine()              { Script:Ansi '2K' + Script:Ansi '1G' }
function Script:ClearDown()              { Script:Ansi '0J' }
function Script:HideCursor()             { Write-Host (Script:Ansi '?25l') -NoNewline }
function Script:ShowCursor()             { Write-Host (Script:Ansi '?25h') -NoNewline }
function Script:MoveTo([int]$row, [int]$col) { Script:Ansi "${row};${col}H" }

#endregion

#region ── Box drawing ─────────────────────────────────────────────────────────

$Script:BOX = @{
    TL = [char]0x250C  # ┌
    TR = [char]0x2510  # ┐
    BL = [char]0x2514  # └
    BR = [char]0x2518  # ┘
    H  = [char]0x2500  # ─
    V  = [char]0x2502  # │
    TM = [char]0x252C  # ┬
    BM = [char]0x2534  # ┴
    LM = [char]0x251C  # ├
    RM = [char]0x2524  # ┤
    X  = [char]0x253C  # ┼
}

function Script:DrawBox([int]$width) {
    $h = $Script:BOX.H * ($width - 2)
    "$($Script:BOX.TL)$h$($Script:BOX.TR)"
    "$($Script:BOX.BL)$h$($Script:BOX.BR)"
}

#endregion

#region ── Public: Header ──────────────────────────────────────────────────────

function Show-Header {
    param([string]$Subtitle = '')

    Clear-Host
    $w = [Console]::WindowWidth
    $accent = $Script:C.BrightCyan

    $logo = @(
        '  _____                 _        ',
        ' | ____|_ __ ___  _ __ | |_ _   _',
        ' |  _| | `_ ` _ \| `_ \| __| | | |',
        ' | |___| | | | | | |_) | |_| |_| |',
        ' |_____|_| |_| |_| .__/ \__|\__, |',
        '                 |_|        |___/ ',
        '  ____        _   _____ _ _           ',
        ' |  _ \  ___ | |_|  ___(_) | ___  ___ ',
        ' | | | |/ _ \| __| |_  | | |/ _ \/ __|',
        ' | |_| | (_) | |_|  _| | | |  __/\__ \',
        ' |____/ \___/ \__|_|   |_|_|\___||___/'
    )

    Write-Host ''
    foreach ($line in $logo) {
        $pad = [Math]::Max(0, [int](($w - $line.Length) / 2))
        Write-Host (' ' * $pad + $accent + $line + $Script:C.Reset)
    }

    $tag = 'EmptyDotFiles Windows Desktop Environment Installer'
    $pad = [Math]::Max(0, [int](($w - $tag.Length) / 2))
    Write-Host (' ' * $pad + $Script:C.BrightBlack + $tag + $Script:C.Reset)

    if ($Subtitle) {
        $pad = [Math]::Max(0, [int](($w - $Subtitle.Length) / 2))
        Write-Host (' ' * $pad + $Script:C.Yellow + $Subtitle + $Script:C.Reset)
    }

    Write-Host ''
    Write-Host ($Script:C.BrightBlack + ('─' * $w) + $Script:C.Reset)
    Write-Host ''
}

#endregion

#region ── Public: Single-select menu (arrow keys) ─────────────────────────────

function Show-Menu {
    <#
    .SYNOPSIS
        Interactive single-select menu. Returns the index of the chosen option.
    .PARAMETER Options
        Array of option label strings.
    .PARAMETER Descriptions
        Optional parallel array of description strings shown below the label.
    .PARAMETER SwatchColors
        Optional parallel array of #RRGGBB hex strings. If provided, a color swatch
        is rendered to the left of that option.
    .PARAMETER Default
        Index of the initially highlighted option (0-based). Default 0.
    #>
    param(
        [Parameter(Mandatory)] [string]   $Title,
        [Parameter(Mandatory)] [string[]] $Options,
        [string[]] $Descriptions  = @(),
        [string[]] $SwatchColors  = @(),
        [int]      $Default       = 0
    )

    Script:HideCursor
    try {
        $selected = $Default
        $count    = $Options.Count

        while ($true) {
            # Render all options
            $output = @()
            for ($i = 0; $i -lt $count; $i++) {
                $isActive = ($i -eq $selected)
                $prefix   = if ($isActive) { "$($Script:C.BrightCyan)$($Script:C.Bold) ▶  " } else { "$($Script:C.BrightBlack)   " }
                $label    = if ($isActive) { "$($Script:C.BrightWhite)$($Script:C.Bold)$($Options[$i])" } else { "$($Script:C.White)$($Options[$i])" }

                $swatch = ''
                if ($SwatchColors.Count -gt $i -and $SwatchColors[$i]) {
                    $bg = Script:HexToAnsi $SwatchColors[$i] $true
                    $swatch = "  $bg    $($Script:C.Reset)  "
                }

                $output += "$prefix$swatch$label$($Script:C.Reset)"

                if ($Descriptions.Count -gt $i -and $Descriptions[$i]) {
                    $desc = $Descriptions[$i]
                    $output += "      $($Script:C.BrightBlack)$desc$($Script:C.Reset)"
                }
                $output += ''
            }

            # Print header + options
            Write-Host "  $($Script:C.BrightYellow)$Title$($Script:C.Reset)"
            Write-Host "  $($Script:C.BrightBlack)↑↓ navigate · Enter select$($Script:C.Reset)"
            Write-Host ''
            $output | ForEach-Object { Write-Host "  $_" }

            # Read key
            $key = [Console]::ReadKey($true)

            # Erase what we just drew (header 3 lines + options block)
            $linesToErase = 3 + ($output.Count)
            for ($l = 0; $l -lt $linesToErase; $l++) {
                Write-Host (Script:CursorUp) -NoNewline
                Write-Host (Script:ClearLine) -NoNewline
            }

            switch ($key.Key) {
                'UpArrow'   { $selected = ($selected - 1 + $count) % $count }
                'DownArrow' { $selected = ($selected + 1) % $count }
                'Enter'     { return $selected }
                'Escape'    { return -1 }
            }
        }
    } finally {
        Script:ShowCursor
    }
}

#endregion

#region ── Public: Multi-select menu (space to toggle) ─────────────────────────

function Show-MultiMenu {
    <#
    .SYNOPSIS
        Multi-select checkbox menu. Returns a bool[] of which items are checked.
    .PARAMETER PreChecked
        Bool[] of initial checked state. Defaults to all false.
    #>
    param(
        [Parameter(Mandatory)] [string]   $Title,
        [Parameter(Mandatory)] [string[]] $Options,
        [string[]] $Descriptions = @(),
        [bool[]]   $PreChecked   = @()
    )

    Script:HideCursor
    try {
        $count   = $Options.Count
        $checked = [bool[]]::new($count)
        for ($i = 0; $i -lt [Math]::Min($PreChecked.Count, $count); $i++) {
            $checked[$i] = $PreChecked[$i]
        }
        $cursor = 0

        while ($true) {
            $output = @()
            for ($i = 0; $i -lt $count; $i++) {
                $isActive = ($i -eq $cursor)
                $box      = if ($checked[$i]) { "$($Script:C.BrightGreen)[✓]" } else { "$($Script:C.BrightBlack)[ ]" }
                $arrow    = if ($isActive)    { "$($Script:C.BrightCyan)$($Script:C.Bold) ▶" } else { '  ' }
                $label    = if ($isActive)    { "$($Script:C.BrightWhite)$($Script:C.Bold)$($Options[$i])" } else { "$($Script:C.White)$($Options[$i])" }

                $output += "$arrow $box $label$($Script:C.Reset)"

                if ($Descriptions.Count -gt $i -and $Descriptions[$i]) {
                    $output += "       $($Script:C.BrightBlack)$($Descriptions[$i])$($Script:C.Reset)"
                }
                $output += ''
            }

            Write-Host "  $($Script:C.BrightYellow)$Title$($Script:C.Reset)"
            Write-Host "  $($Script:C.BrightBlack)↑↓ navigate · Space toggle · Enter confirm$($Script:C.Reset)"
            Write-Host ''
            $output | ForEach-Object { Write-Host "  $_" }

            $key = [Console]::ReadKey($true)

            $linesToErase = 3 + $output.Count
            for ($l = 0; $l -lt $linesToErase; $l++) {
                Write-Host (Script:CursorUp) -NoNewline
                Write-Host (Script:ClearLine) -NoNewline
            }

            switch ($key.Key) {
                'UpArrow'   { $cursor = ($cursor - 1 + $count) % $count }
                'DownArrow' { $cursor = ($cursor + 1) % $count }
                'Spacebar'  { $checked[$cursor] = -not $checked[$cursor] }
                'Enter'     { return $checked }
                'Escape'    { return $null }
            }
        }
    } finally {
        Script:ShowCursor
    }
}

#endregion

#region ── Public: Text input ──────────────────────────────────────────────────

function Read-TextInput {
    <#
    .SYNOPSIS
        Inline text input with a default value.
        Returns the typed string, or $Default if the user presses Enter on an empty field.
        Returns $null if the user presses Escape (meaning "skip / leave blank").
    #>
    param(
        [Parameter(Mandatory)] [string] $Prompt,
        [string] $Default   = '',
        [string] $Hint      = '',
        [switch] $IsSecret               # Masks input as asterisks (for API keys)
    )

    $hint = if ($Hint) { " $($Script:C.BrightBlack)($Hint)$($Script:C.Reset)" } else { '' }
    $def  = if ($Default) { " $($Script:C.BrightBlack)[default: $Default]$($Script:C.Reset)" } else { '' }
    Write-Host "  $($Script:C.BrightYellow)$Prompt$($Script:C.Reset)$def$hint"
    Write-Host "  $($Script:C.BrightBlack)Press Escape to skip$($Script:C.Reset)"
    Write-Host -NoNewline "  $($Script:C.Cyan)> $($Script:C.White)"

    $buffer = [System.Text.StringBuilder]::new()
    while ($true) {
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'Enter' {
                Write-Host $Script:C.Reset
                Write-Host ''
                $val = $buffer.ToString()
                if ($val) { return $val } else { return $Default }
            }
            'Escape' {
                Write-Host $Script:C.Reset
                Write-Host ''
                return $null
            }
            'Backspace' {
                if ($buffer.Length -gt 0) {
                    $buffer.Remove($buffer.Length - 1, 1) | Out-Null
                    Write-Host -NoNewline "`b `b"
                }
            }
            default {
                if ($key.KeyChar -and $key.KeyChar -ne [char]0) {
                    [void]$buffer.Append($key.KeyChar)
                    $display = if ($IsSecret) { '*' } else { $key.KeyChar }
                    Write-Host -NoNewline $display
                }
            }
        }
    }
}

#endregion

#region ── Public: Progress ────────────────────────────────────────────────────

function Show-Progress {
    param(
        [string] $Activity,
        [int]    $Step,
        [int]    $Total
    )
    $pct   = [int](($Step / $Total) * 100)
    $width = 40
    $done  = [int](($Step / $Total) * $width)
    $bar   = ($Script:C.BrightCyan + ('█' * $done)) + ($Script:C.BrightBlack + ('░' * ($width - $done))) + $Script:C.Reset
    Write-Host "  $bar  $($Script:C.BrightWhite)$pct%$($Script:C.Reset)  $Activity"
}

#endregion

#region ── Public: Themed write helpers ────────────────────────────────────────

function Write-Step    { param([string]$msg) Write-Host "  $($Script:C.BrightCyan)◆$($Script:C.Reset)  $msg" }
function Write-Success { param([string]$msg) Write-Host "  $($Script:C.BrightGreen)✔$($Script:C.Reset)  $msg" }
function Write-Warn    { param([string]$msg) Write-Host "  $($Script:C.Yellow)⚠$($Script:C.Reset)  $msg" }
function Write-Fail    { param([string]$msg) Write-Host "  $($Script:C.BrightRed)✘$($Script:C.Reset)  $msg" }
function Write-Info    { param([string]$msg) Write-Host "  $($Script:C.BrightBlack)·$($Script:C.Reset)  $msg" }

function Write-SectionHeader {
    param([string]$Title, [int]$Step, [int]$Total)
    $w = [Console]::WindowWidth
    Write-Host ''
    Write-Host ($Script:C.BrightBlack + ('─' * $w) + $Script:C.Reset)
    Write-Host "  $($Script:C.BrightYellow)$($Script:C.Bold)Step $Step of $Total — $Title$($Script:C.Reset)"
    Write-Host ''
}

#endregion

Export-ModuleMember -Function Show-Header, Show-Menu, Show-MultiMenu, Read-TextInput,
                              Show-Progress, Write-Step, Write-Success, Write-Warn,
                              Write-Fail, Write-Info, Write-SectionHeader
