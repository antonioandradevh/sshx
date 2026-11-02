# SshThemes test runner (no Pester required).
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1

[CmdletBinding()]
param([switch]$Keep)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path (Join-Path $repoRoot 'src') (Join-Path 'SshThemes' 'SshThemes.psd1')
$testHome = Join-Path ([System.IO.Path]::GetTempPath()) ('sshthemes-tests-' + [guid]::NewGuid().ToString('N'))

$previousHome = $env:SSHTHEMES_HOME
$previousNoAnsi = $env:SSHTHEMES_NO_ANSI
$env:SSHTHEMES_HOME = $testHome
$env:SSHTHEMES_NO_ANSI = $null

$script:Passed = 0
$script:Failed = 0
$script:Failures = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        $script:Passed++
        Write-Host ('  ok   ' + $Message) -ForegroundColor DarkGreen
    }
    else {
        $script:Failed++
        $script:Failures += $Message
        Write-Host ('  FAIL ' + $Message) -ForegroundColor Red
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    $same = ([string]$Expected -eq [string]$Actual)
    if (-not $same) {
        $Message = $Message + " (esperado: '$Expected', obtido: '$Actual')"
    }
    Assert-True -Condition $same -Message $Message
}

function Assert-Match {
    param([string]$Pattern, [string]$Text, [string]$Message)
    $ok = ($Text -match $Pattern)
    if (-not $ok) {
        $Message = $Message + " (padrao: '$Pattern')"
    }
    Assert-True -Condition $ok -Message $Message
}

Write-Host ''
Write-Host 'SshThemes test suite' -ForegroundColor Cyan
Write-Host "Home de teste: $testHome" -ForegroundColor DarkGray
Write-Host ''

try {
    Remove-Module SshThemes -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force -WarningAction SilentlyContinue
    $module = Get-Module SshThemes | Where-Object { $_.Path -eq $modulePath } | Select-Object -First 1
    if (-not $module) { $module = Get-Module SshThemes | Select-Object -First 1 }
    Assert-True -Condition ($null -ne $module) -Message 'modulo importado'

    # ------------------------------------------------------------------ themes
    $catalog = & $module { Get-SshThemeCatalog }
    Assert-True -Condition ($catalog.Count -ge 15) -Message 'catalogo tem 15+ temas'
    Assert-True -Condition ($catalog.Contains('debian')) -Message 'tema debian existe'
    Assert-Equal -Expected '#A81D33' -Actual (Get-SshTheme debian).Accent -Message 'hex padrao do Debian'
    Assert-Equal -Expected '#FF9900' -Actual (Get-SshTheme s3).Accent -Message 'hex padrao do S3'
    Assert-Equal -Expected '#1B0A0F' -Actual (Get-SshTheme debian).Background -Message 'tema Debian tem fundo proprio'
    Assert-True -Condition ($null -eq (Get-SshTheme s3).Background) -Message 'tema S3 fica so no texto (sem fundo)'
    Assert-True -Condition ($null -eq (Get-SshTheme aws).Background) -Message 'tema AWS fica so no texto (sem fundo)'
    Assert-Equal -Expected 'auto' -Actual (Get-SshSetting 'terminal.mode') -Message 'modo de terminal padrao e auto'
    Assert-Equal -Expected 'True' -Actual (Get-SshSetting 'prompt.icons') -Message 'prompt padrao usa icones'
    Assert-Equal -Expected 'nerd' -Actual (Get-SshSetting 'glyphSet') -Message 'conjunto padrao usa Nerd Font'
    Assert-Equal -Expected 'False' -Actual (Get-SshSetting 'prompt.deviceName') -Message 'prompt padrao nao mostra o nome da distro'
    Assert-Equal -Expected 'False' -Actual (Get-SshSetting 'show.clock') -Message 'relogio oculto por padrao'
    Assert-Equal -Expected 'local' -Actual (@($catalog.Keys)[0]) -Message 'tema local aparece primeiro'
    Assert-Equal -Expected 'True' -Actual (Get-SshSetting 'prompt.iconParts.device') -Message 'icone do sistema ligado por padrao'
    Assert-Equal -Expected 'False' -Actual (Get-SshSetting 'prompt.iconParts.path') -Message 'icone de pasta oculto por padrao'
    Assert-Equal -Expected 'False' -Actual (Get-SshSetting 'prompt.iconParts.duration') -Message 'icone de tempo oculto por padrao'
    Assert-Equal -Expected 'False' -Actual (Get-SshSetting 'path.icons') -Message 'icones de diretorio ocultos por padrao'
    $localTheme = Get-SshTheme local
    Assert-Equal -Expected ([string][char]0xF17A) -Actual $localTheme.IconsNerd.badge -Message 'sessao local usa o icone do Windows'
    foreach ($dash in @('-font', '-icons', '-color', '-distros', '-lock', '-unlock', '-bg', '-set', '-get', '-edit', '-reset', '-help')) {
        Assert-True -Condition ((Get-Command -Name $dash -ErrorAction SilentlyContinue).CommandType -eq 'Alias') -Message ('alias ' + $dash + ' existe')
    }

    $defaultPrompt = & $module {
        param($t, $s)
        Format-SshPromptText -Theme $t -Settings $s -Path 'C:\tmp\app' -DeviceLabel '' -UserName 'root' -HostName 'srv01' -GitBranch 'main' -Duration ([timespan]::FromMilliseconds(128)) -ExitCode 0 -Success $true -Plain
    } (Get-SshTheme debian) (Get-SshSetting)
    Assert-True -Condition ($defaultPrompt.Contains([string][char]0xF306)) -Message 'prompt padrao mostra o icone do sistema'
    Assert-True -Condition (-not $defaultPrompt.Contains([string][char]0xF07B)) -Message 'prompt padrao nao mostra icone de pasta'
    Assert-True -Condition (-not $defaultPrompt.Contains([string][char]0xF2F2)) -Message 'prompt padrao nao mostra icone de tempo'
    Assert-True -Condition (-not $defaultPrompt.Contains([string][char]0xF007)) -Message 'prompt padrao nao mostra icone de usuario'
    Assert-True -Condition (-not $defaultPrompt.Contains([string][char]0xF126)) -Message 'prompt padrao nao mostra icone de git'

    $debian = Get-SshTheme debian
    Assert-Equal -Expected 'DEBIAN' -Actual $debian.BadgeText -Message 'badge do Debian'
    Assert-True -Condition ($debian.Icon.Length -gt 0) -Message 'tema tem icone'

    $custom = Set-SshTheme -Name debian -Accent '#123456' -BadgeIcon 'D' -PromptColors @{ path = '#00FF00' } -PassThru
    Assert-Equal -Expected '#123456' -Actual $custom.Accent -Message 'Set-SshTheme troca o hex'
    Assert-Equal -Expected 'D' -Actual $custom.Icon -Message 'Set-SshTheme troca o icone'
    Assert-Equal -Expected '#00FF00' -Actual $custom.Prompt.path -Message 'Set-SshTheme troca cor do path'
    Assert-True -Condition $custom.IsCustom -Message 'tema marcado como customizado'

    Reload-SshConfig | Out-Null
    $persisted = Get-SshTheme debian
    Assert-Equal -Expected '#123456' -Actual $persisted.Accent -Message 'override persiste apos reload'
    Assert-Equal -Expected '#D70A53' -Actual $persisted.Accent2 -Message 'campos nao sobrescritos continuam do padrao'

    Set-SshTheme -Name debian -Reset
    Assert-Equal -Expected '#A81D33' -Actual (Get-SshTheme debian).Accent -Message 'Reset restaura o padrao'
    Assert-True -Condition (-not (Get-SshTheme debian).IsCustom) -Message 'Reset limpa a flag custom'

    $emoji = [char]::ConvertFromUtf32(0x1F680)
    New-SshTheme -Name 'meu-tema' -Label 'Meu Tema' -Accent '#ABCDEF' -Icon $emoji -Detect @{ hostPatterns = @('^meu') } | Out-Null
    $mine = Get-SshTheme meu-tema
    Assert-Equal -Expected $emoji -Actual $mine.Icon -Message 'tema custom aceita emoji'
    $match = & $module { Get-SshTypeFromInfo -Info @{ Target = 'meu-host'; HostName = 'meu-host'; OsId = ''; OsLike = @(); Uname = '' } }
    Assert-Equal -Expected 'meu-tema' -Actual $match.Type -Message 'tema custom participa da deteccao'
    Remove-SshTheme -Name meu-tema -Force
    Assert-True -Condition (-not (& $module { (Get-SshThemeCatalog).Contains('meu-tema') })) -Message 'Remove-SshTheme remove tema custom'

    # -------------------------------------------------------------- detection
    $detectCases = @(
        @{ Name = 'debian'; Info = @{ Target = 'srv'; HostName = 'srv'; OsId = 'debian'; OsLike = @(); Uname = 'Linux' }; Expected = 'debian' },
        @{ Name = 'ubuntu'; Info = @{ Target = 'srv'; HostName = 'srv'; OsId = 'ubuntu'; OsLike = @('debian'); Uname = 'Linux' }; Expected = 'ubuntu' },
        @{ Name = 'amazon linux'; Info = @{ Target = 'srv'; HostName = 'srv'; OsId = 'amzn'; OsLike = @('fedora'); Uname = 'Linux' }; Expected = 'amazon' },
        @{ Name = 'alpine'; Info = @{ Target = 'srv'; HostName = 'srv'; OsId = 'alpine'; OsLike = @(); Uname = 'Linux' }; Expected = 'alpine' },
        @{ Name = 's3 endpoint'; Info = @{ Target = 'bucket.s3.amazonaws.com'; HostName = 'bucket.s3.amazonaws.com'; OsId = ''; OsLike = @(); Uname = '' }; Expected = 's3' },
        @{ Name = 'ec2 host'; Info = @{ Target = 'ec2-1-2-3-4.compute-1.amazonaws.com'; HostName = 'ec2-1-2-3-4.compute-1.amazonaws.com'; OsId = ''; OsLike = @(); Uname = '' }; Expected = 'aws' },
        @{ Name = 'windows'; Info = @{ Target = 'winbox'; HostName = 'winbox'; OsId = ''; OsLike = @(); Uname = 'Windows_NT' }; Expected = 'windows' },
        @{ Name = 'desconhecido'; Info = @{ Target = '10.0.0.9'; HostName = '10.0.0.9'; OsId = ''; OsLike = @(); Uname = '' }; Expected = 'generic' }
    )
    foreach ($case in $detectCases) {
        $result = & $module { param($info) Get-SshTypeFromInfo -Info $info } $case.Info
        Assert-Equal -Expected $case.Expected -Actual $result.Type -Message ("deteccao: " + $case.Name)
    }

    $s3Type = Resolve-SshDeviceType -Target 's3://bucket/prefix'
    Assert-Equal -Expected 's3' -Actual $s3Type.Type -Message 'Resolve-SshDeviceType detecta s3://'
    $forced = Resolve-SshDeviceType -Target 'qualquer-host' -Type debian -NoProbe
    Assert-Equal -Expected 'debian' -Actual $forced.Type -Message 'tipo explicito vence a deteccao'

    # ---------------------------------------------------------------- targets
    $parsed = & $module { Split-SshTarget -Target 'root@10.0.0.5:2222' }
    Assert-Equal -Expected 'root' -Actual $parsed.User -Message 'parse user@host:port'
    Assert-Equal -Expected '10.0.0.5' -Actual $parsed.HostName -Message 'parse host'
    Assert-Equal -Expected '2222' -Actual $parsed.Port -Message 'parse porta'
    $parsedS3 = & $module { Split-SshTarget -Target 's3://meu-bucket/pasta/sub' }
    Assert-True -Condition $parsedS3.IsS3 -Message 'parse s3://'
    Assert-Equal -Expected 'meu-bucket' -Actual $parsedS3.Bucket -Message 'parse bucket'
    Assert-Equal -Expected 'pasta/sub' -Actual $parsedS3.Prefix -Message 'parse prefixo s3'

    Register-SshDevice -Name 'lab01' -HostName '10.10.10.10' -User 'admin' -Port 2200 -Type debian -Label 'Lab 01'
    $devices = @(Get-SshDevice)
    Assert-Equal -Expected 1 -Actual $devices.Count -Message 'Register-SshDevice grava um dispositivo'
    Assert-Equal -Expected '10.10.10.10' -Actual $devices[0].HostName -Message 'host do dispositivo'
    Assert-Equal -Expected 'debian' -Actual $devices[0].Type -Message 'tipo do dispositivo'
    $resolved = & $module { param($t) Resolve-SshTarget -Target $t } 'lab01'
    Assert-Equal -Expected 'admin@10.10.10.10' -Actual $resolved.SshTarget -Message 'alias resolve para user@host'
    Assert-Equal -Expected '2200' -Actual $resolved.Port -Message 'alias resolve porta'
    Remove-SshDevice -Name 'lab01' -Force
    Assert-Equal -Expected 0 -Actual @(Get-SshDevice).Count -Message 'Remove-SshDevice apaga'

    # --------------------------------------------------------------- rendering
    Assert-Equal -Expected '128 ms' -Actual (& $module { param($s) Format-SshDuration -Duration ([timespan]::FromMilliseconds(128)) -Settings $s } (Get-SshSetting)) -Message 'duracao em ms'
    Assert-Equal -Expected '1.50 s' -Actual (& $module { param($s) Format-SshDuration -Duration ([timespan]::FromMilliseconds(1500)) -Settings $s } (Get-SshSetting)) -Message 'duracao em segundos'
    Assert-Equal -Expected '1m 05s' -Actual (& $module { param($s) Format-SshDuration -Duration ([timespan]::FromSeconds(65)) -Settings $s } (Get-SshSetting)) -Message 'duracao em minutos'
    Assert-Equal -Expected '1h 02m' -Actual (& $module { param($s) Format-SshDuration -Duration ([timespan]::FromMinutes(62)) -Settings $s } (Get-SshSetting)) -Message 'duracao em horas'

    $homePath = Join-Path (Join-Path $HOME 'projetos') 'app'
    $settings = Get-SshSetting
    $formattedHome = & $module { param($p, $s) Format-SshPath -Path $p -Settings $s -NoIcons } $homePath $settings
    Assert-Match -Pattern '^~/' -Text $formattedHome -Message 'path usa ~ para o home'
    Assert-Match -Pattern 'projetos/app$' -Text $formattedHome -Message 'path termina no projeto'

    $deepPath = Join-Path (Join-Path (Join-Path (Join-Path $HOME 'a') 'b') 'c') 'd'
    $deepSettings = & $module { param($s) Copy-SshDeep -InputObject $s } $settings
    $deepSettings['path']['maxSegments'] = 2
    $shortPath = & $module { param($p, $s) Format-SshPath -Path $p -Settings $s -NoIcons } $deepPath $deepSettings
    Assert-True -Condition ($shortPath.Length -lt 20) -Message 'path smart encurta segmentos'
    Assert-Match -Pattern 'c/d$' -Text $shortPath -Message 'path smart preserva os ultimos segmentos'
    $leafPath = & $module { param($p, $s) Format-SshPath -Path $p -Settings $s -NoIcons } $deepPath (@{ path = @{ style = 'leaf'; icons = $false } })
    Assert-Equal -Expected 'd' -Actual $leafPath -Message 'path estilo leaf'

    $prompt = & $module {
        param($theme, $s)
        Format-SshPromptText -Theme $theme -Settings $s -Path 'C:\tmp\app' -DeviceLabel 'DEBIAN' -UserName 'root' -HostName 'srv01' -Duration ([timespan]::FromMilliseconds(128)) -ExitCode 0 -Success $true -Plain -NoIcons
    } (Get-SshTheme debian) $settings
    Assert-True -Condition ($prompt -cnotmatch 'DEBIAN') -Message 'prompt padrao nao mostra o nome da distro'
    Assert-Match -Pattern 'root' -Text $prompt -Message 'prompt mostra o usuario'
    Assert-Match -Pattern 'srv01' -Text $prompt -Message 'prompt mostra o host'
    Assert-Match -Pattern 'root@srv01' -Text $prompt -Message 'prompt junta usuario e host'
    Assert-Match -Pattern '128 ms' -Text $prompt -Message 'prompt mostra a duracao'
    Assert-Match -Pattern ([regex]::Escape([string][char]0x276F)) -Text $prompt -Message 'prompt tem segunda linha com seta'

    $cleanPrompt = & $module {
        param($theme, $s)
        Format-SshPromptText -Theme $theme -Settings $s -Path 'C:\tmp\app' -DeviceLabel 'DEBIAN' -UserName 'root' -HostName 'srv01' -Duration ([timespan]::FromMilliseconds(128)) -ExitCode 0 -Success $true -Plain
    } (Get-SshTheme debian) $settings
    $iconCodePoints = @(0x1F552, 0x1F4C1, 0x2713, 0x23F1, 0x1F300, 0x1F464, 0x1F5A5)
    $hasIcon = $false
    foreach ($codePoint in $iconCodePoints) {
        if ($cleanPrompt.Contains([char]::ConvertFromUtf32($codePoint))) { $hasIcon = $true }
    }
    Assert-True -Condition (-not $hasIcon) -Message 'prompt padrao nao tem emojis'
    Assert-True -Condition ($cleanPrompt.Contains([string][char]0xF306)) -Message 'prompt usa o icone Nerd Font do Debian'
    Assert-True -Condition ($cleanPrompt -cnotmatch 'DEBIAN') -Message 'prompt com icones nao mostra o nome da distro'
    Assert-True -Condition ($cleanPrompt -notmatch '\d\d:\d\d') -Message 'prompt padrao nao mostra relogio'
    Assert-Equal -Expected '1' -Actual ([regex]::Matches($cleanPrompt, [regex]::Escape('srv01')).Count) -Message 'prompt nao repete o host'

    $failPrompt = & $module {
        param($theme, $s)
        Format-SshPromptText -Theme $theme -Settings $s -Path 'C:\tmp' -DeviceLabel 'DEBIAN' -UserName 'root' -HostName 'srv01' -Duration ([timespan]::FromMilliseconds(8000)) -ExitCode 2 -Success $false -Plain -NoIcons
    } (Get-SshTheme debian) $settings
    Assert-Match -Pattern 'exit 2' -Text $failPrompt -Message 'prompt mostra falha e codigo'
    Assert-Match -Pattern '8.00 s' -Text $failPrompt -Message 'prompt mostra comandos lentos'

    $hiddenSettings = & $module { param($s) Copy-SshDeep -InputObject $s } $settings
    $hiddenSettings['show']['duration'] = $false
    $hiddenSettings['show']['clock'] = $false
    $hidden = & $module {
        param($theme, $s)
        Format-SshPromptText -Theme $theme -Settings $s -Path 'C:\tmp' -DeviceLabel 'DEBIAN' -UserName 'root' -HostName 'srv01' -Duration ([timespan]::FromMilliseconds(128)) -Plain -NoIcons -NoArrow
    } (Get-SshTheme debian) $hiddenSettings
    Assert-True -Condition ($hidden -notmatch '128 ms') -Message 'configuracao esconde a duracao'
    Assert-True -Condition ($hidden -notmatch '\d\d:\d\d') -Message 'configuracao esconde o relogio'

    $banner = & $module {
        param($theme, $s)
        Format-SshBanner -Theme $theme -Settings $s -Resolved ([pscustomobject]@{ SshTarget = 'root@srv01'; HostName = 'srv01'; Port = 22; User = 'root'; Label = 'srv01'; IsS3 = $false }) -TypeResult ([pscustomobject]@{ Info = @{ OsName = 'Debian GNU/Linux' } })
    } (Get-SshTheme debian) $settings
    $bannerText = (& $module { param($lines) @($lines | ForEach-Object { Remove-SshAnsi $_ }) } $banner) -join "`n"
    Assert-True -Condition ($bannerText.Contains([string][char]0xF306)) -Message 'banner usa o icone do tema'
    Assert-True -Condition ($bannerText -cnotmatch 'DEBIAN') -Message 'banner nao mostra o nome da distro'
    Assert-Match -Pattern 'root@srv01' -Text $bannerText -Message 'banner mostra destino'
    Assert-Match -Pattern 'Debian GNU/Linux' -Text $bannerText -Message 'banner mostra o sistema'
    Assert-Match -Pattern 'destino' -Text $bannerText -Message 'banner tem rotulos'
    Assert-True -Condition (-not $bannerText.Contains([char]::ConvertFromUtf32(0x1F300))) -Message 'banner sem emoji por padrao'

    $bannerWidth = & $module { param($line) Get-SshDisplayWidth -Text (Remove-SshAnsi $line) } $banner[0]
    Assert-True -Condition ($bannerWidth -ge 44 -and $bannerWidth -le 68) -Message 'banner respeita a largura configurada'

    $oldNoAnsiSession = $env:SSHTHEMES_NO_ANSI
    $env:SSHTHEMES_NO_ANSI = '1'
    $sessionState = & $module {
        param($theme, $s)
        $session = [pscustomobject]@{ Kind = 'ssh'; Theme = 'debian'; Label = 'srv01'; User = 'root'; HostName = 'srv01'; HostLabel = 'srv01'; StartedAt = Get-Date }
        $started = Start-SshSession -Session $session -Theme $theme -Settings $s
        $ok = ($null -ne $started.PSObject.Properties['TerminalState'])
        Stop-SshSession | Out-Null
        return $ok
    } (Get-SshTheme debian) $settings
    Assert-True -Condition $sessionState -Message 'sessao aceita TerminalState mesmo sem a propriedade'
    $env:SSHTHEMES_NO_ANSI = $oldNoAnsiSession

    # ---------------------------------------------------------------- terminal
    $oldNoColor = $env:NO_COLOR
    $env:NO_COLOR = '1'
    Assert-True -Condition (-not (& $module { Test-SshAnsiTerminal })) -Message 'NO_COLOR desliga ANSI'
    $env:NO_COLOR = $oldNoColor

    $oldNoAnsi = $env:SSHTHEMES_NO_ANSI
    $env:SSHTHEMES_NO_ANSI = '1'
    $state = & $module { param($theme, $s) Set-SshTerminalAppearance -Theme $theme -Settings $s -Title 'teste' } (Get-SshTheme debian) $settings
    Assert-True -Condition (-not $state.Applied) -Message 'sem ANSI nao aplica tema no terminal'
    & $module { param($s) Restore-SshTerminalAppearance -State $s } $state
    $env:SSHTHEMES_NO_ANSI = $oldNoAnsi

    Assert-True -Condition (& $module { param($t, $s) Test-SshTerminalFull -Theme $t -Settings $s } (Get-SshTheme debian) @{ terminal = @{ mode = 'auto' } }) -Message 'auto pinta o terminal quando o tema tem fundo'
    Assert-True -Condition (-not (& $module { param($t, $s) Test-SshTerminalFull -Theme $t -Settings $s } (Get-SshTheme s3) @{ terminal = @{ mode = 'auto' } })) -Message 'auto mantem S3 so no texto'
    Assert-True -Condition (-not (& $module { param($t, $s) Test-SshTerminalFull -Theme $t -Settings $s } (Get-SshTheme debian) @{ terminal = @{ mode = 'text' } })) -Message 'modo text ignora o fundo do tema'
    Assert-True -Condition (& $module { param($t, $s) Test-SshTerminalFull -Theme $t -Settings $s } (Get-SshTheme s3) @{ terminal = @{ mode = 'full' } }) -Message 'modo full pinta mesmo sem fundo definido'

    # ---------------------------------------------------------------- settings
    Set-SshSetting -DurationWarnMs 500 -Show @{ clock = $false } -PathStyle leaf -MaxPathSegments 2 | Out-Null
    Assert-Equal -Expected '500' -Actual (Get-SshSetting 'duration.warnMs') -Message 'Set-SshSetting altera duracao'
    Assert-Equal -Expected 'False' -Actual (Get-SshSetting 'show.clock') -Message 'Set-SshSetting altera show'
    Assert-Equal -Expected 'leaf' -Actual (Get-SshSetting 'path.style') -Message 'Set-SshSetting altera path'
    Set-SshSetting -DetectStrictHostKeys $true -TerminalMode text | Out-Null
    Assert-Equal -Expected 'True' -Actual (Get-SshSetting 'detect.strictHostKeys') -Message 'Set-SshSetting liga strictHostKeys'
    Assert-Equal -Expected 'text' -Actual (Get-SshSetting 'terminal.mode') -Message 'Set-SshSetting altera o modo do terminal'
    Set-SshSetting -TerminalResetOnExit $false | Out-Null
    Assert-Equal -Expected 'False' -Actual (Get-SshSetting 'terminal.resetOnExit') -Message 'Set-SshSetting controla a restauracao ao sair'
    Set-SshSetting -PromptIcons $true | Out-Null
    Assert-Equal -Expected 'True' -Actual (Get-SshSetting 'prompt.icons') -Message 'Set-SshSetting liga os icones do prompt'
    Set-SshSetting -IconParts @{ path = $true } | Out-Null
    Assert-Equal -Expected 'True' -Actual (Get-SshSetting 'prompt.iconParts.path') -Message 'Set-SshSetting liga o icone da pasta'
    Set-SshSetting -IconParts @{ path = $false } | Out-Null
    Assert-Equal -Expected 'False' -Actual (Get-SshSetting 'prompt.iconParts.path') -Message 'Set-SshSetting desliga o icone da pasta'
    Set-SshSetting -RemoteAutoTheme $false | Out-Null
    Assert-Equal -Expected 'False' -Actual (Get-SshSetting 'remote.auto') -Message 'Set-SshSetting desliga o tema remoto automatico'
    $iconsOnSettings = Get-SshSetting
    $iconsPrompt = & $module {
        param($theme, $s)
        Format-SshPromptText -Theme $theme -Settings $s -Path 'C:\tmp' -DeviceLabel 'DEBIAN' -UserName 'root' -HostName 'srv01' -Duration ([timespan]::FromMilliseconds(128)) -Plain
    } (Get-SshTheme debian) $iconsOnSettings
    Assert-True -Condition ($iconsPrompt.Contains([string][char]0xF306)) -Message 'PromptIcons traz os icones de volta'
    Set-SshSetting -Reset
    Assert-Equal -Expected 'False' -Actual (Get-SshSetting 'show.clock') -Message 'Reset restaura settings'
    Assert-Equal -Expected 'smart' -Actual (Get-SshSetting 'path.style') -Message 'Reset restaura path'
    Assert-Equal -Expected 'False' -Actual (Get-SshSetting 'detect.strictHostKeys') -Message 'Reset desliga strictHostKeys'
    Assert-Equal -Expected 'auto' -Actual (Get-SshSetting 'terminal.mode') -Message 'Reset volta ao modo auto'
    Assert-Equal -Expected 'True' -Actual (Get-SshSetting 'terminal.resetOnExit') -Message 'Reset volta a restaurar ao sair'
    Assert-Equal -Expected 'True' -Actual (Get-SshSetting 'prompt.icons') -Message 'Reset volta ao prompt com icones'
    Assert-Equal -Expected 'False' -Actual (Get-SshSetting 'prompt.deviceName') -Message 'Reset volta a esconder o nome da distro'
    Assert-Equal -Expected 'True' -Actual (Get-SshSetting 'remote.auto') -Message 'Reset religa o tema remoto automatico'

    Disable-SshThemePrompt 6>$null
    Assert-True -Condition (-not (& $module { Test-SshPromptEnabled })) -Message 'Disable desativa o prompt'
    Enable-SshThemePrompt 6>$null
    Assert-True -Condition (& $module { Test-SshPromptEnabled }) -Message 'Enable reativa o prompt'

    # -------------------------------------------------------------------- s3
    $s3Preview = Start-AwsWorkspace -Target 's3://demo-bucket/backups' -DryRun -NoBanner -PassThru
    Assert-Equal -Expected 's3' -Actual $s3Preview.Kind -Message 'workspace S3 dry-run'
    Assert-Equal -Expected 's3://demo-bucket/backups' -Actual $s3Preview.Uri -Message 'workspace monta a URI'
    Assert-True -Condition $s3Preview.DryRun -Message 'workspace dry-run nao inicia sessao'
    $s3Bucket = Start-AwsWorkspace -Bucket 'demo-bucket' -Prefix 'backups/2026' -DryRun -NoBanner -PassThru
    Assert-Equal -Expected 's3://demo-bucket/backups/2026' -Actual $s3Bucket.Uri -Message 'workspace aceita -Bucket e -Prefix'
    Start-AwsWorkspace -Bucket 'demo-bucket' -Prefix 'backups/2026' -NoBanner 6>$null | Out-Null
    $s3Session = Get-SshSession
    Assert-Equal -Expected 's3' -Actual $s3Session.Kind -Message 'sessao S3 ativa'
    Assert-Equal -Expected 'demo-bucket' -Actual $s3Session.Bucket -Message 'sessao S3 expoe o bucket'
    Assert-Equal -Expected 'backups/2026' -Actual $s3Session.Prefix -Message 'sessao S3 expoe o prefixo'
    Exit-SshDevice 6>$null | Out-Null
    Assert-True -Condition (-not (Get-SshSession).Active) -Message 'exitssh encerra a sessao S3'
    Assert-True -Condition ($null -eq (Get-SshSession).Active -or -not (Get-SshSession).Active) -Message 'dry-run nao deixa sessao ativa'

    $sshPreview = Connect-SshDevice -Target 'debian-host' -Type debian -DryRun -NoBanner -PassThru
    Assert-Equal -Expected 'debian' -Actual $sshPreview.Type -Message 'ssh dry-run usa tipo explicito'
    Assert-True -Condition $sshPreview.DryRun -Message 'ssh dry-run retorna DryRun'

    # ----------------------------------------------------------------- remote
    $remoteScript = Get-SshRemoteThemeScript -Type debian -Settings $settings
    Assert-Match -Pattern '__ssht_prompt' -Text $remoteScript -Message 'script remoto define o prompt'
    Assert-Match -Pattern 'PROMPT_COMMAND' -Text $remoteScript -Message 'script remoto instala PROMPT_COMMAND'
    Assert-Match -Pattern '\\u' -Text $remoteScript -Message 'script remoto usa usuario do bash'
    Assert-Match -Pattern '38;2;168;29;51' -Text $remoteScript -Message 'script remoto usa o hex do Debian'
    Assert-True -Condition ($remoteScript.Contains([string][char]0xF306)) -Message 'script remoto usa o icone Nerd Font do Debian'
    Assert-True -Condition ($remoteScript -cnotmatch 'DEBIAN') -Message 'script remoto nao mostra o nome da distro'
    Assert-True -Condition (-not $remoteScript.Contains([char]::ConvertFromUtf32(0x1F300))) -Message 'script remoto sem emoji por padrao'
    Assert-True -Condition (-not $remoteScript.Contains('__DEVICE__')) -Message 'script remoto nao deixa placeholder'
    Assert-True -Condition (& $module { Test-SshRemoteThemeSupported -Type 's3' }) -Message 'tema remoto aceita s3'
    Assert-True -Condition (& $module { Test-SshRemoteThemeSupported -Type 'aws' }) -Message 'tema remoto aceita aws'
    Assert-True -Condition (-not (& $module { Test-SshRemoteThemeSupported -Type 'windows' })) -Message 'tema remoto ignora windows'
    Assert-True -Condition (-not (& $module { Test-SshRemoteThemeSupported -Type 'generic' })) -Message 'tema remoto ignora generic'
    $remoteS3 = Get-SshRemoteThemeScript -Type s3 -Settings $settings
    Assert-Match -Pattern 'AWS S3' -Text $remoteS3 -Message 'script remoto do s3 usa o tema S3'
    Assert-True -Condition ($remoteS3.Contains([string][char]0xF1C0)) -Message 'script remoto do s3 usa o icone de banco'

    # ------------------------------------------------------------------ fonts
    $fontInfo = & $module { Get-SshNerdFontInfo }
    Assert-Equal -Expected 'JetBrainsMono Nerd Font' -Actual $fontInfo.Name -Message 'fonte padrao definida'
    Assert-Match -Pattern '^https://raw\.githubusercontent\.com/.+\.ttf$' -Text $fontInfo.Url -Message 'fonte tem URL de download'
    Assert-Match -Pattern 'Open Font License' -Text $fontInfo.License -Message 'fonte usa licenca livre'
    $fontList = @(Get-SshNerdFont)
    Assert-True -Condition ($fontList -is [array]) -Message 'Get-SshNerdFont retorna lista'
    $isNerd = Test-SshNerdFont
    Assert-True -Condition ($isNerd -is [bool]) -Message 'Test-SshNerdFont retorna booleano'
    $fontDry = Set-SshTerminalFont -Name 'Test Nerd Font' -DryRun -PassThru
    if ($fontDry) {
        Assert-True -Condition $fontDry.DryRun -Message 'Set-SshTerminalFont dry-run nao grava'
        Assert-Equal -Expected 'Test Nerd Font' -Actual $fontDry.Face -Message 'Set-SshTerminalFont usa a fonte pedida'
    }
    $fontResetDry = Set-SshTerminalFont -Reset -DryRun -PassThru
    if ($fontResetDry) {
        Assert-True -Condition $fontResetDry.Reset -Message 'Set-SshTerminalFont -Reset dry-run'
    }

    # ------------------------------------------------------- uninstaller font
    $uninstallPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Uninstall.ps1'
    $uninstallTokens = $null
    $uninstallErrors = $null
    $uninstallAst = [System.Management.Automation.Language.Parser]::ParseFile($uninstallPath, [ref]$uninstallTokens, [ref]$uninstallErrors)
    $uninstallFuncs = $uninstallAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
    foreach ($func in $uninstallFuncs) { . ([scriptblock]::Create($func.Extent.Text)) }

    $fontSettings = Join-Path $testHome 'wt-settings.json'
    '{"profiles":{"defaults":{"font":{"face":"0xProto Nerd Font"}}}}' | Set-Content -LiteralPath $fontSettings -Encoding UTF8
    '{"profiles":{"defaults":{}}}' | Set-Content -LiteralPath ($fontSettings + '.sshthemes.bak') -Encoding UTF8
    Restore-SshThemesTerminalFont -Path $fontSettings 6>$null
    $fontAfter = Get-Content -LiteralPath $fontSettings -Raw | ConvertFrom-Json
    Assert-True -Condition ($null -eq $fontAfter.profiles.defaults.font) -Message 'desinstalador remove a fonte Nerd'

    '{"profiles":{"defaults":{"font":{"face":"0xProto Nerd Font"}}}}' | Set-Content -LiteralPath $fontSettings -Encoding UTF8
    '{"profiles":{"defaults":{"font":{"face":"Cascadia Mono"}}}}' | Set-Content -LiteralPath ($fontSettings + '.sshthemes.bak') -Encoding UTF8
    Restore-SshThemesTerminalFont -Path $fontSettings 6>$null
    $fontAfter = Get-Content -LiteralPath $fontSettings -Raw | ConvertFrom-Json
    Assert-Equal -Expected 'Cascadia Mono' -Actual $fontAfter.profiles.defaults.font.face -Message 'desinstalador restaura a fonte anterior'

    '{"profiles":{"defaults":{"font":{"face":"0xProto Nerd Font"}}}}' | Set-Content -LiteralPath $fontSettings -Encoding UTF8
    Restore-SshThemesTerminalFont -Path $fontSettings -Face 'Consolas' 6>$null
    $fontAfter = Get-Content -LiteralPath $fontSettings -Raw | ConvertFrom-Json
    Assert-Equal -Expected 'Consolas' -Actual $fontAfter.profiles.defaults.font.face -Message 'desinstalador aceita -DefaultFont'

    # ------------------------------------------------------------- dash commands
    Invoke-SshIconsCommand 'path' 'on' 6>$null
    Assert-Equal -Expected 'True' -Actual (Get-SshSetting 'prompt.iconParts.path') -Message '-icons path on'
    Invoke-SshIconsCommand 'reset' 6>$null
    Assert-Equal -Expected 'False' -Actual (Get-SshSetting 'prompt.iconParts.path') -Message '-icons reset'
    Invoke-SshColorCommand 'debian' 'accent' 'E95420' 6>$null
    Assert-Equal -Expected '#E95420' -Actual (Get-SshTheme debian).Accent -Message '-color aceita hex sem #'
    Invoke-SshColorCommand 'reset' 'debian' 6>$null
    Assert-Equal -Expected '#A81D33' -Actual (Get-SshTheme debian).Accent -Message '-color reset'
    Invoke-SshDistrosCommand 'set' 'debian' 6>$null
    Assert-Equal -Expected 'debian' -Actual (Get-SshSetting 'defaultTheme') -Message '-distros set'
    Invoke-SshDistrosCommand 6>$null
    Assert-True -Condition $true -Message '-distros lista sem erro'

    # ---------------------------------------------------------------- background
    Invoke-SshBackgroundCommand 'debian' 'off' 6>$null
    Assert-True -Condition ($null -eq (Get-SshTheme debian).Background) -Message '-bg debian off remove o fundo'
    Invoke-SshBackgroundCommand 'debian' '123456' 6>$null
    Assert-Equal -Expected '#123456' -Actual (Get-SshTheme debian).Background -Message '-bg debian <hex> define o fundo'
    Invoke-SshBackgroundCommand 'debian' 'reset' 6>$null
    Assert-Equal -Expected '#1B0A0F' -Actual (Get-SshTheme debian).Background -Message '-bg debian reset volta ao padrao'
    Invoke-SshBackgroundCommand 'off' 6>$null
    Assert-Equal -Expected 'text' -Actual (Get-SshSetting 'terminal.mode') -Message '-bg off desliga o fundo do terminal'
    Invoke-SshBackgroundCommand 'auto' 6>$null
    Assert-Equal -Expected 'auto' -Actual (Get-SshSetting 'terminal.mode') -Message '-bg auto volta ao modo auto'

    # ----------------------------------------------------------------- set / get
    Invoke-SshSetCommand 'theme' 'debian' 'prompt.path' '#FFFFFF' 6>$null
    Assert-Equal -Expected '#FFFFFF' -Actual (Get-SshThemeValue -Name debian -Path 'prompt.path') -Message '-set theme altera campo aninhado'
    Invoke-SshSetCommand 'setting' 'terminal.mode' 'text' 6>$null
    Assert-Equal -Expected 'text' -Actual (Get-SshSetting 'terminal.mode') -Message '-set setting altera configuracao'
    Invoke-SshSetCommand 'prompt.separator' '|' 6>$null
    Assert-Equal -Expected '|' -Actual (Get-SshSetting 'prompt.separator') -Message '-set <caminho> <valor> atalho'
    Invoke-SshSetCommand 'device' 'lab02' 'label' 'Lab 02' 6>$null
    Assert-Equal -Expected 'Lab 02' -Actual (Get-SshDevice lab02).Label -Message '-set device altera campo do dispositivo'
    Remove-SshDevice -Name lab02 -Force
    Invoke-SshResetCommand 'theme' 'debian' 6>$null
    Assert-Equal -Expected '#A81D33' -Actual (Get-SshTheme debian).Accent -Message '-reset theme restaura o tema'
    Invoke-SshResetCommand 'settings' 6>$null
    Assert-Equal -Expected 'auto' -Actual (Get-SshSetting 'terminal.mode') -Message '-reset settings restaura configuracoes'
    Invoke-SshGetCommand 'setting' 'terminal.mode' 6>$null
    Assert-True -Condition $true -Message '-get setting nao lanca excecao'
    Invoke-SshGetCommand 'theme' 'debian' 'prompt.path' 6>$null
    Assert-True -Condition $true -Message '-get theme nao lanca excecao'
    Show-SshHelp 6>$null
    Assert-True -Condition $true -Message '-help nao lanca excecao'

    # -------------------------------------------------------------------- locks
    Invoke-SshLockCommand '10.9.9.9' 'ubuntu' 6>$null
    $locks = @(Get-SshDeviceLocks)
    Assert-Equal -Expected 1 -Actual $locks.Count -Message '-lock grava o lock'
    Assert-Equal -Expected 'ubuntu' -Actual $locks[0].Type -Message '-lock usa o tema pedido'
    $lockedDevice = Get-SshDevice '10.9.9.9'
    Assert-True -Condition $lockedDevice.Locked -Message '-lock marca o dispositivo'
    $lockedType = Resolve-SshDeviceType -Target '10.9.9.9' -NoProbe
    Assert-Equal -Expected 'ubuntu' -Actual $lockedType.Type -Message 'lock vence a deteccao'
    Assert-Equal -Expected 'lock' -Actual $lockedType.Source -Message 'origem do tipo e lock'
    Invoke-SshLockCommand '10.9.9.9' 6>$null
    Invoke-SshUnlockCommand '10.9.9.9' 6>$null
    Assert-Equal -Expected 0 -Actual (@(Get-SshDeviceLocks)).Count -Message '-unlock remove o lock'
    Remove-SshDevice -Name '10.9.9.9' -Force

    Register-SshDevice -Name 'locked01' -HostName '10.9.9.8' -Type debian
    Set-SshDeviceLock -Target 'locked01' -Type alpine
    $lockedAlias = Resolve-SshDeviceType -Target 'locked01' -NoProbe
    Assert-Equal -Expected 'alpine' -Actual $lockedAlias.Type -Message 'lock por alias vence o tipo salvo'
    Remove-SshDeviceLock -Target 'locked01'
    Remove-SshDevice -Name 'locked01' -Force

    Register-SshDevice -Name 'lockip01' -HostName '10.9.9.7' -Type debian
    Set-SshDeviceLock -Target '10.9.9.7' -Type ubuntu
    $lockedByIp = Resolve-SshDeviceType -Target 'lockip01' -NoProbe
    Assert-Equal -Expected 'ubuntu' -Actual $lockedByIp.Type -Message 'lock por IP vale para o alias registrado'
    Assert-Equal -Expected 1 -Actual (@(Get-SshDeviceLocks)).Count -Message 'lock por IP nao duplica o registro'
    Remove-SshDeviceLock -Target '10.9.9.7'
    Remove-SshDevice -Name 'lockip01' -Force

    Register-SshDevice -Name 'reg01' -HostName '10.9.9.6' -Type alpine
    $registered = Resolve-SshDeviceType -Target 'reg01' -NoProbe
    Assert-Equal -Expected 'alpine' -Actual $registered.Type -Message 'tipo registrado vence a deteccao'
    Assert-Equal -Expected 'device' -Actual $registered.Source -Message 'origem do tipo e device'
    $refreshed = Resolve-SshDeviceType -Target 'reg01' -NoProbe -Refresh
    Assert-Equal -Expected 'generic' -Actual $refreshed.Type -Message '-Refresh ignora o tipo registrado'
    Remove-SshDevice -Name 'reg01' -Force

    # ------------------------------------------------------------ ssh pass-through
    Assert-Equal -Expected '2222' -Actual (& $module { Get-SshArgumentValue -Arguments @('-X', '-p', '2222', '-l', 'root') -Names @('-p') }) -Message 'le -p das flags nativas'
    Assert-True -Condition (& $module { Test-SshArgumentPresent -Arguments @('-L', '8080:localhost:80') -Names @('-L') }) -Message 'detecta -L nas flags nativas'
    $passThrough = Connect-SshDevice -Target 'debian-host' -Type debian -DryRun -NoBanner -PassThru -SshArgument @('-X', '-L', '8080:localhost:80')
    Assert-True -Condition $passThrough.DryRun -Message 'flags nativas nao quebram o dry-run'
    Assert-True -Condition ($null -eq (& $module { Get-SshArgumentValue -Arguments @('-L', '8080:localhost:80') -Names @('-l') })) -Message 'flags ssh sao case-sensitive'

    $nativeDry = sshx -X debian-host -DryRun -NoBanner -PassThru
    Assert-True -Condition ($nativeDry.DryRun) -Message 'sshx encaminha -X'
    $nativeLogin = sshx -l root -p 2222 debian-host -DryRun -NoBanner -PassThru
    Assert-Equal -Expected 'root' -Actual $nativeLogin.Resolved.User -Message 'sshx le -l'
    Assert-Equal -Expected '2222' -Actual $nativeLogin.Resolved.Port -Message 'sshx le -p'
    $nativeForward = sshx debian-host -L 8080:localhost:80 -DryRun -NoBanner -PassThru
    Assert-True -Condition ([string]::IsNullOrEmpty($nativeForward.Resolved.User)) -Message 'sshx nao confunde -L com -l'
    $s3Wrapper = sshx -S3 s3://demo-bucket/backups -DryRun -NoBanner -PassThru
    Assert-Equal -Expected 's3' -Actual $s3Wrapper.Kind -Message 'sshx -S3 abre workspace'

    # ------------------------------------------------------------------- json
    $json = Get-Content (Join-Path $testHome 'themes.json') -Raw -Encoding UTF8
    Assert-True -Condition ($json -match 'version') -Message 'themes.json e valido'
    $hostsJson = Get-Content (Join-Path $testHome 'hosts.json') -Raw -Encoding UTF8
    Assert-True -Condition ($hostsJson -match 'devices') -Message 'hosts.json e valido'

    Show-SshThemes -NoColor 6>$null
    Show-SshDevices 6>$null
    Preview-SshTheme -Name debian -Plain -Width 60 6>$null
    Assert-True -Condition $true -Message 'comandos de exibicao nao lancam excecao'
}
catch {
    $script:Failed++
    $script:Failures += ('EXCECAO: ' + $_.Exception.Message)
    Write-Host ('  FAIL excecao: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ($_.ScriptStackTrace) -ForegroundColor DarkGray
}
finally {
    Remove-Module SshThemes -Force -ErrorAction SilentlyContinue
    if (-not $Keep) {
        Remove-Item -LiteralPath $testHome -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "Configs preservadas em $testHome" -ForegroundColor DarkGray
    }
    if ($null -eq $previousHome) { Remove-Item Env:\SSHTHEMES_HOME -ErrorAction SilentlyContinue }
    else { $env:SSHTHEMES_HOME = $previousHome }
    if ($null -eq $previousNoAnsi) { Remove-Item Env:\SSHTHEMES_NO_ANSI -ErrorAction SilentlyContinue }
    else { $env:SSHTHEMES_NO_ANSI = $previousNoAnsi }
}

Write-Host ''
Write-Host ('Resultado: ' + $script:Passed + ' passaram, ' + $script:Failed + ' falharam') -ForegroundColor $(if ($script:Failed -eq 0) { 'Green' } else { 'Red' })
if ($script:Failed -gt 0) {
    Write-Host 'Falhas:' -ForegroundColor Red
    foreach ($failure in $script:Failures) { Write-Host ('  - ' + $failure) -ForegroundColor Red }
    exit 1
}
exit 0
