# Theme cmdlets: inspect, customize, create, preview.

function Get-SshTheme {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Name = '*',
        [switch]$Raw,
        [switch]$Json
    )

    $catalog = Get-SshThemeCatalog
    $names = @()
    if ($Name -match '[\*\?]') {
        $names = @($catalog.Keys | Where-Object { $_ -like $Name })
    }
    elseif ($catalog.Contains($Name)) {
        $names = @($Name)
    }
    else {
        throw "Tema '$Name' nao encontrado. Use Show-SshThemes para listar."
    }

    $result = @()
    foreach ($themeName in $names) {
        $theme = $catalog[$themeName]
        if ($Json) {
            $result += ($theme.Data | ConvertTo-Json -Depth 20)
        }
        elseif ($Raw) {
            $result += $theme.Data
        }
        else {
            $result += $theme
        }
    }

    return $result
}

function Set-SshTheme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [string]$Accent,
        [string]$Accent2,
        [string]$Foreground,
        [string]$Background,
        [string]$Cursor,
        [string]$Label,
        [string]$BadgeText,
        [Alias('BadgeIcon')][string]$Icon,
        [string]$Note,
        [hashtable]$Icons,
        [hashtable]$IconsNerd,
        [hashtable]$PromptColors,
        [hashtable]$Detect,
        [switch]$Reset,
        [switch]$PassThru
    )

    $theme = Get-SshThemeByName -Name $Name -AllowMissing
    if (-not $theme) {
        throw "Tema '$Name' nao existe. Use New-SshTheme para criar."
    }

    if ($Reset) {
        Save-SshThemeData -Name $Name -Remove
        Write-Host "Tema '$Name' restaurado para o padrao." -ForegroundColor DarkGray
        if ($PassThru) { return (Get-SshThemeByName -Name $Name) }
        return
    }

    $data = @{}

    # Explicit checks, because parameter names are case-insensitive but the loop above is not.
    if ($PSBoundParameters.ContainsKey('Accent')) { $data['accent'] = $Accent }
    if ($PSBoundParameters.ContainsKey('Accent2')) { $data['accent2'] = $Accent2 }
    if ($PSBoundParameters.ContainsKey('Foreground')) { $data['foreground'] = $Foreground }
    if ($PSBoundParameters.ContainsKey('Background')) {
        if ([string]::IsNullOrWhiteSpace($Background) -or $Background -eq 'none') { $data['background'] = $null }
        else { $data['background'] = $Background }
    }
    if ($PSBoundParameters.ContainsKey('Cursor')) {
        if ([string]::IsNullOrWhiteSpace($Cursor) -or $Cursor -eq 'none') { $data['cursor'] = $null }
        else { $data['cursor'] = $Cursor }
    }
    if ($PSBoundParameters.ContainsKey('Label')) { $data['label'] = $Label }
    if ($PSBoundParameters.ContainsKey('BadgeText')) { $data['badgeText'] = $BadgeText }
    if ($PSBoundParameters.ContainsKey('Icon')) {
        $data['icon'] = $Icon
        $iconMap = @{}
        if ($data.ContainsKey('icons')) { $iconMap = $data['icons'] }
        $iconMap['badge'] = $Icon
        $data['icons'] = $iconMap
    }
    if ($PSBoundParameters.ContainsKey('Note')) { $data['note'] = $Note }

    foreach ($colorKey in @('accent', 'accent2', 'foreground', 'background', 'cursor')) {
        if ($data.ContainsKey($colorKey) -and $data[$colorKey] -and -not (Test-SshHexColor $data[$colorKey])) {
            throw "Cor invalida em -$colorKey`: '$($data[$colorKey])'. Use #RRGGBB."
        }
    }

    if ($Icons) {
        $data['icons'] = @{}
        foreach ($key in $Icons.Keys) {
            if (Test-SshHexColor $Icons[$key]) {
                throw "O icone '$key' parece uma cor hex. Use -Accent para cores."
            }
            $data['icons'][[string]$key] = [string]$Icons[$key]
        }
    }
    if ($IconsNerd) { $data['iconsNerd'] = $IconsNerd }
    if ($Detect) { $data['detect'] = $Detect }

    if ($PromptColors) {
        $data['prompt'] = @{}
        foreach ($key in $PromptColors.Keys) {
            if ($PromptColors[$key] -and -not (Test-SshHexColor ([string]$PromptColors[$key]))) {
                throw "Cor invalida em -PromptColors '$key': '$($PromptColors[$key])'."
            }
            $data['prompt'][[string]$key] = [string]$PromptColors[$key]
        }
    }

    if ($data.Count -eq 0) {
        throw 'Nenhuma alteracao informada. Use -Accent, -Icon, -PromptColors, -Reset, etc.'
    }

    Save-SshThemeData -Name $Name -Data $data
    Write-Host "Tema '$Name' atualizado." -ForegroundColor DarkGray
    if ($PassThru) { return (Get-SshThemeByName -Name $Name) }
}

function New-SshTheme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [string]$Label,
        [string]$Icon = '',
        [string]$Accent = '#4CC2FF',
        [string]$Accent2,
        [string]$Foreground = '#E6E6E6',
        [string]$Background,
        [string]$BadgeText,
        [string]$Note,
        [hashtable]$PromptColors,
        [hashtable]$Icons,
        [hashtable]$Detect,
        [switch]$Force,
        [switch]$PassThru
    )

    if ($Name -notmatch '^[a-zA-Z0-9_-]+$') {
        throw "Nome de tema invalido: '$Name'. Use letras, numeros, '-' e '_'."
    }

    $catalog = Get-SshThemeCatalog
    if ($catalog.Contains($Name) -and -not $Force) {
        throw "O tema '$Name' ja existe. Use -Force para sobrescrever ou Set-SshTheme para ajustar."
    }
    foreach ($pair in @(@('Accent', $Accent), @('Accent2', $Accent2), @('Foreground', $Foreground), @('Background', $Background))) {
        if ($pair[1] -and -not (Test-SshHexColor $pair[1])) {
            throw "Cor invalida em -$($pair[0]): '$($pair[1])'."
        }
    }

    $data = @{
        label      = if ($Label) { $Label } else { $Name }
        icon       = $Icon
        accent     = $Accent
        accent2    = if ($Accent2) { $Accent2 } else { $Accent }
        foreground = $Foreground
        background = if ($Background) { $Background } else { $null }
        badgeText  = if ($BadgeText) { $BadgeText } else { $Name.ToUpperInvariant() }
        note       = $Note
    }
    if ($PromptColors) { $data['prompt'] = $PromptColors }
    if ($Icons) { $data['icons'] = $Icons }
    if ($Detect) { $data['detect'] = $Detect }

    Save-SshThemeData -Name $Name -Data $data
    Write-Host "Tema '$Name' criado." -ForegroundColor DarkGray
    if ($PassThru) { return (Get-SshThemeByName -Name $Name) }
}

function Remove-SshTheme {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [switch]$Force
    )

    $theme = Get-SshThemeByName -Name $Name -AllowMissing
    if (-not $theme) { throw "Tema '$Name' nao encontrado." }

    $defaultsDoc = Read-SshJsonFile -Path (Get-SshModuleConfigPath 'themes.default.json') -Default @{ themes = @{} }
    $defaultThemes = Get-SshValue $defaultsDoc 'themes' @{}
    $isBuiltIn = ($defaultThemes -is [System.Collections.IDictionary]) -and $defaultThemes.Contains($Name)

    if ($Force -or $PSCmdlet.ShouldProcess($Name, $(if ($isBuiltIn) { 'restaurar tema padrao' } else { 'remover tema customizado' }))) {
        Save-SshThemeData -Name $Name -Remove
        if ($isBuiltIn) {
            Write-Host "Tema '$Name' restaurado para o padrao." -ForegroundColor DarkGray
        }
        else {
            Write-Host "Tema '$Name' removido." -ForegroundColor DarkGray
        }
    }
}

function Show-SshThemes {
    [CmdletBinding()]
    param(
        [switch]$Detailed,
        [switch]$NoColor,
        [switch]$PassThru
    )

    $settings = Get-SshSettings
    $catalog = Get-SshThemeCatalog
    $useColor = (-not $NoColor) -and (Test-SshAnsiTerminal)
    $widths = @{ type = 4; label = 5; accent = 6; badge = 6 }

    foreach ($name in $catalog.Keys) {
        if ($name.Length -gt $widths.type) { $widths.type = $name.Length }
        $label = $catalog[$name].Label
        if ($label.Length -gt $widths.label) { $widths.label = $label.Length }
        if ($catalog[$name].BadgeText.Length -gt $widths.badge) { $widths.badge = $catalog[$name].BadgeText.Length }
    }

    $header = (Pad-SshText 'TIPO' ($widths.type + 2)) + (Pad-SshText 'TEMA' ($widths.label + 2)) + (Pad-SshText 'HEX' 10) + (Pad-SshText 'BADGE' ($widths.badge + 2)) + 'CUSTOM'
    Write-Host ''
    Write-Host ('  Temas SshThemes  ' + (Get-SshUiChar 'dot') + '  ' + $catalog.Count + ' disponiveis') -ForegroundColor DarkGray
    Write-Host ('  ' + $header) -ForegroundColor DarkGray
    Write-Host ('  ' + ((Get-SshUiChar 'h') * ($header.Length))) -ForegroundColor DarkGray

    foreach ($name in $catalog.Keys) {
        $theme = $catalog[$name]
        $icon = Get-SshThemeIcon -Theme $theme -Settings $settings
        $iconPrefix = if ($icon) { $icon + ' ' } else { '' }
        $type = Pad-SshText $name ($widths.type + 2)
        $label = Pad-SshText $theme.Label ($widths.label + 2)
        $hex = Pad-SshText $theme.Accent 10
        $badge = Pad-SshText $theme.BadgeText ($widths.badge + 2)
        $custom = if ($theme.IsCustom) { 'sim' } else { 'nao' }
        if ($useColor) {
            $swatch = Format-SshAnsi -Text ((Get-SshUiChar 'swatch') + (Get-SshUiChar 'swatch')) -Color $theme.Accent
            Write-Host ('  ' + $iconPrefix + $type + $label + $hex + $swatch + '  ' + $badge + $custom)
        }
        else {
            Write-Host ('  ' + $iconPrefix + $type + $label + $hex + '[] ' + $badge + $custom)
        }
        if ($Detailed -and $theme.Note) {
            Write-Host ('      ' + $theme.Note) -ForegroundColor DarkGray
        }
    }

    Write-Host ''
    Write-Host '  Personalize: Set-SshTheme -Name debian -Accent "#FF0000" -Icon "..."' -ForegroundColor DarkGray
    Write-Host '  Teste visual: Preview-SshTheme -Name debian' -ForegroundColor DarkGray
    Write-Host ''

    if ($PassThru) { return @($catalog.Values) }
}

function Preview-SshTheme {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][Alias('Type')][string]$Name = 'local',
        [switch]$All,
        [switch]$Plain,
        [int]$Width = 68
    )

    $catalog = Get-SshThemeCatalog
    $settings = Get-SshSettings
    $previewSettings = Copy-SshDeep -InputObject $settings
    $previewSettings['terminal']['bannerWidth'] = $Width

    $names = if ($All) { @($catalog.Keys) } else { @($Name) }

    foreach ($themeName in $names) {
        if (-not $catalog.Contains($themeName)) {
            throw "Tema '$themeName' nao encontrado."
        }
        $theme = $catalog[$themeName]
        $isS3 = ($themeName -eq 's3')
        $mode = if ($isS3) { 's3' } else { 'ssh' }

        $resolved = [pscustomobject]@{
            SshTarget = 'root@host.example'
            HostName  = 'host.example'
            Port      = 22
            User      = 'root'
            Label     = if ($isS3) { 's3://meu-bucket/backups' } else { 'host.example' }
            IsS3      = $isS3
        }
        $typeResult = [pscustomobject]@{ Info = @{ OsName = $theme.Note } }

        Write-Host ''
        foreach ($line in (Format-SshBanner -Theme $theme -Settings $previewSettings -Resolved $resolved -TypeResult $typeResult -Mode $mode)) {
            if ($Plain) { Write-Host (Remove-SshAnsi $line) } else { Write-Host $line }
        }

        $samplePath = Join-Path (Join-Path $HOME 'projetos') 'sshthemes'
        $promptLine = Format-SshPromptText `
            -Theme $theme `
            -Settings $previewSettings `
            -Path $samplePath `
            -DeviceLabel $theme.BadgeText `
            -UserName 'root' `
            -HostName 'host.example' `
            -GitBranch 'main' `
            -Duration ([timespan]::FromMilliseconds(128)) `
            -ExitCode 0 `
            -Success $true `
            -Plain:$Plain

        foreach ($line in ($promptLine -split [Environment]::NewLine)) {
            if ($Plain) { Write-Host $line } else { Write-Host $line }
        }

        $summary = Format-SshSummary -Session ([pscustomobject]@{ Kind = $mode }) -Duration ([timespan]::FromMilliseconds(34200)) -ExitCode 0 -Settings $previewSettings -Theme $theme
        foreach ($line in $summary) {
            if ($Plain) { Write-Host (Remove-SshAnsi $line) } else { Write-Host $line }
        }
        if ($Plain) { Write-Host '' }
    }
}

function Edit-SshTheme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [switch]$NoLaunch
    )

    $theme = Get-SshThemeByName -Name $Name -AllowMissing
    if (-not $theme) { throw "Tema '$Name' nao encontrado." }

    # Persist the fully merged theme so every field is visible/editable.
    Save-SshThemeData -Name $Name -Data (Copy-SshDeep -InputObject $theme.Data)
    $path = Get-SshUserConfigPath 'themes.json'

    Write-Host "Tema '$Name' gravado em:" -ForegroundColor DarkGray
    Write-Host "  $path" -ForegroundColor DarkGray
    Write-Host "Edite o objeto .themes.$Name e rode: Reload-SshConfig" -ForegroundColor DarkGray

    if (-not $NoLaunch) {
        Start-Process -FilePath notepad.exe -ArgumentList "`"$path`""
    }
}
