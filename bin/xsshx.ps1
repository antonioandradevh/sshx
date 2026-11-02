# SshThemes launcher used by the Windows and Unix wrappers.
# No param block on purpose: native ssh flags such as -L, -p and -l must be
# forwarded untouched. The xsshx module command does the actual parsing.
$ErrorActionPreference = 'Stop'

# Running from the repository uses the local source; the installed copy falls
# back to the module registered in PSModulePath.
$localModule = Join-Path (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'src') 'SshThemes') 'SshThemes.psd1'
if (Test-Path -LiteralPath $localModule) {
    Import-Module $localModule -Force -DisableNameChecking -WarningAction SilentlyContinue
}
else {
    try {
        Import-Module SshThemes -ErrorAction Stop -DisableNameChecking -WarningAction SilentlyContinue
    }
    catch {
        throw 'Modulo SshThemes nao encontrado. Rode o instalador primeiro (Install.ps1 ou ./install.sh).'
    }
}

xsshx @args
