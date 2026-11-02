# SshThemes - device-aware SSH terminal themes for PowerShell.
# Source files are ASCII-only on purpose: Windows PowerShell 5.1 reads
# BOM-less scripts as ANSI, so every non-ASCII glyph lives in JSON config.

$script:ModuleRoot    = $PSScriptRoot
$script:ModuleVersion = '1.0.0'
$script:Esc           = [string][char]27
$script:Session       = $null
$script:TerminalStack = New-Object System.Collections.Stack
$script:Cache         = @{}
$script:NativeCache   = @{}

# Keep a reference to the prompt that existed before this module was loaded.
if (-not $global:SshTheme_OriginalPrompt) {
    $existingPrompt = Get-Command prompt -CommandType Function -ErrorAction SilentlyContinue
    if ($existingPrompt -and $existingPrompt.Source -ne 'SshThemes') {
        $global:SshTheme_OriginalPrompt = $existingPrompt.ScriptBlock
    }
}

$private = Join-Path $PSScriptRoot 'Private'
$public  = Join-Path $PSScriptRoot 'Public'

Get-ChildItem -Path $private -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
    . $_.FullName
}
Get-ChildItem -Path $public -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
    . $_.FullName
}

Initialize-SshThemeHome

Set-Alias -Name xsshx   -Value Invoke-XsshxCommand -Force
Set-Alias -Name cdev    -Value Connect-SshDevice  -Force
Set-Alias -Name awsx    -Value Start-AwsWorkspace -Force
Set-Alias -Name s3x     -Value Start-AwsWorkspace -Force
Set-Alias -Name exitssh -Value Exit-SshDevice     -Force

Set-Alias -Name '-font'       -Value Invoke-SshFontCommand       -Force
Set-Alias -Name '-icons'      -Value Invoke-SshIconsCommand      -Force
Set-Alias -Name '-color'      -Value Invoke-SshColorCommand      -Force
Set-Alias -Name '-distros'    -Value Invoke-SshDistrosCommand    -Force
Set-Alias -Name '-lock'       -Value Invoke-SshLockCommand       -Force
Set-Alias -Name '-unlock'     -Value Invoke-SshUnlockCommand     -Force
Set-Alias -Name '-locks'      -Value Invoke-SshLockCommand       -Force
Set-Alias -Name '-bg'         -Value Invoke-SshBackgroundCommand -Force
Set-Alias -Name '-background' -Value Invoke-SshBackgroundCommand -Force
Set-Alias -Name '-set'        -Value Invoke-SshSetCommand        -Force
Set-Alias -Name '-get'        -Value Invoke-SshGetCommand        -Force
Set-Alias -Name '-edit'       -Value Invoke-SshEditCommand       -Force
Set-Alias -Name '-reset'      -Value Invoke-SshResetCommand      -Force
Set-Alias -Name '-help'       -Value Show-SshHelp                -Force
