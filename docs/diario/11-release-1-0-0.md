# 11 — Release 1.0.0

Data: 2026-11-12 · Branch: `release/1.0.0`

## Definição do 1.0.0
Versão para **uso pessoal no Windows**, sem instalador e sem assinatura. O app abre pelo `qml.exe` assinado do Qt, com os scripts de `tools/`. Linux não testado.

Limitações conhecidas e aceitas:
- temperatura da CPU indisponível;
- bateria Logitech com leitura instável (~45% dos ciclos);
- bateria do fone Bluetooth e de aparelhos BLE em aberto;
- Kirigami substituído por um shim só do Windows.

A tag `v1.0.0` e o GitHub Release ficam com o autor, depois do merge.

## O que foi feito
| Arquivo | Mudança |
| --- | --- |
| `CMakeLists.txt` | `project(DREAVON VERSION 1.0.0)` é a fonte única. O CMake lê `KPlugin.Version` do `package/metadata.json` e **para o build** se o número for diferente. O plugin recebe `DREAVON_VERSION` |
| `package/metadata.json` | `0.1.0` → `1.0.0` (metadados do plasmoide; conferido pelo CMake) |
| `native/plugin.cpp` | Singleton `AppInfo` (`name`, `version`, `repository`) para o QML, sem repetir o número |
| `package/contents/ui/ConfigAbout.qml` (novo), `SettingsWindow.qml` | Aba **Sobre**: "DREAVON 1.0.0", edição, link do repositório, crédito ao Plasdria e ao PRAGUS (MIT), licenças (MIT, LGPL-3.0 do Qt, LGPL-3.0-or-later dos ícones Breeze). Mesmo formato das outras abas (`ConfigPage` + `FormLayout`) |
| `CHANGELOG.md` (novo) | Keep a Changelog, em português: a seção `[1.0.0]` resume os passos 1 a 7b, os dispositivos, a bateria Logitech, a rede, a música, as notificações e o atalho, o uso de CPU e o uso local, com links para os diários e PRs. Inclui a seção "Conhecido e fora do 1.0.0" |
| `README.md` | Selo e status "1.0.0 — uso pessoal no Windows", seção "Como abrir", tabela da base com o estado no Windows, roadmap marcado, "Limitações conhecidas", tecnologias e estrutura atualizadas, LGPL do Qt nos créditos |
| `CONTRIBUTING.md` | Regra de versão (definida pelo usuário): recurso novo sobe o número do meio, correção sobe o último, quebra de configurações salvas ou do QML sobe o primeiro. Uma versão por release, não por PR: o PR do recurso já sobe a versão e registra no CHANGELOG, e a tag `vX.Y.Z` e o Release saem depois do merge. Prefixos `perf/` e `release/` |
| `docs/windows-port.md` | Estado no 1.0.0 e pontos em aberto resolvidos |
| `docs/releases/v1.0.0.md` (novo) | Notas para o GitHub Releases, sem binários |
| `docs/passo-2-casca.md` | Pendência das capturas do Plasdria marcada como feita |

## Auditoria antes de taguear
**Como foi feita:** um roteiro fora do repositório leu os dados reais **direto da fonte**:
- usuário e nome do computador;
- SSID atual e redes salvas;
- e-mail do usuário;
- cidade, nome e textos dos lembretes do `settings.ini`;
- título, artista e álbum da última música (`media.json`).

Depois procurou cada valor **nos arquivos versionados e em todo o histórico do git**, imprimindo só onde achou e a categoria, nunca o valor. Também procurou padrões genéricos: chaves de API (`sk-ant-`, `sk-`, `ghp_`, `AIza`…), chaves privadas, e-mails, IPs e caminhos `C:\Users\...`. As imagens em `docs/` e `docs/diario/img/` foram olhadas uma a uma.

| Item | Encontrado | Decisão |
| --- | --- | --- |
| Chaves de API, tokens, chaves privadas | nenhum, nos arquivos nem no histórico | — |
| E-mail do usuário | nenhum no conteúdo | — |
| E-mails nos metadados dos commits (autor) | sim: o do usuário, o do autor do Plasdria e o do bot do GitHub | é do próprio git; reescrever o histórico não é recomendado. Fica registrado |
| Nome do usuário | só como **crédito**: `LICENSE`, autor no `metadata.json`, links do GitHub (conta pública) no README, no plugin e no diário 01 | intencional, mantido |
| Caminhos pessoais (`C:\Users\...`) | só um caminho **fictício** (`C:\Users\x`) em `tests/chatclient_test.cpp`, do commit original do Plasdria | mantido |
| E-mail em teste | `tests/fake_claude.py`, endereço de exemplo (`example.invalid`) | mantido |
| SSID, redes salvas, nome do computador, IPs reais | nenhum | — |
| Lembretes reais, nome configurado | nenhum | — |
| Música real (título, artista, álbum) | nenhum | — |
| Cidade | só a **cidade padrão herdada do Plasdria** (`AppSettings.qml`, `config/main.xml`, `tools/preview.qml`) e nos resultados de teste dos diários 02 e 03. Não é a cidade configurada pelo usuário | mantida (decisão do usuário) |
| Modelo do notebook e da CPU/GPU | diário 04 (4 linhas) | trocado por rótulos genéricos; os números da comparação ficaram (decisão do usuário) |
| Capturas de tela com dados reais | `docs/screenshot.png`, `docs/screenshot-narrow.png`, `docs/banner.png`: do Plasdria original, com nome, lembretes, agenda, música e cidade do autor original; não usadas pelo README | **removidas** (decisão do usuário). Continuam no histórico, como no repositório público do Plasdria |
| `docs/diario/img/` | capturas do rodapé do clima com dados fictícios ("CIDADE", "-10°", "100%") | mantidas |
| `.claude/settings.local.json`, credenciais, caches, `.ini`, `media.json`, `.dll`/`.exe` | nenhum versionado; `settings.local.json` ignorado pelo `.gitignore` | — |
| Licenças | `LICENSE` (MIT do DREAVON, Plasdria e PRAGUS), `COPYING-ICONS` dos ícones Breeze, `.claude/skills/design-system/LICENSE` (MIT) e `.claude/skills/task-observer/LICENSE.txt` (CC BY 4.0), todos versionados; a tabela em `.claude/skills/README.md` aponta para eles | completo; a LGPL do Qt foi acrescentada ao README no 7b e aparece na aba Sobre |
| Menções ao "Plasdria" | só crédito ou histórico: README, CONTRIBUTING, `windows-port.md`, `passo-2-casca.md` (plano da troca de nome), aba Sobre e diários | mantidas |

## Verificação
| Teste | Resultado |
| --- | --- |
| Build do zero (diretório `build-windows-release` apagado, `build-windows.ps1`) | ok, sem erros; a conferência de versão do CMake passou (1.0.0 = 1.0.0) |
| Versão no QML | `AppInfo.version` = "1.0.0" |
| App aberto pelo atalho do Menu Iniciar | ok (confirmado pelo usuário): aba Sobre com "DREAVON 1.0.0", créditos e licenças; chat, clima, sistema, rede, música, lembretes com toast "DREAVON", atalho global e bandeja |
| `tests/timeparse_test.qml` (no `qml.exe`) | **todos os testes passaram** |
| `tests/windows/injecao-cmd/injecao.ps1` | **todos os cenários passaram** (3 cenários, 10 verificações) |
| `tests/chathistory_test.cpp` (CMake temporário fora do repositório; o `.pro` é qmake) | **"ChatHistory checks passed"**, código 0 |
| `tests/chatclient_test.cpp` | **não verificado**: usa qmake e aponta o "executável" do Claude para `fake_claude.py`, que só roda direto no Linux |
| `tests/mediaclient_test.cpp` e `tests/run.sh` | **não verificado**: dependem de D-Bus (`dbus-run-session`), só no Linux |

## Não verificado
- **Linux:** compilação e execução, inclusive os testes de chat e de música com D-Bus.
- **Conferência de versão divergente:** a parada do build com números diferentes foi escrita, mas não provocada de propósito.
- **Link da aba Sobre com o repositório privado:** abre a página do GitHub, que pede login para quem não tem acesso.

## Pendências
- **Depois do merge:** criar a tag `v1.0.0` na `main` e o GitHub Release com `docs/releases/v1.0.0.md` (com o autor).
- **Limitações do 1.0.0:** ver o CHANGELOG.
- **Testes de chat e música no Windows:** adaptar para CMake e um CLI falso que rode no Windows, se for útil.
