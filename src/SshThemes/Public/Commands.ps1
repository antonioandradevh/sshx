# Dash commands: -font, -icons, -color, -distros, -lock, -unlock, -bg,
# -set, -get, -edit, -reset and -help. They are aliases of the module, so the
# user types them directly in PowerShell, without a leading slash.

function Get-SshCommandSub {
    param($Arguments)

    if (-not $Arguments -or $Arguments.Count -eq 0) { return '' }
    return ([string]$Arguments[0]).ToLowerInvariant()
}

function Get-SshCommandRest {
    param($Arguments, [int]$Start)

    if (-not $Arguments -or $Arguments.Count -le $Start) { return '' }
    return (($Arguments[$Start..($Arguments.Count - 1)]) -join ' ')
}

function Write-SshCommandHint {
    param([string]$Text)
    Write-Host ('  ' + $Text) -ForegroundColor DarkGray
}

function Write-SshCommandValue {
    param($Value)

    if ($null -eq $Value) { Write-Host '  (null)' -ForegroundColor DarkGray; return }
    if ($Value -is [System.Collections.IDictionary] -or $Value -is [pscustomobject]) {
        Write-Host ($Value | ConvertTo-Json -Depth 20) -ForegroundColor DarkGray
        return
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        Write-Host (($Value | ForEach-Object { [string]$_ }) -join ', ') -ForegroundColor DarkGray
        return
    }
    Write-Host ('  ' + [string]$Value) -ForegroundColor DarkGray
}

function Invoke-SshFontCommand {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    $sub = Get-SshCommandSub $Arguments

    switch ($sub) {
        '' {
            $path = Get-SshTerminalSettingsPath
            $face = ''
            if ($path) {
                try {
                    $data = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($data.profiles -and $data.profiles.defaults -and $data.profiles.defaults.font) {
                        $face = [string]$data.profiles.defaults.font.face
                    }
                }
                catch { }
            }
            $nerd = @(Get-SshNerdFont)
            Write-Host ''
            Write-Host '  -font' -ForegroundColor Cyan
            Write-Host ('  sistema: ' + $(if (Test-SshWindows) { 'Windows' } elseif (Test-SshMacOS) { 'macOS' } else { 'Linux' })) -ForegroundColor DarkGray
            if (Test-SshWindows) {
                Write-Host ('  Windows Terminal: ' + $(if ($face) { $face } else { '(padrao)' })) -ForegroundColor DarkGray
            }
            else {
                Write-Host ('  pasta de fontes: ' + (Get-SshFontDirectory)) -ForegroundColor DarkGray
            }
            Write-Host ('  Nerd Fonts: ' + $(if ($nerd.Count -gt 0) { (@($nerd | ForEach-Object { $_.Name }) -join ', ') } else { 'nenhuma instalada' })) -ForegroundColor DarkGray
            Write-Host ''
            Write-SshCommandHint '-font list              lista as Nerd Fonts instaladas'
            Write-SshCommandHint '-font set <nome>        define a fonte do Windows Terminal'
            Write-SshCommandHint '-font install           instala a JetBrainsMono Nerd Font'
            Write-SshCommandHint '-font reset             volta para a fonte padrao'
            Write-SshCommandHint '-font test              mostra os glifos usados no prompt'
            Write-Host ''
        }
        'list' {
            $fonts = @(Get-SshNerdFont)
            if ($fonts.Count -eq 0) {
                Write-Host '  Nenhuma Nerd Font instalada. Use -font install.' -ForegroundColor Yellow
                return
            }
            Write-Host ''
            foreach ($font in $fonts) {
                Write-Host ('  ' + (Pad-SshText $font.Name 34) + $font.Scope + '  ' + $font.Path) -ForegroundColor DarkGray
            }
            Write-Host ''
        }
        'set' {
            if ($Arguments.Count -lt 2) {
                Write-Host '  Uso: -font set <nome>   (veja -font list)' -ForegroundColor Yellow
                return
            }
            Set-SshTerminalFont -Name (Get-SshCommandRest -Arguments $Arguments -Start 1) -Force
        }
        'install' {
            Install-SshNerdFont -Force
        }
        'reset' {
            Set-SshTerminalFont -Reset
        }
        'test' {
            $settings = Get-SshSettings
            $theme = Get-SshThemeByName -Name (Get-SshValue $settings 'defaultTheme' 'local')
            $glyphs = @()
            foreach ($name in @('badge', 'user', 'path', 'git', 'duration', 'clock', 'ok', 'fail')) {
                $glyph = Get-SshGlyph -Theme $theme -Settings $settings -Name $name
                if (-not $glyph -and $name -eq 'badge') { $glyph = Get-SshThemeIcon -Theme $theme -Settings $settings }
                if ($glyph) { $glyphs += ($name + '=' + $glyph) }
            }
            Write-Host ''
            if ($glyphs.Count -gt 0) {
                Write-Host ('  ' + ($glyphs -join '   ')) -ForegroundColor White
            }
            else {
                Write-Host '  Nenhum glifo ativo. Use -icons on.' -ForegroundColor Yellow
            }
            Write-Host ('  Fonte: ' + $(if (Test-SshNerdFont) { 'Nerd Font detectada' } else { 'nenhuma Nerd Font' })) -ForegroundColor DarkGray
            Write-Host ''
        }
        default {
            Set-SshTerminalFont -Name (Get-SshCommandRest -Arguments $Arguments -Start 0) -Force
        }
    }
}

function Invoke-SshIconsCommand {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    $sub = Get-SshCommandSub $Arguments
    $parts = @('device', 'user', 'path', 'git', 'duration', 'clock', 'exit')

    switch ($sub) {
        { $_ -in @('', 'list', 'status') } {
            $settings = Get-SshSettings
            $icons = [bool](Get-SshValue (Get-SshValue $settings 'prompt' @{}) 'icons' $true)
            $set = [string](Get-SshValue $settings 'glyphSet' 'nerd')
            $labels = @{
                device = 'sistema'; user = 'usuario'; path = 'pasta'; git = 'git'
                duration = 'tempo'; clock = 'relogio'; exit = 'status'
            }
            Write-Host ''
            Write-Host ('  -icons  ' + $(if ($icons) { 'ligados' } else { 'desligados' }) + '  (' + $set + ')') -ForegroundColor Cyan
            foreach ($part in $parts) {
                $on = Test-SshPartIcon -Settings $settings -Part $part
                Write-Host ('  ' + (Pad-SshText $labels[$part] 9) + $(if ($on) { 'on' } else { 'off' })) -ForegroundColor DarkGray
            }
            Write-Host ''
            Write-SshCommandHint '-icons on | off            liga/desliga todos os icones'
            Write-SshCommandHint '-icons nerd | ascii        escolhe o conjunto de glifos'
            Write-SshCommandHint '-icons <parte> on | off    parte: device, user, path, git, duration, clock, exit'
            Write-SshCommandHint '-icons reset               volta ao padrao (so o icone do sistema)'
            Write-Host ''
        }
        'on' {
            Set-SshSetting -PromptIcons $true 6>$null
            Write-Host '  icones ligados.' -ForegroundColor DarkGray
        }
        'off' {
            Set-SshSetting -PromptIcons $false 6>$null
            Write-Host '  icones desligados.' -ForegroundColor DarkGray
        }
        'nerd' {
            Set-SshSetting -GlyphSet 'nerd' 6>$null
            Write-Host '  conjunto de glifos: nerd' -ForegroundColor DarkGray
        }
        'ascii' {
            Set-SshSetting -GlyphSet 'ascii' 6>$null
            Write-Host '  conjunto de glifos: ascii' -ForegroundColor DarkGray
        }
        'reset' {
            Reset-SshSetting -Name 'prompt' -Confirm:$false 6>$null
            Reset-SshSetting -Name 'path.icons' -Confirm:$false 6>$null
            Reset-SshSetting -Name 'glyphSet' -Confirm:$false 6>$null
            Write-Host '  icones restaurados: somente o icone do sistema.' -ForegroundColor DarkGray
        }
        default {
            $part = $sub
            if ($part -notin $parts) {
                Write-Host ('  Parte desconhecida: ' + $part) -ForegroundColor Yellow
                Write-Host ('  Use: ' + ($parts -join ', ')) -ForegroundColor DarkGray
                return
            }
            $value = if ($Arguments.Count -gt 1) { ([string]$Arguments[1]).ToLowerInvariant() } else { 'on' }
            if ($value -notin @('on', 'off', 'true', 'false', '1', '0', 'sim', 'nao')) {
                Write-Host '  Uso: -icons <parte> on|off' -ForegroundColor Yellow
                return
            }
            $enabled = $value -in @('on', 'true', '1', 'sim')
            if ($part -eq 'path') {
                Set-SshSetting -IconParts @{ $part = $enabled } -PathIcons $enabled 6>$null
            }
            else {
                Set-SshSetting -IconParts @{ $part = $enabled } 6>$null
            }
            Write-Host ('  icone ' + $part + ': ' + $(if ($enabled) { 'on' } else { 'off' })) -ForegroundColor DarkGray
        }
    }
}

function Invoke-SshColorCommand {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    $sub = Get-SshCommandSub $Arguments
    $themeKeys = @('accent', 'accent2', 'foreground', 'background', 'cursor')
    $promptKeys = @('user', 'host', 'path', 'git', 'muted', 'durationFast', 'durationWarn', 'durationSlow', 'exitOk', 'exitFail')

    if ($sub -in @('', 'list')) {
        $catalog = Get-SshThemeCatalog
        Write-Host ''
        Write-Host '  -color' -ForegroundColor Cyan
        foreach ($name in @($catalog.Keys | Sort-Object)) {
            $theme = $catalog[$name]
            Write-Host ('  ' + (Pad-SshText $name 12) + (Pad-SshText $theme.Accent 10) + (Pad-SshText $theme.Accent2 10) + $theme.Label) -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-SshCommandHint '-color <tema>                    mostra as cores do tema'
        Write-SshCommandHint '-color <tema> <chave> <hex>      troca uma cor (hex sem # ou entre aspas)'
        Write-SshCommandHint '-color <tema> background none    remove o fundo do tema'
        Write-SshCommandHint '-color reset <tema>              volta o tema ao padrao'
        Write-SshCommandHint ('chaves: ' + (($themeKeys + $promptKeys) -join ', '))
        Write-SshCommandHint 'exemplo: -color debian accent E95420   ou   -color debian accent "#E95420"'
        Write-Host ''
        return
    }

    if ($sub -eq 'reset') {
        if ($Arguments.Count -lt 2) {
            Write-Host '  Uso: -color reset <tema>' -ForegroundColor Yellow
            return
        }
        Set-SshTheme -Name $Arguments[1] -Reset
        return
    }

    $themeName = [string]$Arguments[0]
    $theme = Get-SshThemeByName -Name $themeName -AllowMissing
    if (-not $theme) {
        Write-Host ('  Tema desconhecido: ' + $themeName + '. Use -color para listar.') -ForegroundColor Yellow
        return
    }

    if ($Arguments.Count -lt 3) {
        Write-Host ''
        Write-Host ('  ' + $theme.Label + '  (' + $theme.Name + ')') -ForegroundColor Cyan
        Write-Host ('  accent      ' + $theme.Accent) -ForegroundColor DarkGray
        Write-Host ('  accent2     ' + $theme.Accent2) -ForegroundColor DarkGray
        Write-Host ('  foreground  ' + $(if ($theme.Foreground) { $theme.Foreground } else { '(padrao)' })) -ForegroundColor DarkGray
        Write-Host ('  background  ' + $(if ($theme.Background) { $theme.Background } else { '(sem fundo)' })) -ForegroundColor DarkGray
        Write-Host ('  cursor      ' + $(if ($theme.Cursor) { $theme.Cursor } else { '(padrao)' })) -ForegroundColor DarkGray
        foreach ($key in $promptKeys) {
            $value = Get-SshValue $theme.Prompt $key $null
            if ($value) { Write-Host ('  prompt.' + (Pad-SshText $key 14) + $value) -ForegroundColor DarkGray }
        }
        Write-Host ''
        Write-SshCommandHint ('Trocar: -color ' + $theme.Name + ' <chave> #RRGGBB')
        Write-SshCommandHint ('Remover fundo: -color ' + $theme.Name + ' background none')
        Write-Host ''
        return
    }

    $key = [string]$Arguments[1]
    $hex = [string]$Arguments[2]
    $lowerHex = $hex.ToLowerInvariant()

    if ($key -eq 'background' -and $lowerHex -in @('none', 'off', 'remove', '0')) {
        Set-SshTheme -Name $themeName -Background 'none' | Out-Null
        Write-Host ('  fundo removido do tema ' + $themeName + '.') -ForegroundColor DarkGray
        return
    }
    if ($key -eq 'background' -and $lowerHex -in @('reset', 'default', 'auto')) {
        Remove-SshThemeValue -Name $themeName -Path 'background'
        return
    }

    if ($hex -notmatch '^#') { $hex = '#' + $hex }
    if (-not (Test-SshHexColor $hex)) {
        Write-Host ('  Cor invalida: ' + $hex + '. Use #RRGGBB (entre aspas) ou RRGGBB.') -ForegroundColor Yellow
        return
    }

    switch ($key) {
        'accent' { Set-SshTheme -Name $themeName -Accent $hex | Out-Null }
        'accent2' { Set-SshTheme -Name $themeName -Accent2 $hex | Out-Null }
        'foreground' { Set-SshTheme -Name $themeName -Foreground $hex | Out-Null }
        'background' { Set-SshTheme -Name $themeName -Background $hex | Out-Null }
        'cursor' { Set-SshTheme -Name $themeName -Cursor $hex | Out-Null }
        default {
            if ($key -in $promptKeys) {
                Set-SshTheme -Name $themeName -PromptColors @{ $key = $hex } | Out-Null
            }
            else {
                Write-Host ('  Chave desconhecida: ' + $key) -ForegroundColor Yellow
                Write-Host ('  Use: ' + (($themeKeys + $promptKeys) -join ', ')) -ForegroundColor DarkGray
            }
        }
    }
}

function Invoke-SshDistrosCommand {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    $sub = Get-SshCommandSub $Arguments

    switch ($sub) {
        { $_ -in @('', 'list') } {
            Show-SshThemes
            Write-SshCommandHint '-distros <nome>          previsualiza o tema'
            Write-SshCommandHint '-distros set <nome>      define o tema padrao'
            Write-SshCommandHint '-distros reset <nome>    restaura o tema padrao'
            Write-SshCommandHint '-distros custom <nome>   abre o JSON do tema no editor'
            Write-SshCommandHint '-lock <ip> <nome>        trava o tema em um host/IP'
            Write-Host ''
        }
        'set' {
            if ($Arguments.Count -lt 2) {
                Write-Host '  Uso: -distros set <nome>' -ForegroundColor Yellow
                return
            }
            Set-SshSetting -DefaultTheme $Arguments[1] | Out-Null
            Write-Host ('  tema padrao: ' + $Arguments[1]) -ForegroundColor DarkGray
        }
        'reset' {
            if ($Arguments.Count -lt 2) {
                Write-Host '  Uso: -distros reset <nome>' -ForegroundColor Yellow
                return
            }
            Set-SshTheme -Name $Arguments[1] -Reset
        }
        'custom' {
            if ($Arguments.Count -lt 2) {
                Write-Host '  Uso: -distros custom <nome>' -ForegroundColor Yellow
                return
            }
            Edit-SshTheme -Name $Arguments[1]
        }
        default {
            Preview-SshTheme -Name $Arguments[0]
        }
    }
}

function Show-SshLocks {
    [CmdletBinding()]
    param()

    $locks = @(Get-SshDeviceLocks)
    Write-Host ''
    Write-Host ('  Locks  ' + (Get-SshUiChar 'dot') + '  ' + $locks.Count) -ForegroundColor DarkGray
    if ($locks.Count -eq 0) {
        Write-Host '  Nenhum host travado. Use: -lock <ip|host> <tema>' -ForegroundColor DarkGray
        Write-Host ''
        return
    }
    foreach ($lock in $locks) {
        Write-Host ('  ' + (Pad-SshText $lock.Name 22) + (Pad-SshText $lock.Type 12) + $lock.HostName) -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-SshCommandHint '-unlock <ip|host>        remove o lock'
    Write-Host ''
}

function Invoke-SshLockCommand {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    if (-not $Arguments -or $Arguments.Count -eq 0) {
        Show-SshLocks
        return
    }

    $sub = Get-SshCommandSub $Arguments
    if ($sub -in @('list', 'status', 'show')) { Show-SshLocks; return }
    if ($sub -in @('remove', 'off', 'unlock', 'reset')) {
        if ($Arguments.Count -lt 2) {
            Write-Host '  Uso: -lock remove <ip|host>' -ForegroundColor Yellow
            return
        }
        Remove-SshDeviceLock -Target $Arguments[1] | Out-Null
        return
    }

    if ($Arguments.Count -eq 1) {
        $device = @(Get-SshDevice -Name $Arguments[0])
        if ($device.Count -eq 0) {
            Write-Host ('  ' + $Arguments[0] + ' nao tem lock. Use: -lock ' + $Arguments[0] + ' <tema>') -ForegroundColor Yellow
            return
        }
        $item = $device[0]
        if ($item.Locked) {
            Write-Host ('  ' + $item.Name + ' -> ' + $item.LockedType + ' (' + $item.LockedAt + ')') -ForegroundColor DarkGray
        }
        else {
            Write-Host ('  ' + $item.Name + ' nao esta travado. Tema atual: ' + $item.Type) -ForegroundColor DarkGray
        }
        return
    }

    $target = $Arguments[0]
    $theme = $Arguments[1]

    # Aceita tambem -lock <tema> <ip> quando o primeiro argumento e um tema.
    $catalog = Get-SshThemeCatalog
    if ($catalog.Contains($sub) -and -not $catalog.Contains(([string]$Arguments[1]).ToLowerInvariant())) {
        $theme = $Arguments[0]
        $target = $Arguments[1]
    }

    Set-SshDeviceLock -Target $target -Type $theme | Out-Null
    Write-SshCommandHint 'Use sshx <ip> para conectar. O lock vence a deteccao.'
    Write-Host ''
}

function Invoke-SshUnlockCommand {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    if (-not $Arguments -or $Arguments.Count -eq 0) {
        Show-SshLocks
        return
    }

    if (([string]$Arguments[0]).ToLowerInvariant() -eq 'all') {
        foreach ($lock in @(Get-SshDeviceLocks)) {
            Remove-SshDeviceLock -Target $lock.Name | Out-Null
        }
        return
    }

    foreach ($target in $Arguments) {
        Remove-SshDeviceLock -Target $target | Out-Null
    }
}

function Invoke-SshBackgroundCommand {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    if (-not $Arguments -or $Arguments.Count -eq 0) {
        $settings = Get-SshSettings
        $mode = [string](Get-SshValue (Get-SshValue $settings 'terminal' @{}) 'mode' 'auto')
        $catalog = Get-SshThemeCatalog
        Write-Host ''
        Write-Host ('  -bg  modo do terminal: ' + $mode) -ForegroundColor Cyan
        foreach ($name in @($catalog.Keys | Sort-Object)) {
            $theme = $catalog[$name]
            $bg = if ($theme.Background) { $theme.Background } else { '(sem fundo)' }
            Write-Host ('  ' + (Pad-SshText $name 12) + $bg) -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-SshCommandHint '-bg off | text            nunca troca o fundo do terminal'
        Write-SshCommandHint '-bg auto | on             respeita o fundo de cada tema'
        Write-SshCommandHint '-bg full                  sempre aplica fg/bg/cursor'
        Write-SshCommandHint '-bg <tema> off            remove o fundo daquele tema'
        Write-SshCommandHint '-bg <tema> <hex>          define o fundo daquele tema'
        Write-SshCommandHint '-bg <tema> reset          volta o fundo ao padrao'
        Write-Host ''
        return
    }

    $first = ([string]$Arguments[0]).ToLowerInvariant()
    if ($first -in @('on', 'off', 'auto', 'text', 'full', 'none', 'reset')) {
        switch ($first) {
            { $_ -in @('off', 'text', 'none') } {
                Set-SshSetting -TerminalMode text 6>$null
                Write-Host '  fundo desligado: o terminal nao troca fg/bg/cursor.' -ForegroundColor DarkGray
            }
            { $_ -in @('on', 'auto') } {
                Set-SshSetting -TerminalMode auto 6>$null
                Write-Host '  modo auto: cada tema decide se pinta o fundo.' -ForegroundColor DarkGray
            }
            'full' {
                Set-SshSetting -TerminalMode full 6>$null
                Write-Host '  modo full: sempre aplica fg/bg/cursor.' -ForegroundColor DarkGray
            }
            'reset' {
                Reset-SshSetting -Name 'terminal.mode' -Confirm:$false 6>$null
                Write-Host '  modo do terminal restaurado (auto).' -ForegroundColor DarkGray
            }
        }
        return
    }

    $themeName = [string]$Arguments[0]
    $value = if ($Arguments.Count -gt 1) { ([string]$Arguments[1]).ToLowerInvariant() } else { '' }

    if ($themeName -eq 'all') {
        if ($value -in @('off', 'none', 'remove', '0', '')) {
            foreach ($name in @((Get-SshThemeCatalog).Keys)) {
                Set-SshThemeValue -Name $name -Path 'background' -Value $null
            }
            Write-Host '  fundo removido de todos os temas.' -ForegroundColor DarkGray
            return
        }
        if ($value -in @('reset', 'default', 'auto')) {
            foreach ($name in @((Get-SshThemeCatalog).Keys)) {
                Remove-SshThemeValue -Name $name -Path 'background'
            }
            return
        }
        $allHex = [string]$Arguments[1]
        if ($allHex -notmatch '^#') { $allHex = '#' + $allHex }
        if (-not (Test-SshHexColor $allHex)) {
            Write-Host ('  Cor invalida: ' + $allHex + '. Use #RRGGBB ou none.') -ForegroundColor Yellow
            return
        }
        foreach ($name in @((Get-SshThemeCatalog).Keys)) {
            Set-SshThemeValue -Name $name -Path 'background' -Value $allHex
        }
        return
    }

    $theme = Get-SshThemeByName -Name $themeName -AllowMissing
    if (-not $theme) {
        Write-Host ('  Tema desconhecido: ' + $themeName + '. Use -bg para listar.') -ForegroundColor Yellow
        return
    }

    if ($Arguments.Count -lt 2) {
        Write-Host ('  ' + $theme.Name + ': fundo = ' + $(if ($theme.Background) { $theme.Background } else { '(sem fundo)' })) -ForegroundColor DarkGray
        return
    }

    if ($value -in @('off', 'none', 'remove', '0')) {
        Set-SshThemeValue -Name $themeName -Path 'background' -Value $null
        Write-Host ('  fundo removido do tema ' + $themeName + '.') -ForegroundColor DarkGray
        return
    }
    if ($value -in @('reset', 'default', 'auto')) {
        Remove-SshThemeValue -Name $themeName -Path 'background'
        return
    }

    $hex = [string]$Arguments[1]
    if ($hex -notmatch '^#') { $hex = '#' + $hex }
    if (-not (Test-SshHexColor $hex)) {
        Write-Host ('  Cor invalida: ' + $hex + '. Use #RRGGBB ou none.') -ForegroundColor Yellow
        return
    }
    Set-SshThemeValue -Name $themeName -Path 'background' -Value $hex
}

function ConvertFrom-SshCliValue {
    param([string]$Value)

    if ($null -eq $Value) { return $null }
    $trimmed = $Value.Trim()
    if ($trimmed -eq '') { return '' }
    if ($trimmed -in @('null', 'none')) { return $null }
    if ($trimmed -eq 'true') { return $true }
    if ($trimmed -eq 'false') { return $false }
    if ($trimmed -match '^-?\d+$') { return [int]$trimmed }
    if ($trimmed -match '^-?\d+\.\d+$') { return [double]$trimmed }
    if ($trimmed.StartsWith('[') -or $trimmed.StartsWith('{')) {
        try { return (ConvertTo-SshHashtable -InputObject ($trimmed | ConvertFrom-Json)) } catch { }
    }
    if ($trimmed.Contains(',')) {
        return @($trimmed -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    }
    return $Value
}

function Invoke-SshSetCommand {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    if (-not $Arguments -or $Arguments.Count -lt 2) {
        Write-Host '  Uso:' -ForegroundColor Yellow
        Write-SshCommandHint '-set theme <tema> <caminho> <valor>'
        Write-SshCommandHint '-set setting <caminho> <valor>'
        Write-SshCommandHint '-set device <nome> <campo> <valor>'
        Write-SshCommandHint 'exemplo: -set theme debian prompt.path "#FFFFFF"'
        Write-SshCommandHint 'exemplo: -set setting terminal.mode text'
        Write-Host ''
        return
    }

    $scope = ([string]$Arguments[0]).ToLowerInvariant()
    switch ($scope) {
        'theme' {
            if ($Arguments.Count -lt 4) {
                Write-Host '  Uso: -set theme <tema> <caminho> <valor>' -ForegroundColor Yellow
                return
            }
            $name = [string]$Arguments[1]
            $path = [string]$Arguments[2]
            $value = ConvertFrom-SshCliValue (Get-SshCommandRest -Arguments $Arguments -Start 3)
            if ($path -eq 'background' -and $null -eq $value) {
                Set-SshThemeValue -Name $name -Path $path -Value $null
            }
            else {
                Set-SshThemeValue -Name $name -Path $path -Value $value
            }
        }
        'setting' {
            $path = [string]$Arguments[1]
            $value = ConvertFrom-SshCliValue (Get-SshCommandRest -Arguments $Arguments -Start 2)
            if ($path -eq 'defaultTheme') {
                if (-not (Get-SshThemeByName -Name ([string]$value) -AllowMissing)) {
                    Write-Host ('  Tema desconhecido: ' + $value) -ForegroundColor Yellow
                    return
                }
            }
            if ($path -eq 'terminal.mode' -and ([string]$value) -notin @('auto', 'text', 'full')) {
                Write-Host '  terminal.mode aceita auto, text ou full.' -ForegroundColor Yellow
                return
            }
            $data = @{}
            Set-SshNestedValue -Object $data -Path $path -Value $value
            Save-SshSettingsData -Data $data
            Write-Host ('  setting ' + $path + ' = ' + $(if ($null -eq $value) { 'null' } else { [string]$value })) -ForegroundColor DarkGray
        }
        'device' {
            if ($Arguments.Count -lt 4) {
                Write-Host '  Uso: -set device <nome> <campo> <valor>' -ForegroundColor Yellow
                return
            }
            $name = [string]$Arguments[1]
            $field = [string]$Arguments[2]
            $value = ConvertFrom-SshCliValue (Get-SshCommandRest -Arguments $Arguments -Start 3)
            $registry = Get-SshDeviceRegistry
            $key = $name
            if (-not $registry.devices.Contains($key)) {
                foreach ($candidate in @($registry.devices.Keys)) {
                    if ([string](Get-SshValue $registry.devices[$candidate] 'host' '') -eq $name) { $key = $candidate; break }
                }
            }
            if (-not $registry.devices.Contains($key)) { $registry.devices[$key] = @{} }
            Set-SshNestedValue -Object $registry.devices[$key] -Path $field -Value $value
            Save-SshDeviceRegistry -Document $registry
            Write-Host ('  device ' + $key + '.' + $field + ' = ' + $(if ($null -eq $value) { 'null' } else { [string]$value })) -ForegroundColor DarkGray
        }
        default {
            # Atalho: -set <setting.path> <valor>
            $path = [string]$Arguments[0]
            $value = ConvertFrom-SshCliValue (Get-SshCommandRest -Arguments $Arguments -Start 1)
            $data = @{}
            Set-SshNestedValue -Object $data -Path $path -Value $value
            Save-SshSettingsData -Data $data
            Write-Host ('  setting ' + $path + ' = ' + $(if ($null -eq $value) { 'null' } else { [string]$value })) -ForegroundColor DarkGray
        }
    }
}

function Invoke-SshGetCommand {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    if (-not $Arguments -or $Arguments.Count -eq 0) {
        Write-SshCommandValue (Get-SshSettings)
        return
    }

    $scope = ([string]$Arguments[0]).ToLowerInvariant()
    switch ($scope) {
        'theme' {
            if ($Arguments.Count -lt 2) {
                Write-SshCommandValue (Get-SshThemeCatalog)
                return
            }
            $path = if ($Arguments.Count -gt 2) { [string]$Arguments[2] } else { '' }
            Write-SshCommandValue (Get-SshThemeValue -Name $Arguments[1] -Path $path)
        }
        'setting' {
            $path = if ($Arguments.Count -gt 1) { [string]$Arguments[1] } else { '' }
            if ($path) { Write-SshCommandValue (Get-SshSetting $path) }
            else { Write-SshCommandValue (Get-SshSettings) }
        }
        'device' {
            $name = if ($Arguments.Count -gt 1) { [string]$Arguments[1] } else { '*' }
            $path = if ($Arguments.Count -gt 2) { [string]$Arguments[2] } else { '' }
            $devices = @(Get-SshDevice -Name $name)
            if ($path) {
                foreach ($device in $devices) { Write-SshCommandValue (Get-SshNestedValue -Object $device -Path $path -Default $null) }
            }
            else { Write-SshCommandValue $devices }
        }
        'lock' {
            if ($Arguments.Count -gt 1) {
                Write-SshCommandValue @(Get-SshDeviceLocks | Where-Object { $_.Name -eq $Arguments[1] -or $_.HostName -eq $Arguments[1] })
            }
            else { Write-SshCommandValue @(Get-SshDeviceLocks) }
        }
        default {
            Write-SshCommandValue (Get-SshSetting ([string]$Arguments[0]))
        }
    }
}

function Invoke-SshEditCommand {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    if (-not $Arguments -or $Arguments.Count -eq 0) {
        Edit-SshConfig -Name settings
        return
    }

    $first = ([string]$Arguments[0]).ToLowerInvariant()
    if ($first -eq 'theme') {
        if ($Arguments.Count -lt 2) {
            Write-Host '  Uso: -edit theme <tema>' -ForegroundColor Yellow
            return
        }
        Edit-SshTheme -Name $Arguments[1]
        return
    }
    if ($first -in @('settings', 'themes', 'hosts', 'glyphs')) {
        Edit-SshConfig -Name $first
        return
    }

    Edit-SshTheme -Name $Arguments[0]
}

function Invoke-SshResetCommand {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    if (-not $Arguments -or $Arguments.Count -eq 0) {
        Write-Host '  Uso: -reset theme <tema> | -reset settings | -reset locks | -reset all' -ForegroundColor Yellow
        return
    }

    $scope = ([string]$Arguments[0]).ToLowerInvariant()
    switch ($scope) {
        'theme' {
            if ($Arguments.Count -lt 2) {
                Write-Host '  Uso: -reset theme <tema>' -ForegroundColor Yellow
                return
            }
            Set-SshTheme -Name $Arguments[1] -Reset
        }
        'settings' {
            Reset-SshSetting -Confirm:$false
        }
        'locks' {
            foreach ($lock in @(Get-SshDeviceLocks)) { Remove-SshDeviceLock -Target $lock.Name | Out-Null }
        }
        'all' {
            Reset-SshSetting -Confirm:$false
            foreach ($name in @((Get-SshThemeCatalog).Keys)) { Save-SshThemeData -Name $name -Remove }
            foreach ($lock in @(Get-SshDeviceLocks)) { Remove-SshDeviceLock -Target $lock.Name | Out-Null }
            Write-Host '  temas, configuracoes e locks restaurados.' -ForegroundColor DarkGray
        }
        default {
            Set-SshTheme -Name $Arguments[0] -Reset
        }
    }
}

function Invoke-SshxCommand {
    # Deliberately no param block: native ssh flags such as -L, -p and -l must
    # reach ssh untouched instead of being matched as PowerShell parameters.
    $Arguments = @($args)

    if ($Arguments.Count -eq 0) {
        Connect-SshDevice
        return
    }

    foreach ($argument in $Arguments) {
        if ([string]$argument -in @('-Help', '--help', '-help')) {
            Show-SshHelp
            return
        }
    }

    $customValue = @{
        '-Type'         = 'Type'
        '-User'         = 'User'
        '-Port'         = 'Port'
        '-IdentityFile' = 'IdentityFile'
        '-Profile'      = 'Profile'
        '-Region'       = 'Region'
        '-EndpointUrl'  = 'EndpointUrl'
        '-Bucket'       = 'Bucket'
        '-Prefix'       = 'Prefix'
        '-Command'      = 'Command'
        '-Lock'         = 'Lock'
    }
    $customSwitch = @{
        '-Unlock'       = 'Unlock'
        '-NoDetect'     = 'NoDetect'
        '-Refresh'      = 'Refresh'
        '-RemoteTheme'  = 'RemoteTheme'
        '-NoRemoteTheme' = 'NoRemoteTheme'
        '-FullTheme'    = 'FullTheme'
        '-NoBackground' = 'NoBackground'
        '-DryRun'       = 'DryRun'
        '-NoBanner'     = 'NoBanner'
        '-PassThru'     = 'PassThru'
        '-S3'           = 'S3'
    }

    # ssh options that consume the next argument. The comparison is
    # case-sensitive because -C/-c, -F/-f, -O/-o, -Q/-q and -S/-s differ.
    $nativeValue = @(
        '-B', '-b', '-c', '-D', '-E', '-e', '-F', '-I', '-i', '-J', '-L', '-l',
        '-m', '-O', '-o', '-P', '-p', '-Q', '-R', '-S', '-W', '-w'
    )

    $parameters = @{}
    $native = @()
    $target = $null
    $commandParts = @()
    $afterSeparator = $false

    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $argument = [string]$Arguments[$i]

        if ($afterSeparator) {
            $commandParts += $argument
            continue
        }
        if ($argument -eq '--') {
            $afterSeparator = $true
            continue
        }

        $lower = $argument.ToLowerInvariant()
        if ($customValue.ContainsKey($lower)) {
            if ($i + 1 -lt $Arguments.Count) {
                $parameters[$customValue[$lower]] = [string]$Arguments[$i + 1]
                $i++
            }
            continue
        }
        if ($customSwitch.ContainsKey($lower)) {
            $parameters[$customSwitch[$lower]] = $true
            continue
        }

        if ($argument.StartsWith('-')) {
            $native += $argument
            if (($nativeValue -ccontains $argument) -and ($i + 1 -lt $Arguments.Count)) {
                $native += [string]$Arguments[$i + 1]
                $i++
            }
            continue
        }

        if (-not $target) { $target = $argument }
        else { $commandParts += $argument }
    }

    if ($target) { $parameters['Target'] = $target }
    if ($commandParts.Count -gt 0 -and -not $parameters.ContainsKey('Command')) {
        $parameters['Command'] = ($commandParts -join ' ')
    }
    if ($native.Count -gt 0) { $parameters['SshArgument'] = $native }

    if ($parameters.ContainsKey('S3')) {
        $s3 = @{}
        foreach ($key in @('Target', 'Bucket', 'Prefix', 'Profile', 'Region', 'EndpointUrl', 'FullTheme', 'NoBackground', 'DryRun', 'NoBanner', 'PassThru')) {
            if ($parameters.ContainsKey($key)) { $s3[$key] = $parameters[$key] }
        }
        Start-AwsWorkspace @s3
        return
    }

    Connect-SshDevice @parameters
}

function Show-SshHelp {
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host '  SshThemes - comandos' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  -help' -ForegroundColor White
    Write-SshCommandHint 'mostra esta ajuda'
    Write-Host ''
    Write-Host '  -font' -ForegroundColor White
    Write-SshCommandHint 'lista/instala/define a fonte do terminal e testa os glifos'
    Write-Host ''
    Write-Host '  -icons' -ForegroundColor White
    Write-SshCommandHint 'liga/desliga icones por parte (device, user, path, git, duration, clock, exit)'
    Write-Host ''
    Write-Host '  -color' -ForegroundColor White
    Write-SshCommandHint 'lista e troca cores de qualquer tema (accent, prompt.*, fundo, cursor)'
    Write-Host ''
    Write-Host '  -distros' -ForegroundColor White
    Write-SshCommandHint 'lista, previsualiza e define o tema padrao de cada distro/dispositivo'
    Write-Host ''
    Write-Host '  -lock / -unlock' -ForegroundColor White
    Write-SshCommandHint 'trava um tema em um IP/host; o lock vence a deteccao'
    Write-SshCommandHint '-lock 10.0.0.5 debian      -unlock 10.0.0.5'
    Write-Host ''
    Write-Host '  -bg' -ForegroundColor White
    Write-SshCommandHint 'remove/troca o fundo de um tema ou o modo do terminal'
    Write-SshCommandHint '-bg off    -bg debian off    -bg debian 1B0A0F'
    Write-Host ''
    Write-Host '  -set / -get / -edit / -reset' -ForegroundColor White
    Write-SshCommandHint 'edita qualquer campo de tema, setting ou device'
    Write-SshCommandHint '-set theme debian prompt.path "#FFFFFF"'
    Write-SshCommandHint '-set setting terminal.mode text'
    Write-SshCommandHint '-get setting terminal.mode'
    Write-SshCommandHint '-edit theme debian'
    Write-SshCommandHint '-reset theme debian'
    Write-Host ''
    Write-Host '  sshx' -ForegroundColor White
    Write-SshCommandHint 'conecta e aplica o tema; flags do ssh passam direto'
    Write-SshCommandHint 'sshx -X root@10.0.0.5'
    Write-SshCommandHint 'sshx root@10.0.0.5 -L 8080:localhost:80'
    Write-SshCommandHint 'sshx 10.0.0.5 -Lock debian'
    Write-Host ''
    Write-Host '  Exemplos: -font set "0xProto Nerd Font"   -icons path on   -color debian accent E95420' -ForegroundColor DarkGray
    Write-Host ''
}
