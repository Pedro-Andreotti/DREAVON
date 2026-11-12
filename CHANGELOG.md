# Changelog

Todas as mudanças relevantes do DREAVON ficam registradas aqui.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/), e o projeto usa [Versionamento Semântico](https://semver.org/lang/pt-BR/). Cada versão tem uma tag `vX.Y.Z` (ver [CONTRIBUTING.md](CONTRIBUTING.md)).

## [Não lançado]

## [1.0.0] - 2026-11-12

Primeira versão do DREAVON: **uso pessoal no Windows**, sem instalador e sem assinatura. O app abre pelo `qml.exe` assinado do Qt, com os scripts de `tools/`. O DREAVON é uma adaptação do [Plasdria](https://github.com/PietroAlexandria/Plasdria) (© Pietro Alexandria, MIT), um widget para o KDE Plasma 6.

### Adicionado

- **Passo 1, compilação no Windows:** o núcleo C++ compila com CMake, Qt 6 e MSVC, com o código exclusivo do Linux isolado (D-Bus atrás de `QT_DBUS_LIB`) ([diário 01](docs/diario/01-primeiros-passos.md), [PR #3](https://github.com/Pedro-Andreotti/DREAVON/pull/3)).
- **Passo 2, casca própria:** janela Qt Quick sem Plasma, com bandeja, nome e logo do DREAVON, janela de Configurações própria e a chave da API no Gerenciador de Credenciais do Windows. Substituto mínimo do Kirigami só para o Windows, com ícones Breeze ([diário 02](docs/diario/02-casca-windows.md), [PR #6](https://github.com/Pedro-Andreotti/DREAVON/pull/6)).
- **Passo 3, partes portáveis:** clima, notícias, lembretes, calendário (iCal) e chat multi-IA no Windows. Os CLIs de IA rodam sem passar pelo `cmd.exe`: o shim `.cmd` do npm é resolvido para o executável e o texto do usuário vai pelo stdin. O CLI pode ser aberto no Windows Terminal, e o histórico de conversas funciona no Windows. Testado com Claude, Antigravity e API compatível ([diário 03](docs/diario/03-partes-portaveis.md), PRs [#9](https://github.com/Pedro-Andreotti/DREAVON/pull/9) e [#11](https://github.com/Pedro-Andreotti/DREAVON/pull/11)).
- **Passo 4, sistema:** CPU, memória, swap, disco, uptime, processos, bateria, GPU (contadores PDH "GPU Engine") e temperatura do SSD (consulta do driver de armazenamento, sem administrador) ([diário 04](docs/diario/04-sistema-windows.md), [PR #12](https://github.com/Pedro-Andreotti/DREAVON/pull/12)).
- **Dispositivos:** aparelhos USB e Bluetooth pela lista de contêineres do Windows (CfgMgr32), com a bateria que o Windows informa. Bateria do mouse Logitech pelo receptor (HID++ 2.0, só leitura), com cache de 10 min ([diário 05](docs/diario/05-dispositivos-windows.md), PRs [#13](https://github.com/Pedro-Andreotti/DREAVON/pull/13) e [#14](https://github.com/Pedro-Andreotti/DREAVON/pull/14)).
- **Passo 5, rede:**
  - taxas de download e upload só das placas físicas (`GetIfTable2`, sem VPN, adaptadores virtuais e filtros);
  - interface da melhor rota, com nome, tipo e IPv4;
  - SSID e sinal do Wi-Fi (WLAN API), com aviso quando a permissão de localização bloqueia;
  - modo offline e troca de interface sem valor preso ([diário 06](docs/diario/06-rede-windows.md), [PR #16](https://github.com/Pedro-Andreotti/DREAVON/pull/16)).
- **Passo 6, música:**
  - sessão de mídia do Windows (SMTC) por C++/WinRT, por eventos, com título, artista, capa e posição;
  - controles: play/pause, próxima, anterior, seek, aleatório e repetir;
  - Spotify aberto pelo protocolo `spotify:`;
  - navegadores aparecem com o que o site informa ([diário 07](docs/diario/07-musica-windows.md), [PR #18](https://github.com/Pedro-Andreotti/DREAVON/pull/18)).
- **Passo 7a, notificações e atalho global:**
  - alarmes dos lembretes como toast pelo ícone da bandeja, agrupados, avisando os atrasados uma vez só;
  - indicador 🔔 no cartão de lembretes, para o alarme não se perder com o Não Perturbe;
  - atalho global `Ctrl+Shift+Alt+D` (`RegisterHotKey`), configurável nas Configurações, com aviso quando a combinação está em uso ([diário 08](docs/diario/08-notificacoes-atalho-windows.md), [PR #19](https://github.com/Pedro-Andreotti/DREAVON/pull/19)).
- **Passo 7b, uso local:**
  - `tools/install-local.ps1` cria o atalho no Menu Iniciar com AppUserModelID próprio, e as notificações passam a mostrar o nome e o ícone do DREAVON;
  - início com o Windows opcional (desligado por padrão), também nas Configurações;
  - `tools/uninstall-local.ps1` desfaz tudo sem apagar os dados do usuário;
  - guia em [docs/abrir-no-windows.md](docs/abrir-no-windows.md) ([diário 10](docs/diario/10-uso-local-windows.md), [PR #21](https://github.com/Pedro-Andreotti/DREAVON/pull/21)).
- **Configurações > Sobre:** versão, créditos e licenças. A versão sai de um só lugar (`project(VERSION)` no `CMakeLists.txt`), e o build confere se o `package/metadata.json` tem o mesmo número ([diário 11](docs/diario/11-release-1-0-0.md)).
- **Documentação:** `CHANGELOG.md`, notas de release e a regra de versão no `CONTRIBUTING.md`.

### Alterado

- **Uso de CPU em repouso:** caiu de ~42% de um núcleo para 2–10% com a janela aberta e ~1% oculta. A animação do ícone do clima redesenhava a janela a 120 quadros por segundo, até minimizada; agora anima a 15–20 quadros por segundo e só com a janela em foco. Os anéis do cartão Sistema não animam com a janela oculta ([diário 09](docs/diario/09-uso-de-cpu-windows.md), [PR #20](https://github.com/Pedro-Andreotti/DREAVON/pull/20)).
- **Rodapé do clima:** as colunas de "Próximas horas" têm largura igual e espaço entre si, com a temperatura e a chance de chuva em linhas separadas ([diário 06](docs/diario/06-rede-windows.md)).
- **Versão:** de `0.1.0` para `1.0.0`.

### Removido

- Capturas de tela do Plasdria original em `docs/` (`screenshot.png`, `screenshot-narrow.png` e `banner.png`), que não eram do DREAVON e mostravam dados pessoais do autor original ([diário 11](docs/diario/11-release-1-0-0.md)).

### Conhecido e fora do 1.0.0

- **Temperatura da CPU:** indisponível no Windows, porque não há fonte nativa sem administrador ([diário 04](docs/diario/04-sistema-windows.md)).
- **Bateria do mouse Logitech:** a leitura pelo receptor é instável, com ~45% dos ciclos bem-sucedidos; o cartão segura o último valor por até 10 min ([diário 05](docs/diario/05-dispositivos-windows.md)).
- **Bateria do fone Bluetooth e de aparelhos BLE:** em aberto ([diário 05](docs/diario/05-dispositivos-windows.md)).
- **Kirigami:** substituído por um shim mínimo só do Windows.
- **Sem instalador e sem assinatura:** o app abre pelo `qml.exe` do Qt, com os scripts de `tools/` ([diário 10](docs/diario/10-uso-local-windows.md)).
- **Linux:** não testado nesta versão. O código do Linux ficou atrás de `#ifdef`, mas não foi compilado nem executado.

[Não lançado]: https://github.com/Pedro-Andreotti/DREAVON/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Pedro-Andreotti/DREAVON/releases/tag/v1.0.0
