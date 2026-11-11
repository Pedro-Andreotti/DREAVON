# Passo 3 — Partes portáveis (clima, notícias, lembretes, calendário e chat)

**Status: concluído em 11/11/2026** (PR #9), com pendências de verificação listadas abaixo. O registro do que foi feito, com o resultado por provedor e por cartão, está em [`docs/diario/03-partes-portaveis.md`](diario/03-partes-portaveis.md).

**Resumo:** clima, notícias, calendário e lembretes já funcionavam no Windows sem mudança. As correções foram no chat: localizar os CLIs, executá-los sem passar pelo `cmd.exe` (teste de injeção com 10 de 10 verificações ok), abrir o CLI num terminal do Windows e reconhecer o histórico.

**Ainda não verificado:** Codex, Gemini CLI, Antigravity e Ollama não estão instalados na máquina de teste (as contas do Antigravity, do Gemini CLI e do Codex existem, mas falta instalar e entrar em cada CLI); calendário com link `.ics` real; Gemini lendo a pergunta pelo stdin quando só existe o `.cmd`.

Objetivo: verificar no Windows cada área que não depende de D-Bus e corrigir o que for específico de Linux. A casca (passo 2) já mostrou clima, notícias, lembretes e calendário, e o chat respondeu pelo Claude.

## O que verificar e corrigir
1. Abrir o CLI em terminal: `konsole` (`native/plugin.cpp`) → Windows Terminal, PowerShell ou `cmd`.
2. Localizar os CLIs de IA (`findBinary`): caminhos de Linux e `PATH` montado com `:` → `QDir::listSeparator()` e os locais do Windows (`%APPDATA%\npm` etc.).
3. Executar CLIs `.cmd`/`.bat` sem risco de injeção de comandos: preferir `.exe` ou `node` direto; texto do usuário por stdin, nunca como argumento. Testar com aspas, `&`, `|`, `%` e quebras de linha.
4. Histórico e importação de conversas (`chathistory.cpp`): `~/.claude`, `~/.codex`, `~/.gemini/antigravity*` no Windows.
5. Cada provedor do chat: Claude, Codex, Gemini CLI, Antigravity, Ollama e API Compatível (instalado e testado, ou "indisponível" sem erro).
6. Clima e cidades (Open-Meteo): busca de cidade, localização por IP, resumo semanal.
7. Notícias (RSS): tema, acentos e links.
8. Calendário (iCal), incluindo eventos que se repetem.
9. Lembretes: horário na frase, concluir, remover, limpar; `tests/timeparse_test.qml` com o `qml.exe`.
10. Pequenas pendências do passo 2: texto "Como posso ajudar?" por baixo do aviso de erro; ajuda do campo da chave que cita `OPENAI_API_KEY`.

## Item para teste: ícone na barra de tarefas
- **Situação:** ao abrir pelo `qml.exe`, a barra de tarefas mostra o ícone do Qt, e não o do DREAVON. A bandeja já usa o ícone certo.
- **Hipótese a testar (não verificada):** o plugin nativo definir o ícone das janelas ao carregar, com `QGuiApplication::setWindowIcon` a partir de `assets/dreavon.ico`. Isso pode trocar o ícone da janela, mas a barra de tarefas talvez continue mostrando o do `qml.exe`.
- **Resultado esperado do teste:** relatar se a barra de tarefas mudou. Se não mudar, registrar como limite conhecido até o `dreavon.exe` assinado (passo do instalador, com `app/dreavon.rc`).
- **Estado:** não foi feito no PR #9 (o item foi combinado para depois do merge). Pendente.

## Fora do escopo
Sistema, rede e música (passos 4 a 6) e notificação toast (passo 7). Os alarmes dos lembretes continuam sem aviso no Windows; qualquer aviso provisório dentro do app precisa de decisão antes.
