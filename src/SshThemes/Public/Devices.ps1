# Device connection, S3 workspace and the device registry.

function Register-SshDevice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [Parameter(Mandatory)][string]$HostName,
        [string]$User,
        [int]$Port = 0,
        [string]$Type = 'auto',
        [string]$Label,
        [string]$SshAlias,
        [string[]]$Tags,
        [switch]$Force,
        [switch]$PassThru
    )

    if ($Type -and $Type -ne 'auto' -and -not (Get-SshThemeByName -Name $Type -AllowMissing)) {
        throw "Tema/tipo '$Type' nao existe. Use -distros para listar."
    }

    $registry = Get-SshDeviceRegistry
    if ($registry.devices.Contains($Name) -and -not $Force) {
        throw "Dispositivo '$Name' ja registrado. Use -Force para atualizar."
    }

    $entry = @{
        host  = $HostName
        label = if ($Label) { $Label } else { $Name }
    }
    if ($User) { $entry['user'] = $User }
    if ($Port -gt 0) { $entry['port'] = $Port }
    if ($SshAlias) { $entry['sshAlias'] = $SshAlias }
    if ($Tags) { $entry['tags'] = @($Tags) }
    if ($Type -and $Type -ne 'auto') { $entry['type'] = $Type }
    if ($registry.devices.Contains($Name)) {
        $existing = $registry.devices[$Name]
        $entry = Merge-SshDeep -Base $existing -Override $entry
    }
    $registry.devices[$Name] = $entry
    Save-SshDeviceRegistry -Document $registry

    Write-Host "Dispositivo '$Name' registrado ($HostName)." -ForegroundColor DarkGray
    if ($PassThru) { return (Get-SshDevice -Name $Name) }
}

function Get-SshDevice {
    [CmdletBinding()]
    param([Parameter(Position = 0)][string]$Name = '*')

    $registry = Get-SshDeviceRegistry
    $result = @()
    foreach ($key in @($registry.devices.Keys)) {
        if ($Name -match '[\*\?]') {
            if ($key -notlike $Name) { continue }
        }
        elseif ($key -ne $Name) { continue }

        $entry = $registry.devices[$key]
        $lockedType = [string](Get-SshValue $entry 'lockedType' $null)
        $type = Get-SshValue $entry 'type' $null
        if ($lockedType) { $type = $lockedType }
        if (-not $type) { $type = Get-SshValue $entry 'detectedType' 'auto' }
        $result += [pscustomobject]@{
            PSTypeName   = 'SshThemes.Device'
            Name         = $key
            HostName     = [string](Get-SshValue $entry 'host' '')
            User         = [string](Get-SshValue $entry 'user' '')
            Port         = Get-SshValue $entry 'port' $null
            Type         = [string]$type
            Locked       = [bool]($lockedType)
            LockedType   = $lockedType
            LockedAt     = Get-SshValue $entry 'lockedAt' $null
            Label        = [string](Get-SshValue $entry 'label' $key)
            SshAlias     = [string](Get-SshValue $entry 'sshAlias' '')
            Tags         = @(Get-SshValue $entry 'tags' @())
            DetectedAt   = Get-SshValue $entry 'detectedAt' $null
            OsName       = [string](Get-SshValue $entry 'osName' '')
            RemoteHost   = [string](Get-SshValue $entry 'remoteHostname' '')
        }
    }
    return $result
}

function Remove-SshDevice {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [switch]$Force
    )

    $registry = Get-SshDeviceRegistry
    if (-not $registry.devices.Contains($Name)) { throw "Dispositivo '$Name' nao encontrado." }
    if ($Force -or $PSCmdlet.ShouldProcess($Name, 'remover dispositivo')) {
        $registry.devices.Remove($Name)
        Save-SshDeviceRegistry -Document $registry
        Write-Host "Dispositivo '$Name' removido." -ForegroundColor DarkGray
    }
}

function Show-SshDevices {
    [CmdletBinding()]
    param([switch]$PassThru)

    $devices = @(Get-SshDevice)
    $settings = Get-SshSettings
    $useColor = Test-SshAnsiTerminal
    Write-Host ''
    Write-Host "  Dispositivos registrados  $(Get-SshUiChar 'dot')  $($devices.Count)" -ForegroundColor DarkGray
    if ($devices.Count -eq 0) {
        Write-Host '  Nenhum ainda. Use: Register-SshDevice -Name srv01 -HostName 10.0.0.5 -User root -Type debian' -ForegroundColor DarkGray
        Write-Host '  Ou conecte direto: xsshx root@10.0.0.5' -ForegroundColor DarkGray
        Write-Host ''
        if ($PassThru) { return }
        return
    }

    foreach ($device in $devices) {
        $theme = Get-SshThemeByName -Name $device.Type -AllowMissing
        if (-not $theme) { $theme = Get-SshThemeByName -Name 'generic' }
        $icon = Get-SshThemeIcon -Theme $theme -Settings $settings
        $iconPrefix = if ($icon) { $icon + '  ' } else { '' }
        $target = $device.HostName
        if ($device.User) { $target = "$($device.User)@$target" }
        if ($device.Port) { $target = "$target`:$($device.Port)" }
        $name = Pad-SshText $device.Name 18
        $type = Pad-SshText $device.Type 10
        $lockMark = if ($device.Locked) { ' [lock]' } else { '' }
        Write-Host ('  ' + $iconPrefix + $name + $type + $target + $lockMark)
    }
    Write-Host ''
    Write-Host '  Conecte com: xsshx <nome>' -ForegroundColor DarkGray
    Write-Host ''
    if ($PassThru) { return $devices }
}

function Test-SshRemoteThemeSupported {
    param([string]$Type)

    if ([string]::IsNullOrWhiteSpace($Type)) { return $false }
    return ($Type -notin @('windows', 'generic', 'local'))
}

function Connect-SshDevice {
    [CmdletBinding()]
    [Alias('cdev')]
    param(
        [Parameter(Position = 0)][string]$Target,
        [string]$Type,
        [string]$User,
        [int]$Port,
        [string]$IdentityFile,
        [string]$Profile,
        [string]$Region,
        [string]$Command,
        [string]$Lock,
        [switch]$Unlock,
        [switch]$NoBackground,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$SshArgument,
        [switch]$NoDetect,
        [switch]$Refresh,
        [switch]$RemoteTheme,
        [switch]$NoRemoteTheme,
        [switch]$FullTheme,
        [switch]$DryRun,
        [switch]$NoBanner,
        [switch]$PassThru
    )

    if ([string]::IsNullOrWhiteSpace($Target)) {
        Show-SshDevices -PassThru:$PassThru
        return
    }

    if ($Target -match '^s3://') {
        return (Start-AwsWorkspace -Target $Target -Profile $Profile -Region $Region -DryRun:$DryRun -NoBanner:$NoBanner -FullTheme:$FullTheme -NoBackground:$NoBackground -PassThru:$PassThru)
    }

    if ($Unlock) {
        if (-not $DryRun) { Remove-SshDeviceLock -Target $Target | Out-Null }
        if ([string]::IsNullOrWhiteSpace($Lock)) { return }
    }

    if ($Lock) {
        if (-not $DryRun) { Set-SshDeviceLock -Target $Target -Type $Lock | Out-Null }
        if (-not $Type) { $Type = $Lock }
    }

    # Native ssh flags are forwarded untouched; these few are also read so the
    # banner and the detection probe use the same user/port/key.
    if (-not $User) {
        $userArg = Get-SshArgumentValue -Arguments $SshArgument -Names @('-l')
        if ($userArg) { $User = $userArg }
    }
    if (-not $Port) {
        $portArg = Get-SshArgumentValue -Arguments $SshArgument -Names @('-p')
        if ($portArg -match '^\d+$') { $Port = [int]$portArg }
    }
    if (-not $IdentityFile) {
        $identityArg = Get-SshArgumentValue -Arguments $SshArgument -Names @('-i')
        if ($identityArg) { $IdentityFile = $identityArg }
    }

    $resolved = Resolve-SshTarget -Target $Target -User $User -Port $Port -IdentityFile $IdentityFile

    # A dry run never touches the network: preview only.
    $skipProbe = $NoDetect -or $DryRun
    $typeResult = Resolve-SshDeviceType -Target $Target -Type $Type -NoProbe:$skipProbe -Refresh:$Refresh
    $theme = $typeResult.Theme
    $settings = Get-SshSettings
    $showBanner = (-not $NoBanner) -and [bool](Get-SshValue (Get-SshValue $settings 'show' @{}) 'banner' $true)

    # Lembra o tipo informado manualmente para as proximas conexoes.
    if ($Type -and -not $DryRun) {
        Update-SshDetectedDevice -Resolved $resolved -Type $typeResult.Type -Info @{
            HostName = $resolved.HostName
            OsName   = [string](Get-SshValue $typeResult.Info 'OsName' '')
        }
    }

    $session = [pscustomobject]@{
        Kind       = 'ssh'
        Theme      = $typeResult.Type
        Label      = $resolved.Label
        Target     = $resolved.SshTarget
        User       = $resolved.User
        HostName   = $resolved.HostName
        HostLabel  = $resolved.HostName
        Port       = $resolved.Port
        StartedAt  = Get-Date
        Resolved   = $resolved
        TypeSource = $typeResult.Source
        TerminalState = $null
    }

    $remoteSettings = Get-SshValue $settings 'remote' @{}
    $remoteAuto = [bool](Get-SshValue $remoteSettings 'auto' $true)
    $remoteType = [string]$typeResult.Type
    $remoteSupported = Test-SshRemoteThemeSupported -Type $remoteType
    $useRemoteTheme = $RemoteTheme -or (-not $NoRemoteTheme -and $remoteAuto -and -not $Command -and $remoteSupported)

    if ($RemoteTheme -and $Command) { throw 'Use -RemoteTheme ou -Command, nao os dois.' }

    if ($useRemoteTheme) {
        $shell = [string](Get-SshValue $remoteSettings 'shell' 'bash')
        if ($shell -ne 'bash') {
            if ($RemoteTheme) { throw 'O tema remoto automatico suporta apenas bash por enquanto.' }
            $useRemoteTheme = $false
        }
    }

    if ($DryRun) {
        if ($showBanner) {
            foreach ($line in (Format-SshBanner -Theme $theme -Settings $settings -Resolved $resolved -TypeResult $typeResult -Mode 'ssh')) {
                Write-Host $line
            }
        }
        Write-Host ''
        Write-Host ('  prompt com tema ' + $theme.Label + ':') -ForegroundColor DarkGray
        $previewPath = (Get-Location).Path
        $line = Format-SshPromptText -Theme $theme -Settings $settings -Path $previewPath -DeviceLabel $theme.BadgeText -UserName $(if ($resolved.User) { $resolved.User } else { Get-SshUserName }) -HostName $resolved.HostName -GitBranch (Get-SshGitBranch -Path $previewPath) -Duration ([timespan]::FromMilliseconds(128)) -ExitCode 0 -Success $true
        Write-Host $line
        Write-Host ''
        $remoteLabel = if ($useRemoteTheme) { 'sim (bash)' } elseif ($NoRemoteTheme) { 'nao (-NoRemoteTheme)' } elseif ($Command) { 'nao (-Command)' } else { 'nao' }
        Write-Host ('  tema remoto: ' + $remoteLabel) -ForegroundColor DarkGray
        Write-Host ('  dry-run: nenhuma conexao foi feita. Tipo: ' + $typeResult.Type + ' (' + $typeResult.Source + ')') -ForegroundColor DarkGray
        Write-Host ''
        if ($PassThru) {
            return [pscustomobject]@{ DryRun = $true; Type = $typeResult.Type; Theme = $theme; Resolved = $resolved; Source = $typeResult.Source; RemoteTheme = $useRemoteTheme }
        }
        return
    }

    $sshCommand = Get-Command ssh -ErrorAction SilentlyContinue
    if (-not $sshCommand) { throw 'Cliente ssh nao encontrado no PATH. Instale o OpenSSH Client.' }

    $sshArguments = @()
    if ($resolved.Port -and -not (Test-SshArgumentPresent -Arguments $SshArgument -Names @('-p'))) {
        $sshArguments += @('-p', [string]$resolved.Port)
    }
    if ($resolved.IdentityFile -and -not (Test-SshArgumentPresent -Arguments $SshArgument -Names @('-i'))) {
        $sshArguments += @('-i', $resolved.IdentityFile)
    }
    if ($SshArgument) { $sshArguments += $SshArgument }

    if ($useRemoteTheme) {
        $rcPath = [string](Get-SshValue $remoteSettings 'rcPath' '~/.config/sshthemes/rc')
        $scriptText = Get-SshRemoteThemeScript -Type $typeResult.Type -Settings $settings
        $base64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($scriptText))
        $remoteCommand = "mkdir -p `$(dirname $rcPath) && printf %s '$base64' | base64 -d > $rcPath && if command -v bash >/dev/null 2>&1; then exec bash --rcfile $rcPath -i; else exec `${SHELL:-/bin/sh} -i; fi"
        $sshArguments += @('-t', $resolved.SshTarget, $remoteCommand)
    }
    elseif ($Command) {
        $sshArguments += $resolved.SshTarget
        $sshArguments += $Command
    }
    else {
        $sshArguments += $resolved.SshTarget
    }

    $exitCode = 0
    $startedAt = Get-Date
    try {
        Start-SshSession -Session $session -Theme $theme -Settings $settings -Full:$FullTheme -NoBackground:$NoBackground | Out-Null
        if ($showBanner) {
            foreach ($line in (Format-SshBanner -Theme $theme -Settings $settings -Resolved $resolved -TypeResult $typeResult -Mode 'ssh')) {
                Write-Host $line
            }
            Write-Host ''
        }
        & $sshCommand.Source @sshArguments
        $exitCode = [int]$global:LASTEXITCODE
    }
    finally {
        $duration = (Get-Date) - $startedAt
        $stopped = Stop-SshSession
        $summary = Format-SshSummary -Session $session -Duration $duration -ExitCode $exitCode -Settings $settings -Theme $theme
        foreach ($line in $summary) { Write-Host $line }
        if ($summary.Count -gt 0) { Write-Host '' }
    }

    if ($PassThru) {
        return [pscustomobject]@{
            DryRun   = $false
            Type     = $typeResult.Type
            Theme    = $theme
            Resolved = $resolved
            ExitCode = $exitCode
            Duration = $duration
        }
    }
}

function Start-AwsWorkspace {
    [CmdletBinding()]
    [Alias('awsx', 's3x')]
    param(
        [Parameter(Position = 0)][string]$Target,
        [string]$Bucket,
        [string]$Prefix,
        [string]$Profile,
        [string]$Region,
        [string]$EndpointUrl,
        [switch]$FullTheme,
        [switch]$NoBackground,
        [switch]$DryRun,
        [switch]$NoBanner,
        [switch]$PassThru
    )

    if ($Target -match '^s3://(?<bucket>[^/]+)(?:/(?<prefix>.*))?$') {
        $Bucket = $Matches['bucket']
        if ($Matches['prefix']) { $Prefix = $Matches['prefix'] }
    }
    elseif ($Target -and -not $Bucket) {
        $Bucket = $Target
    }

    if ([string]::IsNullOrWhiteSpace($Bucket)) {
        throw 'Informe o bucket: awsx s3://meu-bucket/prefixo  ou  awsx -Bucket meu-bucket'
    }

    $settings = Get-SshSettings
    $s3Settings = Get-SshValue $settings 's3' @{}
    if (-not $Profile) { $Profile = Get-SshValue $s3Settings 'profile' $null }
    if (-not $Region) { $Region = Get-SshValue $s3Settings 'region' $null }
    if (-not $EndpointUrl) { $EndpointUrl = Get-SshValue $s3Settings 'endpointUrl' $null }

    $prefix = ([string]$Prefix).Trim('/')
    $uri = "s3://$Bucket"
    if ($prefix) { $uri = "$uri/$prefix" }

    $theme = Get-SshThemeByName 's3'
    $showBanner = (-not $NoBanner) -and [bool](Get-SshValue (Get-SshValue $settings 'show' @{}) 'banner' $true)
    $resolved = [pscustomobject]@{
        SshTarget = $uri
        HostName  = $Bucket
        Port      = $null
        User      = $null
        Label     = $uri
        IsS3      = $true
    }
    $typeResult = [pscustomobject]@{ Info = @{ OsName = 'Amazon S3' }; Type = 's3'; Source = 'target' }

    if ($DryRun) {
        if ($showBanner) {
            foreach ($line in (Format-SshBanner -Theme $theme -Settings $settings -Resolved $resolved -TypeResult $typeResult -Mode 's3')) {
                Write-Host $line
            }
        }
        Write-Host ''
        $line = Format-SshPromptText -Theme $theme -Settings $settings -Path (Get-Location).Path -DeviceLabel 'S3' -TargetLabel $uri -UserName '' -HostName '' -Duration ([timespan]::FromMilliseconds(128)) -ExitCode 0 -Success $true
        Write-Host $line
        Write-Host ''
        Write-Host '  dry-run: workspace nao iniciado.' -ForegroundColor DarkGray
        Write-Host ''
        if ($PassThru) { return [pscustomobject]@{ DryRun = $true; Kind = 's3'; Uri = $uri; Theme = $theme; Profile = $Profile; Region = $Region } }
        return
    }

    $aws = Get-Command aws -ErrorAction SilentlyContinue
    if (-not $aws) {
        Write-Host '  aviso: AWS CLI (aws) nao encontrado no PATH. O tema sera aplicado, mas os comandos s3* vao falhar.' -ForegroundColor Yellow
    }

    $priorEnv = @{}
    foreach ($name in @('AWS_PROFILE', 'AWS_REGION', 'AWS_DEFAULT_REGION', 'AWS_ENDPOINT_URL')) {
        $priorEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    if ($Profile) { $env:AWS_PROFILE = $Profile }
    if ($Region) {
        $env:AWS_REGION = $Region
        $env:AWS_DEFAULT_REGION = $Region
    }
    if ($EndpointUrl) { $env:AWS_ENDPOINT_URL = $EndpointUrl }

    $session = [pscustomobject]@{
        Kind       = 's3'
        Theme      = 's3'
        Label      = $uri
        Target     = $uri
        User       = $null
        HostName   = $Bucket
        HostLabel  = $Bucket
        Port       = $null
        StartedAt  = Get-Date
        Bucket     = $Bucket
        Prefix     = $prefix
        Profile    = $Profile
        Region     = $Region
        EndpointUrl = $EndpointUrl
        PriorEnv   = $priorEnv
        TypeSource = 'target'
        TerminalState = $null
    }

    $global:SshS3Context = @{
        Uri      = $uri
        Bucket   = $Bucket
        Prefix   = $prefix
        Profile  = $Profile
        Region   = $Region
        Started  = Get-Date
    }

    Set-Item -Path function:global:__SshS3Uri -Value {
        param([string]$Path)
        if ($Path -match '^s3://') { return $Path }
        $base = ([string]$global:SshS3Context.Uri).TrimEnd('/')
        if ([string]::IsNullOrWhiteSpace($Path)) { return $base }
        return ($base + '/' + $Path.TrimStart('/'))
    } -Force

    Set-Item -Path function:global:__SshS3AssertAws -Value {
        if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
            throw 'AWS CLI (aws) nao encontrado no PATH. Instale o AWS CLI v2 e rode: aws configure'
        }
    } -Force

    Set-Item -Path function:global:s3uri -Value {
        param([string]$Path)
        if (-not $global:SshS3Context) { throw 'Fora do workspace S3. Use: awsx s3://bucket/prefix' }
        __SshS3Uri $Path
    } -Force

    Set-Item -Path function:global:s3ls -Value {
        [CmdletBinding()]
        param([string]$Path = '', [switch]$Recursive, [switch]$Summarize)
        if (-not $global:SshS3Context) { throw 'Fora do workspace S3. Use: awsx s3://bucket/prefix' }
        __SshS3AssertAws
        $awsArgs = @('s3', 'ls', (__SshS3Uri $Path), '--human-readable')
        if ($Recursive) { $awsArgs += '--recursive' }
        if ($Summarize) { $awsArgs += '--summarize' }
        & aws @awsArgs
    } -Force

    Set-Item -Path function:global:s3get -Value {
        [CmdletBinding()]
        param([Parameter(Mandatory)][string]$Key, [string]$Destination = '')
        if (-not $global:SshS3Context) { throw 'Fora do workspace S3. Use: awsx s3://bucket/prefix' }
        __SshS3AssertAws
        if (-not $Destination) { $Destination = (Split-Path -Leaf $Key) }
        & aws s3 cp (__SshS3Uri $Key) $Destination
    } -Force

    Set-Item -Path function:global:s3put -Value {
        [CmdletBinding()]
        param([Parameter(Mandatory)][string]$File, [string]$Key = '')
        if (-not $global:SshS3Context) { throw 'Fora do workspace S3. Use: awsx s3://bucket/prefix' }
        __SshS3AssertAws
        if (-not $Key) { $Key = Split-Path -Leaf $File }
        & aws s3 cp $File (__SshS3Uri $Key)
    } -Force

    Set-Item -Path function:global:s3sync -Value {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)][string]$Path,
            [string]$Prefix = '',
            [switch]$Download,
            [switch]$Delete
        )
        if (-not $global:SshS3Context) { throw 'Fora do workspace S3. Use: awsx s3://bucket/prefix' }
        __SshS3AssertAws
        $awsArgs = @('s3', 'sync')
        if ($Download) { $awsArgs += @((__SshS3Uri $Prefix), $Path) }
        else { $awsArgs += @($Path, (__SshS3Uri $Prefix)) }
        if ($Delete) { $awsArgs += '--delete' }
        & aws @awsArgs
    } -Force

    Set-Item -Path function:global:s3rm -Value {
        [CmdletBinding(SupportsShouldProcess)]
        param([Parameter(Mandatory)][string]$Key, [switch]$Recursive)
        if (-not $global:SshS3Context) { throw 'Fora do workspace S3. Use: awsx s3://bucket/prefix' }
        if ($PSCmdlet.ShouldProcess($Key, 'remover do S3')) {
            __SshS3AssertAws
            $awsArgs = @('s3', 'rm', (__SshS3Uri $Key))
            if ($Recursive) { $awsArgs += '--recursive' }
            & aws @awsArgs
        }
    } -Force

    Start-SshSession -Session $session -Theme $theme -Settings $settings -Full:$FullTheme -NoBackground:$NoBackground | Out-Null

    if ($showBanner) {
        foreach ($line in (Format-SshBanner -Theme $theme -Settings $settings -Resolved $resolved -TypeResult $typeResult -Mode 's3')) {
            Write-Host $line
        }
        $profileText = if ($Profile) { $Profile } else { '(default)' }
        Write-Host ('  aws profile: ' + $profileText + '  ' + (Get-SshUiChar 'dot') + '  regiao: ' + $(if ($Region) { $Region } else { '(default)' })) -ForegroundColor DarkGray
        Write-Host ''
    }

    if ($PassThru) {
        return [pscustomobject]@{
            DryRun = $false
            Kind   = 's3'
            Uri    = $uri
            Theme  = $theme
            Session = $session
            Profile = $Profile
            Region  = $Region
        }
    }
}

function Exit-SshDevice {
    [CmdletBinding()]
    param([switch]$PassThru)

    $session = Get-SshActiveSession
    if (-not $session) {
        Write-Host 'Nenhuma sessao SshThemes ativa.' -ForegroundColor DarkGray
        return
    }

    $duration = (Get-Date) - $session.StartedAt
    $stopped = Stop-SshSession

    if ($session.Kind -eq 's3') {
        foreach ($name in @($session.PriorEnv.Keys)) {
            [Environment]::SetEnvironmentVariable($name, $session.PriorEnv[$name], 'Process')
        }
        Remove-Item -Path variable:global:SshS3Context -ErrorAction SilentlyContinue
        Remove-Item -Path function:global:__SshS3AssertAws -ErrorAction SilentlyContinue
    }

    $settings = Get-SshSettings
    $theme = Get-SshThemeByName -Name $session.Theme -AllowMissing
    if (-not $theme) { $theme = Get-SshThemeByName 'generic' }
    foreach ($line in (Format-SshSummary -Session $session -Duration $duration -ExitCode 0 -Settings $settings -Theme $theme)) {
        Write-Host $line
    }
    Write-Host ''

    if ($PassThru) {
        return [pscustomobject]@{ Session = $session; Duration = $duration }
    }
}

function Get-SshSession {
    [CmdletBinding()]
    param()

    $settings = Get-SshSettings
    $session = Get-SshActiveSession
    if (-not $session) {
        return [pscustomobject]@{
            Active    = $false
            Kind      = 'local'
            Theme     = [string](Get-SshValue $settings 'defaultTheme' 'local')
            Target    = $null
            StartedAt = $null
            Duration  = $null
        }
    }

    return [pscustomobject]@{
        Active    = $true
        Kind      = $session.Kind
        Theme     = $session.Theme
        Target    = $session.Target
        Label     = $session.Label
        Bucket    = Get-SshValue $session 'Bucket' $null
        Prefix    = Get-SshValue $session 'Prefix' $null
        Profile   = Get-SshValue $session 'Profile' $null
        Region    = Get-SshValue $session 'Region' $null
        StartedAt = $session.StartedAt
        Duration  = (Get-Date) - $session.StartedAt
    }
}

# Tab completion for device names, ssh-config aliases and theme names.
Register-ArgumentCompleter -CommandName Connect-SshDevice -ParameterName Target -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $cursorPosition)

    $module = Get-Module SshThemes
    $candidates = @()
    if ($module) {
        try {
            $candidates = & $module {
                $list = @()
                try { $list += @(Get-SshDevice).Name } catch { }
                try { $list += @((Get-SshConfigHosts).Keys) } catch { }
                try { $list += @((Get-SshThemeCatalog).Keys | ForEach-Object { "type:$_" }) } catch { }
                $list += 's3://'
                $list
            }
        }
        catch { }
    }

    foreach ($candidate in @($candidates | Select-Object -Unique)) {
        if ($candidate -like "$wordToComplete*") {
            [System.Management.Automation.CompletionResult]::new($candidate, $candidate, 'ParameterValue', $candidate)
        }
    }
}
