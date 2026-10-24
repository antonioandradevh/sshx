# Terminal integration: ANSI detection, OSC title/colors and restore stack.

function Test-SshAnsiTerminal {
    if ($env:NO_COLOR) { return $false }
    if ($env:SSHTHEMES_NO_ANSI -eq '1') { return $false }
    if ($env:TERM -eq 'dumb') { return $false }

    try {
        if ($Host.UI.PSObject.Properties['SupportsVirtualTerminal'] -and $Host.UI.SupportsVirtualTerminal) {
            return $true
        }
    }
    catch { }

    if ($env:WT_SESSION -or $env:TERM_PROGRAM -eq 'vscode' -or $env:ConEmuANSI -eq 'ON') { return $true }
    if ($env:TERM) { return $true }
    if ($Host.Name -eq 'ConsoleHost') { return $true }

    return $false
}

function Test-SshPromptEnabled {
    if ($env:SSHTHEMES_DISABLE_PROMPT -eq '1') { return $false }
    $settings = Get-SshSettings
    return [bool](Get-SshValue (Get-SshValue $settings 'prompt' @{}) 'enabled' $true)
}

function Write-SshRaw {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return }
    if ($Host.Name -eq 'ConsoleHost') {
        try {
            [Console]::Out.Write($Text)
            [Console]::Out.Flush()
            return
        }
        catch { }
    }
    Write-Host -NoNewline $Text
}

function Write-SshOsc {
    param(
        [Parameter(Mandatory)][int]$Code,
        [string]$Value
    )

    $bell = [string][char]7
    Write-SshRaw -Text "$script:Esc]$Code;$Value$bell"
}

function Set-SshWindowTitle {
    param([string]$Title)

    if ([string]::IsNullOrWhiteSpace($Title)) { return }
    $Title = ($Title -replace '[\x00-\x1F\x7F]', ' ').Trim()
    Write-SshOsc -Code 0 -Value $Title
    try { $Host.UI.RawUI.WindowTitle = $Title } catch { }
}

function Test-SshTerminalFull {
    param(
        [Parameter(Mandatory)]$Theme,
        [Parameter(Mandatory)]$Settings,
        [switch]$Full
    )

    $mode = [string](Get-SshValue (Get-SshValue $Settings 'terminal' @{}) 'mode' 'auto')
    if ($Full -or $mode -eq 'full') { return $true }
    if ($mode -eq 'auto' -and $Theme.Background) { return $true }
    return $false
}

function Set-SshTerminalAppearance {
    param(
        [Parameter(Mandatory)]$Theme,
        [Parameter(Mandatory)]$Settings,
        [string]$Title,
        [switch]$Full
    )

    $state = @{
        Applied     = $false
        Full        = $false
        Title       = $null
        TitleSet    = $false
        ResetOnExit = [bool](Get-SshValue (Get-SshValue $Settings 'terminal' @{}) 'resetOnExit' $true)
        Ansi        = (Test-SshAnsiTerminal)
    }

    if (-not $state.Ansi) { return $state }

    try { $state.Title = [string]$Host.UI.RawUI.WindowTitle } catch { }

    $useFull = Test-SshTerminalFull -Theme $Theme -Settings $Settings -Full:$Full

    if ($useFull) {
        if ($Theme.Foreground) { Write-SshOsc -Code 10 -Value $Theme.Foreground }
        if ($Theme.Background) { Write-SshOsc -Code 11 -Value $Theme.Background }
        if ($Theme.Cursor) { Write-SshOsc -Code 12 -Value $Theme.Cursor }
        $state.Full = $true
    }

    $titleEnabled = [bool](Get-SshValue (Get-SshValue $Settings 'terminal' @{}) 'title' $true)
    if ($titleEnabled -and $Title) {
        Set-SshWindowTitle -Title $Title
        $state.TitleSet = $true
    }

    $state.Applied = $true
    return $state
}

function Restore-SshTerminalAppearance {
    param($State)

    if (-not $State -or -not $State.Applied) { return }

    $resetOnExit = $true
    if ($State.ContainsKey('ResetOnExit')) { $resetOnExit = [bool]$State.ResetOnExit }
    if ($State.Full -and $resetOnExit) {
        Write-SshOsc -Code 110
        Write-SshOsc -Code 111
        Write-SshOsc -Code 112
    }

    if ($State.TitleSet -and $resetOnExit) {
        $title = $State.Title
        if ([string]::IsNullOrWhiteSpace($title)) { $title = 'PowerShell' }
        Set-SshWindowTitle -Title $title
    }
}

function Push-SshTerminalTheme {
    param(
        [Parameter(Mandatory)]$Theme,
        [Parameter(Mandatory)]$Settings,
        [string]$Title,
        [switch]$Full
    )

    $state = Set-SshTerminalAppearance -Theme $Theme -Settings $Settings -Title $Title -Full:$Full
    $script:TerminalStack.Push($state)
    return $state
}

function Pop-SshTerminalTheme {
    if ($script:TerminalStack.Count -eq 0) { return }
    $state = $script:TerminalStack.Pop()
    Restore-SshTerminalAppearance -State $state
}
