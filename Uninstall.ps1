# Removes SshThemes from the current user on Windows, Linux and macOS.
[CmdletBinding()]
param(
    [switch]$PurgeConfig,
    [switch]$KeepFont,
    [string]$DefaultFont,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Test-UninstallWindows {
    $value = Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $value) { return [bool]$value }
    return ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)
}

function Test-UninstallMacOS {
    $value = Get-Variable -Name IsMacOS -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $value) { return [bool]$value }
    return ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::MacOSX)
}

function Get-UninstallHome {
    if ($HOME) { return [string]$HOME }
    try {
        $profile = [Environment]::GetFolderPath('UserProfile')
        if ($profile) { return [string]$profile }
    }
    catch { }
    return (Get-Location).Path
}

function Join-PathParts {
    param([Parameter(Mandatory)][string[]]$Parts)

    $path = $Parts[0]
    for ($i = 1; $i -lt $Parts.Count; $i++) {
        $path = Join-Path $path $Parts[$i]
    }
    return $path
}

function Get-SshThemesTerminalSettingsPath {
    if (-not (Test-UninstallWindows)) { return $null }
    if (-not $env:LOCALAPPDATA) { return $null }
    $candidates = @(
        (Join-PathParts @($env:LOCALAPPDATA, 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json')),
        (Join-PathParts @($env:LOCALAPPDATA, 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json')),
        (Join-PathParts @($env:LOCALAPPDATA, 'Microsoft\Windows Terminal\settings.json'))
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

function Restore-SshThemesTerminalFont {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Face,
        [switch]$DryRun
    )

    $backup = $Path + '.sshthemes.bak'
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    try {
        $current = $raw | ConvertFrom-Json
    }
    catch {
        Write-Host ('  nao consegui ler ' + $Path + '; ajuste a fonte manualmente.') -ForegroundColor Yellow
        return
    }

    if (-not $current.PSObject.Properties['profiles'] -or -not $current.profiles) { return }
    if (-not $current.profiles.PSObject.Properties['defaults'] -or -not $current.profiles.defaults) { return }
    $defaults = $current.profiles.defaults

    $restored = $false
    if ($Face) {
        $newFont = [pscustomobject]@{ face = $Face }
        if ($defaults.PSObject.Properties['font']) { $defaults.font = $newFont }
        else { $defaults | Add-Member -NotePropertyName font -NotePropertyValue $newFont -Force }
        $restored = $true
    }
    elseif (Test-Path -LiteralPath $backup) {
        try {
            $old = Get-Content -LiteralPath $backup -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($old.profiles -and $old.profiles.defaults -and $old.profiles.defaults.PSObject.Properties['font']) {
                $oldFont = $old.profiles.defaults.font
                if ($defaults.PSObject.Properties['font']) { $defaults.font = $oldFont }
                else { $defaults | Add-Member -NotePropertyName font -NotePropertyValue $oldFont -Force }
                $restored = $true
            }
        }
        catch { }
    }

    if (-not $restored -and $defaults.PSObject.Properties['font']) {
        $font = $defaults.font
        if ($font -and $font.PSObject.Properties['face']) {
            $font.PSObject.Properties.Remove('face')
        }
        if (-not $font -or @($font.PSObject.Properties).Count -eq 0) {
            $defaults.PSObject.Properties.Remove('font')
        }
    }

    $label = if ($Face) { $Face } else { 'padrao do Windows Terminal' }
    if ($DryRun) {
        Write-Host ('  [dry-run] restauraria a fonte (' + $label + ') em ' + $Path) -ForegroundColor DarkGray
        return
    }

    $current | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $Path -Encoding UTF8
    if (Test-Path -LiteralPath $backup) {
        Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
    }
    Write-Host ('  fonte do Windows Terminal restaurada: ' + $label) -ForegroundColor Green
}

$homePath = Get-UninstallHome
$targets = New-Object System.Collections.Generic.List[string]

if (Test-UninstallWindows) {
    $documents = [Environment]::GetFolderPath('MyDocuments')
    if (-not $documents) { $documents = Join-PathParts @($homePath, 'Documents') }
    $targets.Add((Join-PathParts @($documents, 'WindowsPowerShell', 'Modules', 'SshThemes')))
    $targets.Add((Join-PathParts @($documents, 'PowerShell', 'Modules', 'SshThemes')))
}
else {
    $targets.Add((Join-PathParts @($homePath, '.local', 'share', 'powershell', 'Modules', 'SshThemes')))
    foreach ($entry in @($env:PSModulePath -split [System.IO.Path]::PathSeparator)) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        if (-not $entry.StartsWith($homePath, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($entry -notmatch '(?i)(Modules|modules)$') { continue }
        $candidate = Join-Path $entry 'SshThemes'
        if (-not $targets.Contains($candidate)) { $targets.Add($candidate) }
    }
}

$targets = @($targets | Select-Object -Unique)

Write-Host ''
Write-Host 'SshThemes - desinstalacao' -ForegroundColor Cyan

if (-not $KeepFont) {
    if (Test-UninstallWindows) {
        $terminalSettings = Get-SshThemesTerminalSettingsPath
        if ($terminalSettings) {
            Restore-SshThemesTerminalFont -Path $terminalSettings -Face $DefaultFont -DryRun:$DryRun
        }
        else {
            Write-Host '  Windows Terminal nao encontrado; fonte nao alterada.' -ForegroundColor DarkGray
        }
    }
    else {
        Write-Host '  a fonte do terminal nao e alterada automaticamente neste sistema.' -ForegroundColor DarkGray
    }
}

$profilePath = $PROFILE.CurrentUserAllHosts
if (Test-Path -LiteralPath $profilePath) {
    $content = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8
    if ($null -eq $content) { $content = '' }
    $pattern = '(?s)# >>> SshThemes >>>.*?# <<< SshThemes <<<\r?\n?'
    $newContent = [regex]::Replace($content, $pattern, '')
    if ($newContent -ne $content) {
        if ($DryRun) {
            Write-Host ('  [dry-run] removeria o bloco de ' + $profilePath) -ForegroundColor DarkGray
        }
        else {
            Set-Content -LiteralPath $profilePath -Value $newContent.TrimEnd() -Encoding UTF8
            Write-Host ('  bloco removido de ' + $profilePath) -ForegroundColor Green
        }
    }
}

foreach ($target in $targets) {
    if (-not (Test-Path -LiteralPath $target)) { continue }
    if ($DryRun) {
        Write-Host ('  [dry-run] removeria ' + $target) -ForegroundColor DarkGray
    }
    else {
        Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ('  removido ' + $target) -ForegroundColor Green
    }
}

# Remove only launchers generated by Install.ps1; never delete a user script.
$launcherDir = Join-PathParts @($homePath, '.local', 'bin')
foreach ($name in @('xsshx', 'sshx', 's3x')) {
    $launcher = Join-Path $launcherDir $name
    if (-not (Test-Path -LiteralPath $launcher)) { continue }
    $firstLines = ''
    try { $firstLines = (Get-Content -LiteralPath $launcher -TotalCount 4 -ErrorAction Stop) -join "`n" } catch { }
    if ($firstLines -notmatch 'SshThemes launcher') { continue }
    if ($DryRun) {
        Write-Host ('  [dry-run] removeria ' + $launcher) -ForegroundColor DarkGray
    }
    else {
        Remove-Item -LiteralPath $launcher -Force -ErrorAction SilentlyContinue
        Write-Host ('  launcher removido: ' + $launcher) -ForegroundColor Green
    }
}

if (Test-UninstallWindows -and $env:LOCALAPPDATA) {
    $fragmentDir = Join-PathParts @($env:LOCALAPPDATA, 'Microsoft\Windows Terminal\Fragments\SshThemes')
    if (Test-Path -LiteralPath $fragmentDir) {
        if ($DryRun) {
            Write-Host ('  [dry-run] removeria ' + $fragmentDir) -ForegroundColor DarkGray
        }
        else {
            Remove-Item -LiteralPath $fragmentDir -Recurse -Force
            Write-Host '  fragmento do Windows Terminal removido' -ForegroundColor Green
        }
    }
}

$configHome = if ($env:SSHTHEMES_HOME) { $env:SSHTHEMES_HOME } else { Join-Path $homePath '.sshthemes' }
if ($PurgeConfig -and (Test-Path -LiteralPath $configHome)) {
    if ($DryRun) {
        Write-Host ('  [dry-run] removeria ' + $configHome) -ForegroundColor DarkGray
    }
    else {
        Remove-Item -LiteralPath $configHome -Recurse -Force
        Write-Host ('  configs removidas: ' + $configHome) -ForegroundColor Green
    }
}
elseif (Test-Path -LiteralPath $configHome) {
    Write-Host ('  configs preservadas em ' + $configHome + ' (use -PurgeConfig para apagar)') -ForegroundColor DarkGray
}

Write-Host ''
Write-Host 'Desinstalacao concluida. Feche e reabra o terminal.' -ForegroundColor Cyan
Write-Host ''
