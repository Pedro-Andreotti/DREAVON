# 10 — Uso local no Windows (sem instalador nem assinatura)

Data: 2026-11-12 · Branch: `feat/uso-local-windows`

## Decisão e motivo
O plano original do passo 7b era um instalador com o executável assinado. **O escopo mudou:** o DREAVON roda só na máquina do autor, que não tem certificado de assinatura de código. Por isso:
- **sem instalador e sem assinatura:** nem `signtool`, nem certificado autoassinado;
- **o app continua abrindo pelo `qml.exe` do Qt**, que é assinado, como no `build-windows.ps1 -Run`. O Controle Inteligente de Aplicativos segue ligado e bloquearia um `dreavon.exe` sem assinatura vindo de fora;
- **o que faltava do "jeito de app instalado"** vem de dois scripts por usuário, sem administrador: atalho no Menu Iniciar, nome e ícone nas notificações e início com o Windows opcional.

**Tentativa descartada:** antes da mudança, um pacote com `windeployqt` e um instalador Inno Setup chegaram a ser montados, mas nada foi commitado. Fica registrado para uma eventual distribuição futura:
- os textos LGPL/GPL precisariam acompanhar as DLLs do Qt;
- o `dreavon.exe` hoje grava a pasta do código-fonte (`DREAVON_SOURCE_DIR`) no binário, o que não pode ir para um pacote distribuído;
- a assinatura seria obrigatória para quem tem o Controle Inteligente ligado.

O Inno Setup 6, instalado para esse teste, foi desinstalado depois (`winget uninstall JRSoftware.InnoSetup`).

## O que foi implementado
| Arquivo | Mudança | Motivo |
| --- | --- | --- |
| `tools/install-local.ps1` (novo) | Cria o atalho "DREAVON" no Menu Iniciar do usuário (alvo: `qml.exe` + `windows/dreavon.qml`, ícone `assets/dreavon.ico`, AUMID `DREAVON.Desktop` gravado no atalho); registra o AUMID em `HKCU\Software\Classes\AppUserModelId\DREAVON.Desktop` (nome e ícone); liga ou desliga o início com o Windows por parâmetro | Atalho e identidade de app sem instalador; nada de sistema nem administrador |
| `tools/uninstall-local.ps1` (novo) | Remove só o que o script criou: atalho (se apontar para o `qml.exe` com `dreavon.qml`), chave do AUMID (só com a marca do script) e valor da chave Run (só se for o comando do DREAVON). Lista, sem apagar, as configurações, o histórico, o cache e a chave da API | Não apagar dados do usuário sem perguntar |
| `native/plugin.cpp` | Ao carregar no Windows: estilo Fusion (se ninguém escolheu outro), esconde o console do `qml.exe` quando ele é exclusivo do app e adota o AUMID `DREAVON.Desktop` se o atalho existir | Um atalho não passa variáveis de ambiente nem esconde o console, como o `-Run` fazia por fora |
| `windows/dreavon.qml` | Com `-- --bandeja`, cria a janela já oculta (só na bandeja) | Início com o Windows sem abrir a janela |
| `native/autostart.h/.cpp` (novo) | Tipo `Autostart` para o QML: liga e desliga o valor `DREAVON` da chave Run do usuário com o comando que abriu o app, mais `-- --bandeja` | Interruptor nas Configurações |
| `ConfigGeneral.qml`, `SettingsWindow.qml`, `main.qml` | Seção "Inicialização" com "Iniciar com o Windows" (vale na hora) | Fácil de desligar sem rodar script |
| `CMakeLists.txt` | `autostart.cpp` nas fontes do plugin | — |

### O que o script faz, em ordem
1. **Caminhos sem nada pessoal no repositório:**
   - Qt: `-QtDir`, a variável `QT_DIR` ou o mesmo padrão do `build-windows.ps1`;
   - repositório: a pasta do próprio script.

   O script confere se o plugin e o shim do Kirigami já foram compilados.
2. **Atalho:** em `[Programas do usuário]\DREAVON.lnk`, com a janela "minimizada". O `qml.exe` é um programa de console, então o console nasce minimizado e o plugin o esconde ao carregar. A janela do DREAVON abre normal.
3. **AUMID:**
   - gravado no atalho pela interface COM do Windows (`IShellLinkW` + `IPropertyStore`, num trecho C# compilado em memória); o `WScript.Shell` não grava essa propriedade;
   - conferido pela leitura do próprio Shell (`System.AppUserModel.ID`);
   - registrado com `DisplayName` = DREAVON e `IconUri` = `assets/icon.png`, só no usuário (HKCU).
4. **Início com o Windows:** `-IniciarComWindows` grava `"<qml.exe>" --apptype widget -I "<repo>\windows\qml" "<repo>\windows\dreavon.qml" -- --bandeja` em `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`. `-NaoIniciarComWindows` apaga o valor. Sem nenhum dos dois, fica como está (desligado na primeira vez). Sem serviço nem tarefa agendada.

### Por que o toast passa a mostrar "DREAVON"
- **O mecanismo:** o Windows identifica o dono de uma notificação pelo **AppUserModelID do processo** e busca nome e ícone no atalho do Menu Iniciar com o mesmo AUMID (e no registro em `AppUserModelId`).
- **Antes:** sem AUMID, a notificação ficava com o executável, o `qml.exe` do Qt.
- **Agora:** o plugin chama `SetCurrentProcessExplicitAppUserModelID(L"DREAVON.Desktop")` antes de criar qualquer janela ou o ícone da bandeja, e só quando o atalho existe. Sem o atalho, um AUMID desconhecido poderia fazer o Windows descartar as notificações.
- **Vale para qualquer forma de abrir:** pelo atalho, pelo início com o Windows ou pelo `build-windows.ps1 -Run`, desde que o atalho exista.

## Testes nesta máquina
| Teste | Resultado |
| --- | --- |
| `install-local.ps1` | atalho criado; AUMID lido de volta do atalho pelo Shell; registro com `DisplayName` e ícone; início com o Windows desligado |
| Abrir pelo atalho do Menu Iniciar | a única janela visível do processo é a do DREAVON, normal (não minimizada); o console do `qml.exe` não aparece |
| Toast de um "Lembrete de teste" | topo da notificação com **"DREAVON"** e o ícone do app, em vez do `qml.exe` (confirmado pelo usuário) |
| Ícone na barra de tarefas | o do DREAVON (confirmado pelo usuário) |
| Configurações | tema escuro (estilo Fusion) mantido; "Iniciar com o Windows" liga e desliga, e o item aparece e some em Configurações do Windows > Aplicativos > Inicialização (confirmado pelo usuário) |
| Atalho global e bandeja | funcionando (confirmado pelo usuário) |

## Toast WinRT com "Adiar 10 min" (proposta, não implementada)
Agora que há um AUMID registrado, um toast WinRT (`Windows.UI.Notifications`, por C++/WinRT, como a música no passo 6) ficou possível sem instalador.

**O que ganharia:**
- botões "Adiar 10 min" e "Concluir" no próprio toast;
- texto com mais formatação;
- substituir ou agrupar toasts do mesmo lembrete (`Tag`/`Group`).

**O que custaria:**
- **Botões com o app aberto:** com o app rodando (sempre, já que os alarmes dependem dele), o evento `Activated` do `ToastNotification` basta: sem ativador COM, sem servidor COM registrado.
- **Botões com o app fechado:** aí sim seria preciso um ativador COM registrado (CLSID no registro do usuário e no atalho). É mais peça para manter e não é necessário aqui.
- **Código:** ~150 linhas em `native/notify_win.*` (XML do toast, eventos `Activated`/`Dismissed`) e um sinal para o QML chamar `snooze(id)` e `toggle(id)` no `RemindersCard`.
- **Risco:** o toast WinRT exige o AUMID registrado (já existe). Sem o atalho, teria de voltar ao `showMessage`.

**Recomendação:** vale a pena **se** você costuma adiar lembretes pelo próprio aviso. É um passo pequeno e isolado. Se o uso for só ver o aviso e abrir o painel, o `showMessage` atual já resolve.

## Licenças
- **README:** cita o MIT do DREAVON, do Plasdria e do PRAGUS (arquivo `LICENSE`) e a LGPL-3.0-or-later dos ícones Breeze (aviso em `windows/qml/org/kde/kirigami/icons/COPYING-ICONS`).
- **Qt:** a LGPL-3.0 ainda não aparecia no README e foi acrescentada. No uso local, o app usa as DLLs da instalação do Qt por ligação dinâmica, sem modificá-las e sem redistribuí-las.

## Como abrir manualmente
Passo a passo para quando o DREAVON não iniciar com o Windows: [`docs/abrir-no-windows.md`](../abrir-no-windows.md).

## Não verificado
- **Início com o Windows de verdade** (sair e entrar no Windows): o valor da chave Run foi conferido, e o `--bandeja` foi testado só pela lógica do `dreavon.qml`, sem um logon real.
- **Console num terminal que não seja o padrão** (por exemplo, o Windows Terminal como console padrão): nesta máquina, o console do atalho não apareceu. Com outro terminal configurado, o esconder pode não funcionar.
- **`uninstall-local.ps1`:** escrito e revisado, mas não rodado, para não desfazer o uso local que está ativo. Roda sem administrador e só apaga itens com a marca do script.
- **Linux:** não afetado. `Autostart` não faz nada fora do Windows (`supported = false`), e o `prepareLocalLaunch` está atrás de `#ifdef Q_OS_WIN`.

## Pendências
- **Toast WinRT com botões:** se aprovado (proposta acima).
- **Se um dia houver distribuição:** retomar o instalador. Isso inclui assinatura com uma AC ou o Trusted Signing, `windeployqt`, os textos LGPL/GPL junto das DLLs e o build sem `DREAVON_SOURCE_DIR`.
