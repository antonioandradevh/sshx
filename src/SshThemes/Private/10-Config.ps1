# Configuration loading, theme catalog and SSH config discovery.

function Clear-SshConfigCache {
    $script:Cache = @{}
}

function Get-SshGlyphPacks {
    if ($script:Cache.GlyphPacks) { return $script:Cache.GlyphPacks }

    $defaults = Read-SshJsonFile -Path (Get-SshModuleConfigPath 'glyphs.default.json') -Default @{ sets = @{} }
    $user = Read-SshJsonFile -Path (Get-SshUserConfigPath 'glyphs.json') -Default @{ sets = @{} }
    $sets = Merge-SshDeep -Base (Get-SshValue $defaults 'sets' @{}) -Override (Get-SshValue $user 'sets' @{})

    $script:Cache.GlyphPacks = $sets
    return $sets
}

function Get-SshSettings {
    if ($script:Cache.Settings) { return $script:Cache.Settings }

    $defaults = Read-SshJsonFile -Path (Get-SshModuleConfigPath 'settings.default.json') -Default @{ settings = @{} }
    $user = Read-SshJsonFile -Path (Get-SshUserConfigPath 'settings.json') -Default @{ settings = @{} }

    $merged = Merge-SshDeep -Base (Get-SshValue $defaults 'settings' @{}) -Override (Get-SshValue $user 'settings' @{})
    $script:Cache.Settings = $merged
    return $merged
}

function New-SshThemeObject {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][hashtable]$Data,
        [bool]$IsCustom = $false
    )

    $prompt = @{}
    $rawPrompt = Get-SshValue $Data 'prompt' @{}
    if ($rawPrompt -is [System.Collections.IDictionary]) {
        foreach ($key in $rawPrompt.Keys) { $prompt[$key] = $rawPrompt[$key] }
    }

    $icons = @{}
    $rawIcons = Get-SshValue $Data 'icons' @{}
    if ($rawIcons -is [System.Collections.IDictionary]) {
        foreach ($key in $rawIcons.Keys) { $icons[$key] = $rawIcons[$key] }
    }

    $iconsNerd = @{}
    $rawIconsNerd = Get-SshValue $Data 'iconsNerd' @{}
    if ($rawIconsNerd -is [System.Collections.IDictionary]) {
        foreach ($key in $rawIconsNerd.Keys) { $iconsNerd[$key] = $rawIconsNerd[$key] }
    }

    $accent = Get-SshValue $Data 'accent' '#4CC2FF'
    $accent2 = Get-SshValue $Data 'accent2' $accent
    if (-not $accent2) { $accent2 = $accent }
    $foreground = Get-SshValue $Data 'foreground' '#E6E6E6'

    if (-not $prompt.user) { $prompt.user = $accent2 }
    if (-not $prompt.host) { $prompt.host = $accent }
    if (-not $prompt.path) { $prompt.path = $foreground }
    if (-not $prompt.git) { $prompt.git = '#8BE9FD' }
    if (-not $prompt.muted) { $prompt.muted = '#808080' }
    if (-not $prompt.durationFast) { $prompt.durationFast = '#50FA7B' }
    if (-not $prompt.durationWarn) { $prompt.durationWarn = '#F1FA8C' }
    if (-not $prompt.durationSlow) { $prompt.durationSlow = '#FF6B6B' }
    if (-not $prompt.exitOk) { $prompt.exitOk = '#50FA7B' }
    if (-not $prompt.exitFail) { $prompt.exitFail = '#FF6B6B' }

    $label = Get-SshValue $Data 'label' ($Name.Substring(0, 1).ToUpper() + $Name.Substring(1))
    $badgeText = Get-SshValue $Data 'badgeText' ''
    if ([string]::IsNullOrWhiteSpace($badgeText)) { $badgeText = $label.ToUpperInvariant() }

    return [pscustomobject]@{
        PSTypeName = 'SshThemes.Theme'
        Name       = $Name
        Label      = $label
        Short      = Get-SshValue $Data 'short' $Name
        Icon       = Get-SshValue $Data 'icon' ''
        Accent     = $accent
        Accent2    = $accent2
        Foreground = $foreground
        Background = Get-SshValue $Data 'background' $null
        Cursor     = Get-SshValue $Data 'cursor' $null
        BadgeText  = $badgeText
        Note       = Get-SshValue $Data 'note' ''
        Prompt     = $prompt
        Icons      = $icons
        IconsNerd  = $iconsNerd
        Detect     = Get-SshValue $Data 'detect' @{}
        IsCustom   = $IsCustom
        Data       = $Data
    }
}

function Get-SshThemeCatalog {
    if ($script:Cache.Themes) { return $script:Cache.Themes }

    $defaultsDoc = Read-SshJsonFile -Path (Get-SshModuleConfigPath 'themes.default.json') -Default @{ defaults = @{}; themes = @{} }
    $userDoc = Read-SshJsonFile -Path (Get-SshUserConfigPath 'themes.json') -Default @{ themes = @{} }

    $baseThemes = Get-SshValue $defaultsDoc 'themes' @{}
    $baseDefaults = Get-SshValue $defaultsDoc 'defaults' @{}
    $userThemes = Get-SshValue $userDoc 'themes' @{}

    $catalog = [ordered]@{}

    foreach ($name in @($baseThemes.Keys)) {
        $data = Merge-SshDeep -Base $baseDefaults -Override $baseThemes[$name]
        $isCustom = $false
        if ($userThemes.Contains($name)) {
            $data = Merge-SshDeep -Base $data -Override $userThemes[$name]
            $isCustom = $true
        }
        $catalog[$name] = New-SshThemeObject -Name $name -Data $data -IsCustom $isCustom
    }

    foreach ($name in @($userThemes.Keys)) {
        if ($catalog.Contains($name)) { continue }
        $data = Merge-SshDeep -Base $baseDefaults -Override $userThemes[$name]
        $catalog[$name] = New-SshThemeObject -Name $name -Data $data -IsCustom $true
    }

    $sorted = [ordered]@{}
    if ($catalog.Contains('local')) { $sorted['local'] = $catalog['local'] }
    foreach ($name in @($catalog.Keys | Sort-Object)) {
        if ($name -eq 'local') { continue }
        $sorted[$name] = $catalog[$name]
    }

    $script:Cache.Themes = $sorted
    return $sorted
}

function Get-SshThemeByName {
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$AllowMissing
    )

    $catalog = Get-SshThemeCatalog
    if ($catalog.Contains($Name)) { return $catalog[$Name] }
    if ($AllowMissing) { return $null }
    throw "Tema '$Name' nao encontrado. Use Show-SshThemes para listar os temas disponiveis."
}

function Get-SshDeviceRegistry {
    $doc = Read-SshJsonFile -Path (Get-SshUserConfigPath 'hosts.json') -Default @{ version = 1; devices = @{} }
    if (-not ($doc -is [System.Collections.IDictionary])) { $doc = @{ version = 1; devices = @{} } }
    if (-not $doc.Contains('devices') -or -not ($doc.devices -is [System.Collections.IDictionary])) {
        $doc.devices = @{}
    }
    return $doc
}

function Save-SshDeviceRegistry {
    param([Parameter(Mandatory)]$Document)
    Write-SshJsonFile -Path (Get-SshUserConfigPath 'hosts.json') -Object $Document
    Clear-SshConfigCache
}

function Get-SshUserThemeDocument {
    $doc = Read-SshJsonFile -Path (Get-SshUserConfigPath 'themes.json') -Default @{ version = 1; themes = @{} }
    if (-not $doc.Contains('themes') -or -not ($doc.themes -is [System.Collections.IDictionary])) {
        $doc.themes = @{}
    }
    return $doc
}

function Save-SshThemeData {
    param(
        [Parameter(Mandatory)][string]$Name,
        $Data,
        [switch]$Remove
    )

    $doc = Get-SshUserThemeDocument
    if ($Remove) {
        if ($doc.themes.Contains($Name)) { $doc.themes.Remove($Name) }
    }
    else {
        $existing = @{}
        if ($doc.themes.Contains($Name)) { $existing = $doc.themes[$Name] }
        $doc.themes[$Name] = Merge-SshDeep -Base $existing -Override $Data
    }

    Write-SshJsonFile -Path (Get-SshUserConfigPath 'themes.json') -Object $doc
    Clear-SshConfigCache
}

function Save-SshSettingsData {
    param($Data)

    $doc = Read-SshJsonFile -Path (Get-SshUserConfigPath 'settings.json') -Default @{ version = 1; settings = @{} }
    if (-not $doc.Contains('settings') -or -not ($doc.settings -is [System.Collections.IDictionary])) {
        $doc.settings = @{}
    }
    $doc.settings = Merge-SshDeep -Base $doc.settings -Override $Data

    Write-SshJsonFile -Path (Get-SshUserConfigPath 'settings.json') -Object $doc
    Clear-SshConfigCache
}

function Get-SshDeviceEntryKey {
    param([Parameter(Mandatory)]$Resolved)

    $key = [string](Get-SshValue $Resolved 'Alias' '')
    if ([string]::IsNullOrWhiteSpace($key)) { $key = [string](Get-SshValue $Resolved 'HostName' '') }
    return $key
}

function Set-SshDeviceLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Target,
        [Parameter(Mandatory, Position = 1)][string]$Type
    )

    $theme = Get-SshThemeByName -Name $Type
    $resolved = Resolve-SshTarget -Target $Target
    if ($resolved.IsS3) { throw 'Lock nao se aplica a s3://. Use o tema s3 automaticamente.' }

    $registry = Get-SshDeviceRegistry
    $key = Get-SshDeviceEntryKey -Resolved $resolved
    # Se o IP/host ja existe registrado com outro nome (alias), trava o mesmo
    # registro para que -lock <ip> e sshx <alias> enxerguem o mesmo lock.
    if (-not $registry.devices.Contains($key)) {
        foreach ($candidate in @($registry.devices.Keys)) {
            if ([string](Get-SshValue $registry.devices[$candidate] 'host' '') -eq $resolved.HostName) {
                $key = $candidate
                break
            }
        }
    }
    if (-not $registry.devices.Contains($key)) { $registry.devices[$key] = @{} }
    $entry = $registry.devices[$key]

    if (-not (Get-SshValue $entry 'host' $null)) { $entry['host'] = $resolved.HostName }
    if ($resolved.User -and -not (Get-SshValue $entry 'user' $null)) { $entry['user'] = $resolved.User }
    if ($resolved.Port -and -not (Get-SshValue $entry 'port' $null)) { $entry['port'] = $resolved.Port }

    $entry['lockedType'] = $theme.Name
    $entry['lockedAt'] = (Get-Date).ToString('o')
    $entry['lock'] = $true
    Save-SshDeviceRegistry -Document $registry

    Write-Host ("  lock: " + $key + " -> " + $theme.Name + " (" + $theme.Label + ")") -ForegroundColor DarkGray
    return [pscustomobject]@{
        Name      = $key
        HostName  = $resolved.HostName
        Type      = $theme.Name
        Label     = $theme.Label
        LockedAt  = $entry['lockedAt']
    }
}

function Remove-SshDeviceLock {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$Target)

    $resolved = Resolve-SshTarget -Target $Target
    $registry = Get-SshDeviceRegistry
    $key = Get-SshDeviceEntryKey -Resolved $resolved
    if (-not $registry.devices.Contains($key)) {
        foreach ($candidate in @($registry.devices.Keys)) {
            if ([string](Get-SshValue $registry.devices[$candidate] 'host' '') -eq $resolved.HostName) {
                $key = $candidate
                break
            }
        }
    }
    if (-not $registry.devices.Contains($key)) {
        Write-Host ("  nenhum lock para " + $Target + ".") -ForegroundColor Yellow
        return $false
    }

    $entry = $registry.devices[$key]
    if (-not (Get-SshValue $entry 'lockedType' $null) -and -not (Get-SshValue $entry 'lock' $false)) {
        Write-Host ("  nenhum lock para " + $Target + ".") -ForegroundColor Yellow
        return $false
    }

    foreach ($name in @('lockedType', 'lockedAt', 'lock')) {
        if ($entry -is [System.Collections.IDictionary] -and $entry.Contains($name)) { $entry.Remove($name) }
    }
    Save-SshDeviceRegistry -Document $registry
    Write-Host ("  lock removido: " + $key + ". A deteccao volta a escolher o tema.") -ForegroundColor DarkGray
    return $true
}

function Get-SshDeviceLocks {
    [CmdletBinding()]
    param()

    $registry = Get-SshDeviceRegistry
    $locks = @()
    foreach ($key in @($registry.devices.Keys)) {
        $entry = $registry.devices[$key]
        $type = [string](Get-SshValue $entry 'lockedType' $null)
        if ([string]::IsNullOrWhiteSpace($type)) { continue }
        $theme = Get-SshThemeByName -Name $type -AllowMissing
        $locks += [pscustomobject]@{
            Name     = $key
            HostName = [string](Get-SshValue $entry 'host' $key)
            Type     = $type
            Label    = if ($theme) { $theme.Label } else { $type }
            LockedAt = Get-SshValue $entry 'lockedAt' $null
        }
    }
    return @($locks | Sort-Object -Property Name)
}

function Get-SshConfigHosts {
    if ($script:Cache.SshConfigHosts) { return $script:Cache.SshConfigHosts }

    $path = Join-Path (Join-Path (Get-SshHomePath) '.ssh') 'config'
    $hosts = @{}
    if (-not (Test-Path -LiteralPath $path)) {
        $script:Cache.SshConfigHosts = $hosts
        return $hosts
    }

    $aliases = @()
    foreach ($line in (Get-Content -LiteralPath $path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }

        if ($trimmed -match '^(?i)Host\s+(.+)$') {
            $aliases = @()
            foreach ($token in ($Matches[1] -split '\s+')) {
                if ($token -and $token -notmatch '[\*\?]') { $aliases += $token }
            }
            foreach ($alias in $aliases) {
                if (-not $hosts.ContainsKey($alias)) { $hosts[$alias] = @{} }
            }
            continue
        }

        if ($trimmed -match '^(?i)Match\s+') {
            $aliases = @()
            continue
        }

        if ($aliases.Count -gt 0 -and $trimmed -match '^(?<key>[A-Za-z][A-Za-z0-9]*)\s+(?<value>.+)$') {
            $key = $Matches['key']
            $value = $Matches['value'].Trim().Trim('"')
            foreach ($alias in $aliases) {
                if (-not $hosts[$alias].ContainsKey($key)) {
                    $hosts[$alias][$key] = $value
                }
            }
        }
    }

    $script:Cache.SshConfigHosts = $hosts
    return $hosts
}

function Get-SshConfigHostHint {
    param([string]$Alias)

    if ([string]::IsNullOrWhiteSpace($Alias)) { return $null }
    $hosts = Get-SshConfigHosts
    if ($hosts.ContainsKey($Alias)) { return $hosts[$Alias] }
    return $null
}
