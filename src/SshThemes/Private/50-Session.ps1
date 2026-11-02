# Session state and the exported prompt function.

function Test-SshCommandIsNative {
    param([string]$CommandLine)

    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $false }
    $first = ($CommandLine.Trim() -split '\s+')[0]
    $first = $first.Trim('"').Trim("'")
    if ([string]::IsNullOrWhiteSpace($first)) { return $false }

    if ($script:NativeCache.ContainsKey($first)) { return $script:NativeCache[$first] }

    $isNative = $false
    $command = Get-Command -Name $first -ErrorAction SilentlyContinue
    if ($command) {
        if ($command.CommandType -eq 'Application') { $isNative = $true }
        elseif ($command.CommandType -eq 'Alias' -and $command.ResolvedCommand) {
            if ($command.ResolvedCommand.CommandType -eq 'Application') { $isNative = $true }
        }
    }

    $script:NativeCache[$first] = $isNative
    return $isNative
}

function Get-SshPromptState {
    $settings = Get-SshSettings
    $session = $script:Session

    $themeName = [string](Get-SshValue $settings 'defaultTheme' 'local')
    if ($session -and $session.Theme) { $themeName = [string]$session.Theme }

    $theme = Get-SshThemeByName -Name $themeName -AllowMissing
    if (-not $theme) { $theme = Get-SshThemeByName -Name 'generic' }

    $path = (Get-Location).Path
    $duration = $null
    $exitCode = 0
    $success = $true

    $history = Get-History -Count 1 -ErrorAction SilentlyContinue
    if ($history) {
        if ($history.StartExecutionTime -and $history.EndExecutionTime) {
            $elapsed = $history.EndExecutionTime - $history.StartExecutionTime
            if ($elapsed.TotalMilliseconds -ge 0) { $duration = $elapsed }
        }

        if (Test-SshCommandIsNative -CommandLine $history.CommandLine) {
            $exitCode = [int]$global:LASTEXITCODE
            $success = ($exitCode -eq 0)
        }
        else {
            $success = ([string]$history.ExecutionStatus -ne 'Failed')
            $exitCode = if ($success) { 0 } else { 1 }
        }
    }

    $userName = Get-SshUserName
    $hostName = Get-SshMachineName
    $deviceLabel = $theme.BadgeText
    $targetLabel = ''

    if ($session) {
        if ($session.Kind -eq 's3') {
            $userName = ''
            $hostName = ''
            $deviceLabel = 'S3'
            $targetLabel = [string]$session.Label
        }
        else {
            if ($session.User) { $userName = [string]$session.User }
            if ($session.HostLabel) { $hostName = [string]$session.HostLabel }
            # O host ja aparece em user@host; nao repete o alvo.
            $targetLabel = ''
        }
    }

    return [pscustomobject]@{
        Theme       = $theme
        Settings    = $settings
        Path        = $path
        GitBranch   = (Get-SshGitBranch -Path $path)
        Duration    = $duration
        ExitCode    = $exitCode
        Success     = $success
        UserName    = $userName
        HostName    = $hostName
        DeviceLabel = $deviceLabel
        TargetLabel = $targetLabel
        Now         = Get-Date
        Ansi        = (Test-SshAnsiTerminal)
        Session     = $session
    }
}

function Start-SshSession {
    param(
        [Parameter(Mandatory)]$Session,
        [Parameter(Mandatory)]$Theme,
        [Parameter(Mandatory)]$Settings,
        [switch]$Full,
        [switch]$NoBackground
    )

    $icon = Get-SshThemeIcon -Theme $Theme -Settings $Settings
    $title = if ($icon) { "$icon $($Theme.Label) - $($Session.Label)" } else { "$($Theme.Label) - $($Session.Label)" }
    $terminalState = Push-SshTerminalTheme -Theme $Theme -Settings $Settings -Title $title -Full:$Full -NoBackground:$NoBackground
    if ($Session.PSObject.Properties['TerminalState']) { $Session.TerminalState = $terminalState }
    else { $Session | Add-Member -NotePropertyName TerminalState -NotePropertyValue $terminalState }
    $script:Session = $Session
    return $Session
}

function Stop-SshSession {
    $session = $script:Session
    if (-not $session) { return $null }
    Pop-SshTerminalTheme
    $script:Session = $null
    return $session
}

function Get-SshActiveSession {
    return $script:Session
}

function prompt {
    $fallback = $global:SshTheme_OriginalPrompt
    try {
        if (-not (Test-SshPromptEnabled)) {
            if ($fallback) { return (& $fallback) }
            return "PS $($executionContext.SessionState.Path.CurrentLocation)> "
        }

        $state = Get-SshPromptState
        $rendered = Format-SshPromptText `
            -Theme $state.Theme `
            -Settings $state.Settings `
            -Path $state.Path `
            -DeviceLabel $state.DeviceLabel `
            -TargetLabel $state.TargetLabel `
            -UserName $state.UserName `
            -HostName $state.HostName `
            -GitBranch $state.GitBranch `
            -Duration $state.Duration `
            -ExitCode $state.ExitCode `
            -Success $state.Success `
            -Now $state.Now `
            -Plain:(-not $state.Ansi)

        return $rendered
    }
    catch {
        if ($fallback) {
            try { return (& $fallback) } catch { }
        }
        return "PS $($executionContext.SessionState.Path.CurrentLocation)> "
    }
}
