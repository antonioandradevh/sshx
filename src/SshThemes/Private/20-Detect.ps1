# Target parsing, SSH config hints and remote device detection.

function Split-SshTarget {
    param([Parameter(Mandatory)][string]$Target)

    $raw = $Target.Trim()
    $result = @{
        Raw      = $raw
        IsS3     = $false
        Scheme   = $null
        Bucket   = $null
        Prefix   = $null
        User     = $null
        HostName = $raw
        Port     = $null
    }

    if ($raw -match '^(?i)s3://(?<bucket>[^/]+)(?:/(?<prefix>.*))?$') {
        $result.IsS3 = $true
        $result.Scheme = 's3'
        $result.Bucket = $Matches['bucket']
        $result.Prefix = $Matches['prefix']
        $result.HostName = $Matches['bucket']
        return $result
    }

    $rest = $raw
    if ($rest -match '^(?i)(?<scheme>ssh|sftp)://(?<rest>.+)$') {
        $result.Scheme = $Matches['scheme'].ToLowerInvariant()
        $rest = $Matches['rest']
        $rest = $rest.TrimEnd('/')
    }

    if ($rest -match '^(?<user>[^@/]+)@(?<host>.+)$') {
        $result.User = $Matches['user']
        $rest = $Matches['host']
    }

    if ($rest -match '^\[(?<host>[^\]]+)\](?::(?<port>\d+))?$') {
        $result.HostName = $Matches['host']
        if ($Matches['port']) { $result.Port = [int]$Matches['port'] }
    }
    elseif ($rest -match '^(?<host>[^:]+):(?<port>\d+)$') {
        $result.HostName = $Matches['host']
        $result.Port = [int]$Matches['port']
    }
    else {
        $result.HostName = $rest
    }

    return $result
}

function Resolve-SshTarget {
    param(
        [Parameter(Mandatory)][string]$Target,
        [string]$User,
        [int]$Port,
        [string]$IdentityFile
    )

    $parsed = Split-SshTarget -Target $Target
    if ($parsed.IsS3) {
        return [pscustomobject]@{
            Raw        = $parsed.Raw
            IsS3       = $true
            Scheme     = 's3'
            Bucket     = $parsed.Bucket
            Prefix     = $parsed.Prefix
            Alias      = $null
            User       = $null
            Port       = $null
            HostName   = $parsed.Bucket
            SshTarget  = $parsed.Raw
            Entry      = $null
            ConfigHint = $null
            Label      = ('s3://' + $parsed.Bucket + $(if ($parsed.Prefix) { '/' + $parsed.Prefix } else { '' }))
        }
    }

    $registry = Get-SshDeviceRegistry
    $lookupKey = $parsed.HostName
    if (-not $registry.devices.Contains($lookupKey) -and $registry.devices.Contains($parsed.Raw)) {
        $lookupKey = $parsed.Raw
    }
    $entry = $null
    if ($registry.devices.Contains($lookupKey)) { $entry = $registry.devices[$lookupKey] }

    $configHint = $null
    if (-not $parsed.User -and -not $parsed.Port) {
        $configHint = Get-SshConfigHostHint -Alias $parsed.HostName
    }

    $hostName = $parsed.HostName
    if ($entry -and (Get-SshValue $entry 'host')) { $hostName = [string](Get-SshValue $entry 'host') }
    elseif ($configHint -and $configHint.ContainsKey('HostName')) { $hostName = [string]$configHint['HostName'] }

    $finalUser = if ($User) { $User } elseif ($parsed.User) { $parsed.User } elseif ($entry -and (Get-SshValue $entry 'user')) { [string](Get-SshValue $entry 'user') } elseif ($configHint -and $configHint.ContainsKey('User')) { [string]$configHint['User'] } else { $null }

    $finalPort = $null
    if ($Port -gt 0) { $finalPort = $Port }
    elseif ($parsed.Port) { $finalPort = $parsed.Port }
    elseif ($entry -and (Get-SshValue $entry 'port')) { $finalPort = [int](Get-SshValue $entry 'port') }
    elseif ($configHint -and $configHint.ContainsKey('Port')) { $finalPort = [int]$configHint['Port'] }

    $sshTarget = $parsed.Raw
    if ($parsed.Scheme -match '^(ssh|sftp)$') {
        $sshTarget = $hostName
        if ($finalUser) { $sshTarget = "$finalUser@$hostName" }
    }
    elseif ($entry -and -not (Get-SshValue $entry 'sshAlias')) {
        $sshTarget = $hostName
        if ($finalUser) { $sshTarget = "$finalUser@$hostName" }
        $parsed.Raw = $sshTarget
    }
    elseif ($entry -and (Get-SshValue $entry 'sshAlias')) {
        $sshTarget = [string](Get-SshValue $entry 'sshAlias')
    }

    $label = Get-SshValue $entry 'label' $null
    if ([string]::IsNullOrWhiteSpace($label)) { $label = $hostName }

    return [pscustomobject]@{
        Raw        = $parsed.Raw
        IsS3       = $false
        Scheme     = $parsed.Scheme
        Bucket     = $null
        Prefix     = $null
        Alias      = $lookupKey
        User       = $finalUser
        Port       = $finalPort
        HostName   = $hostName
        SshTarget  = $sshTarget
        Entry      = $entry
        ConfigHint = $configHint
        Label      = $label
        IdentityFile = $IdentityFile
    }
}

function Invoke-SshProbe {
    param(
        [Parameter(Mandatory)][string]$SshTarget,
        [int]$Port,
        [int]$TimeoutSeconds = 6,
        [bool]$StrictHostKeys = $false
    )

    $ssh = Get-Command ssh -ErrorAction SilentlyContinue
    if (-not $ssh) {
        return @{ Ok = $false; Error = 'Cliente ssh nao encontrado no PATH.' }
    }

    $remoteCommand = 'echo @@SSHT_OS_BEGIN@@; cat /etc/os-release 2>/dev/null; echo @@SSHT_OS_END@@; echo @@SSHT_UNAME@@$(uname -s 2>/dev/null); echo @@SSHT_HOST@@$(hostname 2>/dev/null); echo @@SSHT_AWS@@$(command -v aws 2>/dev/null); echo @@SSHT_DOCKER@@$([ -f /.dockerenv ] && echo yes || echo no)'

    $hostKeyPolicy = if ($StrictHostKeys) { 'yes' } else { 'accept-new' }
    $arguments = @(
        '-o', 'BatchMode=yes',
        '-o', "ConnectTimeout=$TimeoutSeconds",
        '-o', "StrictHostKeyChecking=$hostKeyPolicy",
        '-o', 'NumberOfPasswordPrompts=0',
        '-o', 'LogLevel=ERROR'
    )
    if ($Port -gt 0) { $arguments += @('-p', [string]$Port) }
    $arguments += $SshTarget
    $arguments += $remoteCommand

    $raw = ''
    try {
        $raw = (& $ssh.Source @arguments 2>&1 | Out-String)
    }
    catch {
        return @{ Ok = $false; Error = $_.Exception.Message }
    }

    if ($raw -notmatch '@@SSHT_OS_BEGIN@@') {
        $message = ($raw -replace '\s+', ' ').Trim()
        if ($message.Length -gt 240) { $message = $message.Substring(0, 240) + '...' }
        return @{ Ok = $false; Error = $message }
    }

    $osBlock = ''
    if ($raw -match '(?s)@@SSHT_OS_BEGIN@@(.*?)@@SSHT_OS_END@@') {
        $osBlock = $Matches[1]
    }

    $os = @{}
    foreach ($line in ($osBlock -split "`n")) {
        if ($line -match '^\s*(?<key>[A-Za-z0-9_]+)\s*=\s*(?<value>.*)$') {
            $value = $Matches['value'].Trim().Trim('"').Trim("'")
            $os[$Matches['key']] = $value
        }
    }

    $uname = ''
    if ($raw -match '(?m)^@@SSHT_UNAME@@(.*)$') { $uname = $Matches[1].Trim() }
    $hostname = ''
    if ($raw -match '(?m)^@@SSHT_HOST@@(.*)$') { $hostname = $Matches[1].Trim() }
    $aws = ''
    if ($raw -match '(?m)^@@SSHT_AWS@@(.*)$') { $aws = $Matches[1].Trim() }
    $docker = $false
    if ($raw -match '(?m)^@@SSHT_DOCKER@@(?<value>.*)$') { $docker = ($Matches['value'].Trim() -eq 'yes') }

    $idLike = @()
    if ($os.ContainsKey('ID_LIKE')) { $idLike = @($os['ID_LIKE'] -split '\s+') }

    return @{
        Ok         = $true
        OsId       = if ($os.ContainsKey('ID')) { $os['ID'].ToLowerInvariant() } else { '' }
        OsLike     = $idLike
        OsName     = if ($os.ContainsKey('PRETTY_NAME')) { $os['PRETTY_NAME'] } elseif ($os.ContainsKey('NAME')) { $os['NAME'] } else { '' }
        Uname      = $uname
        Hostname   = $hostname
        Aws        = [bool]$aws
        AwsPath    = $aws
        Docker     = $docker
        Raw        = $raw.Trim()
    }
}

function Get-SshTypeFromInfo {
    param(
        [Parameter(Mandatory)]$Info,
        $Catalog
    )

    if (-not $Catalog) { $Catalog = Get-SshThemeCatalog }

    $target = [string](Get-SshValue $Info 'Target' '')
    $hostName = [string](Get-SshValue $Info 'HostName' '')
    $osId = ([string](Get-SshValue $Info 'OsId' '')).ToLowerInvariant()
    $osLike = @(Get-SshValue $Info 'OsLike' @())
    $uname = [string](Get-SshValue $Info 'Uname' '')
    $aws = [bool](Get-SshValue $Info 'Aws' $false)

    $bestName = $null
    $bestScore = 0
    $bestDetail = @()

    foreach ($name in @($Catalog.Keys)) {
        if ($name -eq 'local') { continue }
        $theme = $Catalog[$name]
        $detect = $theme.Detect
        if (-not ($detect -is [System.Collections.IDictionary]) -or $detect.Count -eq 0) { continue }

        $score = 0
        $detail = @()

        $schemes = @(Get-SshValue $detect 'targetSchemes' @())
        foreach ($scheme in $schemes) {
            if ($scheme -and $target.ToLowerInvariant().StartsWith(([string]$scheme).ToLowerInvariant())) {
                $score += 300
                $detail += "scheme:$scheme"
                break
            }
        }

        $osIds = @(Get-SshValue $detect 'osIds' @())
        if ($osId -and ($osIds -contains $osId)) {
            $score += 100
            $detail += "os:$osId"
        }

        $idLikes = @(Get-SshValue $detect 'idLike' @())
        foreach ($like in $idLikes) {
            if ($like -and ($osLike -contains $like)) {
                $score += 60
                $detail += "like:$like"
                break
            }
        }

        $unames = @(Get-SshValue $detect 'uname' @())
        foreach ($candidate in $unames) {
            if ($candidate -and $uname -and $uname.ToLowerInvariant().Contains(([string]$candidate).ToLowerInvariant())) {
                $score += 50
                $detail += "uname:$candidate"
                break
            }
        }

        $patterns = @(Get-SshValue $detect 'hostPatterns' @())
        foreach ($pattern in $patterns) {
            if (-not $pattern) { continue }
            foreach ($candidate in @($hostName, $target)) {
                if (-not $candidate) { continue }
                try {
                    if ($candidate -match $pattern) {
                        $score += 70
                        $detail += "host:$pattern"
                        break
                    }
                }
                catch { }
            }
        }

        $contains = @(Get-SshValue $detect 'hostContains' @())
        foreach ($fragment in $contains) {
            if ($fragment -and $hostName -and $hostName.ToLowerInvariant().Contains(([string]$fragment).ToLowerInvariant())) {
                $score += 65
                $detail += "contains:$fragment"
                break
            }
        }

        if ($aws -and (Get-SshValue $detect 'requiresAws' $false)) {
            $score += 20
            $detail += 'aws'
        }

        if ($score -gt $bestScore) {
            $bestScore = $score
            $bestName = $name
            $bestDetail = $detail
        }
    }

    if (-not $bestName) { $bestName = 'generic' }
    $theme = $Catalog[$bestName]

    return [pscustomobject]@{
        Type   = $bestName
        Label  = $theme.Label
        Icon   = $theme.Icon
        Accent = $theme.Accent
        Score  = $bestScore
        Detail = $bestDetail
        Theme  = $theme
    }
}

function Update-SshDetectedDevice {
    param(
        [Parameter(Mandatory)]$Resolved,
        [Parameter(Mandatory)][string]$Type,
        $Info
    )

    if ($Resolved.IsS3) { return }
    if ([string]::IsNullOrWhiteSpace($Resolved.HostName)) { return }

    $registry = Get-SshDeviceRegistry
    $key = [string]$Resolved.Alias
    if ([string]::IsNullOrWhiteSpace($key)) { $key = $Resolved.HostName }

    if (-not $registry.devices.Contains($key)) { $registry.devices[$key] = @{} }
    $entry = $registry.devices[$key]

    if (-not $entry.Contains('host') -or -not $entry['host']) { $entry['host'] = $Resolved.HostName }
    if ($Resolved.User -and -not $entry.Contains('user')) { $entry['user'] = $Resolved.User }
    if ($Resolved.Port -and -not $entry.Contains('port')) { $entry['port'] = $Resolved.Port }

    $entry['detectedType'] = $Type
    $entry['detectedAt'] = (Get-Date).ToString('o')
    if ($Info -and (Get-SshValue $Info 'OsName')) { $entry['osName'] = [string](Get-SshValue $Info 'OsName') }
    if ($Info -and (Get-SshValue $Info 'Hostname')) { $entry['remoteHostname'] = [string](Get-SshValue $Info 'Hostname') }

    Save-SshDeviceRegistry -Document $registry
}

function Resolve-SshDeviceType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Target,
        [string]$Type,
        [switch]$NoProbe,
        [switch]$Refresh
    )

    $resolved = Resolve-SshTarget -Target $Target
    if ($resolved.IsS3) {
        $theme = Get-SshThemeByName 's3'
        return [pscustomobject]@{
            Type     = 's3'
            Label    = $theme.Label
            Icon     = $theme.Icon
            Accent   = $theme.Accent
            Source   = 'target'
            Score    = 300
            Info     = @{ Target = $resolved.Raw; HostName = $resolved.HostName }
            Theme    = $theme
            Resolved = $resolved
        }
    }

    if ($Type) {
        $theme = Get-SshThemeByName -Name $Type
        return [pscustomobject]@{
            Type     = $Type
            Label    = $theme.Label
            Icon     = $theme.Icon
            Accent   = $theme.Accent
            Source   = 'explicit'
            Score    = 1000
            Info     = @{ Target = $resolved.Raw; HostName = $resolved.HostName }
            Theme    = $theme
            Resolved = $resolved
        }
    }

    $settings = Get-SshSettings
    $cacheDays = [int](Get-SshValue (Get-SshValue $settings 'detect' @{}) 'cacheDays' 30)
    $entry = $resolved.Entry
    $cachedType = $null
    if ($entry) { $cachedType = Get-SshValue $entry 'detectedType' $null }

    if ($cachedType -and -not $Refresh) {
        $catalog = Get-SshThemeCatalog
        if ($catalog.Contains($cachedType)) {
            $detectedAt = Get-SshValue $entry 'detectedAt' $null
            $fresh = $true
            if ($detectedAt) {
                try {
                    $age = (Get-Date) - [datetime]::Parse($detectedAt)
                    if ($age.TotalDays -gt $cacheDays) { $fresh = $false }
                }
                catch { }
            }
            if ($fresh) {
                $theme = $catalog[$cachedType]
                return [pscustomobject]@{
                    Type     = $cachedType
                    Label    = $theme.Label
                    Icon     = $theme.Icon
                    Accent   = $theme.Accent
                    Source   = 'cache'
                    Score    = 90
                    Info     = @{ Target = $resolved.Raw; HostName = $resolved.HostName }
                    Theme    = $theme
                    Resolved = $resolved
                }
            }
        }
    }

    $probeEnabled = [bool](Get-SshValue (Get-SshValue $settings 'detect' @{}) 'probe' $true)
    if (-not $NoProbe -and $probeEnabled) {
        $timeout = [int](Get-SshValue (Get-SshValue $settings 'detect' @{}) 'timeoutSeconds' 6)
        $strictHosts = [bool](Get-SshValue (Get-SshValue $settings 'detect' @{}) 'strictHostKeys' $false)
        $probe = Invoke-SshProbe -SshTarget $resolved.SshTarget -Port $resolved.Port -TimeoutSeconds $timeout -StrictHostKeys $strictHosts
        if ($probe.Ok) {
            $probe.Target = $resolved.Raw
            $probe.HostName = if ($probe.Hostname) { $probe.Hostname } else { $resolved.HostName }
            $match = Get-SshTypeFromInfo -Info $probe
            Update-SshDetectedDevice -Resolved $resolved -Type $match.Type -Info $probe
            return [pscustomobject]@{
                Type     = $match.Type
                Label    = $match.Label
                Icon     = $match.Icon
                Accent   = $match.Accent
                Source   = 'probe'
                Score    = $match.Score
                Info     = $probe
                Theme    = $match.Theme
                Resolved = $resolved
            }
        }

        Write-Verbose "Deteccao remota indisponivel para $($resolved.SshTarget): $($probe.Error)"
        $hostMatch = Get-SshTypeFromInfo -Info @{ Target = $resolved.Raw; HostName = $resolved.HostName; Aws = $false }
        if ($hostMatch.Score -gt 0) {
            return [pscustomobject]@{
                Type     = $hostMatch.Type
                Label    = $hostMatch.Label
                Icon     = $hostMatch.Icon
                Accent   = $hostMatch.Accent
                Source   = 'hostname'
                Score    = $hostMatch.Score
                Info     = @{ Target = $resolved.Raw; HostName = $resolved.HostName }
                Theme    = $hostMatch.Theme
                Resolved = $resolved
            }
        }

        $theme = Get-SshThemeByName 'generic'
        return [pscustomobject]@{
            Type     = 'generic'
            Label    = $theme.Label
            Icon     = $theme.Icon
            Accent   = $theme.Accent
            Source   = 'fallback'
            Score    = 0
            Info     = @{ Target = $resolved.Raw; HostName = $resolved.HostName; ProbeError = $probe.Error }
            Theme    = $theme
            Resolved = $resolved
        }
    }

    $hostMatch = Get-SshTypeFromInfo -Info @{ Target = $resolved.Raw; HostName = $resolved.HostName; Aws = $false }
    $source = if ($hostMatch.Score -gt 0) { 'hostname' } else { 'fallback' }
    return [pscustomobject]@{
        Type     = $hostMatch.Type
        Label    = $hostMatch.Label
        Icon     = $hostMatch.Icon
        Accent   = $hostMatch.Accent
        Source   = $source
        Score    = $hostMatch.Score
        Info     = @{ Target = $resolved.Raw; HostName = $resolved.HostName }
        Theme    = $hostMatch.Theme
        Resolved = $resolved
    }
}
