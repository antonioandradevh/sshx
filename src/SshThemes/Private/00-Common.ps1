# Common helpers: paths, JSON, deep merge, colors, ANSI and width math.

function Get-SshThemeHome {
    if ($env:SSHTHEMES_HOME -and -not [string]::IsNullOrWhiteSpace($env:SSHTHEMES_HOME)) {
        return $env:SSHTHEMES_HOME
    }
    return (Join-Path $HOME '.sshthemes')
}

function Get-SshModuleConfigPath {
    param([Parameter(Mandatory)][string]$Name)
    return (Join-Path (Join-Path $script:ModuleRoot 'config') $Name)
}

function Get-SshUserConfigPath {
    param([Parameter(Mandatory)][string]$Name)
    return (Join-Path (Get-SshThemeHome) $Name)
}

function Initialize-SshThemeHome {
    $homeDir = Get-SshThemeHome
    if (-not (Test-Path -LiteralPath $homeDir)) {
        New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
    }

    $seeds = @{
        'themes.json'   = (@{ version = 1; themes = @{} } | ConvertTo-Json -Depth 10)
        'hosts.json'    = (@{ version = 1; devices = @{} } | ConvertTo-Json -Depth 10)
        'settings.json' = (@{ version = 1; settings = @{} } | ConvertTo-Json -Depth 10)
        'glyphs.json'   = (@{ version = 1; sets = @{} } | ConvertTo-Json -Depth 10)
    }

    foreach ($name in $seeds.Keys) {
        $path = Join-Path $homeDir $name
        if (-not (Test-Path -LiteralPath $path)) {
            Write-SshJsonFile -Path $path -Object ($seeds[$name] | ConvertFrom-Json)
        }
    }
}

function Read-SshJsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        $Default = $null
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $Default
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $Default
    }

    try {
        $object = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "JSON invalido em '$Path': $($_.Exception.Message)"
    }

    return (ConvertTo-SshHashtable -InputObject $object)
}

function Write-SshJsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Object
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $json = $Object | ConvertTo-Json -Depth 30
    if ($null -eq $json) { $json = '{}' }
    $encoding = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $encoding)
}

function ConvertTo-SshHashtable {
    param($InputObject)

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $hash = @{}
        foreach ($key in @($InputObject.Keys)) {
            $hash[[string]$key] = ConvertTo-SshHashtable -InputObject $InputObject[$key]
        }
        return $hash
    }

    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $hash = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $hash[$property.Name] = ConvertTo-SshHashtable -InputObject $property.Value
        }
        return $hash
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ,(ConvertTo-SshHashtable -InputObject $item)
        }
        return ,$items
    }

    return $InputObject
}

function Copy-SshDeep {
    param($InputObject)

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $hash = @{}
        foreach ($key in @($InputObject.Keys)) {
            $hash[[string]$key] = Copy-SshDeep -InputObject $InputObject[$key]
        }
        return $hash
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ,(Copy-SshDeep -InputObject $item)
        }
        return ,$items
    }

    return $InputObject
}

function Merge-SshDeep {
    param($Base, $Override)

    if ($null -eq $Override) { return (Copy-SshDeep -InputObject $Base) }

    if ($Base -is [System.Collections.IDictionary] -and $Override -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in @($Base.Keys)) {
            $result[[string]$key] = Copy-SshDeep -InputObject $Base[$key]
        }
        foreach ($key in @($Override.Keys)) {
            $keyString = [string]$key
            if ($result.ContainsKey($keyString) -and
                $result[$keyString] -is [System.Collections.IDictionary] -and
                $Override[$key] -is [System.Collections.IDictionary]) {
                $result[$keyString] = Merge-SshDeep -Base $result[$keyString] -Override $Override[$key]
            }
            else {
                $result[$keyString] = Copy-SshDeep -InputObject $Override[$key]
            }
        }
        return $result
    }

    return (Copy-SshDeep -InputObject $Override)
}

function Get-SshValue {
    param(
        $Object,
        [Parameter(Mandatory)][string]$Name,
        $Default = $null
    )

    if ($null -eq $Object) { return $Default }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $Default
}

function Test-SshHexColor {
    param([string]$Color)
    if ([string]::IsNullOrWhiteSpace($Color)) { return $false }
    return ($Color -match '^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$')
}

function Convert-SshHexToRgb {
    param([Parameter(Mandatory)][string]$Color)

    if (-not (Test-SshHexColor $Color)) {
        throw "Cor hex invalida: '$Color'. Use o formato #RRGGBB ou #RGB."
    }

    $hex = $Color.TrimStart('#')
    if ($hex.Length -eq 3) {
        $hex = '' + $hex[0] + $hex[0] + $hex[1] + $hex[1] + $hex[2] + $hex[2]
    }

    return @{
        R = [Convert]::ToInt32($hex.Substring(0, 2), 16)
        G = [Convert]::ToInt32($hex.Substring(2, 2), 16)
        B = [Convert]::ToInt32($hex.Substring(4, 2), 16)
    }
}

function Format-SshAnsi {
    param(
        [string]$Text,
        [string]$Color,
        [switch]$Bold,
        [switch]$Background
    )

    if ($null -eq $Text) { $Text = '' }
    if (-not $Color -and -not $Bold) { return $Text }

    $codes = @()
    if ($Color -and (Test-SshHexColor $Color)) {
        $rgb = Convert-SshHexToRgb -Color $Color
        if ($Background) {
            $codes += "48;2;$($rgb.R);$($rgb.G);$($rgb.B)"
        }
        else {
            $codes += "38;2;$($rgb.R);$($rgb.G);$($rgb.B)"
        }
    }
    if ($Bold) { $codes += '1' }
    if ($codes.Count -eq 0) { return $Text }

    return "$script:Esc[$($codes -join ';')m$Text$script:Esc[0m"
}

function Remove-SshAnsi {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    return [regex]::Replace($Text, "$script:Esc\[[0-9;]*[A-Za-z]", '')
}

function Get-SshDisplayWidth {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    $plain = Remove-SshAnsi -Text $Text
    $width = 0

    for ($i = 0; $i -lt $plain.Length; $i++) {
        $char = $plain[$i]
        $code = [int]$char

        if ([char]::IsHighSurrogate($char) -and ($i + 1) -lt $plain.Length) {
            $width += 2
            $i++
            continue
        }
        if ($code -eq 0xFE0F -or $code -eq 0x200D -or $code -eq 0xFE0E) { continue }
        if ($code -ge 0x1F000) { $width += 2; continue }
        if ($code -ge 0xE000 -and $code -le 0xF8FF) { $width += 1; continue }
        if (($code -ge 0x1100 -and $code -le 0x115F) -or
            ($code -ge 0x2E80 -and $code -le 0xA4CF) -or
            ($code -ge 0xAC00 -and $code -le 0xD7A3) -or
            ($code -ge 0xF900 -and $code -le 0xFAFF) -or
            ($code -ge 0xFF00 -and $code -le 0xFF60)) {
            $width += 2
            continue
        }
        $width += 1
    }

    return $width
}

function Pad-SshText {
    param(
        [string]$Text,
        [int]$Width,
        [switch]$Right
    )

    $visible = Get-SshDisplayWidth -Text $Text
    $missing = $Width - $visible
    if ($missing -le 0) { return $Text }
    $padding = ' ' * $missing
    if ($Right) { return $padding + $Text }
    return $Text + $padding
}

function Truncate-SshText {
    param(
        [string]$Text,
        [int]$Width
    )

    if ($Width -le 0) { return '' }
    if ((Get-SshDisplayWidth -Text $Text) -le $Width) { return $Text }

    $suffix = Get-SshUiChar 'ellipsis'
    $target = $Width - (Get-SshDisplayWidth -Text $suffix)
    if ($target -lt 1) { return $suffix }

    $builder = ''
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $candidate = $builder + $Text[$i]
        if ((Get-SshDisplayWidth -Text $candidate) -gt $target) { break }
        $builder = $candidate
    }
    return ($builder.TrimEnd() + $suffix)
}

function Get-SshUiChar {
    param([Parameter(Mandatory)][string]$Name)

    switch ($Name) {
        'h'        { return [string][char]0x2500 }
        'v'        { return [string][char]0x2502 }
        'tl'       { return [string][char]0x256D }
        'tr'       { return [string][char]0x256E }
        'bl'       { return [string][char]0x2570 }
        'br'       { return [string][char]0x256F }
        'arrow'    { return [string][char]0x276F }
        'dot'      { return [string][char]0x00B7 }
        'ellipsis' { return [string][char]0x2026 }
        'swatch'   { return [string][char]0x2588 }
        'rule'     { return [string][char]0x2500 }
        default    { return '' }
    }
}
