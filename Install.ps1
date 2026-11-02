# Installs the SshThemes module for the current user on Windows, Linux and macOS.
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipProfile,
    [switch]$WindowsTerminal,
    [switch]$NoFont,
    [switch]$NoTerminalFont,
    [switch]$NoLauncher,
    [string]$FontName,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Test-InstallWindows {
    $value = Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $value) { return [bool]$value }
    return ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)
}

function Test-InstallMacOS {
    $value = Get-Variable -Name IsMacOS -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $value) { return [bool]$value }
    return ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::MacOSX)
}

function Get-InstallHome {
    if ($HOME) { return [string]$HOME }
    try {
        $profile = [Environment]::GetFolderPath('UserProfile')
        if ($profile) { return [string]$profile }
    }
    catch { }
    return (Get-Location).Path
}

function Get-InstallPlatformName {
    if (Test-InstallWindows) { return 'windows' }
    if (Test-InstallMacOS) { return 'macos' }
    return 'linux'
}

function Join-PathParts {
    param([Parameter(Mandatory)][string[]]$Parts)

    $path = $Parts[0]
    for ($i = 1; $i -lt $Parts.Count; $i++) {
        $path = Join-Path $path $Parts[$i]
    }
    return $path
}

function ConvertTo-ShSingleQuoted {
    param([Parameter(Mandatory)][string]$Value)
    return "'" + $Value.Replace("'", "'\''") + "'"
}

function Write-InstallStep {
    param([string]$Text, [string]$Color = 'DarkGray')
    Write-Host ('  ' + $Text) -ForegroundColor $Color
}

$source = Join-Path (Join-Path $PSScriptRoot 'src') 'SshThemes'
$binSource = Join-Path (Join-Path $PSScriptRoot 'bin') 'sshx.ps1'
$homePath = Get-InstallHome
$platform = Get-InstallPlatformName

if (-not (Test-Path -LiteralPath $source)) {
    throw "Pasta do modulo nao encontrada: $source"
}

# The font helpers only need the platform helpers; importing the whole module
# would create ~/.sshthemes even during a dry run.
. (Join-Path (Join-Path $source 'Private') '05-Platform.ps1')
. (Join-Path (Join-Path $source 'Private') '25-Font.ps1')

$targets = New-Object System.Collections.Generic.List[string]

if (Test-InstallWindows) {
    $documents = [Environment]::GetFolderPath('MyDocuments')
    if (-not $documents) { $documents = Join-PathParts @($homePath, 'Documents') }

    $targets.Add((Join-PathParts @($documents, 'WindowsPowerShell', 'Modules', 'SshThemes')))
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        $targets.Add((Join-PathParts @($documents, 'PowerShell', 'Modules', 'SshThemes')))
    }
}
else {
    $known = Join-PathParts @($homePath, '.local', 'share', 'powershell', 'Modules')
    $targets.Add((Join-Path $known 'SshThemes'))

    # Respect a custom PSModulePath when it points to a user module directory.
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
Write-Host 'SshThemes - instalacao' -ForegroundColor Cyan
Write-Host ('  origem:   ' + $source) -ForegroundColor DarkGray
Write-Host ('  sistema:  ' + $platform) -ForegroundColor DarkGray
if ($DryRun) { Write-Host '  modo:     dry-run (nada sera alterado)' -ForegroundColor Yellow }
Write-Host ''

$fontFace = $null
$installedTargets = @()

foreach ($target in $targets) {
    if ($DryRun) {
        Write-InstallStep ('[dry-run] copiaria o modulo para ' + $target)
        continue
    }

    if (Test-Path -LiteralPath $target) {
        try {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
        catch {
            Write-InstallStep ('aviso: nao consegui limpar ' + $target + '; atualizando por cima.') 'Yellow'
        }
    }

    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force

    if (Test-Path -LiteralPath $binSource) {
        $binTarget = Join-Path $target 'bin'
        New-Item -ItemType Directory -Path $binTarget -Force | Out-Null
        Copy-Item -LiteralPath $binSource -Destination (Join-Path $binTarget 'sshx.ps1') -Force
    }

    $installedTargets += $target
    Write-InstallStep ('modulo instalado em ' + $target) 'Green'
}

# ------------------------------------------------------------------- Nerd Font
if (-not $NoFont) {
    try {
        if ($DryRun) {
            $fontDryRun = @{ DryRun = $true }
            if ($FontName) { $fontDryRun['Name'] = $FontName }
            $fontInfo = Install-SshNerdFont @fontDryRun -PassThru
            if ($fontInfo -and -not $NoTerminalFont) {
                $terminalDryRun = @{ DryRun = $true }
                if ($FontName) { $terminalDryRun['Name'] = $FontName }
                Set-SshTerminalFont @terminalDryRun | Out-Null
            }
        }
        else {
            $fontParams = @{ PassThru = $true }
            if ($FontName) { $fontParams['Name'] = $FontName }
            $installedFont = Install-SshNerdFont @fontParams
            if ($installedFont) { $fontFace = $installedFont.Name }
            if ($fontFace -and -not $NoTerminalFont) {
                Set-SshTerminalFont -Name $fontFace | Out-Null
            }
        }
    }
    catch {
        Write-InstallStep ('fonte: ' + $_.Exception.Message) 'Yellow'
        Write-InstallStep 'o prompt continua funcionando; instale uma Nerd Font manualmente se aparecerem quadrados.'
    }
}

# --------------------------------------------------------------------- profile
$profilePath = $null
if (-not $SkipProfile) {
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path -Parent $profilePath
    $startMarker = '# >>> SshThemes >>>'
    $endMarker = '# <<< SshThemes <<<'
    $block = @(
        $startMarker,
        'Import-Module SshThemes -ErrorAction SilentlyContinue -DisableNameChecking',
        $endMarker
    ) -join [Environment]::NewLine

    if ($DryRun) {
        Write-InstallStep ('[dry-run] atualizaria ' + $profilePath)
    }
    else {
        if ($profileDir -and -not (Test-Path -LiteralPath $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }

        $content = ''
        if (Test-Path -LiteralPath $profilePath) {
            $content = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8
            if ($null -eq $content) { $content = '' }
            $pattern = '(?s)' + [regex]::Escape($startMarker) + '.*?' + [regex]::Escape($endMarker) + '\r?\n?'
            $content = [regex]::Replace($content, $pattern, '')
        }

        if (-not $Force -and $content -match [regex]::Escape('Import-Module SshThemes')) {
            Write-InstallStep 'perfil ja importa SshThemes; nada a fazer.'
        }
        else {
            $content = $content.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $block + [Environment]::NewLine
            Set-Content -LiteralPath $profilePath -Value $content -Encoding UTF8
            Write-InstallStep ('perfil atualizado: ' + $profilePath) 'Green'
        }
    }
}

# ---------------------------------------------------------- Windows Terminal
if ($WindowsTerminal) {
    if (-not (Test-InstallWindows)) {
        Write-InstallStep 'Windows Terminal so existe no Windows; fragmento ignorado.' 'Yellow'
    }
    elseif (-not $env:LOCALAPPDATA) {
        Write-InstallStep 'LOCALAPPDATA nao definido; fragmento ignorado.' 'Yellow'
    }
    else {
        $wtSettings = @(
            (Join-PathParts @($env:LOCALAPPDATA, 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json')),
            (Join-PathParts @($env:LOCALAPPDATA, 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json')),
            (Join-PathParts @($env:LOCALAPPDATA, 'Microsoft\Windows Terminal\settings.json'))
        ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        $wtInstalled = [bool]$wtSettings -or [bool](Get-Command wt.exe -ErrorAction SilentlyContinue)

        if (-not $wtInstalled) {
            Write-InstallStep 'Windows Terminal nao encontrado; fragmento nao criado.' 'Yellow'
        }
        else {
            $fragmentDir = Join-PathParts @($env:LOCALAPPDATA, 'Microsoft\Windows Terminal\Fragments\SshThemes')
            $fragmentPath = Join-Path $fragmentDir 'ssh-themes.json'
            $profileCommand = 'powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -Command "Import-Module SshThemes; Show-SshDevices"'
            $profileEntry = [ordered]@{
                guid              = '{7f0a1f2e-3c4d-4e5f-8a9b-0c1d2e3f4a5b}'
                name              = 'SSH Themes'
                commandline       = $profileCommand
                startingDirectory = '%USERPROFILE%'
                tabTitle          = 'SSH Themes'
                hidden            = $false
            }
            if ($fontFace) { $profileEntry['font'] = [ordered]@{ face = $fontFace } }
            $fragment = [ordered]@{ profiles = @($profileEntry) }

            if ($DryRun) {
                Write-InstallStep ('[dry-run] criaria o perfil do Windows Terminal em ' + $fragmentPath)
            }
            else {
                if (-not (Test-Path -LiteralPath $fragmentDir)) {
                    New-Item -ItemType Directory -Path $fragmentDir -Force | Out-Null
                }
                $fragment | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $fragmentPath -Encoding UTF8
                Write-InstallStep ('perfil do Windows Terminal: ' + $fragmentPath) 'Green'
            }
        }
    }
}

# -------------------------------------------------------------- Unix launchers
$launcherPaths = @()
if (-not (Test-InstallWindows) -and -not $NoLauncher) {
    $launcherDir = Join-PathParts @($homePath, '.local', 'bin')
    $primaryTarget = if ($installedTargets.Count -gt 0) { $installedTargets[0] } elseif ($targets.Count -gt 0) { $targets[0] } else { $null }
    $sshxScript = if ($primaryTarget) { Join-PathParts @($primaryTarget, 'bin', 'sshx.ps1') } else { $null }

    if (-not $sshxScript) {
        Write-InstallStep 'nenhum modulo instalado; launchers ignorados.' 'Yellow'
    }
    else {
        $sshxPath = Join-Path $launcherDir 'sshx'
        $s3xPath = Join-Path $launcherDir 's3x'
        $quotedScript = ConvertTo-ShSingleQuoted -Value $sshxScript

        $sshxContent = @(
            '#!/usr/bin/env sh',
            '# SshThemes launcher (generated by Install.ps1)',
            'exec pwsh -NoLogo -NoProfile -File ' + $quotedScript + ' "$@"',
            ''
        ) -join "`n"

        $s3xContent = @(
            '#!/usr/bin/env sh',
            '# SshThemes launcher (generated by Install.ps1)',
            'exec pwsh -NoLogo -NoProfile -File ' + $quotedScript + ' -S3 "$@"',
            ''
        ) -join "`n"

        if ($DryRun) {
            Write-InstallStep ('[dry-run] criaria ' + $sshxPath)
            Write-InstallStep ('[dry-run] criaria ' + $s3xPath)
        }
        else {
            if (-not (Test-Path -LiteralPath $launcherDir)) {
                New-Item -ItemType Directory -Path $launcherDir -Force | Out-Null
            }
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($sshxPath, $sshxContent, $utf8NoBom)
            [System.IO.File]::WriteAllText($s3xPath, $s3xContent, $utf8NoBom)
            if (Get-Command chmod -ErrorAction SilentlyContinue) {
                & chmod 755 $sshxPath 2>$null
                & chmod 755 $s3xPath 2>$null
            }
            $launcherPaths += $sshxPath
            $launcherPaths += $s3xPath
            Write-InstallStep ('launchers: ' + $sshxPath + ' e ' + $s3xPath) 'Green'
            if (-not (($env:PATH -split [System.IO.Path]::PathSeparator) -contains $launcherDir)) {
                Write-InstallStep ('adicione ' + $launcherDir + ' ao PATH para usar sshx/s3x fora do PowerShell.') 'Yellow'
            }
        }
    }
}

# ------------------------------------------------------------------ metadata
if (-not $DryRun) {
    $configHome = if ($env:SSHTHEMES_HOME) { $env:SSHTHEMES_HOME } else { Join-Path $homePath '.sshthemes' }
    if (-not (Test-Path -LiteralPath $configHome)) {
        New-Item -ItemType Directory -Path $configHome -Force | Out-Null
    }
    $metadata = [ordered]@{
        version     = '1.0.0'
        installedAt = (Get-Date).ToString('o')
        platform    = $platform
        source      = $source
        modules     = @($installedTargets)
        launchers   = @($launcherPaths)
        profile     = $profilePath
        font        = $fontFace
    }
    $metadataPath = Join-Path $configHome 'install.json'
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($metadataPath, ($metadata | ConvertTo-Json -Depth 8) + [Environment]::NewLine, $utf8NoBom)
    Write-InstallStep ('metadados: ' + $metadataPath) 'Green'
}

if ($DryRun) {
    Write-Host ''
    Write-Host 'Dry-run concluido. Nada foi alterado.' -ForegroundColor Yellow
    return
}

Write-Host ''
Write-Host 'Pronto. Abra um novo terminal e teste:' -ForegroundColor Cyan
Write-Host ''
Write-Host '  sshx root@10.0.0.5' -ForegroundColor White
Write-Host '  sshx -X root@10.0.0.5' -ForegroundColor White
Write-Host '  sshx 10.0.0.5 -Lock debian' -ForegroundColor White
Write-Host '  -help' -ForegroundColor White
Write-Host ''
if (Test-InstallWindows) {
    Write-Host 'Dica: rode Install.ps1 -WindowsTerminal para criar o perfil no Windows Terminal.' -ForegroundColor DarkGray
}
else {
    Write-Host 'Dica: adicione ~/.local/bin ao PATH para usar sshx/s3x em qualquer shell.' -ForegroundColor DarkGray
}
Write-Host ''
