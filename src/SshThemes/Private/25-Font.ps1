# Nerd Font discovery, per-user installation and Windows Terminal font setup.

$script:SshNerdFontCatalog = [ordered]@{
    Name      = 'JetBrainsMono Nerd Font'
    FileName  = 'JetBrainsMonoNerdFont-Regular.ttf'
    BoldFile  = 'JetBrainsMonoNerdFont-Bold.ttf'
    Url       = 'https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/JetBrainsMono/Ligatures/JetBrainsMonoNerdFont-Regular.ttf'
    BoldUrl   = 'https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/JetBrainsMono/Ligatures/JetBrainsMonoNerdFont-Bold.ttf'
    License   = 'SIL Open Font License 1.1'
}

$script:SshNerdFontPreference = @(
    'JetBrainsMono Nerd Font',
    'CaskaydiaCove Nerd Font',
    'CaskaydiaCove NF',
    'FiraCode Nerd Font',
    '0xProto Nerd Font',
    'Hack Nerd Font',
    'MesloLGS NF'
)

function Get-SshNerdFontInfo {
    [CmdletBinding()]
    param()
    return [pscustomobject]$script:SshNerdFontCatalog
}

function Get-SshFontFamilyName {
    param([Parameter(Mandatory)][string]$Path)

    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $collection = New-Object System.Drawing.Text.PrivateFontCollection
        try {
            $collection.AddFontFile($Path)
            if ($collection.Families.Count -gt 0) { return $collection.Families[0].Name }
        }
        finally {
            $collection.Dispose()
        }
    }
    catch { }
    return $null
}

function Get-SshFontRegistryEntries {
    param([ValidateSet('User', 'Machine')][string]$Scope = 'User')

    $path = if ($Scope -eq 'User') {
        'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    }
    else {
        'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    }

    if (-not (Test-Path -LiteralPath $path)) { return @() }

    $result = @()
    $item = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
    if (-not $item) { return @() }

    foreach ($prop in $item.PSObject.Properties) {
        if ($prop.Name -like 'PS*') { continue }
        if ($prop.Name -notmatch 'Nerd Font') { continue }
        $file = [string]$prop.Value
        if ([string]::IsNullOrWhiteSpace($file)) { continue }
        if (-not [System.IO.Path]::IsPathRooted($file)) {
            $file = Join-Path (Join-Path $env:WINDIR 'Fonts') $file
        }
        $result += [pscustomobject]@{
            Name   = ($prop.Name -replace '\s*\(TrueType\)\s*$', '')
            Path   = $file
            Scope  = $Scope
            Exists = (Test-Path -LiteralPath $file)
        }
    }

    return $result
}

function Get-SshNerdFont {
    [CmdletBinding()]
    param()

    $fonts = @()
    $fonts += Get-SshFontRegistryEntries -Scope User
    $fonts += Get-SshFontRegistryEntries -Scope Machine

    $userFontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    if (Test-Path -LiteralPath $userFontDir) {
        $known = @($fonts | ForEach-Object { $_.Path })
        Get-ChildItem -LiteralPath $userFontDir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @('.ttf', '.otf') } |
            Where-Object { $_.Name -match 'NerdFont|Nerd Font' } |
            ForEach-Object {
                if ($known -contains $_.FullName) { return }
                $family = Get-SshFontFamilyName -Path $_.FullName
                if (-not $family) { return }
                $fonts += [pscustomobject]@{
                    Name   = $family
                    Path   = $_.FullName
                    Scope  = 'User'
                    Exists = $true
                }
            }
    }

    $fonts = @($fonts | Where-Object { $_.Exists } | Sort-Object -Property Name -Unique)
    $ranked = @()
    foreach ($font in $fonts) {
        $rank = [array]::IndexOf($script:SshNerdFontPreference, $font.Name)
        if ($rank -lt 0) { $rank = 999 }
        $ranked += [pscustomobject]@{
            Name   = $font.Name
            Path   = $font.Path
            Scope  = $font.Scope
            Exists = $font.Exists
            Rank   = $rank
        }
    }

    return @($ranked | Sort-Object -Property Rank, Name)
}

function Test-SshNerdFont {
    [CmdletBinding()]
    param([string]$Name)

    $fonts = @(Get-SshNerdFont)
    if ($Name) {
        return [bool](@($fonts | Where-Object { $_.Name -eq $Name }).Count -gt 0)
    }
    return [bool]($fonts.Count -gt 0)
}

function Register-SshFontFile {
    param([Parameter(Mandatory)][string]$Path)

    $family = Get-SshFontFamilyName -Path $Path
    if (-not $family) { $family = [System.IO.Path]::GetFileNameWithoutExtension($Path) }

    $regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    if (-not (Test-Path -LiteralPath $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    New-ItemProperty -Path $regPath -Name "$family (TrueType)" -Value $Path -PropertyType String -Force | Out-Null

    try {
        if (-not ('SshThemes.NativeFont' -as [type])) {
            Add-Type -Namespace SshThemes -Name NativeFont -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern int AddFontResource(string lpFileName);
[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);
'@
        }
        [void][SshThemes.NativeFont]::AddFontResource($Path)
        [void][SshThemes.NativeFont]::SendMessage([IntPtr]0xffff, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero)
    }
    catch { }
}

function Install-SshNerdFont {
    [CmdletBinding()]
    param(
        [string]$Name = 'JetBrainsMono Nerd Font',
        [switch]$Force,
        [switch]$DryRun,
        [switch]$PassThru
    )

    $installed = @(Get-SshNerdFont)
    if (-not $Force -and $installed.Count -gt 0) {
        $chosen = @($installed | Where-Object { $_.Name -eq $Name })
        if ($chosen.Count -eq 0) { $chosen = @($installed[0]) }
        Write-Host ("  Nerd Font ja instalada: " + $chosen[0].Name) -ForegroundColor DarkGray
        if ($PassThru) { return $chosen[0] }
        return
    }

    $catalog = Get-SshNerdFontInfo
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'

    if ($DryRun) {
        Write-Host ("  [dry-run] instalaria " + $catalog.Name + " em " + $fontDir) -ForegroundColor DarkGray
        Write-Host ("  [dry-run] baixaria " + $catalog.Url) -ForegroundColor DarkGray
        if ($PassThru) {
            return [pscustomobject]@{
                Name  = $catalog.Name
                Path  = (Join-Path $fontDir $catalog.FileName)
                Scope = 'User'
                DryRun = $true
            }
        }
        return
    }

    if (-not (Test-Path -LiteralPath $fontDir)) {
        New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
    }

    $files = @(
        @{ File = $catalog.FileName; Url = $catalog.Url },
        @{ File = $catalog.BoldFile; Url = $catalog.BoldUrl }
    )

    foreach ($entry in $files) {
        $destination = Join-Path $fontDir $entry.File
        if (-not (Test-Path -LiteralPath $destination)) {
            Write-Host ("  baixando " + $entry.File + "...") -ForegroundColor DarkGray
            Invoke-WebRequest -Uri $entry.Url -OutFile $destination -UseBasicParsing -TimeoutSec 180
        }
        Register-SshFontFile -Path $destination
    }

    $regular = Join-Path $fontDir $catalog.FileName
    $family = Get-SshFontFamilyName -Path $regular
    if (-not $family) { $family = $catalog.Name }

    Write-Host ("  Nerd Font instalada: " + $family) -ForegroundColor Green

    if ($PassThru) {
        return [pscustomobject]@{
            Name  = $family
            Path  = $regular
            Scope = 'User'
        }
    }
}

function Get-SshTerminalSettingsPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

function Set-SshTerminalFont {
    [CmdletBinding()]
    param(
        [string]$Name,
        [switch]$Reset,
        [switch]$Force,
        [switch]$DryRun,
        [switch]$PassThru
    )

    $settingsPath = Get-SshTerminalSettingsPath

    if ($Reset) {
        if (-not $settingsPath) {
            Write-Host '  Windows Terminal nao encontrado; fonte nao alterada.' -ForegroundColor Yellow
            return
        }
        if ($DryRun) {
            Write-Host ("  [dry-run] removeria a fonte personalizada de " + $settingsPath) -ForegroundColor DarkGray
            if ($PassThru) { return [pscustomobject]@{ Path = $settingsPath; Face = $null; Reset = $true; DryRun = $true } }
            return
        }

        $rawReset = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8
        try { $dataReset = $rawReset | ConvertFrom-Json }
        catch { throw "Nao consegui interpretar $settingsPath. Ajuste a fonte manualmente." }

        if ($dataReset.profiles -and $dataReset.profiles.defaults -and $dataReset.profiles.defaults.PSObject.Properties['font']) {
            $fontReset = $dataReset.profiles.defaults.font
            if ($fontReset -and $fontReset.PSObject.Properties['face']) {
                $fontReset.PSObject.Properties.Remove('face')
            }
            if (-not $fontReset -or @($fontReset.PSObject.Properties).Count -eq 0) {
                $dataReset.profiles.defaults.PSObject.Properties.Remove('font')
            }
        }

        $backupReset = $settingsPath + '.sshthemes.bak'
        if (-not (Test-Path -LiteralPath $backupReset)) {
            Copy-Item -LiteralPath $settingsPath -Destination $backupReset -Force
        }
        $dataReset | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
        Write-Host '  fonte do Windows Terminal restaurada para o padrao.' -ForegroundColor Green
        if ($PassThru) { return [pscustomobject]@{ Path = $settingsPath; Face = $null; Reset = $true; Backup = $backupReset } }
        return
    }

    if (-not $Name) {
        $font = Get-SshNerdFont | Select-Object -First 1
        if (-not $font) {
            throw 'Nenhuma Nerd Font instalada. Rode Install-SshNerdFont primeiro.'
        }
        $Name = $font.Name
    }

    if (-not $settingsPath) {
        Write-Host '  Windows Terminal nao encontrado; fonte nao configurada.' -ForegroundColor Yellow
        return
    }

    if ($DryRun) {
        Write-Host ("  [dry-run] configuraria a fonte '" + $Name + "' em " + $settingsPath) -ForegroundColor DarkGray
        if ($PassThru) {
            return [pscustomobject]@{ Path = $settingsPath; Face = $Name; DryRun = $true }
        }
        return
    }

    $raw = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8
    try {
        $data = $raw | ConvertFrom-Json
    }
    catch {
        throw "Nao consegui interpretar $settingsPath. Ajuste a fonte manualmente para '$Name'."
    }

    if (-not $data.PSObject.Properties['profiles'] -or -not $data.profiles) {
        $data | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    if (-not $data.profiles.PSObject.Properties['defaults'] -or -not $data.profiles.defaults) {
        $data.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force
    }

    $defaults = $data.profiles.defaults
    if (-not $defaults.PSObject.Properties['font'] -or -not $defaults.font) {
        $defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{}) -Force
    }

    $font = $defaults.font
    $current = if ($font.PSObject.Properties['face']) { [string]$font.face } else { '' }
    if ($current -and -not $Force) {
        Write-Host ("  Windows Terminal ja usa a fonte '" + $current + "'.") -ForegroundColor DarkGray
        if ($PassThru) { return [pscustomobject]@{ Path = $settingsPath; Face = $current } }
        return
    }

    if ($font.PSObject.Properties['face']) {
        $font.face = $Name
    }
    else {
        $font | Add-Member -NotePropertyName face -NotePropertyValue $Name -Force
    }

    $backup = $settingsPath + '.sshthemes.bak'
    Copy-Item -LiteralPath $settingsPath -Destination $backup -Force
    $data | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
    Write-Host ("  Windows Terminal configurado com a fonte '" + $Name + "'.") -ForegroundColor Green
    Write-Host ("  backup: " + $backup) -ForegroundColor DarkGray

    if ($PassThru) {
        return [pscustomobject]@{ Path = $settingsPath; Face = $Name; Backup = $backup }
    }
}
