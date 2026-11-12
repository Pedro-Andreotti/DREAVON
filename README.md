<div align="center">

<img src="docs/brand/dreavon-banner.svg" width="900" alt="DREAVON — System Intelligence" />

**O guardião silencioso da sua área de trabalho.**

Um widget de desktop para **Windows** com chat multi-IA, música, rede, lembretes, clima, notícias e monitoramento do sistema, em um painel escuro e futurista.

![Versão](https://img.shields.io/badge/vers%C3%A3o-1.0.0-2f8bff?style=flat-square)
![Status](https://img.shields.io/badge/status-uso%20pessoal%20no%20Windows-2f8bff?style=flat-square)
![Windows](https://img.shields.io/badge/alvo-Windows-0b0e14?style=flat-square&logo=windows&logoColor=a9b1bf)
![Qt 6](https://img.shields.io/badge/Qt-6-41CD52?style=flat-square)
![C++17](https://img.shields.io/badge/C%2B%2B-17-00599C?style=flat-square)
![Licença MIT](https://img.shields.io/badge/Licen%C3%A7a-MIT-a4a5b0?style=flat-square)

</div>

> **1.0.0 — uso pessoal no Windows.** O DREAVON abre no Windows numa janela própria, com o painel geral, o chat, o clima, as notícias, os lembretes com alarme, o calendário, o sistema, os dispositivos, a rede e a música. Não há instalador nem assinatura: ele abre pelo `qml.exe` assinado do Qt, com os scripts de `tools/` (ver [Como abrir](#como-abrir)). O código vem do [Plasdria](https://github.com/PietroAlexandria/Plasdria), um widget para KDE Plasma (Linux). O que mudou em cada versão está no [CHANGELOG](CHANGELOG.md).

## O que é o DREAVON

O DREAVON (*System Intelligence*) reúne em um só painel o que importa durante o dia: um assistente de IA, o que está tocando, a saúde do computador e da rede, e os compromissos. A ideia é ser discreto como um guardião: fica ali, em silêncio, e mostra o que precisa quando você olha.

A identidade segue o mesmo espírito:

| Elemento | Escolha |
| --- | --- |
| Nome | DREAVON |
| Subtítulo | System Intelligence |
| Cores | preto, grafite, azul elétrico e prata |
| Símbolo | olho de dragão dentro de uma moldura de runa |
| Personalidade | guardião silencioso |
| Interface | modo escuro futurista, com detalhes de fantasia |

## O que vem da base (Plasdria)

Estas são as funções da base Linux e como ficaram no Windows no 1.0.0.

| Recurso | Na base Linux | No Windows (1.0.0) |
| --- | --- | --- |
| Painel geral | relógio, saudação, clima resumido e visão do dia | mesma interface QML, numa janela própria com bandeja |
| Chat multi-IA | Antigravity, Claude, Codex, Gemini CLI, Ollama e APIs compatíveis com OpenAI | CLIs executados sem `cmd.exe`; testado com Claude, Antigravity e API compatível |
| Música | MPRIS (D-Bus) | sessão de mídia do Windows (SMTC) |
| Rede | `/proc/net/dev` e NetworkManager | IP Helper e WLAN API |
| Sistema | CPU, GPU, RAM, disco, temperaturas e bateria via `/proc` e `/sys` | PDH, `GlobalMemoryStatusEx`, API de energia e temperatura do SSD; sem temperatura da CPU |
| Dispositivos | UPower e BlueZ (D-Bus) | lista de aparelhos do Windows e bateria Logitech por HID++ |
| Lembretes com alarme | notificação do sistema | notificação (toast) pelo ícone da bandeja, com o nome do DREAVON |
| Calendário, clima e notícias | iCal, Open-Meteo e Google News | iguais (só dependem de rede) |

O mapeamento completo, com as dúvidas em aberto, está em [`docs/windows-port.md`](docs/windows-port.md).

## Como abrir

Requisitos: Windows 10/11 com Qt 6, MSVC (Build Tools), CMake e Ninja instalados.

1. **Compile** na pasta do projeto: `.\build-windows.ps1` (gera o núcleo em `package\contents\ui\bridge\dreavonplugin.dll`).
2. **Crie o atalho** no Menu Iniciar: `.\tools\install-local.ps1`. Para abrir junto com o Windows, na bandeja, acrescente `-IniciarComWindows`.
3. **Abra** pelo Menu Iniciar ("DREAVON").

Para abrir sem atalho: `.\build-windows.ps1 -Run`. Passo a passo e solução de problemas: [`docs/abrir-no-windows.md`](docs/abrir-no-windows.md). Para desfazer o atalho e o início com o Windows: `.\tools\uninstall-local.ps1` (não apaga configurações nem a chave da API). Detalhes em [`docs/diario/10-uso-local-windows.md`](docs/diario/10-uso-local-windows.md).

## Limitações conhecidas

- **Sem instalador e sem assinatura:** o DREAVON é para uso pessoal e abre pelo `qml.exe` do Qt. Um `dreavon.exe` sem assinatura seria bloqueado pelo Controle Inteligente de Aplicativos do Windows.
- **Temperatura da CPU:** indisponível no Windows, porque não há fonte nativa sem administrador.
- **Bateria do mouse Logitech:** a leitura pelo receptor é instável (~45% dos ciclos); o cartão segura o último valor por até 10 min.
- **Bateria do fone Bluetooth e de aparelhos BLE:** ainda não aparece.
- **Kirigami:** substituído por um shim mínimo, só no Windows.
- **Linux:** não testado nesta versão.

## Roadmap

- [x] Repositório próprio, com o histórico e os créditos do Plasdria
- [x] Plano da adaptação e convenção de branches
- [x] **1.** Compilar o núcleo no Windows (CMake, Qt 6, MSVC) isolando o código exclusivo de Linux ([PR #3](https://github.com/Pedro-Andreotti/DREAVON/pull/3))
- [x] **2.** Casca própria em janela Qt Quick, sem Plasma, com bandeja, nome e logo do DREAVON e chave da API no Gerenciador de Credenciais ([plano](docs/passo-2-casca.md), [diário](docs/diario/02-casca-windows.md), [PR #6](https://github.com/Pedro-Andreotti/DREAVON/pull/6))
- [x] **3.** Partes portáveis: clima, notícias, lembretes, calendário e chat, com os CLIs de IA executados sem passar pelo `cmd.exe` ([diário](docs/diario/03-partes-portaveis.md))
- [x] **4.** Sistema: CPU, RAM, swap, disco, bateria, GPU e temperatura do SSD — **concluído parcialmente**: a temperatura da CPU segue indisponível no Windows (sem fonte nativa sem administrador) ([diário](docs/diario/04-sistema-windows.md))
- [x] **4b.** Dispositivos: USB e Bluetooth pela lista do Windows e bateria do mouse Logitech pelo receptor (HID++, só leitura) — a bateria do fone Bluetooth segue em aberto ([diário](docs/diario/05-dispositivos-windows.md))
- [x] **5.** Rede: tráfego (só placas físicas), IP, tipo, nome e sinal do Wi-Fi, latência e modo offline ([diário](docs/diario/06-rede-windows.md))
- [x] **6.** Música via SMTC (C++/WinRT): Spotify, navegadores e outros players, com capa, posição e controles ([diário](docs/diario/07-musica-windows.md))
- [x] **7.** Extras do Windows:
  - [x] **7a.** Notificações dos lembretes (toast, agrupadas, com indicador no cartão) e atalho global configurável (Ctrl+Shift+Alt+D) ([diário](docs/diario/08-notificacoes-atalho-windows.md)); a bandeja existe desde o passo 2
  - [x] **7b.** Uso local, sem instalador nem assinatura: atalho no Menu Iniciar com AUMID próprio (toast com o nome "DREAVON") e início com o Windows opcional ([diário](docs/diario/10-uso-local-windows.md))
- [x] Desempenho: CPU em repouso de ~42% para 2–10% de um núcleo com a janela aberta e ~1% oculta, com a animação do clima a 15–20 quadros por segundo e só em foco ([diário](docs/diario/09-uso-de-cpu-windows.md))
- [x] **1.0.0** — uso pessoal no Windows: versão única, Configurações > Sobre, CHANGELOG e auditoria de privacidade ([diário](docs/diario/11-release-1-0-0.md), [notas](docs/releases/v1.0.0.md))
- [ ] Depois do 1.0.0: bateria do fone Bluetooth e BLE, identidade final das telas

## Tecnologias

| Camada | Tecnologias |
| --- | --- |
| Interface | QML / Qt Quick |
| Núcleo | C++17, Qt 6 (Core, Qml, Network, Gui, Concurrent) |
| Windows | C++/WinRT (música), Win32 (rede, dispositivos, atalho global), PDH (sistema) |
| Alvo | Windows 10/11, MSVC, CMake e Ninja |
| Origem | KDE Plasma 6, Kirigami, D-Bus (no Windows: shim do Kirigami e APIs nativas) |

## Estrutura

```text
native/        Núcleo C++ (chat, clima, sistema, música e rede)
package/       Interface QML e configurações (formato de plasmoide da base)
docs/          Plano do port, diários de desenvolvimento, notas de release e identidade visual
  brand/       Logo, marca e banner do DREAVON
  diario/      Um diário por passo (decisões, testes, não verificado)
  releases/    Notas de cada versão
app/           Inicializador nativo (dreavon.exe); sem assinatura, não é usado no 1.0.0
windows/       Ponto de entrada no Windows e substituto mínimo do Kirigami
tests/         Testes herdados (chat simulado e música simulada) e testes do Windows
tools/         Uso local (install-local.ps1, uninstall-local.ps1) e prévia da interface
```

## Executar a base Linux

A base ainda pode ser compilada em Linux com KDE Plasma 6, como no Plasdria: veja o [README original](https://github.com/PietroAlexandria/Plasdria#instalação). Os scripts `build.sh` e `install.sh` são da base Linux e não foram testados depois da troca de nome (o identificador do pacote agora é `local.dreavon`).

## Contribuindo

Cada etapa do roadmap é uma branch, com Pull Request e *squash merge*. As regras estão em [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Créditos e licença

[MIT](LICENSE). O DREAVON é uma adaptação do [Plasdria](https://github.com/PietroAlexandria/Plasdria) (© Pietro Alexandria, MIT), que inclui código do [PRAGUS](https://github.com/gustavoprad0/PRAGUS) (MIT). Os avisos de copyright originais foram mantidos. No Windows, os ícones da interface são um subconjunto do tema [Breeze](https://invent.kde.org/frameworks/breeze-icons) (© Uri Herrera e outros, LGPL-3.0-or-later), em `windows/qml/org/kde/kirigami/icons/`, com o aviso em `COPYING-ICONS`. O DREAVON usa o [Qt 6](https://www.qt.io/) (© The Qt Company e colaboradores) sob a LGPL-3.0, por ligação dinâmica às DLLs da instalação do Qt, sem modificá-las. Avisos completos em Configurações > Sobre e no [LICENSE](LICENSE). Projeto independente, sem afiliação com a Anthropic, a Microsoft, o KDE, a Qt Company ou os provedores de dados.
