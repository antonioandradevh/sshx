# SshThemes

Terminal SSH com **tema por dispositivo** no PowerShell. Ao conectar, o SshThemes descobre o que ha do outro lado (Debian, Ubuntu, Alpine, Amazon Linux, EC2, S3, Windows...) e veste a sessao com as cores, icones e o prompt daquele sistema. Tudo e editavel: hex, icones, o que aparece no prompt, tempo de cada comando e o formato dos diretorios.

```
╭──────────────────────────────────────────────────────────────────╮
│ <icone> DEBIAN                                               SSH │
│ ──────────────────────────────────────────────────────────────── │
│ destino   root@host.example                                      │
│ host      host.example:22                                        │
│ usuario   root                                                   │
│ sistema   Debian GNU/Linux                                       │
│ tema      Debian  #A81D33 ██                                     │
│ sessao    2026-10-24 06:32:54  text                              │
│ -Type <tema> forca o tema  -  exit encerra a sessao              │
╰──────────────────────────────────────────────────────────────────╯
<icone>  root@host.example  ~/projetos/app  main  128 ms
❯
```

`<icone>` e o glifo Nerd Font do dispositivo (Debian, Ubuntu, Windows...). Por padrao e o unico icone do prompt.

## O que ele faz

- **Detecta o dispositivo remoto** por `/etc/os-release`, `uname`, hostname e padroes do `~/.ssh/config`.
- **Aplica um tema por tipo**: Debian vermelho, Ubuntu laranja, Alpine azul, AWS laranja, S3 com icone de banco, Windows azul etc.
- **Personaliza o terminal**: titulo da aba, banner e cores. No modo `auto` (padrao), temas com fundo proprio (Debian, Ubuntu, Fedora...) repintam foreground/background/cursor; temas sem fundo (S3, AWS, generic) mudam so o texto.
- **Prompt limpo**: dispositivo, `usuario@host`, diretorio, branch git, **duracao do ultimo comando** e codigo de saida. Por padrao so o **icone do sistema** aparece (o Windows usa o logo do Windows); os outros icones ficam desligados.
- **Comandos `/`**: `/font`, `/icons`, `/color`, `/distros` e `/help` para personalizar tudo sem editar JSON.
- **Workspace S3**: `awsx s3://bucket/prefixo` abre um ambiente AWS CLI com o tema S3 e atalhos `s3ls`, `s3get`, `s3put`, `s3sync`, `s3rm`.
- **Tema remoto no bash**: injeta automaticamente o prompt do tema no shell remoto; pode ser desligado com `-NoRemoteTheme`.
- **Tudo configuravel**: `Set-SshTheme`, `Set-SshSetting`, comandos `/` ou edicao direta dos JSONs em `~/.sshthemes`.

## Requisitos

- Windows 10/11 com **PowerShell 5.1** ou **PowerShell 7+**.
- **OpenSSH Client** (`ssh.exe`) no PATH.
- Terminal com ANSI (Windows Terminal, VS Code, ConEmu). O prompt cai para modo texto sem cor se ANSI nao estiver disponivel.
- Opcional: **AWS CLI** para o workspace S3.
- A **Nerd Font** e instalada automaticamente pelo instalador (JetBrainsMono Nerd Font). Se ja existir uma Nerd Font na maquina, ela e reaproveitada.

## Instalacao

```powershell
# na pasta do projeto
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1

# opcional: cria tambem o perfil "SSH Themes" no Windows Terminal
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -WindowsTerminal

# veja o que seria feito, sem alterar nada
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -DryRun

# nao mexa em fontes / no Windows Terminal
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -NoFont
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -NoTerminalFont

# escolha outra Nerd Font ja instalada
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -FontName 'CaskaydiaCove Nerd Font'
```

O instalador copia o modulo para `Documents\WindowsPowerShell\Modules\SshThemes`, adiciona um bloco idempotente no seu perfil e cria as configuracoes do usuario em `~/.sshthemes`.

Ele tambem instala uma **Nerd Font** por usuario em `%LOCALAPPDATA%\Microsoft\Windows\Fonts` e ajusta `profiles.defaults.font.face` no `settings.json` do Windows Terminal (com backup em `settings.json.sshthemes.bak`). Assim os icones do prompt aparecem sem configuracao manual. Se voce ja tem uma Nerd Font, o instalador apenas a reutiliza.

Abra um novo PowerShell e teste:

```powershell
Show-SshThemes
Preview-SshTheme -Name debian
Connect-SshDevice -Target root@10.0.0.5 -DryRun
```

## Uso rapido

```powershell
# conectar (detecta o tipo automaticamente)
sshx root@192.168.0.20

# forcar um tema quando a deteccao nao ajuda (ex.: servidor sem chave)
sshx root@10.0.0.5 -Type debian

# alias registrado
Register-SshDevice -Name lab01 -HostName 10.10.10.10 -User admin -Port 2200 -Type debian -Label "Lab 01"
sshx lab01

# ver o banner e o prompt sem conectar (a deteccao usa apenas hostname no dry-run)
sshx lab01 -DryRun

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
/help
```

`Connect-SshDevice` tambem aceita `-Command`, `-RemoteTheme`, `-NoRemoteTheme`, `-FullTheme`, `-NoDetect`, `-Refresh` e `-SshArgument`. Rode `sshx -Help` para a lista.

Os comandos `/font`, `/icons`, `/color` e `/distros` estao detalhados em [Comandos rapidos](#comandos-rapidos-).

O `-Type` informado numa conexao fica salvo no registro de dispositivos; as proximas conexoes ao mesmo host ja usam esse tema, inclusive no prompt remoto automatico.

## Como a deteccao funciona

Ordem de prioridade:

1. `-Type` explicito.
2. Tipo salvo no registro de dispositivos (`hosts.json`, campo `type`).
3. Cache da ultima deteccao (`detectedType`, valido por `detect.cacheDays`, padrao 30 dias).
4. Sonda SSH: le `/etc/os-release`, `uname`, `hostname` e a presenca do `aws`.
5. Padroes de hostname (`ec2-*.amazonaws.com`, `*.s3.amazonaws.com`, `deb*` etc.).
6. Tema `generic`.

A sonda usa `BatchMode=yes`, `NumberOfPasswordPrompts=0` e `ConnectTimeout` configuravel. Ou seja: **ela nao pede senha**. Se o host so aceita senha, a deteccao cai para hostname/generic e voce pode usar `-Type` uma vez; o tipo fica salvo no registro para as proximas conexoes.

Por padrao a sonda aceita host novo na primeira conexao (`accept-new`). Para exigir que o host ja esteja em `known_hosts` (mais seguro, mas a deteccao falha no primeiro contato):

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
| `local` | `#4CC2FF` | `U+F17A` (Windows) | prompt local |
| `debian` | `#A81D33` | `U+F306` | Debian |
| `ubuntu` | `#E95420` | `U+F31B` | Ubuntu |
| `raspbian` | `#C51A4A` | `U+F315` | Raspberry Pi OS |
| `alpine` | `#0D597F` | `U+F300` | Alpine |
| `fedora` | `#51A2DA` | `U+F30A` | Fedora |
| `rhel` | `#EE0000` | `U+F316` | RHEL / Red Hat |
| `centos` | `#A14F9F` | `U+F304` | CentOS |
| `rocky` | `#10B981` | `U+F32B` | Rocky Linux |
| `alma` | `#F59E0B` | `U+F31D` | AlmaLinux |
| `arch` | `#1793D1` | `U+F303` | Arch / Manjaro |
| `opensuse` | `#73BA25` | `U+F314` | openSUSE / SLES |
| `gentoo` | `#8E7CC3` | `U+F30D` | Gentoo |
| `kali` | `#557C94` | `U+F327` | Kali |
| `amazon` | `#FF9900` | `U+F270` | Amazon Linux |
| `aws` | `#FF9900` | `U+F0EF` | AWS / EC2 |
| `s3` | `#FF9900` | `U+F1C0` | `s3://`, hosts S3 |
| `windows` | `#0078D4` | `U+F17A` | Windows OpenSSH |
| `proxmox` | `#E57000` | `U+E937` | Proxmox VE |
| `generic` | `#8A8A8A` | `U+F31A` | Linux desconhecido |

Os codepoints sao glifos Nerd Font: aparecem corretos quando a fonte do terminal e uma Nerd Font (o `/font` cuida disso). `Show-SshThemes -Detailed` mostra todos com nota e se foram customizados.

## Personalizacao

### Trocar hex e icone de um tipo

```powershell
# so o hex
Set-SshTheme -Name debian -Accent "#FF0077"

# hex principal, hex secundario, icone do badge e nota
Set-SshTheme -Name debian `
  -Accent "#B00020" `
  -Accent2 "#FF5C8A" `
  -Icon ([string][char]0xF306) `
  -Note "Debian do laboratorio"

# icone diferente para cada parte do prompt desse tema (glifos Nerd Font)
Set-SshTheme -Name debian -Icons @{
  path     = [string][char]0xF07B
  git      = [string][char]0xF126
  duration = [string][char]0xF2F2
  ok       = [string][char]0xF00C
}

# cores finas do prompt (usuario, host, path, git, duracao, exit)
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

# voltar ao padrao
Set-SshTheme -Name debian -Reset
# ou
Remove-SshTheme -Name debian -Force
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
Edit-SshConfig -Name themes    # ou settings, hosts, glyphs
Reload-SshConfig               # depois de salvar
```

`Edit-SshTheme -Name debian` materializa o tema inteiro em `themes.json` e abre no Notepad, otimo para copiar e ajustar.

### Configuracoes globais

```powershell
# o que aparece no prompt
Set-SshSetting -Show @{
  clock    = $false
  duration = $true
  exitCode = $true
  git      = $true
  path     = $true
}

# duracao: amarelo a partir de 1,5s, vermelho a partir de 5s
Set-SshSetting -DurationWarnMs 1500 -DurationSlowMs 5000 -DurationPrecision 2

# diretorios e icones (padrao: somente o icone do sistema)
Set-SshSetting -PathStyle smart -MaxPathSegments 4 -PathIcons $false
Set-SshSetting -PromptIcons $true    # liga os icones do prompt (padrao: true)
Set-SshSetting -IconParts @{ device = $true; path = $true; duration = $false }
Set-SshSetting -DirectoryIcons @{
  ".git"         = [string][char]0xF1D3
  "node_modules" = [string][char]0xF1B3
  "Downloads"    = [string][char]0xF019
}

# relogio, largura e layout
Set-SshSetting -ClockFormat "HH:mm:ss" -BannerWidth 72 -Multiline $true -Separator "  "

# modo do terminal: "auto" pinta o fundo quando o tema define um; "text" so muda o texto; "full" sempre pinta fg/bg/cursor
Set-SshSetting -TerminalMode auto
Set-SshSetting -TerminalMode full
Set-SshSetting -TerminalMode text

# ao sair, restaura as cores originais do terminal (padrao: true)
Set-SshSetting -TerminalResetOnExit $true

# troca todo o conjunto de icones (padrao: nerd)
Set-SshSetting -GlyphSet nerd    # Nerd Font, instalada pelo Install.ps1
Set-SshSetting -GlyphSet emoji
Set-SshSetting -GlyphSet ascii

# sonda de deteccao
Set-SshSetting -DetectProbe $true -DetectTimeoutSeconds 6 -DetectStrictHostKeys $false

# prompt remoto no bash (padrao: true)
Set-SshSetting -RemoteAutoTheme $true
Set-SshSetting -RemoteAutoTheme $false

# padrao do workspace S3
Set-SshSetting -S3Profile producao -S3Region us-east-1

# prompt ligado/desligado
Disable-SshThemePrompt
Enable-SshThemePrompt

# tudo de volta ao padrao
Set-SshSetting -Reset
```

Consulte um valor com `Get-SshSetting show.duration` ou o objeto inteiro com `Get-SshSetting`.

### Modo auto, texto e full

O padrao e `auto`: cada tema decide. Temas com `background` no JSON (Debian, Ubuntu, Fedora etc.) repintam foreground, background e cursor do terminal; temas sem `background` (S3, AWS, generic, local) mantem o visual do seu terminal e mudam apenas banner, titulo e prompt. Assim S3 e AWS continuam **somente texto**, sem trocar o fundo.

```powershell
Set-SshSetting -TerminalMode auto   # padrao: respeita o fundo de cada tema
Set-SshSetting -TerminalMode text   # nunca troca fg/bg/cursor
Set-SshSetting -TerminalMode full   # sempre troca fg/bg/cursor

# forcar so numa conexao
sshx s3://bucket -FullTheme
```

As cores sao enviadas com OSC 10/11/12 e restauradas ao sair (ou com OSC 110/111/112). Funciona no Windows Terminal, VS Code e terminais com suporte a OSC.

## O prompt

```
<icone>  root@srv01  ~/app/src  main  1.24 s
❯
```

`<icone>` e o glifo do dispositivo detectado (Debian, Ubuntu, Windows...). No Windows local aparece o logo do Windows.

- **Somente o icone do sistema por padrao**: o unico icone e o do dispositivo (`local` no Windows usa o logo do Windows). Tempo, pasta, usuario, git e status ficam sem icone. `Set-SshSetting -IconParts @{ path = $true; duration = $true }` liga cada parte; `-PromptIcons $false` desliga tudo.
- **Duracao**: vem de `StartExecutionTime`/`EndExecutionTime` do historico do PowerShell, medida real do comando (sem contar o tempo digitando).
- **Conclusao**: comando nativo usa `$LASTEXITCODE`; cmdlets usam o `ExecutionStatus` do historico. Sucesso nao adiciona nada; falha mostra `exit 1`. Com o icone de status ligado, aparece `✓` ou `✗ 1`.
- **Cores da duracao**: `durationFast`, `durationWarn` e `durationSlow` definem os limites visuais.
- **Diretorios**: `path.style` aceita `smart` (padrao), `full` ou `leaf`; `directoryIcons` usa nome exato ou curinga (`node_*`).
- **Git**: le `.git/HEAD` subindo diretorios, sem executar `git` a cada prompt.

Tudo isso pode ser desligado individualmente em `show`.

## Comandos rapidos (/)

Sao aliases do modulo: digite direto no PowerShell, sem chamar `Invoke-Ssh...`.

```powershell
/font                     # fonte atual + Nerd Fonts instaladas
/icons                    # estado de cada icone do prompt
/color debian             # todas as cores do tema Debian
/distros                  # lista os temas disponiveis
/help                     # resumo de tudo
```

### `/font`

| Comando | O que faz |
| --- | --- |
| `/font` | mostra a fonte do Windows Terminal e as Nerd Fonts instaladas |
| `/font list` | lista as Nerd Fonts (com o escopo: usuario/maquina) |
| `/font set <nome>` | define a fonte do Windows Terminal (faz backup do `settings.json`) |
| `/font install` | baixa e instala a JetBrainsMono Nerd Font por usuario |
| `/font reset` | remove a fonte personalizada e volta ao padrao do Windows Terminal |
| `/font test` | imprime os glifos ativos do prompt para conferir a fonte |

```powershell
/font set "0xProto Nerd Font"    # nome exato, entre aspas se tiver espacos
/font set "JetBrainsMono Nerd Font"
```

Use `/font list` para ver os nomes exatos disponiveis.

### `/icons`

| Comando | O que faz |
| --- | --- |
| `/icons` | mostra o estado de cada parte (sistema, usuario, pasta, git, tempo, relogio, status) |
| `/icons on` / `/icons off` | liga/desliga todos os icones de uma vez |
| `/icons <parte> on` / `off` | liga/desliga so uma parte |
| `/icons nerd` / `/icons ascii` | troca o conjunto de glifos |
| `/icons reset` | volta ao padrao: somente o icone do sistema |

Partes aceitas: `device`, `user`, `path`, `git`, `duration`, `clock`, `exit`.

```powershell
/icons path on        # icone de pasta de volta
/icons duration on    # icone de tempo de volta
/icons exit on        # marca de sucesso/falha
/icons reset          # so o icone do sistema
```

### `/color`

| Comando | O que faz |
| --- | --- |
| `/color` | lista todos os temas com `accent` e `accent2` |
| `/color <tema>` | mostra accent, accent2, foreground, background, cursor e as cores do prompt |
| `/color <tema> <chave> <hex>` | troca uma cor do tema |
| `/color reset <tema>` | restaura o tema inteiro para o padrao |

```powershell
/color debian accent E95420          # hex sem #
/color debian accent "#E95420"       # com # precisa de aspas
/color debian path 8BE9FD            # cores do prompt usam a chave direta
/color debian background 1B0A0F
/color reset debian
```

O `#` sem aspas inicia um comentario no PowerShell, por isso o comando aceita `RRGGBB` puro.

Chaves de cor aceitas: `accent`, `accent2`, `foreground`, `background`, `cursor` e as do prompt (`user`, `host`, `path`, `git`, `muted`, `durationFast`, `durationWarn`, `durationSlow`, `exitOk`, `exitFail`).

### `/distros`

| Comando | O que faz |
| --- | --- |
| `/distros` | lista os temas de distros/dispositivos (hex, badge e se esta customizado) |
| `/distros <nome>` | previsualiza o tema sem aplicar |
| `/distros set <nome>` | define o tema padrao (usado quando nao ha deteccao) |
| `/distros reset <nome>` | restaura o tema para o padrao de fabrica |
| `/distros custom <nome>` | abre o JSON do tema no Notepad para editar tudo |

```powershell
/distros set debian
/distros ubuntu
/distros custom s3
```

### `/help`

Mostra o resumo dos quatro comandos e um exemplo de cada.

> Depois de alterar arquivos do modulo, recarregue com
> `Remove-Module SshThemes -Force -ErrorAction SilentlyContinue; Import-Module SshThemes -Force -DisableNameChecking`.

## Registro de dispositivos

```powershell
Register-SshDevice -Name srv01 -HostName 10.0.0.5 -User root -Type debian -Label "Web"
Register-SshDevice -Name srv02 -HostName 10.0.0.6 -SshAlias srv02-prod   # usa o alias do ~/.ssh/config
Get-SshDevice
Show-SshDevices
Remove-SshDevice -Name srv02
```

`hosts.json` guarda tambem o ultimo tipo detectado (`detectedType`), o `osName`, o hostname remoto e a data. Hosts descobertos por conexao direta entram ali automaticamente.

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
# conectar e ja aplicar o tema no prompt do bash remoto
sshx srv01

# desligar apenas nesta conexao
sshx srv01 -NoRemoteTheme

# desligar para sempre
Set-SshSetting -RemoteAutoTheme $false

# instalar o rc manualmente, sem conectar
Install-SshRemoteTheme -Target srv01
```

O rc e enviado em uma unica conexao para `~/.config/sshthemes/rc` e executado com `bash --rcfile ...`. Se o servidor nao tiver `bash`, a conexao cai para o shell padrao. O `.bashrc` remoto e carregado antes do prompt do SshThemes.

A injecao vale para qualquer tema de servidor, inclusive `s3` e `aws` (uteis em gateways/appliances S3). Ficam de fora apenas `windows`, `generic` e `local`. Para conferir se uma conexao vai injetar o tema, use `-DryRun`: a saida mostra `tema remoto: sim (bash)` ou `nao`.

## Fontes e icones

O prompt usa **Nerd Font** por padrao (`glyphSet = nerd`) e mostra o icone do tema no lugar do nome da distro. O instalador ja cuida da fonte; os comandos abaixo servem para conferir ou trocar.

```powershell
# fontes Nerd instaladas na maquina
Get-SshNerdFont

# fonte padrao do modulo (nome, URL e licenca)
Get-SshNerdFontInfo

# instala a JetBrainsMono Nerd Font se nao houver nenhuma Nerd Font
Install-SshNerdFont

# aponta o Windows Terminal para uma Nerd Font instalada
Set-SshTerminalFont
Set-SshTerminalFont -Name 'CaskaydiaCove Nerd Font'

# confere se existe Nerd Font
Test-SshNerdFont
```

A instalacao e por usuario, sem admin: o arquivo vai para `%LOCALAPPDATA%\Microsoft\Windows\Fonts` e o registro para `HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts`. O `Set-SshTerminalFont` altera `profiles.defaults.font.face` no `settings.json` do Windows Terminal e guarda um backup em `settings.json.sshthemes.bak`.

Depois da primeira instalacao, feche e abra o Windows Terminal para ele carregar a fonte. Se preferir nao usar Nerd Font:

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
powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -Command "Import-Module SshThemes; sshx srv01"
```

Tambem existem os launchers `sshx.cmd` e `s3x.cmd` na raiz do projeto. Coloque a pasta no PATH ou crie atalhos.

## Estrutura

```
terminal/
├─ Install.ps1
├─ Uninstall.ps1
├─ sshx.cmd / s3x.cmd
├─ bin/sshx.ps1
├─ tests/Run-Tests.ps1
└─ src/SshThemes/
   ├─ SshThemes.psd1
   ├─ SshThemes.psm1
   ├─ Private/        # config, deteccao, render, terminal, sessao
   ├─ Public/         # cmdlets Themes, Devices, Settings, Remote
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
├─ hosts.json       # dispositivos e cache de deteccao
└─ glyphs.json      # pacotes de icones extras
```

## Testes

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
```

Os testes cobrem catalogo, overrides, deteccao por OS/hostname/S3, parsing de alvos, duracao, path, prompt, banner, settings, workspace S3 e geracao do script remoto. Nao precisam de rede nem de Pester.

## Solucao de problemas

**Icones como `?` ou quadrados.** Rode `Install-SshNerdFont` e `Set-SshTerminalFont`, depois feche e abra o Windows Terminal. Para conferir: `Test-SshNerdFont` e `Get-SshNerdFont`. No modo `ascii`, os icones viram texto (`u`, `h`, `dir`).

**A deteccao nao pega o servidor.** Ele provavelmente so aceita senha. Rode uma vez com `-Type debian` (ou o tema certo); o tipo fica salvo. Confira com `Resolve-SshDeviceType -Target host` e `Show-SshDevices`.

**Cores nao aparecem.** Use Windows Terminal/VS Code, confirme que `$env:NO_COLOR` nao esta definido e rode `Show-SshThemes`. Em consoles antigos o modulo cai para texto sem ANSI.

**O prompt original sumiu.** Rode `Disable-SshThemePrompt` para voltar ao prompt anterior; `Enable-SshThemePrompt` reativa. O prompt original e guardado na importacao do modulo.

**ExecutionPolicy.** Se o PowerShell bloquear os scripts, use `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` ou inicie com `-ExecutionPolicy Bypass`.

**Ambiente S3 sem AWS CLI.** O tema e o workspace abrem, mas os comandos `s3*` falham. Instale o AWS CLI v2 e rode `aws configure`.

**Tema remoto falhou.** O servidor precisa de `bash` e `base64`. Rode com `-NoRemoteTheme` para usar apenas o tema local.

## Desinstalar

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
# apaga tambem ~/.sshthemes (hex, icones, dispositivos)
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1 -PurgeConfig
# nao mexe na fonte do Windows Terminal
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1 -KeepFont
# forca uma fonte especifica (ex.: a padrao do PowerShell/Windows)
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1 -DefaultFont Consolas
```

O desinstalador restaura a fonte do Windows Terminal usando o backup `settings.json.sshthemes.bak`; se nao houver backup, remove o `font.face` que o SshThemes definiu e o terminal volta ao padrao. Use `-DefaultFont <nome>` para escolher a fonte final. A fonte instalada em `%LOCALAPPDATA%\Microsoft\Windows\Fonts` permanece na maquina (outros apps podem usa-la).

## Privacidade e limites

- Nada e enviado para servidor algum, exceto a sonda de deteccao (comandos `cat`, `uname`, `hostname`) e, se voce pedir, o rc do tema remoto.
- Senhas continuam sendo tratadas pelo `ssh`; o modulo nao armazena credenciais.
- O tema e aplicado no **cliente** (seu terminal). No servidor, o prompt remoto e alterado automaticamente via bash (ou com `-NoRemoteTheme` para nao alterar).
- A duracao e a conclusao refletem o ultimo comando do PowerShell, nao comandos executados dentro de uma sessao SSH remota.
