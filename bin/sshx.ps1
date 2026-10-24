[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Target,
    [string]$Type,
    [string]$User,
    [int]$Port,
    [string]$IdentityFile,
    [string]$Profile,
    [string]$Region,
    [string]$EndpointUrl,
    [string]$Bucket,
    [string]$Prefix,
    [string]$Command,
    [switch]$NoDetect,
    [switch]$Refresh,
    [switch]$RemoteTheme,
    [switch]$NoRemoteTheme,
    [switch]$FullTheme,
    [switch]$DryRun,
    [switch]$NoBanner,
    [switch]$S3,
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Extra
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host ''
    Write-Host 'sshx - SshThemes launcher' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  sshx <host|alias|user@host|s3://bucket/prefix> [opcoes]' -ForegroundColor White
    Write-Host ''
    Write-Host '  -Type <tema>       forca o tema (debian, ubuntu, aws, s3, ...)' -ForegroundColor DarkGray
    Write-Host '  -Port <n>          porta SSH' -ForegroundColor DarkGray
    Write-Host '  -User <nome>       usuario SSH' -ForegroundColor DarkGray
    Write-Host '  -RemoteTheme       injeta o prompt tema no bash remoto' -ForegroundColor DarkGray
    Write-Host '  -NoRemoteTheme     nao injeta o prompt remoto nesta conexao' -ForegroundColor DarkGray
    Write-Host '  -FullTheme         aplica tambem fg/bg/cursor do tema' -ForegroundColor DarkGray
    Write-Host '  -DryRun            mostra o banner e o prompt sem conectar' -ForegroundColor DarkGray
    Write-Host '  -S3                abre workspace S3 (AWS CLI)' -ForegroundColor DarkGray
    Write-Host '  -Bucket <nome>     bucket S3 (modo -S3)' -ForegroundColor DarkGray
    Write-Host '  -Prefix <chave>    prefixo dentro do bucket (modo -S3)' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Personalize: /font  /icons  /color  /distros   (/help para detalhes)' -ForegroundColor DarkGray
    Write-Host ''
    return
}

try {
    Import-Module SshThemes -ErrorAction Stop -DisableNameChecking
}
catch {
    $localModule = Join-Path (Split-Path -Parent $PSScriptRoot) 'src\SshThemes\SshThemes.psd1'
    if (Test-Path -LiteralPath $localModule) {
        Import-Module $localModule -Force
    }
    else {
        throw 'Modulo SshThemes nao encontrado. Rode .\Install.ps1 primeiro.'
    }
}

if ($S3) {
    $s3Params = @{}
    foreach ($key in @('Target', 'Bucket', 'Prefix', 'Profile', 'Region', 'EndpointUrl', 'FullTheme', 'DryRun', 'NoBanner')) {
        if ($PSBoundParameters.ContainsKey($key)) { $s3Params[$key] = $PSBoundParameters[$key] }
    }
    if ($Extra) { throw 'Parametros extras nao sao suportados no modo -S3.' }
    Start-AwsWorkspace @s3Params
    return
}

$sshParams = @{}
foreach ($key in @('Target', 'Type', 'User', 'Port', 'IdentityFile', 'Command', 'NoDetect', 'Refresh', 'RemoteTheme', 'NoRemoteTheme', 'FullTheme', 'DryRun', 'NoBanner')) {
    if ($PSBoundParameters.ContainsKey($key)) { $sshParams[$key] = $PSBoundParameters[$key] }
}
if ($Extra) { $sshParams['SshArgument'] = $Extra }

Connect-SshDevice @sshParams
