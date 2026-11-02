@{
    RootModule        = 'SshThemes.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'c9f4a2e1-7b3d-4a55-9e2f-1d6c8b0a4f21'
    Author            = 'SshThemes'
    CompanyName       = 'SshThemes'
    Copyright         = '(c) 2026 SshThemes. MIT License.'
    Description       = 'SSH terminal themes that detect the remote device and restyle the session (colors, icons, prompt, command duration).'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'prompt',
        'Connect-SshDevice',
        'Start-AwsWorkspace',
        'Exit-SshDevice',
        'Get-SshSession',
        'Get-SshTheme',
        'Set-SshTheme',
        'Set-SshThemeValue',
        'Get-SshThemeValue',
        'Remove-SshThemeValue',
        'New-SshTheme',
        'Remove-SshTheme',
        'Show-SshThemes',
        'Preview-SshTheme',
        'Edit-SshTheme',
        'Get-SshDevice',
        'Register-SshDevice',
        'Remove-SshDevice',
        'Show-SshDevices',
        'Get-SshSetting',
        'Set-SshSetting',
        'Reset-SshSetting',
        'Enable-SshThemePrompt',
        'Disable-SshThemePrompt',
        'Resolve-SshDeviceType',
        'Set-SshDeviceLock',
        'Remove-SshDeviceLock',
        'Get-SshDeviceLocks',
        'Reload-SshConfig',
        'Edit-SshConfig',
        'Install-SshRemoteTheme',
        'Get-SshRemoteThemeScript',
        'Get-SshNerdFont',
        'Get-SshNerdFontInfo',
        'Test-SshNerdFont',
        'Install-SshNerdFont',
        'Set-SshTerminalFont',
        'Invoke-XsshxCommand',
        'Invoke-SshFontCommand',
        'Invoke-SshIconsCommand',
        'Invoke-SshColorCommand',
        'Invoke-SshDistrosCommand',
        'Invoke-SshLockCommand',
        'Invoke-SshUnlockCommand',
        'Invoke-SshBackgroundCommand',
        'Invoke-SshSetCommand',
        'Invoke-SshGetCommand',
        'Invoke-SshEditCommand',
        'Invoke-SshResetCommand',
        'Show-SshLocks',
        'Show-SshHelp'
    )
    AliasesToExport   = @(
        'xsshx',
        'cdev',
        'awsx',
        's3x',
        'exitssh',
        '-font',
        '-icons',
        '-color',
        '-distros',
        '-lock',
        '-unlock',
        '-locks',
        '-bg',
        '-background',
        '-set',
        '-get',
        '-edit',
        '-reset',
        '-help'
    )
    PrivateData       = @{
        PSData = @{
            Tags = @('SSH', 'Terminal', 'Theme', 'Prompt', 'AWS', 'S3', 'WindowsTerminal')
        }
    }
}
