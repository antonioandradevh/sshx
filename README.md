# SshThemes

Terminal SSH com **tema por dispositivo** no PowerShell, agora em Windows, Linux e macOS. Ao conectar, o SshThemes descobre o que ha do outro lado (Debian, Ubuntu, Alpine, Amazon Linux, EC2, S3, Windows...) e veste a sessao com as cores, icones e o prompt daquele sistema. Tudo e editavel: hex, icones, o que aparece no prompt, tempo de cada comando, fundo do terminal e o formato dos diretorios.

```
+------------------------------------------------------------------+
| <icone> DEBIAN                                               SSH |
| ---------------------------------------------------------------- |
| destino   root@host.example                                      |
| host      host.example:22                                        |
| usuario   root                                                   |
| sistema   Debian GNU/Linux                                       |
| tema      Debian  #A81D33 ##                                     |
| sessao    2026-10-24 06:32:54  text                              |
| -Type <tema> forca o tema  -  exit encerra a sessao              |
+------------------------------------------------------------------+
<icone>  root@host.example  ~/projetos/app  main  128 ms
>
```

`<icone>` e o glifo Nerd Font do dispositivo (Debian, Ubuntu, Windows...). Por padrao e o unico icone do prompt.

## O que ele faz

- **Detecta o dispositivo remoto** por `/etc/os-release`, `uname`, hostname e padroes do `~/.ssh/config`.
- **Aplica um tema por tipo**: Debian vermelho, Ubuntu laranja, Alpine azul, AWS laranja, S3 com icone de banco, Windows azul etc.
- **Trava o tema em um IP/host** com `-lock`: o lock vence cache e deteccao.
- **Personaliza o terminal**: titulo da aba, banner e cores. No modo `auto` (padrao), temas com fundo proprio repintam foreground/background/cursor; temas sem fundo mudam so o texto.
- **Prompt limpo**: dispositivo, `usuario@host`, diretorio, branch git, **duracao do ultimo comando** e codigo de saida. Por padrao so o **icone do sistema** aparece.
- **Comandos com dash**: `-font`, `-icons`, `-color`, `-distros`, `-lock`, `-unlock`, `-bg`, `-set`, `-get`, `-edit`, `-reset` e `-help`.
- **Flags nativas do ssh**: `xsshx -X`, `xsshx host -L 8080:localhost:80`, `xsshx -l root -p 2222 host` etc. passam direto para o `ssh`.
- **Workspace S3**: `awsx s3://bucket/prefixo` abre um ambiente AWS CLI com o tema S3 e atalhos `s3ls`, `s3get`, `s3put`, `s3sync`, `s3rm`.
- **Tema remoto no bash**: injeta automaticamente o prompt do tema no shell remoto; pode ser desligado com `-NoRemoteTheme`.
- **Tudo configuravel**: comandos com dash, cmdlets ou edicao direta dos JSONs em `~/.sshthemes`.

## Requisitos

- **Windows 10/11** com PowerShell 5.1 ou PowerShell 7+.
- **Linux/macOS** com PowerShell 7+ (`pwsh`). O `install.sh` instala o `pwsh` se necessario.
- **OpenSSH Client** (`ssh`) no PATH.
- Terminal com ANSI. O prompt cai para modo texto sem cor se ANSI nao estiver disponivel.
- Opcional: **AWS CLI** para o workspace S3.
- A **Nerd Font** e instalada automaticamente pelo instalador (JetBrainsMono Nerd Font). Se ja existir uma Nerd Font, ela e reaproveitada.

## Instalacao

### Windows

```powershell
# na pasta do projeto
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1

# opcional: cria tambem o perfil "SSH Themes" no Windows Terminal
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -WindowsTerminal

# veja o que seria feito, sem alterar nada
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -DryRun

# nao mexa em fontes / no terminal
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -NoFont
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -NoTerminalFont

# escolha outra Nerd Font ja instalada
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -FontName 'CaskaydiaCove Nerd Font'
```

### Linux e macOS

```sh
chmod +x install.sh
./install.sh

# veja o que seria feito
./install.sh -DryRun

# sem fonte e sem launchers
./install.sh -NoFont -NoLauncher

# ajuda
./install.sh --help
```

O `install.sh`:

1. detecta Linux ou macOS;
2. procura o `pwsh` e, se nao encontrar, usa o instalador oficial da Microsoft (ou Homebrew no macOS);
3. executa o `Install.ps1` com todos os argumentos encaminhados.

O instalador:

- copia o modulo para os diretorios de modulos do usuario:
  - Windows: `Documents\WindowsPowerShell\Modules\SshThemes` e, se houver `pwsh`, `Documents\PowerShell\Modules\SshThemes`;
  - Linux/macOS: `~/.local/share/powershell/Modules/SshThemes`;
- adiciona um bloco idempotente no perfil do PowerShell;
- instala uma **Nerd Font** por usuario:
  - Windows: `%LOCALAPPDATA%\Microsoft\Windows\Fonts` e registro em `HKCU`;
  - Linux: `~/.local/share/fonts` (ou `$XDG_DATA_HOME/fonts`);
  - macOS: `~/Library/Fonts`;
- no Windows, ajusta `profiles.defaults.font.face` no `settings.json` do Windows Terminal (com backup em `settings.json.sshthemes.bak`);
- no Linux/macOS, cria `~/.local/bin/xsshx` e `~/.local/bin/s3x` executaveis;
- grava os metadados em `~/.sshthemes/install.json`.

Abra um novo terminal e teste:

```powershell
-distros
-distros debian
xsshx root@10.0.0.5 -DryRun
```

## Uso rapido

```powershell
# conectar (detecta o tipo automaticamente)
xsshx root@192.168.0.20

# forcar um tema quando a deteccao nao ajuda (ex.: servidor sem chave)
xsshx root@10.0.0.5 -Type debian

# travar o tema naquele IP/host
xsshx 10.0.0.5 -Lock debian
xsshx 10.0.0.5 -Unlock

# alias registrado
Register-SshDevice -Name lab01 -HostName 10.10.10.10 -User admin -Port 2200 -Type debian -Label "Lab 01"
xsshx lab01

# ver o banner e o prompt sem conectar
xsshx lab01 -DryRun

# workspace S3 com tema AWS (somente texto)
awsx s3://meu-bucket/backups

# dentro do workspace S3
s3ls
s3ls 2026/ -Recursive
s3get backups/db.dump .\db.dump
s3put .\relatorio.pdf relatorios/2026/relatorio.pdf
s3sync .\site\ -Prefix site
s3sync .\restore\ -Prefix site -Download
exitssh

# personalizar sem editar JSON
-help
```

`xsshx` e um wrapper: ele entende as opcoes do SshThemes e **encaminha qualquer outra flag para o ssh**. `Connect-SshDevice` continua disponivel para scripts; para flags nativas nele, use `-SshArgument`.

## Flags nativas do ssh

O `xsshx` aceita as flags do OpenSSH sem reinterpretar:

```powershell
xsshx -X root@10.0.0.5                 # X11 forwarding
xsshx -A root@10.0.0.5                 # agent forwarding
xsshx -4 root@10.0.0.5                 # so IPv4
xsshx root@10.0.0.5 -L 8080:localhost:80
xsshx root@10.0.0.5 -R 9000:localhost:9000
xsshx root@10.0.0.5 -D 1080
xsshx -J bastion root@10.0.0.5         # ProxyJump
xsshx -o StrictHostKeyChecking=no root@10.0.0.5
xsshx -l root -p 2222 10.0.0.5         # usuario e porta no estilo ssh
xsshx -i ~/.ssh/id_ed25519 root@10.0.0.5
```

As flags `-l`, `-p` e `-i` tambem sao lidas pelo SshThemes para montar o banner, a deteccao e o prompt; o restante e passado intacto.

O `ssh` nativo continua funcionando normalmente (`ssh -X host`, `ssh -L ...`). Use `xsshx` quando quiser o mesmo comando **com** o tema aplicado.

Para um comando remoto, use `-Command`:

```powershell
xsshx root@10.0.0.5 -Command "uptime && df -h"
```

## Como a deteccao funciona

Ordem de prioridade:

1. `-Type` explicito.
2. **Lock** do host/IP (`lockedType` em `hosts.json`).
3. Tipo salvo no registro de dispositivos (`type`).
4. Cache da ultima deteccao (`detectedType`, valido por `detect.cacheDays`, padrao 30 dias).
5. Sonda SSH: le `/etc/os-release`, `uname`, `hostname` e a presenca do `aws`.
6. Padroes de hostname (`ec2-*.amazonaws.com`, `*.s3.amazonaws.com`, `deb*` etc.).
7. Tema `generic`.

A sonda usa `BatchMode=yes`, `NumberOfPasswordPrompts=0` e `ConnectTimeout` configuravel. Ou seja: **ela nao pede senha**. Se o host so aceita senha, a deteccao cai para hostname/generic e voce pode usar `-Type` uma vez ou travar o tema com `-Lock`.

Por padrao a sonda aceita host novo na primeira conexao (`accept-new`). Para exigir que o host ja esteja em `known_hosts`:

```powershell
Set-SshSetting -DetectStrictHostKeys $true
Set-SshSetting -DetectStrictHostKeys $false   # volta ao padrao
```

Cada tema tem regras em `detect`:

```json
"debian": {
  "detect": {
    "osIds": ["debian"],
    "idLike": ["debian"],
    "hostPatterns": ["(^|[-.])deb"]
  }
}
```

Voce pode adicionar `hostContains`, `uname` e `targetSchemes` no mesmo objeto.

## Temas incluidos

| Tema | Hex principal | Icone (Nerd Font) | Detecta |
| --- | --- | --- | --- |
| `local` | `#4CC2FF` | Windows | prompt local |
| `debian` | `#A81D33` | Debian | Debian |
| `ubuntu` | `#E95420` | Ubuntu | Ubuntu |
| `raspbian` | `#C51A4A` | Raspberry | Raspberry Pi OS |
| `alpine` | `#0D597F` | Alpine | Alpine |
| `fedora` | `#51A2DA` | Fedora | Fedora |
| `rhel` | `#EE0000` | Red Hat | RHEL / Red Hat |
| `centos` | `#A14F9F` | CentOS | CentOS |
| `rocky` | `#10B981` | Rocky | Rocky Linux |
| `alma` | `#F59E0B` | Alma | AlmaLinux |
| `arch` | `#1793D1` | Arch | Arch / Manjaro |
| `opensuse` | `#73BA25` | SUSE | openSUSE / SLES |
| `gentoo` | `#8E7CC3` | Gentoo | Gentoo |
| `kali` | `#557C94` | Kali | Kali |
| `amazon` | `#FF9900` | Amazon | Amazon Linux |
| `aws` | `#FF9900` | AWS | AWS / EC2 |
| `s3` | `#FF9900` | S3 | `s3://`, hosts S3 |
| `windows` | `#0078D4` | Windows | Windows OpenSSH |
| `proxmox` | `#E57000` | Proxmox | Proxmox VE |
| `generic` | `#8A8A8A` | Linux | Linux desconhecido |

Os codepoints sao glifos Nerd Font: aparecem corretos quando a fonte do terminal e uma Nerd Font (`-font` cuida disso). `Show-SshThemes -Detailed` mostra todos com nota e se foram customizados.

## Comandos com dash

Sao aliases do modulo: digite direto no PowerShell, sem chamar `Invoke-Ssh...`.

```powershell
-help                     # resumo de tudo
-font                     # fonte atual + Nerd Fonts instaladas
-icons                    # estado de cada icone do prompt
-color debian             # todas as cores do tema Debian
-distros                  # lista os temas disponiveis
-lock                     # lista os locks
-bg                       # lista o modo do terminal e o fundo de cada tema
```

### `-font`

| Comando | O que faz |
| --- | --- |
| `-font` | mostra a fonte do terminal e as Nerd Fonts instaladas |
| `-font list` | lista as Nerd Fonts (com o escopo: usuario/maquina) |
| `-font set <nome>` | define a fonte do Windows Terminal (faz backup do `settings.json`) |
| `-font install` | baixa e instala a JetBrainsMono Nerd Font por usuario |
| `-font reset` | remove a fonte personalizada e volta ao padrao |
| `-font test` | imprime os glifos ativos do prompt para conferir a fonte |

```powershell
-font set "0xProto Nerd Font"
-font set "JetBrainsMono Nerd Font"
```

No Linux/macOS o arquivo da fonte e instalado no diretorio correto, mas a escolha da fonte no terminal (GNOME Terminal, Konsole, Alacritty, kitty, Terminal.app, iTerm2) continua manual. `-font set` avisa isso.

### `-icons`

| Comando | O que faz |
| --- | --- |
| `-icons` | mostra o estado de cada parte (sistema, usuario, pasta, git, tempo, relogio, status) |
| `-icons on` / `-icons off` | liga/desliga todos os icones de uma vez |
| `-icons <parte> on` / `off` | liga/desliga so uma parte |
| `-icons nerd` / `-icons ascii` | troca o conjunto de glifos |
| `-icons reset` | volta ao padrao: somente o icone do sistema |

Partes aceitas: `device`, `user`, `path`, `git`, `duration`, `clock`, `exit`.

```powershell
-icons path on
-icons duration on
-icons exit on
-icons reset
```

### `-color`

| Comando | O que faz |
| --- | --- |
| `-color` | lista todos os temas com `accent` e `accent2` |
| `-color <tema>` | mostra accent, accent2, foreground, background, cursor e as cores do prompt |
| `-color <tema> <chave> <hex>` | troca uma cor do tema |
| `-color <tema> background none` | remove o fundo do tema |
| `-color reset <tema>` | restaura o tema inteiro para o padrao |

```powershell
-color debian accent E95420          # hex sem #
-color debian accent "#E95420"       # com # precisa de aspas
-color debian path 8BE9FD            # cores do prompt usam a chave direta
-color debian background 1B0A0F
-color reset debian
```

O `#` sem aspas inicia um comentario no PowerShell, por isso o comando aceita `RRGGBB` puro.

Chaves aceitas: `accent`, `accent2`, `foreground`, `background`, `cursor` e as do prompt (`user`, `host`, `path`, `git`, `muted`, `durationFast`, `durationWarn`, `durationSlow`, `exitOk`, `exitFail`).

### `-distros`

| Comando | O que faz |
| --- | --- |
| `-distros` | lista os temas de distros/dispositivos (hex, badge e se esta customizado) |
| `-distros <nome>` | previsualiza o tema sem aplicar |
| `-distros set <nome>` | define o tema padrao (usado quando nao ha deteccao) |
| `-distros reset <nome>` | restaura o tema para o padrao de fabrica |
| `-distros custom <nome>` | abre o JSON do tema no editor para editar tudo |

```powershell
-distros set debian
-distros ubuntu
-distros custom s3
```

### `-lock` e `-unlock`

Travam o tema em um IP ou host. O lock vence cache, sonda e tipo salvo.

```powershell
-lock 10.0.0.5 debian        # IP -> Debian
-lock srv01 ubuntu           # alias/host -> Ubuntu
-lock debian 10.0.0.5        # a ordem tambem pode ser tema + host
-lock                        # lista os locks
-lock 10.0.0.5               # mostra o lock daquele host
-unlock 10.0.0.5             # remove o lock
-unlock all                  # remove todos
```

O lock fica em `~/.sshthemes/hosts.json` (`lockedType`, `lockedAt`, `lock`). Se o host nao estiver registrado, ele entra no registro automaticamente.

### `-bg` (fundo do terminal)

| Comando | O que faz |
| --- | --- |
| `-bg` | lista o modo do terminal e o fundo de cada tema |
| `-bg off` / `-bg text` | nunca troca o fundo do terminal |
| `-bg auto` / `-bg on` | respeita o fundo de cada tema (padrao) |
| `-bg full` | sempre aplica fg/bg/cursor |
| `-bg <tema> off` | remove o fundo daquele tema |
| `-bg <tema> <hex>` | define o fundo daquele tema |
| `-bg <tema> reset` | volta o fundo ao padrao |
| `-bg all off` | remove o fundo de todos os temas |
| `-bg all reset` | restaura o fundo de todos os temas |

```powershell
-bg debian off
-bg debian 1B0A0F
-bg ubuntu reset
-bg off
-bg auto
```

### `-set`, `-get`, `-edit` e `-reset`

Editam qualquer campo de tema, setting ou device.

```powershell
# tema
-set theme debian prompt.path "#FFFFFF"
-set theme debian background none
-set theme debian detect.hostPatterns '["^deb","^lab"]'
-set theme debian icons.path "X"

# setting
-set setting terminal.mode text
-set setting prompt.icons false
-set setting path.maxSegments 3
-set setting detect.cacheDays 7

# device
-set device lab01 label "Lab 01"
-set device lab01 type debian
-set device lab01 port 2200

# atalho: caminho de setting direto
-set prompt.separator "  "

# consultar
-get setting terminal.mode
-get theme debian prompt.path
-get device lab01
-get lock 10.0.0.5

# editar no editor (VISUAL/EDITOR ou notepad)
-edit theme debian
-edit settings
-edit themes
-edit hosts
-edit glyphs

# restaurar
-reset theme debian
-reset settings
-reset locks
-reset all
```

Valores aceitam `true`, `false`, numeros, `null`/`none`, JSON (`[...]` ou `{...}`) e listas separadas por virgula.

> Depois de alterar arquivos do modulo, recarregue com
> `Remove-Module SshThemes -Force -ErrorAction SilentlyContinue; Import-Module SshThemes -Force -DisableNameChecking`.

## Personalizacao com cmdlets

### Trocar hex e icone de um tipo

```powershell
Set-SshTheme -Name debian -Accent "#FF0077"

Set-SshTheme -Name debian `
  -Accent "#B00020" `
  -Accent2 "#FF5C8A" `
  -Icon ([string][char]0xF306) `
  -Note "Debian do laboratorio"

Set-SshTheme -Name debian -Icons @{
  path     = [string][char]0xF07B
  git      = [string][char]0xF126
  duration = [string][char]0xF2F2
  ok       = [string][char]0xF00C
}

Set-SshTheme -Name debian -PromptColors @{
  user         = "#FF8FB3"
  host         = "#FF3355"
  path         = "#F8F8F2"
  git          = "#8BE9FD"
  durationFast = "#50FA7B"
  durationWarn = "#F1FA8C"
  durationSlow = "#FF5555"
  exitOk       = "#50FA7B"
  exitFail     = "#FF5555"
}

Set-SshTheme -Name debian -Reset
```

Os overrides ficam em `~/.sshthemes/themes.json`; os padroes continuam no modulo. Assim voce nao perde suas mudancas ao atualizar.

### Criar um tema para um SSH que nao existe na lista

```powershell
New-SshTheme -Name "meu-nas" `
  -Label "NAS da sala" `
  -Accent "#00C2A8" `
  -Accent2 "#5CFFE8" `
  -Icon ([string][char]0xF1C0) `
  -BadgeText "NAS" `
  -Detect @{ hostPatterns = @("^nas-", "192\.168\.1\.50$") } `
  -PromptColors @{ path = "#B8FFF5" }
```

O tema entra no catalogo, na deteccao e no banner automaticamente.

### Editar o JSON direto

```powershell
-edit themes     # ou settings, hosts, glyphs
-edit theme debian
Reload-SshConfig
```

`Edit-SshTheme -Name debian` materializa o tema inteiro em `themes.json` e abre no editor, otimo para copiar e ajustar.

### Configuracoes globais

```powershell
Set-SshSetting -Show @{
  clock    = $false
  duration = $true
  exitCode = $true
  git      = $true
  path     = $true
}

Set-SshSetting -DurationWarnMs 1500 -DurationSlowMs 5000 -DurationPrecision 2

Set-SshSetting -PathStyle smart -MaxPathSegments 4 -PathIcons $false
Set-SshSetting -PromptIcons $true
Set-SshSetting -IconParts @{ device = $true; path = $true; duration = $false }
Set-SshSetting -DirectoryIcons @{
  ".git"         = [string][char]0xF1D3
  "node_modules" = [string][char]0xF1B3
  "Downloads"    = [string][char]0xF019
}

Set-SshSetting -ClockFormat "HH:mm:ss" -BannerWidth 72 -Multiline $true -Separator "  "

Set-SshSetting -TerminalMode auto
Set-SshSetting -TerminalMode full
Set-SshSetting -TerminalMode text

Set-SshSetting -TerminalResetOnExit $true
Set-SshSetting -GlyphSet nerd
Set-SshSetting -GlyphSet emoji
Set-SshSetting -GlyphSet ascii

Set-SshSetting -DetectProbe $true -DetectTimeoutSeconds 6 -DetectStrictHostKeys $false
Set-SshSetting -RemoteAutoTheme $true
Set-SshSetting -S3Profile producao -S3Region us-east-1

Disable-SshThemePrompt
Enable-SshThemePrompt

Set-SshSetting -Reset
```

Consulte um valor com `Get-SshSetting show.duration` ou o objeto inteiro com `Get-SshSetting`.

### Modo auto, texto e full

O padrao e `auto`: cada tema decide. Temas com `background` no JSON (Debian, Ubuntu, Fedora etc.) repintam foreground, background e cursor do terminal; temas sem `background` (S3, AWS, generic, local) mantem o visual do seu terminal e mudam apenas banner, titulo e prompt.

```powershell
Set-SshSetting -TerminalMode auto
Set-SshSetting -TerminalMode text
Set-SshSetting -TerminalMode full

xsshx s3://bucket -FullTheme
xsshx debian-host -NoBackground
```

As cores sao enviadas com OSC 10/11/12 e restauradas ao sair (ou com OSC 110/111/112). Funciona no Windows Terminal, VS Code e terminais com suporte a OSC.

## O prompt

```
<icone>  root@srv01  ~/app/src  main  1.24 s
>
```

- **Somente o icone do sistema por padrao**: o unico icone e o do dispositivo. Tempo, pasta, usuario, git e status ficam sem icone. `-icons path on` liga cada parte; `-icons off` desliga tudo.
- **Duracao**: vem de `StartExecutionTime`/`EndExecutionTime` do historico do PowerShell, medida real do comando (sem contar o tempo digitando).
- **Conclusao**: comando nativo usa `$LASTEXITCODE`; cmdlets usam o `ExecutionStatus` do historico. Sucesso nao adiciona nada; falha mostra `exit 1`.
- **Cores da duracao**: `durationFast`, `durationWarn` e `durationSlow` definem os limites visuais.
- **Diretorios**: `path.style` aceita `smart` (padrao), `full` ou `leaf`; `directoryIcons` usa nome exato ou curinga.
- **Git**: le `.git/HEAD` subindo diretorios, sem executar `git` a cada prompt.

Tudo isso pode ser desligado individualmente em `show`.

## Registro de dispositivos

```powershell
Register-SshDevice -Name srv01 -HostName 10.0.0.5 -User root -Type debian -Label "Web"
Register-SshDevice -Name srv02 -HostName 10.0.0.6 -SshAlias srv02-prod
Get-SshDevice
Show-SshDevices
Remove-SshDevice -Name srv02
```

`hosts.json` guarda tambem o ultimo tipo detectado (`detectedType`), o `osName`, o hostname remoto, a data e o lock (`lockedType`). Hosts descobertos por conexao direta entram ali automaticamente.

## Workspace S3 / AWS

```powershell
awsx s3://meu-bucket/backups
# ou
s3x -Bucket meu-bucket -Prefix backups -Profile producao -Region us-east-1
```

O workspace:

- aplica o tema `s3` (laranja AWS, icone de banco de dados);
- define `AWS_PROFILE`, `AWS_REGION`, `AWS_DEFAULT_REGION` e, se informado, `AWS_ENDPOINT_URL`;
- cria atalhos globais:

| Comando | O que faz |
| --- | --- |
| `s3ls [path] [-Recursive]` | lista o bucket/prefixo |
| `s3get <key> [destino]` | baixa um objeto |
| `s3put <arquivo> [key]` | envia um arquivo |
| `s3sync <pasta> [-Prefix key] [-Download] [-Delete]` | sincroniza |
| `s3rm <key> [-Recursive]` | remove |
| `s3uri [key]` | mostra a URI final |
| `exitssh` | restaura o tema, as variaveis de ambiente e o prompt |

O tema vale para o prompt e para o banner; a saida do `aws` continua com as cores normais da AWS CLI.

## Tema remoto no bash

O prompt que aparece depois do login SSH vem do shell remoto, nao do PowerShell. Por isso o SshThemes injeta automaticamente um rc de bash com o tema do dispositivo na conexao (padrao: ligado).

```powershell
xsshx srv01
xsshx srv01 -NoRemoteTheme
Set-SshSetting -RemoteAutoTheme $false
Install-SshRemoteTheme -Target srv01
```

O rc e enviado em uma unica conexao para `~/.config/sshthemes/rc` e executado com `bash --rcfile ...`. Se o servidor nao tiver `bash`, a conexao cai para o shell padrao. O `.bashrc` remoto e carregado antes do prompt do SshThemes.

A injecao vale para qualquer tema de servidor, inclusive `s3` e `aws`. Ficam de fora apenas `windows`, `generic` e `local`. Use `-DryRun` para conferir: a saida mostra `tema remoto: sim (bash)` ou `nao`.

## Fontes e icones

O prompt usa **Nerd Font** por padrao (`glyphSet = nerd`) e mostra o icone do tema no lugar do nome da distro.

```powershell
Get-SshNerdFont
Get-SshNerdFontInfo
Install-SshNerdFont
Set-SshTerminalFont
Set-SshTerminalFont -Name 'CaskaydiaCove Nerd Font'
Test-SshNerdFont
```

No Windows a instalacao e por usuario, sem admin: o arquivo vai para `%LOCALAPPDATA%\Microsoft\Windows\Fonts` e o registro para `HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts`. O `Set-SshTerminalFont` altera `profiles.defaults.font.face` no `settings.json` do Windows Terminal e guarda um backup em `settings.json.sshthemes.bak`.

No Linux/macOS o arquivo vai para `~/.local/share/fonts` ou `~/Library/Fonts`, e o cache e atualizado com `fc-cache`. Escolha a fonte manualmente no seu terminal.

Se preferir nao usar Nerd Font:

```powershell
Set-SshSetting -GlyphSet ascii
```

## Windows Terminal

O instalador com `-WindowsTerminal` cria um fragmento em:

```
%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\SshThemes\ssh-themes.json
```

Ele adiciona o perfil **SSH Themes**, que abre o PowerShell e lista os dispositivos. Para abrir direto em um host, use a linha de comando do perfil:

```
powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -Command "Import-Module SshThemes; xsshx srv01"
```

Tambem existem os launchers `xsshx.cmd` e `s3x.cmd` na raiz do projeto. Coloque a pasta no PATH ou crie atalhos.

## Linux e macOS

O modulo usa `pwsh` e funciona com os mesmos comandos:

```sh
xsshx root@10.0.0.5
xsshx -X root@10.0.0.5
xsshx 10.0.0.5 -Lock debian
```

Os launchers `~/.local/bin/xsshx` e `~/.local/bin/s3x` sao scripts `sh` que chamam o `pwsh`. Se `~/.local/bin` nao estiver no PATH:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

O `install.sh` instala o `pwsh` automaticamente quando necessario. Se preferir instalar manualmente:

- Linux: https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux
- macOS: `brew install --cask powershell`

## Estrutura

```
terminal/
├─ Install.ps1
├─ Uninstall.ps1
├─ install.sh
├─ xsshx.cmd / s3x.cmd
├─ bin/xsshx.ps1
├─ tests/Run-Tests.ps1
└─ src/SshThemes/
   ├─ SshThemes.psd1
   ├─ SshThemes.psm1
   ├─ Private/        # config, deteccao, render, terminal, sessao, plataforma, fontes
   ├─ Public/         # cmdlets Themes, Devices, Settings, Remote, Commands
   └─ config/
      ├─ themes.default.json
      ├─ settings.default.json
      └─ glyphs.default.json
```

Configs do usuario:

```
~/.sshthemes/
├─ themes.json      # overrides/customizacoes
├─ settings.json    # preferencias
├─ hosts.json       # dispositivos, cache de deteccao e locks
├─ glyphs.json      # pacotes de icones extras
└─ install.json     # metadados da instalacao
```

## Testes

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
```

Os testes cobrem catalogo, overrides, deteccao por OS/hostname/S3, parsing de alvos, duracao, path, prompt, banner, settings, workspace S3, geracao do script remoto, comandos com dash, locks, fundo, `-set`/`-get` e flags nativas do ssh. Nao precisam de rede nem de Pester.

## Solucao de problemas

**Icones como `?` ou quadrados.** Rode `-font install` e `-font set "JetBrainsMono Nerd Font"` no Windows. No Linux/macOS, escolha a Nerd Font nas preferencias do terminal. Para conferir: `Test-SshNerdFont` e `Get-SshNerdFont`. No modo `ascii`, os icones viram texto.

**A deteccao nao pega o servidor.** Ele provavelmente so aceita senha. Rode uma vez com `-Type debian` (ou o tema certo) ou trave com `-lock 10.0.0.5 debian`. Confira com `Resolve-SshDeviceType -Target host` e `Show-SshDevices`.

**Cores nao aparecem.** Use Windows Terminal/VS Code ou um terminal com ANSI, confirme que `$env:NO_COLOR` nao esta definido e rode `Show-SshThemes`. Em consoles antigos o modulo cai para texto sem ANSI.

**O prompt original sumiu.** Rode `Disable-SshThemePrompt` para voltar ao prompt anterior; `Enable-SshThemePrompt` reativa. O prompt original e guardado na importacao do modulo.

**ExecutionPolicy (Windows).** Se o PowerShell bloquear os scripts, use `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` ou inicie com `-ExecutionPolicy Bypass`.

**`pwsh` nao encontrado (Linux/macOS).** Rode `./install.sh` de novo; ele tenta instalar o PowerShell 7. Se falhar, instale manualmente pelo link acima.

**`xsshx: command not found` (Linux/macOS).** Adicione `~/.local/bin` ao PATH ou rode `./install.sh` sem `-NoLauncher`.

**Ambiente S3 sem AWS CLI.** O tema e o workspace abrem, mas os comandos `s3*` falham. Instale o AWS CLI v2 e rode `aws configure`.

**Tema remoto falhou.** O servidor precisa de `bash` e `base64`. Rode com `-NoRemoteTheme` para usar apenas o tema local.

**Flag do ssh nao passou.** Use `xsshx` (o wrapper), nao `Connect-SshDevice` diretamente. No cmdlet, flags nativas vao em `-SshArgument`.

## Desinstalar

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1 -PurgeConfig
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1 -KeepFont
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1 -DefaultFont Consolas
```

No Linux/macOS, rode com `pwsh`:

```sh
pwsh -NoProfile -File ./Uninstall.ps1
```

O desinstalador remove o bloco do perfil, o modulo dos diretorios de usuario, os launchers `~/.local/bin/xsshx` e `~/.local/bin/s3x` (somente se foram gerados pelo SshThemes) e o fragmento do Windows Terminal. Com `-PurgeConfig`, apaga tambem `~/.sshthemes`.

No Windows, a fonte do Windows Terminal e restaurada usando o backup `settings.json.sshthemes.bak`; se nao houver backup, remove o `font.face` que o SshThemes definiu. Use `-DefaultFont <nome>` para escolher a fonte final. A fonte instalada permanece na maquina (outros apps podem usa-la).

## Privacidade e limites

- Nada e enviado para servidor algum, exceto a sonda de deteccao (comandos `cat`, `uname`, `hostname`) e, se voce pedir, o rc do tema remoto.
- Senhas continuam sendo tratadas pelo `ssh`; o modulo nao armazena credenciais.
- O tema e aplicado no **cliente** (seu terminal). No servidor, o prompt remoto e alterado automaticamente via bash (ou com `-NoRemoteTheme` para nao alterar).
- A duracao e a conclusao refletem o ultimo comando do PowerShell, nao comandos executados dentro de uma sessao SSH remota.
