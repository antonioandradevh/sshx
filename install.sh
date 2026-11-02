#!/usr/bin/env sh
# SshThemes installer for Linux and macOS.
# Ensures PowerShell 7 (pwsh) is available, then runs the cross-platform
# Install.ps1 with every argument forwarded unchanged.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INSTALL_PS1="$SCRIPT_DIR/Install.ps1"

usage() {
    cat <<'EOF'
SshThemes installer (Linux/macOS)

Uso:
  ./install.sh [opcoes do Install.ps1]

Opcoes uteis:
  -DryRun            mostra o que seria feito, sem alterar nada
  -SkipProfile       nao mexe no perfil do PowerShell
  -NoFont            nao instala Nerd Font
  -NoTerminalFont    instala a fonte, mas nao configura o terminal
  -NoLauncher        nao cria ~/.local/bin/sshx e ~/.local/bin/s3x
  -FontName <nome>   usa outra Nerd Font ja instalada
  -Force             reescreve o bloco do perfil
  -WindowsTerminal   ignorado fora do Windows

Exemplos:
  ./install.sh
  ./install.sh -DryRun
  ./install.sh -NoFont -NoLauncher
EOF
}

case "${1:-}" in
    -h|--help|help)
        usage
        exit 0
        ;;
esac

if [ ! -f "$INSTALL_PS1" ]; then
    echo "Install.ps1 nao encontrado em $SCRIPT_DIR" >&2
    exit 1
fi

find_pwsh() {
    if command -v pwsh >/dev/null 2>&1; then
        command -v pwsh
        return 0
    fi
    for candidate in /usr/bin/pwsh /usr/local/bin/pwsh /opt/microsoft/powershell/7/pwsh /snap/bin/pwsh; do
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

install_pwsh() {
    os=$(uname -s 2>/dev/null || echo unknown)
    case "$os" in
        Darwin)
            if command -v brew >/dev/null 2>&1; then
                echo "pwsh nao encontrado; instalando com Homebrew..."
                brew install --cask powershell
            else
                echo "pwsh nao encontrado; usando o instalador oficial da Microsoft..."
                if command -v curl >/dev/null 2>&1; then
                    curl -fsSL https://aka.ms/install-powershell.sh | bash
                elif command -v wget >/dev/null 2>&1; then
                    wget -qO- https://aka.ms/install-powershell.sh | bash
                else
                    echo "curl ou wget e necessario para instalar o PowerShell." >&2
                    return 1
                fi
            fi
            ;;
        Linux)
            echo "pwsh nao encontrado; usando o instalador oficial da Microsoft..."
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL https://aka.ms/install-powershell.sh | bash
            elif command -v wget >/dev/null 2>&1; then
                wget -qO- https://aka.ms/install-powershell.sh | bash
            else
                echo "curl ou wget e necessario para instalar o PowerShell." >&2
                return 1
            fi
            ;;
        *)
            echo "Sistema nao suportado: $os (use Windows, Linux ou macOS)." >&2
            return 1
            ;;
    esac
}

PWSH=$(find_pwsh || true)
if [ -z "${PWSH:-}" ]; then
    install_pwsh
    hash -r 2>/dev/null || true
    PWSH=$(find_pwsh || true)
fi

if [ -z "${PWSH:-}" ]; then
    cat >&2 <<'EOF'
Nao consegui encontrar o pwsh depois da instalacao.

Instale o PowerShell 7 manualmente:
  https://learn.microsoft.com/powershell/scripting/install/installing-powershell

Depois rode novamente:
  ./install.sh
EOF
    exit 1
fi

echo "SshThemes: usando $PWSH"
exec "$PWSH" -NoLogo -NoProfile -File "$INSTALL_PS1" "$@"
