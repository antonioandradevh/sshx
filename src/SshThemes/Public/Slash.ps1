# Slash commands: /font, /icons, /color, /distros and /help.

function Get-SshSlashSub {
    param($Arguments)

    if (-not $Arguments -or $Arguments.Count -eq 0) { return '' }
    return ([string]$Arguments[0]).ToLowerInvariant()
}

function Write-SshSlashHint {
    param([string]$Text)
    Write-Host ('  ' + $Text) -ForegroundColor DarkGray
}

function Invoke-SshFontCommand {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    $sub = Get-SshSlashSub $Arguments

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
            Write-Host '  /font' -ForegroundColor Cyan
            Write-Host ('  Windows Terminal: ' + $(if ($face) { $face } else { '(padrao)' })) -ForegroundColor DarkGray
            Write-Host ('  Nerd Fonts: ' + $(if ($nerd.Count -gt 0) { (@($nerd | ForEach-Object { $_.Name }) -join ', ') } else { 'nenhuma instalada' })) -ForegroundColor DarkGray
            Write-Host ''
            Write-SshSlashHint '/font list              lista as Nerd Fonts instaladas'
            Write-SshSlashHint '/font set <nome>        define a fonte do Windows Terminal'
            Write-SshSlashHint '/font install           instala a JetBrainsMono Nerd Font'
            Write-SshSlashHint '/font reset             volta para a fonte padrao'
            Write-SshSlashHint '/font test              mostra os glifos usados no prompt'
            Write-Host ''
        }
        'list' {
            $fonts = @(Get-SshNerdFont)
            if ($fonts.Count -eq 0) {
                Write-Host '  Nenhuma Nerd Font instalada. Use /font install.' -ForegroundColor Yellow
                return
            }
            Write-Host ''
            foreach ($font in $fonts) {
                Write-Host ('  ' + (Pad-SshText $font.Name 34) + $font.Scope) -ForegroundColor DarkGray
            }
            Write-Host ''
        }
        'set' {
            if ($Arguments.Count -lt 2) {
                Write-Host '  Uso: /font set <nome>   (veja /font list)' -ForegroundColor Yellow
                return
            }
            Set-SshTerminalFont -Name $Arguments[1] -Force
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
                Write-Host '  Nenhum glifo ativo. Use /icons on.' -ForegroundColor Yellow
            }
            Write-Host ('  Fonte: ' + $(if (Test-SshNerdFont) { 'Nerd Font detectada' } else { 'nenhuma Nerd Font' })) -ForegroundColor DarkGray
            Write-Host ''
        }
        default {
            Set-SshTerminalFont -Name $Arguments[0] -Force
        }
    }
}

function Invoke-SshIconsCommand {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    $sub = Get-SshSlashSub $Arguments
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
            Write-Host ('  /icons  ' + $(if ($icons) { 'ligados' } else { 'desligados' }) + '  (' + $set + ')') -ForegroundColor Cyan
            foreach ($part in $parts) {
                $on = Test-SshPartIcon -Settings $settings -Part $part
                Write-Host ('  ' + (Pad-SshText $labels[$part] 9) + $(if ($on) { 'on' } else { 'off' })) -ForegroundColor DarkGray
            }
            Write-Host ''
            Write-SshSlashHint '/icons on | off            liga/desliga todos os icones'
            Write-SshSlashHint '/icons nerd | ascii        escolhe o conjunto de glifos'
            Write-SshSlashHint '/icons <parte> on | off    parte: device, user, path, git, duration, clock, exit'
            Write-SshSlashHint '/icons reset               volta ao padrao (so o icone do sistema)'
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
                Write-Host '  Uso: /icons <parte> on|off' -ForegroundColor Yellow
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

    $sub = Get-SshSlashSub $Arguments
    $themeKeys = @('accent', 'accent2', 'foreground', 'background', 'cursor')
    $promptKeys = @('user', 'host', 'path', 'git', 'muted', 'durationFast', 'durationWarn', 'durationSlow', 'exitOk', 'exitFail')

    if ($sub -in @('', 'list')) {
        $catalog = Get-SshThemeCatalog
        Write-Host ''
        Write-Host '  /color' -ForegroundColor Cyan
        foreach ($name in @($catalog.Keys | Sort-Object)) {
            $theme = $catalog[$name]
            Write-Host ('  ' + (Pad-SshText $name 12) + (Pad-SshText $theme.Accent 10) + (Pad-SshText $theme.Accent2 10) + $theme.Label) -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-SshSlashHint '/color <tema>                    mostra as cores do tema'
        Write-SshSlashHint '/color <tema> <chave> <hex>      troca uma cor (hex sem # ou entre aspas)'
        Write-SshSlashHint '/color reset <tema>              volta o tema ao padrao'
        Write-SshSlashHint ('chaves: ' + (($themeKeys + $promptKeys) -join ', '))
        Write-SshSlashHint 'exemplo: /color debian accent E95420   ou   /color debian accent "#E95420"'
        Write-Host ''
        return
    }

    if ($sub -eq 'reset') {
        if ($Arguments.Count -lt 2) {
            Write-Host '  Uso: /color reset <tema>' -ForegroundColor Yellow
            return
        }
        Set-SshTheme -Name $Arguments[1] -Reset
        return
    }

    $themeName = [string]$Arguments[0]
    $theme = Get-SshThemeByName -Name $themeName -AllowMissing
    if (-not $theme) {
        Write-Host ('  Tema desconhecido: ' + $themeName + '. Use /color para listar.') -ForegroundColor Yellow
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
        Write-SshSlashHint ('Trocar: /color ' + $theme.Name + ' <chave> #RRGGBB')
        Write-Host ''
        return
    }

    $key = [string]$Arguments[1]
    $hex = [string]$Arguments[2]
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

    $sub = Get-SshSlashSub $Arguments

    switch ($sub) {
        { $_ -in @('', 'list') } {
            Show-SshThemes
            Write-SshSlashHint '/distros <nome>          previsualiza o tema'
            Write-SshSlashHint '/distros set <nome>      define o tema padrao'
            Write-SshSlashHint '/distros reset <nome>    restaura o tema padrao'
            Write-SshSlashHint '/distros custom <nome>   abre o JSON do tema no Notepad'
            Write-Host ''
        }
        'set' {
            if ($Arguments.Count -lt 2) {
                Write-Host '  Uso: /distros set <nome>' -ForegroundColor Yellow
                return
            }
            Set-SshSetting -DefaultTheme $Arguments[1] | Out-Null
            Write-Host ('  tema padrao: ' + $Arguments[1]) -ForegroundColor DarkGray
        }
        'reset' {
            if ($Arguments.Count -lt 2) {
                Write-Host '  Uso: /distros reset <nome>' -ForegroundColor Yellow
                return
            }
            Set-SshTheme -Name $Arguments[1] -Reset
        }
        'custom' {
            if ($Arguments.Count -lt 2) {
                Write-Host '  Uso: /distros custom <nome>' -ForegroundColor Yellow
                return
            }
            Edit-SshTheme -Name $Arguments[1]
        }
        default {
            Preview-SshTheme -Name $Arguments[0]
        }
    }
}

function Show-SshSlashHelp {
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host '  SshThemes - comandos' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  /font' -ForegroundColor White
    Write-SshSlashHint 'lista/instala/define a fonte do terminal e testa os glifos'
    Write-Host ''
    Write-Host '  /icons' -ForegroundColor White
    Write-SshSlashHint 'liga/desliga icones por parte (device, user, path, git, duration, clock, exit)'
    Write-Host ''
    Write-Host '  /color' -ForegroundColor White
    Write-SshSlashHint 'lista e troca cores de qualquer tema (accent, prompt.*, fundo, cursor)'
    Write-Host ''
    Write-Host '  /distros' -ForegroundColor White
    Write-SshSlashHint 'lista, previsualiza e define o tema padrao de cada distro/dispositivo'
    Write-Host ''
    Write-SshSlashHint 'Exemplos: /font set "0xProto Nerd Font"   /icons path on   /color debian accent E95420   /distros set debian'
    Write-Host ''
}
