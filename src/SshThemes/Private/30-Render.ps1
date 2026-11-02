# Rendering: glyphs, duration, paths, banner, prompt and session summary.

function Test-SshPromptIcons {
    param($Settings)
    return [bool](Get-SshValue (Get-SshValue $Settings 'prompt' @{}) 'icons' $false)
}

function Test-SshPartIcon {
    param(
        $Settings,
        [Parameter(Mandatory)][string]$Part
    )

    if (-not (Test-SshPromptIcons -Settings $Settings)) { return $false }

    $parts = Get-SshValue (Get-SshValue $Settings 'prompt' @{}) 'iconParts' @{}
    if ($parts -isnot [System.Collections.IDictionary] -or $parts.Count -eq 0) {
        return ($Part -eq 'device')
    }
    return [bool](Get-SshValue $parts $Part ($Part -eq 'device'))
}

function Get-SshGlyph {
    param(
        $Theme,
        $Settings,
        [Parameter(Mandatory)][string]$Name,
        [string]$Part,
        [switch]$NoIcons
    )

    if ($NoIcons) { return '' }
    if (-not (Test-SshPromptIcons -Settings $Settings)) { return '' }
    if ($Part -and -not (Test-SshPartIcon -Settings $Settings -Part $Part)) { return '' }

    if ($Theme -and $Theme.Icons -and $Theme.Icons.ContainsKey($Name) -and $Theme.Icons[$Name]) {
        return [string]$Theme.Icons[$Name]
    }

    $iconsOverride = Get-SshValue $Settings 'icons' @{}
    if ($iconsOverride -is [System.Collections.IDictionary] -and $iconsOverride.Contains($Name) -and $iconsOverride[$Name]) {
        return [string]$iconsOverride[$Name]
    }

    $setName = [string](Get-SshValue $Settings 'glyphSet' 'emoji')
    $packs = Get-SshGlyphPacks
    if ($packs.Contains($setName)) {
        $set = $packs[$setName]
        if ($set -is [System.Collections.IDictionary] -and $set.Contains($Name) -and $set[$Name]) {
            return [string]$set[$Name]
        }
    }

    if ($packs.Contains('emoji')) {
        $emoji = $packs['emoji']
        if ($emoji -is [System.Collections.IDictionary] -and $emoji.Contains($Name)) {
            return [string]$emoji[$Name]
        }
    }

    return ''
}

function Get-SshThemeIcon {
    param($Theme, $Settings)

    if (-not (Test-SshPromptIcons -Settings $Settings)) { return '' }

    $setName = [string](Get-SshValue $Settings 'glyphSet' 'emoji')
    if ($Theme.Icons -and $Theme.Icons.ContainsKey('badge') -and $Theme.Icons['badge']) {
        return [string]$Theme.Icons['badge']
    }
    if ($setName -eq 'nerd' -and $Theme.IconsNerd -and $Theme.IconsNerd.ContainsKey('badge') -and $Theme.IconsNerd['badge']) {
        return [string]$Theme.IconsNerd['badge']
    }
    return [string]$Theme.Icon
}

function Format-SshDuration {
    param(
        $Duration,
        $Settings
    )

    if ($null -eq $Duration) { return '' }
    if ($Duration -isnot [timespan]) {
        try { $Duration = [timespan]$Duration } catch { return '' }
    }

    $ms = [math]::Round($Duration.TotalMilliseconds)
    if ($ms -lt 1000) { return "$ms ms" }

    if ($ms -lt 60000) {
        $precision = 2
        $durationSettings = Get-SshValue $Settings 'duration' @{}
        $precision = [int](Get-SshValue $durationSettings 'precision' 2)
        if ($precision -lt 0) { $precision = 0 }
        if ($precision -gt 3) { $precision = 3 }
        $value = [math]::Round($ms / 1000, $precision)
        $format = '0' + $(if ($precision -gt 0) { '.' + ('0' * $precision) } else { '' })
        return (($value.ToString($format, [cultureinfo]::InvariantCulture)) + ' s')
    }

    $ts = [timespan]::FromMilliseconds($ms)
    if ($ts.TotalHours -ge 1) {
        return ('{0}h {1:00}m' -f [math]::Floor($ts.TotalHours), $ts.Minutes)
    }
    return ('{0}m {1:00}s' -f [math]::Floor($ts.TotalMinutes), $ts.Seconds)
}

function Get-SshDurationColor {
    param($Duration, $Settings, $Theme)

    if ($null -eq $Duration) { return $Theme.Prompt.muted }
    $ms = ([timespan]$Duration).TotalMilliseconds
    $durationSettings = Get-SshValue $Settings 'duration' @{}
    $warn = [double](Get-SshValue $durationSettings 'warnMs' 1500)
    $slow = [double](Get-SshValue $durationSettings 'slowMs' 5000)

    if ($ms -ge $slow) { return $Theme.Prompt.durationSlow }
    if ($ms -ge $warn) { return $Theme.Prompt.durationWarn }
    return $Theme.Prompt.durationFast
}

function Get-SshDirectoryIcon {
    param(
        [string]$Name,
        $Settings,
        $Theme,
        [switch]$NoIcons
    )

    if ($NoIcons -or -not (Test-SshPartIcon -Settings $Settings -Part 'path')) { return '' }
    if (-not (Get-SshValue (Get-SshValue $Settings 'path' @{}) 'icons' $true)) { return '' }

    $map = Get-SshValue (Get-SshValue $Settings 'path' @{}) 'directoryIcons' @{}
    if ($map -is [System.Collections.IDictionary]) {
        if ($map.Contains($Name) -and $map[$Name]) { return [string]$map[$Name] }
        foreach ($key in @($map.Keys)) {
            if ($key -match '[\*\?]' -and $Name -like $key -and $map[$key]) { return [string]$map[$key] }
        }
    }

    return (Get-SshGlyph -Theme $Theme -Settings $Settings -Name 'path' -Part 'path')
}

function Format-SshPath {
    param(
        [string]$Path,
        $Settings,
        $Theme,
        [switch]$NoIcons
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = (Get-Location).Path }

    $pathSettings = Get-SshValue $Settings 'path' @{}
    $style = [string](Get-SshValue $pathSettings 'style' 'smart')
    $maxSegments = [int](Get-SshValue $pathSettings 'maxSegments' 4)
    $homeAlias = [string](Get-SshValue $pathSettings 'homeAlias' '~')
    $homePath = Get-SshHomePath

    $display = $Path.Replace('\', '/')
    $homeNormalized = $homePath.Replace('\', '/').TrimEnd('/')

    if ($homeNormalized -and $display.ToLowerInvariant() -eq $homeNormalized.ToLowerInvariant()) {
        $display = $homeAlias
    }
    elseif ($homeNormalized -and $display.ToLowerInvariant().StartsWith($homeNormalized.ToLowerInvariant() + '/')) {
        $display = $homeAlias + $display.Substring($homeNormalized.Length)
    }

    $prefix = ''
    $body = $display
    if ($body -match '^([A-Za-z]:)(/.*)?$') {
        $prefix = $Matches[1]
        $body = $Matches[2]
    }
    elseif ($body.StartsWith($homeAlias)) {
        $prefix = $homeAlias
        $body = $body.Substring($homeAlias.Length)
    }
    elseif ($body.StartsWith('/')) {
        $prefix = '/'
        $body = $body.TrimStart('/')
    }

    $segments = @($body -split '/' | Where-Object { $_ -ne '' })
    if ($style -eq 'leaf' -and $segments.Count -gt 0) {
        $segments = @($segments[-1])
        $prefix = ''
    }
    elseif ($style -eq 'smart' -and $maxSegments -gt 0 -and $segments.Count -gt $maxSegments) {
        $segments = @($segments[($segments.Count - $maxSegments)..($segments.Count - 1)])
        if ($prefix -eq '/') { $prefix = '/' + (Get-SshUiChar 'ellipsis') + '/' }
        elseif ($prefix) { $prefix = $prefix + '/' + (Get-SshUiChar 'ellipsis') + '/' }
        else { $prefix = (Get-SshUiChar 'ellipsis') + '/' }
    }

    $leaf = ''
    if ($segments.Count -gt 0) { $leaf = [string]$segments[-1] }

    $joined = ($segments -join '/')
    if ($prefix -eq '/') { $rendered = '/' + $joined }
    elseif ($prefix) { $rendered = $prefix + $(if ($joined) { '/' + $joined } else { '' }) }
    else { $rendered = $joined }

    if ([string]::IsNullOrWhiteSpace($rendered)) { $rendered = '/' }

    $icon = Get-SshDirectoryIcon -Name $leaf -Settings $Settings -Theme $Theme -NoIcons:$NoIcons
    if ($icon) { return "$icon $rendered" }
    return $rendered
}

function Get-SshGitBranch {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = (Get-Location).Path }
    $current = $null
    try { $current = Get-Item -LiteralPath $Path -ErrorAction Stop } catch { return '' }
    if (-not $current.PSIsContainer) { $current = $current.Directory }

    for ($depth = 0; $depth -lt 12 -and $current; $depth++) {
        $gitPath = Join-Path $current.FullName '.git'
        if (Test-Path -LiteralPath $gitPath) {
            $headPath = $null
            if (Test-Path -LiteralPath $gitPath -PathType Container) {
                $headPath = Join-Path $gitPath 'HEAD'
            }
            else {
                try {
                    $pointer = (Get-Content -LiteralPath $gitPath -TotalCount 1 -ErrorAction Stop)
                    if ($pointer -match '^gitdir:\s*(.+)$') {
                        $gitDir = $Matches[1].Trim()
                        if (-not [System.IO.Path]::IsPathRooted($gitDir)) {
                            $gitDir = Join-Path $current.FullName $gitDir
                        }
                        $headPath = Join-Path $gitDir 'HEAD'
                    }
                }
                catch { }
            }

            if ($headPath -and (Test-Path -LiteralPath $headPath)) {
                try {
                    $head = (Get-Content -LiteralPath $headPath -TotalCount 1 -ErrorAction Stop).Trim()
                    if ($head -match '^ref:\s*refs/heads/(.+)$') { return $Matches[1] }
                    if ($head.Length -ge 7) { return $head.Substring(0, 7) }
                }
                catch { }
            }
            return ''
        }

        $parent = Split-Path -Parent $current.FullName
        if (-not $parent -or $parent -eq $current.FullName) { break }
        $current = Get-Item -LiteralPath $parent -ErrorAction SilentlyContinue
    }

    return ''
}

function Format-SshBanner {
    param(
        [Parameter(Mandatory)]$Theme,
        [Parameter(Mandatory)]$Settings,
        [Parameter(Mandatory)]$Resolved,
        $TypeResult,
        [ValidateSet('ssh', 's3')][string]$Mode = 'ssh',
        [string]$Version = $script:ModuleVersion
    )

    $width = [int](Get-SshValue (Get-SshValue $Settings 'terminal' @{}) 'bannerWidth' 68)
    try {
        $consoleWidth = $Host.UI.RawUI.WindowSize.Width
        if ($consoleWidth -gt 10 -and $consoleWidth - 2 -lt $width) { $width = $consoleWidth - 2 }
    }
    catch { }
    if ($width -lt 44) { $width = 44 }
    $inner = $width - 4
    $h = Get-SshUiChar 'h'
    $v = Get-SshUiChar 'v'
    $lines = @()

    $border = Format-SshAnsi -Text ($h * ($width - 2)) -Color $Theme.Accent
    $lines += (Format-SshAnsi -Text (Get-SshUiChar 'tl') -Color $Theme.Accent) + $border + (Format-SshAnsi -Text (Get-SshUiChar 'tr') -Color $Theme.Accent)

    $icon = Get-SshThemeIcon -Theme $Theme -Settings $Settings
    $showDeviceName = [bool](Get-SshValue (Get-SshValue $Settings 'prompt' @{}) 'deviceName' $false)
    if ($icon -and $showDeviceName) { $badgeLabel = "$icon $($Theme.BadgeText)" }
    elseif ($icon) { $badgeLabel = [string]$icon }
    elseif ($showDeviceName) { $badgeLabel = [string]$Theme.BadgeText }
    else { $badgeLabel = '' }
    $badge = Format-SshAnsi -Text $badgeLabel -Color $Theme.Accent2 -Bold
    $kind = if ($Mode -eq 's3') { 'S3' } else { 'SSH' }
    $right = Format-SshAnsi -Text $kind -Color $Theme.Prompt.muted

    $leftWidth = Get-SshDisplayWidth $badge
    $rightWidth = Get-SshDisplayWidth $right
    $gap = $inner - $leftWidth - $rightWidth
    if ($gap -lt 1) { $gap = 1 }
    $lines += (Format-SshAnsi -Text $v -Color $Theme.Accent) + ' ' + $badge + (' ' * $gap) + $right + ' ' + (Format-SshAnsi -Text $v -Color $Theme.Accent)

    $line = Format-SshAnsi -Text ($h * $inner) -Color $Theme.Accent
    $lines += (Format-SshAnsi -Text $v -Color $Theme.Accent) + ' ' + $line + ' ' + (Format-SshAnsi -Text $v -Color $Theme.Accent)

    $rows = @()
    $destination = if ($Mode -eq 's3') { $Resolved.Label } else { $Resolved.SshTarget }
    $rows += ,@('destino', $destination)
    $hostValue = [string]$Resolved.HostName
    if ($Resolved.Port -and $Mode -ne 's3') { $hostValue = "$hostValue`:$($Resolved.Port)" }
    $rows += ,@('host', $hostValue)
    $userValue = if ($Resolved.User) { [string]$Resolved.User } else { Get-SshUserName }
    if ($Mode -ne 's3') { $rows += ,@('usuario', $userValue) }

    $systemName = ''
    if ($TypeResult -and $TypeResult.Info) { $systemName = [string](Get-SshValue $TypeResult.Info 'OsName' '') }
    if ($systemName) { $rows += ,@('sistema', $systemName) }

    $swatch = Format-SshAnsi -Text ((Get-SshUiChar 'swatch') + (Get-SshUiChar 'swatch')) -Color $Theme.Accent
    $themeText = (Format-SshAnsi -Text $Theme.Label -Color $Theme.Foreground) + '  ' + (Format-SshAnsi -Text $Theme.Accent -Color $Theme.Prompt.muted) + ' ' + $swatch
    $rows += ,@('tema', $themeText)

    $modeText = [string](Get-SshValue (Get-SshValue $Settings 'terminal' @{}) 'mode' 'text')
    $sessionText = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + '  ' + (Format-SshAnsi -Text $modeText -Color $Theme.Prompt.muted)
    $rows += ,@('sessao', $sessionText)

    foreach ($row in $rows) {
        $label = Format-SshAnsi -Text (Pad-SshText -Text $row[0] -Width 9) -Color $Theme.Prompt.muted
        $value = [string]$row[1]
        $maxValue = $inner - 10
        if ((Get-SshDisplayWidth $value) -gt $maxValue) {
            $value = Truncate-SshText -Text (Remove-SshAnsi $value) -Width $maxValue
        }
        $padding = $inner - 10 - (Get-SshDisplayWidth $value)
        if ($padding -lt 0) { $padding = 0 }
        $content = $label + ' ' + $value + (' ' * $padding)
        $lines += (Format-SshAnsi -Text $v -Color $Theme.Accent) + ' ' + $content + ' ' + (Format-SshAnsi -Text $v -Color $Theme.Accent)
    }

    if ($Mode -eq 's3') {
        $hint = Format-SshAnsi -Text 's3ls | s3get | s3put | s3sync | s3rm  -  exitssh para sair' -Color $Theme.Prompt.muted
    }
    else {
        $hint = Format-SshAnsi -Text ("-Type <tema> forca o tema  -  exit encerra a sessao") -Color $Theme.Prompt.muted
    }
    $lines += (Format-SshAnsi -Text $v -Color $Theme.Accent) + ' ' + (Pad-SshText -Text $hint -Width $inner) + ' ' + (Format-SshAnsi -Text $v -Color $Theme.Accent)

    $lines += (Format-SshAnsi -Text (Get-SshUiChar 'bl') -Color $Theme.Accent) + $border + (Format-SshAnsi -Text (Get-SshUiChar 'br') -Color $Theme.Accent)

    return $lines
}

function Format-SshPromptText {
    param(
        [Parameter(Mandatory)]$Theme,
        [Parameter(Mandatory)]$Settings,
        [string]$Path = '',
        [string]$DeviceLabel,
        [string]$TargetLabel,
        [string]$UserName = (Get-SshUserName),
        [string]$HostName = (Get-SshMachineName),
        [string]$GitBranch = '',
        $Duration = $null,
        [int]$ExitCode = 0,
        [bool]$Success = $true,
        [datetime]$Now = (Get-Date),
        [switch]$Plain,
        [switch]$NoIcons,
        [switch]$NoArrow
    )

    $show = Get-SshValue $Settings 'show' @{}
    $segments = @()

    if (Get-SshValue $show 'clock' $true) {
        $clockFormat = [string](Get-SshValue (Get-SshValue $Settings 'clock' @{}) 'format' 'HH:mm')
        $clockText = ''
        try { $clockText = $Now.ToString($clockFormat) } catch { $clockText = $Now.ToString('HH:mm') }
        $clockGlyph = Get-SshGlyph -Theme $Theme -Settings $Settings -Name 'clock' -Part 'clock' -NoIcons:$NoIcons
        $text = if ($clockGlyph) { "$clockGlyph $clockText" } else { $clockText }
        $segments += [pscustomobject]@{ Text = $text; Color = $Theme.Prompt.muted; Bold = $false }
    }

    if (Get-SshValue $show 'device' $true) {
        $deviceIcon = if (-not $NoIcons -and (Test-SshPartIcon -Settings $Settings -Part 'device')) { Get-SshThemeIcon -Theme $Theme -Settings $Settings } else { '' }
        $showDeviceName = [bool](Get-SshValue (Get-SshValue $Settings 'prompt' @{}) 'deviceName' $false)
        $labelText = if ($DeviceLabel) { $DeviceLabel } else { $Theme.BadgeText }
        $text = ''
        if ($deviceIcon -and $showDeviceName) { $text = "$deviceIcon $labelText" }
        elseif ($deviceIcon) { $text = $deviceIcon }
        elseif ($showDeviceName) { $text = $labelText }
        if ($text) {
            $segments += [pscustomobject]@{ Text = $text; Color = $Theme.Accent2; Bold = $true }
        }
    }

    if ($TargetLabel) {
        $segments += [pscustomobject]@{ Text = $TargetLabel; Color = $Theme.Prompt.muted; Bold = $false }
    }

    $showUser = [bool](Get-SshValue $show 'user' $true) -and -not [string]::IsNullOrWhiteSpace($UserName)
    $showHost = [bool](Get-SshValue $show 'host' $true) -and -not [string]::IsNullOrWhiteSpace($HostName)
    if ($showUser -or $showHost) {
        if ($showUser -and $showHost) { $identity = "$UserName@$HostName" }
        elseif ($showUser) { $identity = $UserName }
        else { $identity = $HostName }

        $identityGlyph = Get-SshGlyph -Theme $Theme -Settings $Settings -Name 'user' -Part 'user' -NoIcons:$NoIcons
        $text = if ($identityGlyph) { "$identityGlyph $identity" } else { $identity }
        $segments += [pscustomobject]@{ Text = $text; Color = $Theme.Prompt.user; Bold = $false }
    }

    if (Get-SshValue $show 'path' $true) {
        $pathText = Format-SshPath -Path $Path -Settings $Settings -Theme $Theme -NoIcons:$NoIcons
        $segments += [pscustomobject]@{ Text = $pathText; Color = $Theme.Prompt.path; Bold = $false }
    }

    if ((Get-SshValue $show 'git' $true) -and $GitBranch) {
        $gitGlyph = Get-SshGlyph -Theme $Theme -Settings $Settings -Name 'git' -Part 'git' -NoIcons:$NoIcons
        $text = if ($gitGlyph) { "$gitGlyph $GitBranch" } else { $GitBranch }
        $segments += [pscustomobject]@{ Text = $text; Color = $Theme.Prompt.git; Bold = $false }
    }

    if ((Get-SshValue $show 'duration' $true) -and $null -ne $Duration) {
        $durationText = Format-SshDuration -Duration $Duration -Settings $Settings
        if ($durationText) {
            $durationGlyph = Get-SshGlyph -Theme $Theme -Settings $Settings -Name 'duration' -Part 'duration' -NoIcons:$NoIcons
            $text = if ($durationGlyph) { "$durationGlyph $durationText" } else { $durationText }
            $segments += [pscustomobject]@{ Text = $text; Color = (Get-SshDurationColor -Duration $Duration -Settings $Settings -Theme $Theme); Bold = $false }
        }
    }

    if (Get-SshValue $show 'exitCode' $true) {
        if ($Success) {
            $okGlyph = Get-SshGlyph -Theme $Theme -Settings $Settings -Name 'ok' -Part 'exit' -NoIcons:$NoIcons
            if ($okGlyph) {
                $segments += [pscustomobject]@{ Text = $okGlyph; Color = $Theme.Prompt.exitOk; Bold = $false }
            }
        }
        else {
            $failGlyph = Get-SshGlyph -Theme $Theme -Settings $Settings -Name 'fail' -Part 'exit' -NoIcons:$NoIcons
            $text = if ($failGlyph) { "$failGlyph $ExitCode" } else { "exit $ExitCode" }
            $segments += [pscustomobject]@{ Text = $text; Color = $Theme.Prompt.exitFail; Bold = $true }
        }
    }

    $separator = [string](Get-SshValue (Get-SshValue $Settings 'prompt' @{}) 'separator' '  ')
    $arrow = if ($NoArrow) { '' } else { Get-SshUiChar 'arrow' }
    $arrowSpace = [string](Get-SshValue (Get-SshValue $Settings 'prompt' @{}) 'arrowSpace' ' ')
    $multiline = [bool](Get-SshValue (Get-SshValue $Settings 'prompt' @{}) 'multiline' $true)

    $colored = @()
    $plainParts = @()
    foreach ($segment in $segments) {
        $plainParts += $segment.Text
        if ($Plain) { $colored += $segment.Text }
        else { $colored += (Format-SshAnsi -Text $segment.Text -Color $segment.Color -Bold:$segment.Bold) }
    }

    $firstLine = ($colored -join $separator)
    if ($Plain) {
        $firstLine = ($plainParts -join $separator)
        if (-not $arrow) { return ($firstLine + ' ') }
        if ($multiline) { return ($firstLine + [Environment]::NewLine + $arrow + $arrowSpace) }
        return ($arrow + $arrowSpace + $firstLine + ' ')
    }

    $arrowText = if ($arrow) { (Format-SshAnsi -Text $arrow -Color $Theme.Accent -Bold) + $arrowSpace } else { '' }
    if ($multiline) {
        return ($firstLine + [Environment]::NewLine + $arrowText)
    }
    return ($arrowText + $firstLine + ' ')
}

function Format-SshSummary {
    param(
        [Parameter(Mandatory)]$Session,
        [timespan]$Duration,
        [int]$ExitCode = 0,
        $Settings,
        $Theme
    )

    if ($Theme -and $Settings -and -not (Get-SshValue (Get-SshValue $Settings 'show' @{}) 'summary' $true)) { return @() }

    $durationText = Format-SshDuration -Duration $Duration -Settings $Settings
    $kind = if ($Session.Kind -eq 's3') { 'workspace s3' } else { 'sessao ssh' }
    $status = if ($ExitCode -eq 0) { 'encerrado' } else { "encerrado com exit $ExitCode" }
    $parts = @($kind, $status)
    if ($durationText) { $parts += $durationText }
    $text = ' ' + ($parts -join ('  ' + (Get-SshUiChar 'dot') + '  ')) + ' '

    $color = if ($ExitCode -eq 0 -and $Theme) { $Theme.Accent } elseif ($Theme) { $Theme.Prompt.exitFail } else { $null }
    $line = Format-SshAnsi -Text $text -Color $color -Bold
    return @($line)
}
