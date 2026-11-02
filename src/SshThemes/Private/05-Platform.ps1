# Cross-platform helpers: OS detection, user/home paths, fonts and editors.
# Source files stay ASCII-only so Windows PowerShell 5.1 can read them.

function Test-SshWindows {
    $value = Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $value) { return [bool]$value }
    return ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)
}

function Test-SshMacOS {
    $value = Get-Variable -Name IsMacOS -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $value) { return [bool]$value }
    return ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::MacOSX)
}

function Test-SshLinux {
    if (Test-SshWindows -or Test-SshMacOS) { return $false }
    return $true
}

function Get-SshUserName {
    if ($env:USER) { return [string]$env:USER }
    if ($env:USERNAME) { return [string]$env:USERNAME }
    try { return [string][Environment]::UserName } catch { }
    return 'user'
}

function Get-SshMachineName {
    if ($env:HOSTNAME) { return [string]$env:HOSTNAME }
    if ($env:COMPUTERNAME) { return [string]$env:COMPUTERNAME }
    try { return [string][Environment]::MachineName } catch { }
    return 'localhost'
}

function Get-SshHomePath {
    if ($HOME) { return [string]$HOME }
    try {
        $profile = [Environment]::GetFolderPath('UserProfile')
        if ($profile) { return [string]$profile }
    }
    catch { }
    return '.'
}

function Get-SshFontDirectory {
    if (Test-SshWindows) {
        if ($env:LOCALAPPDATA) { return (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts') }
        return (Join-Path (Get-SshHomePath) 'AppData\Local\Microsoft\Windows\Fonts')
    }
    if (Test-SshMacOS) { return (Join-Path (Get-SshHomePath) 'Library/Fonts') }
    if ($env:XDG_DATA_HOME) { return (Join-Path $env:XDG_DATA_HOME 'fonts') }
    return (Join-Path (Get-SshHomePath) '.local/share/fonts')
}

function Get-SshFontSearchDirectories {
    $dirs = @()
    if (Test-SshWindows) {
        if ($env:LOCALAPPDATA) { $dirs += (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts') }
        if ($env:WINDIR) { $dirs += (Join-Path $env:WINDIR 'Fonts') }
        return $dirs
    }

    $dirs += (Get-SshFontDirectory)
    if (Test-SshMacOS) {
        $dirs += (Join-Path (Get-SshHomePath) 'Library/Fonts')
        $dirs += '/Library/Fonts'
        $dirs += '/System/Library/Fonts'
    }
    else {
        $dirs += (Join-Path (Get-SshHomePath) '.fonts')
        $dirs += '/usr/local/share/fonts'
        $dirs += '/usr/share/fonts'
    }
    return @($dirs | Select-Object -Unique)
}

function Update-SshFontCache {
    if (Test-SshWindows -or Test-SshMacOS) { return }
    if (-not (Get-Command fc-cache -ErrorAction SilentlyContinue)) { return }
    try { & fc-cache -f 2>$null | Out-Null } catch { }
}

function Test-SshCommandExists {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Get-SshEditorCommand {
    foreach ($candidate in @($env:VISUAL, $env:EDITOR)) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        $parts = @($candidate.Trim() -split '\s+')
        $file = $parts[0]
        if (Get-Command $file -ErrorAction SilentlyContinue) {
            return [pscustomobject]@{
                File = $file
                Args = @(if ($parts.Count -gt 1) { $parts[1..($parts.Count - 1)] } else { @() })
            }
        }
    }

    if (Test-SshWindows) {
        return [pscustomobject]@{ File = 'notepad.exe'; Args = @() }
    }
    if (Test-SshMacOS) {
        if (Get-Command open -ErrorAction SilentlyContinue) { return [pscustomobject]@{ File = 'open'; Args = @('-t') } }
    }
    foreach ($candidate in @('xdg-open', 'nano', 'vi')) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            return [pscustomobject]@{ File = $candidate; Args = @() }
        }
    }
    return [pscustomobject]@{ File = 'vi'; Args = @() }
}

function Open-SshTextFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Arquivo nao encontrado: $Path"
    }

    $editor = Get-SshEditorCommand
    $guiEditors = @('notepad.exe', 'notepad', 'open', 'xdg-open')
    if ($guiEditors -contains [System.IO.Path]::GetFileName($editor.File)) {
        try {
            $arguments = @()
            if ($editor.Args) { $arguments += $editor.Args }
            $arguments += $Path
            Start-Process -FilePath $editor.File -ArgumentList $arguments | Out-Null
            return
        }
        catch { }
    }

    if ($editor.Args) { & $editor.File @($editor.Args) $Path }
    else { & $editor.File $Path }
}

function Get-SshModuleVersion {
    if ($script:ModuleVersion) { return [string]$script:ModuleVersion }
    return '1.0.0'
}
