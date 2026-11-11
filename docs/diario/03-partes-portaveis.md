# 03 — Partes portáveis no Windows (passo 3)

Data: 2026-11-11 · Branch: `feat/portaveis-windows`

## Resumo
Clima, notícias, calendário e lembretes já funcionavam no Windows sem mudança. As correções foram no chat: localizar os CLIs de IA, executá-los sem passar pelo `cmd.exe`, abrir o CLI num terminal do Windows e reconhecer o histórico. Também saíram duas pendências pequenas do diário 02.

## O que foi corrigido
| Item | Arquivo | Motivo |
| --- | --- | --- |
| 1. Abrir o CLI em um terminal | `native/plugin.cpp` (`openCli`, `openWindowsTerminal`) | Usava `konsole`. No Windows: Windows Terminal (`wt.exe -d <pasta> <cli>`, com `;` escapado); sem ele, uma janela de console com o próprio CLI, sem shell no meio e sem herdar stdin/stdout do app; se nada abrir, mensagem clara. |
| 2. Localizar os CLIs | `native/plugin.cpp` (`windowsBinaryDirs`, `findBinary`, `newProcess`, `providers`) | Os caminhos extras eram de Linux e o `PATH` era montado com `:`. No Windows: `%APPDATA%\npm`, `%LOCALAPPDATA%\agy\bin` (pasta do instalador oficial do Antigravity, segundo a [documentação](https://antigravity.google/docs/getting-started/)), `%LOCALAPPDATA%\Programs` (e `Programs\<Nome>`, onde fica o Ollama) e `~\.local\bin`, com `.exe` antes de `.cmd`/`.bat` e `QDir::listSeparator()`. |
| 3. `.cmd`/`.bat` (segurança) | `native/plugin.cpp` (`windowsLaunch`, `batchArgumentsSafe`, `setArgs`, `startProcess`) + `tests/windows/injecao-cmd/` | Ver "Segurança". |
| 4. Histórico | `native/chathistory.cpp` (`samePath`) | A conversa feita pelo app aparecia como "SDK" e não "Pragus": a pasta no disco é `...\Local\DREAVON\workspace` e o app monta `.../dreavon/workspace`. No Windows a comparação agora ignora maiúsculas. |
| 10a. "Como posso ajudar?" por baixo do aviso de erro | `package/contents/ui/ChatView.qml` | O estado vazio era centralizado com `anchors.centerIn`; sem altura, subia por cima do aviso. Agora não passa do topo e a área corta o excesso. |
| 10b. `OPENAI_API_KEY` no campo da chave | `package/contents/ui/ConfigGeneral.qml` | O plugin não lê essa variável; a menção saiu do texto de ajuda. |

Todo o código específico de Windows está atrás de `#ifdef Q_OS_WIN`; o D-Bus continua atrás de `QT_DBUS_LIB`. As duas mudanças de QML (10a e 10b) valem para todas as plataformas.

## Segurança: CLIs que são `.cmd`/`.bat`
No Windows, um `.cmd` é executado pelo `cmd.exe`, que interpreta `&`, `|`, `%`, `^`, `!`, `<`, `>` e aspas nos argumentos. Antes, o Codex recebia o texto do chat como argumento e o Gemini CLI como `-p <texto>`; modelo, conversa e caminhos de anexo também vão como argumentos.

- **Shims do npm:** o `.cmd` é lido e o app executa o alvo direto: o `.exe` (caso do Claude Code: `node_modules\@anthropic-ai\claude-code\bin\claude.exe`) ou `node.exe` + o script `.js`. Só aceita alvos dentro da pasta do `.cmd`.
- **`.cmd` desconhecido:** o texto do usuário vai pelo **stdin** (Codex com `exec ... -`; Gemini CLI sem `-p`), nunca como argumento. Se algum outro argumento tiver `" % ! & | < > ^` ou quebra de linha, o app **não executa** e mostra: "Por segurança, o DREAVON não executou o CLI…".
- **Abrir no terminal:** a mesma regra vale para o CLI aberto no Windows Terminal ou no console.
- **Testes** (`tests/windows/injecao-cmd/injecao.ps1`, sem rede, com CLIs falsos): mensagem com `"aspas" & echo INJETADO > pwned.txt | type %PATH% ^ !x!` e quebra de linha.
  - A: `.cmd` desconhecido → a mensagem chegou só pelo stdin, os argumentos ficaram limpos e nada foi injetado.
  - B: o mesmo `.cmd` com um anexo chamado `foto & echo INJETADO %PATH% !.png` → bloqueado com a mensagem de segurança, nada executado, chat não travou.
  - C: shim do npm com `.js` → rodou `node script.js`; a mensagem chegou idêntica, como argumento, sem passar pelo `cmd.exe`.
  - Resultado: 10 de 10 verificações ok.
- Com o Claude de verdade, o único processo filho foi `claude.exe` (mais o `conhost.exe` do console), sem `cmd.exe`.

## Resultado por provedor
| Provedor | Instalado aqui | Resultado |
| --- | --- | --- |
| Claude | sim (npm, `claude.cmd` → `claude.exe`) | **ok**: modelo Haiku, mensagem com `"aspas" & \| % ^ ! < >` chegou intacta, resposta "OK"; também encontrado sem a pasta do npm no `PATH` |
| API Compatível | — | **ok** com servidor falso em `localhost`: `/models`, `/chat/completions` com stream (SSE) e acentos corretos na resposta |
| Codex | não | **não verificado** com o CLI real. Sem ele: "Codex CLI não encontrado…", sem travar. Caminho de execução testado com CLIs falsos (A, B, C) |
| Gemini CLI | não | **não verificado**. Sem ele: "Gemini CLI não encontrado…", sem travar. O envio pelo stdin quando só existe `.cmd` não foi testado com o CLI real |
| Antigravity (`agy`) | não | **não verificado**. Sem ele: "Antigravity CLI (agy) não encontrado…", sem travar |
| Ollama | não | **não verificado**. Sem ele: "Ollama não respondeu em http://127.0.0.1:11434…", sem travar |

## Resultado por cartão e área
| Área | Resultado | Como foi verificado |
| --- | --- | --- |
| Abrir o CLI no terminal | **corrigido** | CLI falso: no Windows Terminal (`WT_SESSION` presente, pasta de trabalho certa) e, sem o `wt`, numa janela de console própria |
| Histórico e importação | **corrigido** | 30 conversas reais do Claude listadas e uma carregada; `tests/chathistory_test.cpp` compilado com CMake no Windows: "ChatHistory checks passed"; sessão de teste com CRLF, acentos e caminho com `\` lida certo |
| Clima | ok | Ourinhos: temperatura, 7 dias e 12 horas; localização automática por IP encontrou a cidade (nome não registrado aqui) |
| Busca de cidade | ok | "São Paulo" e "Ourinhos" na Open-Meteo |
| Notícias | ok | Temas Principais, Tecnologia e Esportes: 8 itens cada, acentos nos títulos, links `https://` |
| Calendário (iCal) | ok | Arquivo de teste em `localhost` com CRLF, linhas dobradas, acentos, `TZID`, dia inteiro, `RRULE` diária e semanal com `EXDATE`: todas as ocorrências certas |
| Calendário com link real (Google) | **não verificado** | Não há link `.ics` real configurado nesta máquina |
| Lembretes | ok | No `RemindersCard`: "amanhã 9h", "em 20 min" e "sexta 14h30" com o horário certo; marcar feito, remover e limpar concluídos; `tests/timeparse_test.qml` no `qml.exe`: todos passaram |
| Alarme dos lembretes | sem aviso (esperado) | A notificação toast é do passo 7 |

## Pendências
- Codex, Gemini CLI, Antigravity e Ollama não estão instalados: falta testar cada um de verdade. No Gemini, confirmar que ele lê a pergunta pelo stdin quando só existe o `.cmd`.
- Calendário com um link `.ics` real do Google Agenda.
- As conversas do Codex e do Gemini não têm tratamento para falha ao iniciar o processo (sem `errorOccurred`): se o executável sumir entre a checagem e o envio, o chat pode ficar "Pensando". Já era assim na base; não mexi para não mudar o comportamento no Linux.
- A saída do `qml.exe` no console sai na página de código do Windows (cp1252), não em UTF-8: só afeta logs de teste, não o app.
- Linux não testado nesta máquina (as mudanças de C++ estão atrás de `Q_OS_WIN`; as duas de QML valem para todos).
- Pendências antigas que continuam: testes em `tests/` ainda dependem de qmake e `dbus-run-session`; ícones que faltam no Breeze; capturas do Plasdria em `docs/`.

## Complemento (11/11/2026, branch `feat/pendencias-passo-3`)
| Item | Resultado | Detalhe |
| --- | --- | --- |
| Ícone na barra de tarefas | **corrigido** | O plugin define o ícone das janelas ao carregar (`QGuiApplication::setWindowIcon` com `assets/dreavon.ico`, só no Windows). Abrindo pelo `qml.exe`, a barra de tarefas passou a mostrar o olho do DREAVON no lugar do logo verde do Qt. |
| Antigravity (`agy`) | **ok** | Instalado com o instalador oficial (`install.ps1`, lido antes de rodar: baixa o `agy.exe`, confere o SHA-512 e copia para `%LOCALAPPDATA%\agy\bin`). `agy 1.5.6`, assinatura válida da Google LLC. A pasta é mesmo `%LOCALAPPDATA%\agy\bin`, e o app o encontra mesmo sem ela no `PATH` da sessão. Login feito pelo próprio usuário no CLI. Teste pelo app: 5 modelos listados; resposta com acentos ("Quando você coloca o coração em cada ação…"); texto com `"aspas" & \| % ^ ! < >` e quebra de linha repetido idêntico; anexo `.txt` lido (código respondido certo); histórico com a conversa como "Pragus", carregada com 6 mensagens. Processo filho: só `agy.exe` (sem `cmd.exe`). |
| Gemini CLI | **não verificado** | Não instalado (decisão do usuário). Instalação oficial: `npm install -g @google/gemini-cli`. A documentação diz que contas gratuitas e do Google One passaram para o Antigravity CLI em 18/06/2026. Continua sem teste o envio pelo stdin quando só existe o `.cmd`. |
| Codex | **não verificado** | Não instalado (decisão do usuário). Instalação oficial: `npm install -g @openai/codex` ou o instalador `irm https://chatgpt.com/codex/install.ps1 \| iex`. |
| Ollama | fora do escopo | O usuário não usa e não vai instalar. |
| Falha ao iniciar o Codex e o Gemini | **corrigido** | Tratamento de `errorOccurred` (`FailedToStart`), só no Windows, igual ao do Claude e do Antigravity. Teste com o executável apagado entre a conexão e o envio: "Não foi possível iniciar o Codex." / "…o Gemini CLI.", com o chat liberado. O caso de sucesso não mudou (teste de injeção: 10 de 10). No Linux o problema continua (a regra é não mudar o comportamento lá). |
| Calendário com link real | **ok** (sem recorrências para testar) | O link foi colado pelo usuário nas configurações; o teste imprimiu só números. Download ok (HTTP 200, CRLF), 28 eventos, nenhum `RRULE`. Todos os 28 estão no passado (2017 a 2026), por isso o cartão mostra 0 eventos na janela de ontem a +70 dias, o que está certo. As recorrências seguem verificadas só com o calendário de teste do passo 3. |
