# Settings and configuration editing.

function Get-SshNestedValue {
    param($Object, [string]$Path, $Default = $null)

    $current = $Object
    foreach ($part in ($Path -split '\.')) {
        if ($null -eq $current) { return $Default }
        if ($current -is [System.Collections.IDictionary]) {
            if (-not $current.Contains($part)) { return $Default }
            $current = $current[$part]
        }
        else {
            $property = $current.PSObject.Properties[$part]
            if (-not $property) { return $Default }
            $current = $property.Value
        }
    }
    return $current
}

function Set-SshNestedValue {
    param($Object, [string]$Path, $Value)

    $parts = @($Path -split '\.')
    $current = $Object
    for ($i = 0; $i -lt ($parts.Count - 1); $i++) {
        $part = $parts[$i]
        if (-not ($current[$part] -is [System.Collections.IDictionary])) {
            $current[$part] = @{}
        }
        $current = $current[$part]
    }
    $current[$parts[-1]] = $Value
}

function Remove-SshNestedValue {
    param($Object, [string]$Path)

    $parts = @($Path -split '\.')
    $current = $Object
    for ($i = 0; $i -lt ($parts.Count - 1); $i++) {
        $part = $parts[$i]
        if (-not ($current -is [System.Collections.IDictionary]) -or -not $current.Contains($part)) { return }
        $current = $current[$part]
    }
    if ($current -is [System.Collections.IDictionary] -and $current.Contains($parts[-1])) {
        $current.Remove($parts[-1])
    }
}

function Get-SshSetting {
    [CmdletBinding()]
    param([Parameter(Position = 0)][string]$Name)

    $settings = Get-SshSettings
    if ([string]::IsNullOrWhiteSpace($Name)) { return $settings }

    $value = Get-SshNestedValue -Object $settings -Path $Name -Default ([pscustomobject]@{ __missing = $true })
    if ($value -is [pscustomobject] -and $value.PSObject.Properties['__missing']) {
        throw "Configuracao '$Name' nao encontrada."
    }
    return $value
}

function Set-SshSetting {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$DefaultTheme,
        [ValidateSet('emoji', 'nerd', 'ascii')][string]$GlyphSet,
        [ValidateSet('auto', 'text', 'full')][string]$TerminalMode,
        [bool]$TerminalResetOnExit,
        [bool]$PromptEnabled,
        [bool]$PromptIcons,
        [bool]$DeviceName,
        [bool]$Multiline,
        [string]$Separator,
        [string]$ArrowSpace,
        [bool]$Banner,
        [bool]$Summary,
        [int]$BannerWidth,
        [bool]$TerminalTitle,
        [int]$DurationWarnMs,
        [int]$DurationSlowMs,
        [int]$DurationPrecision,
        [ValidateSet('smart', 'full', 'leaf')][string]$PathStyle,
        [int]$MaxPathSegments,
        [bool]$PathIcons,
        [string]$HomeAlias,
        [string]$ClockFormat,
        [bool]$DetectProbe,
        [int]$DetectTimeoutSeconds,
        [int]$CacheDays,
        [bool]$DetectStrictHostKeys,
        [hashtable]$Show,
        [hashtable]$Icons,
        [hashtable]$IconParts,
        [hashtable]$DirectoryIcons,
        [bool]$ApplyForeground,
        [string]$S3Profile,
        [string]$S3Region,
        [string]$S3EndpointUrl,
        [string]$RemoteShell,
        [bool]$RemoteAutoTheme,
        [string]$RemoteRcPath,
        [switch]$Reset,
        [switch]$PassThru
    )

    if ($Reset) {
        Reset-SshSetting
        if ($PassThru) { return (Get-SshSettings) }
        return
    }

    if (-not $PSCmdlet.ShouldProcess('SshThemes settings', 'update')) { return }

    $data = @{}

    if ($PSBoundParameters.ContainsKey('DefaultTheme')) {
        if (-not (Get-SshThemeByName -Name $DefaultTheme -AllowMissing)) {
            throw "Tema '$DefaultTheme' nao existe."
        }
        $data['defaultTheme'] = $DefaultTheme
    }
    if ($PSBoundParameters.ContainsKey('GlyphSet')) { $data['glyphSet'] = $GlyphSet }
    if ($PSBoundParameters.ContainsKey('PromptEnabled')) { $data['prompt'] = @{ enabled = $PromptEnabled } }
    if ($PSBoundParameters.ContainsKey('PromptIcons')) {
        $data['prompt'] = Merge-SshDeep -Base (Get-SshValue $data 'prompt' @{}) -Override @{ icons = $PromptIcons }
    }
    if ($PSBoundParameters.ContainsKey('DeviceName')) {
        $data['prompt'] = Merge-SshDeep -Base (Get-SshValue $data 'prompt' @{}) -Override @{ deviceName = $DeviceName }
    }
    if ($PSBoundParameters.ContainsKey('Multiline')) {
        $data['prompt'] = Merge-SshDeep -Base (Get-SshValue $data 'prompt' @{}) -Override @{ multiline = $Multiline }
    }
    if ($PSBoundParameters.ContainsKey('Separator')) {
        $data['prompt'] = Merge-SshDeep -Base (Get-SshValue $data 'prompt' @{}) -Override @{ separator = $Separator }
    }
    if ($PSBoundParameters.ContainsKey('ArrowSpace')) {
        $data['prompt'] = Merge-SshDeep -Base (Get-SshValue $data 'prompt' @{}) -Override @{ arrowSpace = $ArrowSpace }
    }

    if ($PSBoundParameters.ContainsKey('Banner')) { $data['show'] = @{ banner = $Banner } }
    if ($PSBoundParameters.ContainsKey('Summary')) {
        $data['show'] = Merge-SshDeep -Base (Get-SshValue $data 'show' @{}) -Override @{ summary = $Summary }
    }
    if ($Show) {
        $data['show'] = Merge-SshDeep -Base (Get-SshValue $data 'show' @{}) -Override $Show
    }

    if ($PSBoundParameters.ContainsKey('BannerWidth')) {
        if ($BannerWidth -lt 44) { throw 'BannerWidth minimo: 44.' }
        $data['terminal'] = @{ bannerWidth = $BannerWidth }
    }
    if ($PSBoundParameters.ContainsKey('TerminalMode')) {
        $data['terminal'] = Merge-SshDeep -Base (Get-SshValue $data 'terminal' @{}) -Override @{ mode = $TerminalMode }
    }
    if ($PSBoundParameters.ContainsKey('TerminalTitle')) {
        $data['terminal'] = Merge-SshDeep -Base (Get-SshValue $data 'terminal' @{}) -Override @{ title = $TerminalTitle }
    }
    if ($PSBoundParameters.ContainsKey('TerminalResetOnExit')) {
        $data['terminal'] = Merge-SshDeep -Base (Get-SshValue $data 'terminal' @{}) -Override @{ resetOnExit = $TerminalResetOnExit }
    }
    if ($PSBoundParameters.ContainsKey('ApplyForeground')) {
        $mode = if ($ApplyForeground) { 'full' } else { 'text' }
        $data['terminal'] = Merge-SshDeep -Base (Get-SshValue $data 'terminal' @{}) -Override @{ mode = $mode }
    }

    if ($PSBoundParameters.ContainsKey('DurationWarnMs') -or $PSBoundParameters.ContainsKey('DurationSlowMs') -or $PSBoundParameters.ContainsKey('DurationPrecision')) {
        $duration = @{}
        if ($PSBoundParameters.ContainsKey('DurationWarnMs')) { $duration['warnMs'] = $DurationWarnMs }
        if ($PSBoundParameters.ContainsKey('DurationSlowMs')) { $duration['slowMs'] = $DurationSlowMs }
        if ($PSBoundParameters.ContainsKey('DurationPrecision')) { $duration['precision'] = $DurationPrecision }
        $data['duration'] = $duration
    }

    if ($PSBoundParameters.ContainsKey('PathStyle') -or $PSBoundParameters.ContainsKey('MaxPathSegments') -or $PSBoundParameters.ContainsKey('PathIcons') -or $PSBoundParameters.ContainsKey('HomeAlias') -or $DirectoryIcons) {
        $path = @{}
        if ($PSBoundParameters.ContainsKey('PathStyle')) { $path['style'] = $PathStyle }
        if ($PSBoundParameters.ContainsKey('MaxPathSegments')) { $path['maxSegments'] = $MaxPathSegments }
        if ($PSBoundParameters.ContainsKey('PathIcons')) { $path['icons'] = $PathIcons }
        if ($PSBoundParameters.ContainsKey('HomeAlias')) { $path['homeAlias'] = $HomeAlias }
        if ($DirectoryIcons) { $path['directoryIcons'] = $DirectoryIcons }
        $data['path'] = $path
    }

    if ($PSBoundParameters.ContainsKey('ClockFormat')) { $data['clock'] = @{ format = $ClockFormat } }

    if ($PSBoundParameters.ContainsKey('DetectProbe') -or $PSBoundParameters.ContainsKey('DetectTimeoutSeconds') -or $PSBoundParameters.ContainsKey('CacheDays') -or $PSBoundParameters.ContainsKey('DetectStrictHostKeys')) {
        $detect = @{}
        if ($PSBoundParameters.ContainsKey('DetectProbe')) { $detect['probe'] = $DetectProbe }
        if ($PSBoundParameters.ContainsKey('DetectTimeoutSeconds')) { $detect['timeoutSeconds'] = $DetectTimeoutSeconds }
        if ($PSBoundParameters.ContainsKey('CacheDays')) { $detect['cacheDays'] = $CacheDays }
        if ($PSBoundParameters.ContainsKey('DetectStrictHostKeys')) { $detect['strictHostKeys'] = $DetectStrictHostKeys }
        $data['detect'] = $detect
    }

    if ($Icons) { $data['icons'] = $Icons }
    if ($IconParts) {
        $data['prompt'] = Merge-SshDeep -Base (Get-SshValue $data 'prompt' @{}) -Override @{ iconParts = $IconParts }
    }

    if ($PSBoundParameters.ContainsKey('S3Profile') -or $PSBoundParameters.ContainsKey('S3Region') -or $PSBoundParameters.ContainsKey('S3EndpointUrl')) {
        $s3 = @{}
        if ($PSBoundParameters.ContainsKey('S3Profile')) { $s3['profile'] = $S3Profile }
        if ($PSBoundParameters.ContainsKey('S3Region')) { $s3['region'] = $S3Region }
        if ($PSBoundParameters.ContainsKey('S3EndpointUrl')) { $s3['endpointUrl'] = $S3EndpointUrl }
        $data['s3'] = $s3
    }

    if ($PSBoundParameters.ContainsKey('RemoteShell')) { $data['remote'] = Merge-SshDeep -Base (Get-SshValue $data 'remote' @{}) -Override @{ shell = $RemoteShell } }
    if ($PSBoundParameters.ContainsKey('RemoteAutoTheme')) {
        $data['remote'] = Merge-SshDeep -Base (Get-SshValue $data 'remote' @{}) -Override @{ auto = $RemoteAutoTheme }
    }
    if ($PSBoundParameters.ContainsKey('RemoteRcPath')) {
        $data['remote'] = Merge-SshDeep -Base (Get-SshValue $data 'remote' @{}) -Override @{ rcPath = $RemoteRcPath }
    }

    if ($data.Count -eq 0) { throw 'Nenhuma configuracao informada.' }

    Save-SshSettingsData -Data $data
    Write-Host 'Configuracoes atualizadas.' -ForegroundColor DarkGray
    if ($PassThru) { return (Get-SshSettings) }
}

function Reset-SshSetting {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Name)

    $path = Get-SshUserConfigPath 'settings.json'
    if ($PSCmdlet.ShouldProcess($path, 'resetar configuracoes')) {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            Write-SshJsonFile -Path $path -Object @{ version = 1; settings = @{} }
        }
        else {
            $doc = Read-SshJsonFile -Path $path -Default @{ version = 1; settings = @{} }
            Remove-SshNestedValue -Object $doc.settings -Path $Name
            Write-SshJsonFile -Path $path -Object $doc
        }
        Clear-SshConfigCache
        Write-Host 'Configuracoes restauradas.' -ForegroundColor DarkGray
    }
}

function Enable-SshThemePrompt {
    [CmdletBinding()]
    param()

    Save-SshSettingsData -Data @{ prompt = @{ enabled = $true } }
    Write-Host 'Prompt SshThemes ativado.' -ForegroundColor DarkGray
}

function Disable-SshThemePrompt {
    [CmdletBinding()]
    param()

    Save-SshSettingsData -Data @{ prompt = @{ enabled = $false } }
    Write-Host 'Prompt SshThemes desativado. O prompt original voltou.' -ForegroundColor DarkGray
}

function Reload-SshConfig {
    [CmdletBinding()]
    param([switch]$PassThru)

    Clear-SshConfigCache
    $settings = Get-SshSettings
    $catalog = Get-SshThemeCatalog
    Write-Host "Configuracoes recarregadas ($($catalog.Count) temas)." -ForegroundColor DarkGray
    if ($PassThru) {
        return [pscustomobject]@{ Settings = $settings; Themes = $catalog }
    }
}

function Edit-SshConfig {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('settings', 'themes', 'hosts', 'glyphs')]
        [string]$Name = 'settings'
    )

    Initialize-SshThemeHome
    $path = Get-SshUserConfigPath "$Name.json"
    Write-Host "Editando $path" -ForegroundColor DarkGray
    Write-Host 'Depois de salvar, rode: Reload-SshConfig' -ForegroundColor DarkGray
    Open-SshTextFile -Path $path
}
