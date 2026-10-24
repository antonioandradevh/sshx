# Removes SshThemes from the current user.
[CmdletBinding()]
param(
    [switch]$PurgeConfig,
    [switch]$KeepFont,
    [string]$DefaultFont,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Get-SshThemesTerminalSettingsPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
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

$documents = [Environment]::GetFolderPath('MyDocuments')
$targets = @(
    (Join-Path $documents 'WindowsPowerShell\Modules\SshThemes'),
    (Join-Path $documents 'PowerShell\Modules\SshThemes')
)

Write-Host ''
Write-Host 'SshThemes - desinstalacao' -ForegroundColor Cyan

if (-not $KeepFont) {
    $terminalSettings = Get-SshThemesTerminalSettingsPath
    if ($terminalSettings) {
        Restore-SshThemesTerminalFont -Path $terminalSettings -Face $DefaultFont -DryRun:$DryRun
    }
    else {
        Write-Host '  Windows Terminal nao encontrado; fonte nao alterada.' -ForegroundColor DarkGray
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

$fragmentDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\SshThemes'
if (Test-Path -LiteralPath $fragmentDir) {
    if ($DryRun) {
        Write-Host ('  [dry-run] removeria ' + $fragmentDir) -ForegroundColor DarkGray
    }
    else {
        Remove-Item -LiteralPath $fragmentDir -Recurse -Force
        Write-Host '  fragmento do Windows Terminal removido' -ForegroundColor Green
    }
}

$configHome = if ($env:SSHTHEMES_HOME) { $env:SSHTHEMES_HOME } else { Join-Path $HOME '.sshthemes' }
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
