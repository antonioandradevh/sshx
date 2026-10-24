# Installs the SshThemes module for the current user.
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipProfile,
    [switch]$WindowsTerminal,
    [switch]$NoFont,
    [switch]$NoTerminalFont,
    [string]$FontName,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'src\SshThemes'

if (-not (Test-Path -LiteralPath $source)) {
    throw "Pasta do modulo nao encontrada: $source"
}

$documents = [Environment]::GetFolderPath('MyDocuments')
$targets = New-Object System.Collections.Generic.List[string]
$targets.Add((Join-Path $documents 'WindowsPowerShell\Modules\SshThemes'))

$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwsh) {
    $targets.Add((Join-Path $documents 'PowerShell\Modules\SshThemes'))
}

Write-Host ''
Write-Host 'SshThemes - instalacao' -ForegroundColor Cyan
Write-Host ('  origem: ' + $source) -ForegroundColor DarkGray

$fontFace = $null

foreach ($target in $targets) {
    if ($DryRun) {
        Write-Host ('  [dry-run] copiaria para ' + $target) -ForegroundColor DarkGray
        continue
    }
    if (Test-Path -LiteralPath $target) {
        Write-Host ('  atualizando ' + $target) -ForegroundColor DarkGray
        Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force
    }
    else {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force
        Write-Host ('  instalado em ' + $target) -ForegroundColor Green
    }
}

if (-not $NoFont) {
    $fontScript = Join-Path $source 'Private\25-Font.ps1'
    if (Test-Path -LiteralPath $fontScript) {
        . $fontScript
        try {
            if ($DryRun) {
                $fontDryRun = @{ DryRun = $true }
                if ($FontName) { $fontDryRun['Name'] = $FontName }
                Install-SshNerdFont @fontDryRun
                if (-not $NoTerminalFont) {
                    $terminalDryRun = @{ DryRun = $true }
                    if ($FontName) { $terminalDryRun['Name'] = $FontName }
                    Set-SshTerminalFont @terminalDryRun
                }
            }
            else {
                $fontParams = @{ PassThru = $true }
                if ($FontName) { $fontParams['Name'] = $FontName }
                $installedFont = Install-SshNerdFont @fontParams
                if ($installedFont) { $fontFace = $installedFont.Name }
                if ($fontFace -and -not $NoTerminalFont) {
                    Set-SshTerminalFont -Name $fontFace
                }
            }
        }
        catch {
            Write-Host ('  fonte: ' + $_.Exception.Message) -ForegroundColor Yellow
            Write-Host '  o prompt continua funcionando; instale uma Nerd Font manualmente se aparecerem quadrados.' -ForegroundColor DarkGray
        }
    }
}

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
        Write-Host ('  [dry-run] atualizaria ' + $profilePath) -ForegroundColor DarkGray
    }
    else {
        if (-not (Test-Path -LiteralPath $profileDir)) {
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
            Write-Host '  perfil ja importa SshThemes; nada a fazer.' -ForegroundColor DarkGray
        }
        else {
            $content = $content.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $block + [Environment]::NewLine
            Set-Content -LiteralPath $profilePath -Value $content -Encoding UTF8
            Write-Host ('  perfil atualizado: ' + $profilePath) -ForegroundColor Green
        }
    }
}

if ($WindowsTerminal) {
    $wtSettings = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    $wtInstalled = [bool]$wtSettings -or [bool](Get-Command wt.exe -ErrorAction SilentlyContinue)

    if (-not $wtInstalled) {
        Write-Host '  Windows Terminal nao encontrado; fragmento nao criado.' -ForegroundColor Yellow
    }
    else {
    $fragmentDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\SshThemes'
    $fragmentPath = Join-Path $fragmentDir 'ssh-themes.json'
    $profileCommand = 'powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -Command "Import-Module SshThemes; Show-SshDevices"'
    $profileEntry = [ordered]@{
        guid            = '{7f0a1f2e-3c4d-4e5f-8a9b-0c1d2e3f4a5b}'
        name            = 'SSH Themes'
        commandline     = $profileCommand
        startingDirectory = '%USERPROFILE%'
        tabTitle        = 'SSH Themes'
        hidden          = $false
    }
    if ($fontFace) {
        $profileEntry['font'] = [ordered]@{ face = $fontFace }
    }
    $fragment = [ordered]@{
        profiles = @($profileEntry)
    }

    if ($DryRun) {
        Write-Host ('  [dry-run] criaria o perfil do Windows Terminal em ' + $fragmentPath) -ForegroundColor DarkGray
    }
    else {
        if (-not (Test-Path -LiteralPath $fragmentDir)) {
            New-Item -ItemType Directory -Path $fragmentDir -Force | Out-Null
        }
        $fragment | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $fragmentPath -Encoding UTF8
        Write-Host ('  perfil do Windows Terminal: ' + $fragmentPath) -ForegroundColor Green
    }
    }
}

if ($DryRun) {
    Write-Host ''
    Write-Host 'Dry-run concluido. Nada foi alterado.' -ForegroundColor Yellow
    return
}

Write-Host ''
Write-Host 'Pronto. Abra um novo PowerShell e teste:' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Show-SshThemes' -ForegroundColor White
Write-Host '  Preview-SshTheme -Name debian' -ForegroundColor White
Write-Host '  Connect-SshDevice -Target root@10.0.0.5 -DryRun' -ForegroundColor White
Write-Host '  sshx root@10.0.0.5' -ForegroundColor White
Write-Host ''
Write-Host 'Dica: copie o bloco "SSH Themes" para o seu perfil do Windows Terminal' -ForegroundColor DarkGray
Write-Host 'ou rode Install.ps1 -WindowsTerminal para criar o fragmento automaticamente.' -ForegroundColor DarkGray
Write-Host ''
