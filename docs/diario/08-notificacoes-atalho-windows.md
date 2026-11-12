# 08 — Notificações dos lembretes e atalho global no Windows

Data: 2026-11-12 · Branch: `feat/notificacoes-atalho-windows`

## Causa
- **Notificações:** `DashboardClient::notify()` (`native/dashboardclient.cpp`) só enviava a notificação pelo D-Bus (`org.freedesktop.Notifications`). No Windows havia um `TODO(Windows)` e nada era exibido. O `checkReminders()` do `main.qml` marcava os alarmes como avisados, mas sem nenhum aviso na tela.
- **Atalho global:** no Linux, o atalho era o do Plasma. A janela própria do Windows (passo 2) não tinha nenhum: o painel só abria pelo ícone da bandeja.
- **Bandeja:** já existia desde o passo 2 (`Qt.labs.platform` `SystemTrayIcon`). Só ganhou a notificação e o clique nela.

## O que foi implementado
| Arquivo | Mudança | Motivo |
| --- | --- | --- |
| `native/dashboardclient.h/.cpp` | No Windows, `notify()` emite `notificationRequested(title, body)` e conta o pedido na categoria `dreavon.notify`. O caminho do D-Bus não mudou | O QML continua chamando o mesmo `dashBackend.notify(...)` |
| `package/contents/ui/main.qml` | `tray.showMessage(...)` ao receber o pedido; `onMessageClicked` mostra o painel; alarmes da mesma verificação agrupados num aviso só (Windows); `GlobalHotkey` ligado ao `togglePanel()` | Toast pelo ícone da bandeja e atalho com o mesmo efeito do clique na bandeja |
| `package/contents/ui/RemindersCard.qml` | Marca "🔔 Alarme tocou às HH:MM · dispensar" no lembrete e contador 🔔 no topo do cartão, até ser dispensado, concluído ou adiado | O alarme não se perde se o toast foi escondido (Não Perturbe, PC bloqueado) |
| `native/hotkey_win.h/.cpp` (novo) | `RegisterHotKey` numa janela só de mensagens (`HWND_MESSAGE`); `parse()` da combinação; `probe()` testa uma combinação sem ficar com ela; categoria `dreavon.hotkey` | Win32, sem dependência |
| `native/globalhotkey.h/.cpp` (novo) | Tipo `GlobalHotkey` para o QML (`sequence`, `paused`, `registered`, `status`, `check()`, `activated`). No Windows usa `hotkey_win`; nas outras plataformas não faz nada (`supported = false`) | O `main.qml` é o mesmo em todos os sistemas, então o tipo precisa existir em todos |
| `package/contents/ui/AppSettings.qml`, `SettingsWindow.qml`, `ConfigGeneral.qml` | Chave `globalShortcut` (padrão `Ctrl+Shift+Alt+D`) e a seção "Atalho global" na página Geral: campo de captura e situação (ativo / livre / em uso / inválida) | Atalho configurável, salvo com as outras configurações |
| `CMakeLists.txt` | `globalhotkey.cpp` em todos os sistemas; `hotkey_win.cpp` só no `WIN32` (a `user32` já é ligada por padrão) | Nenhuma biblioteca nova |

### Notificações
- **Entrega:** `showMessage` do ícone da bandeja que já existe. O Windows 10/11 mostra a mensagem como toast e a guarda na central de notificações.
- **Agrupamento:** os alarmes vencidos numa mesma verificação (a cada 15 s) viram **um** aviso só:
  - 1 alarme → "Lembrete" (ou "Lembrete atrasado" se passou mais de 2 min da hora);
  - vários → "N lembretes" (ou "N lembretes atrasados"), com até 3 textos e "…e mais N".
- **Atrasados** (PC suspenso, desligado ou app fechado): na primeira verificação depois de voltar, os vencidos há menos de 6 h saem num aviso agrupado, **uma vez só** (`notified`). Os mais antigos só são marcados, como antes.
- **Indicador no cartão:** cada alarme que tocou ganha `alarmAt`, e o cartão mostra a marca 🔔 até ela ser dispensada, o lembrete ser concluído ou adiado. Isso cobre o Não Perturbe, que esconde o toast sem avisar o app.
- **Linux sem mudança:** o agrupamento e o indicador só valem quando `Qt.platform.os === "windows"`. No Linux continua uma notificação D-Bus por alarme.
- **Privacidade:** o título e o texto do lembrete só vão para a notificação. O log (`dreavon.notify`) tem só a contagem de pedidos.

### Atalho global
- **Registro:** `RegisterHotKey` com `MOD_NOREPEAT`, numa janela própria só de mensagens. O `WM_HOTKEY` chega ao `WndProc` dela e é repassado ao QML na volta do laço de eventos.
- **Por que a janela própria:** a opção sugerida era a fila da thread com filtro nativo do Qt. Só que mensagens postadas na thread se perdem enquanto o Windows roda um laço modal (arrastar ou redimensionar a janela, menu aberto), e o atalho falharia nesses momentos.
- **Ação:** a mesma de clicar no ícone da bandeja (`togglePanel()`):
  - DREAVON oculto, minimizado ou atrás de outro app → vem para a frente com foco no chat;
  - DREAVON na frente e com foco → oculta.
- **Configuração** (Configurações > Geral > Atalho global):
  - **Captura:** clique no campo e pressione a combinação. Esc cancela; Backspace volta ao padrão.
  - **Durante a captura:** o atalho atual fica solto (`paused`), senão a combinação abriria e fecharia o painel em vez de chegar ao campo.
  - **Situação mostrada:** "Ativo.", "Livre. Clique em Aplicar ou OK para usar.", "Em uso por outro aplicativo…" (erro 1409 do Windows) ou "Combinação inválida…". Assim o atalho nunca falha em silêncio.
  - **Combinações aceitas:** Ctrl, Alt ou Win com uma letra, um número, F1–F24 ou Espaço. Só Shift não basta.
- **Desregistro:** ao trocar de atalho, o anterior sai antes de o novo ser registrado. Ao fechar o app, o destrutor chama `UnregisterHotKey` e destrói a janela.

## Decisões e alternativas
**Notificação: bandeja do Qt x toast WinRT** (escolha do usuário: bandeja do Qt)

| Critério | `showMessage` da bandeja (Qt) | Toast WinRT (C++/WinRT) |
| --- | --- | --- |
| App fechado | não avisa (quem confere os lembretes é o app) | também não avisa, pelo mesmo motivo |
| App na bandeja | avisa | avisa |
| Clique | `messageClicked` → mostra o painel | precisa de ativador COM com o app em segundo plano |
| Não Perturbe | o Windows esconde e guarda na central; o app não fica sabendo | igual |
| Nome e ícone no toast | os do executável (hoje o `qml.exe`; "DREAVON" com o `dreavon.exe` do instalador) | "DREAVON" e ícone próprio |
| Exigências | nenhuma | AUMID registrado num atalho do Menu Iniciar (criar um `.lnk` no perfil agora, trabalho do instalador) |
| Esforço / dependência | pouco código, Qt puro | mais código e mais peças para o instalador manter |

**Atalho: RegisterHotKey x gancho de teclado x biblioteca** (escolha do usuário: `RegisterHotKey`)
- **`RegisterHotKey`:** API oficial. O Windows avisa quando o atalho já está em uso (erro 1409), e o app só recebe a combinação registrada.
- **Gancho de baixo nível (`WH_KEYBOARD_LL`):** veria todas as teclas digitadas no PC. É ruim para privacidade e costuma ser marcado por antivírus.
- **QHotkey (terceiros):** usa o mesmo `RegisterHotKey` por baixo e acrescentaria uma dependência.

**Atalho padrão: `Ctrl+Shift+Alt+D`** (escolha do usuário)
- **Candidatos testados nesta máquina:** registrados e desregistrados na hora.
  - **Já em uso:** `Ctrl+Alt+Espaço`, `Win+Alt+D` e `Win+Shift+Espaço`.
  - **Livres:** `Ctrl+Shift+Alt+D`, `Win+Shift+D`, `Ctrl+Alt+D` e `Ctrl+Shift+Espaço`.
- **Combinações só com Ctrl+Alt:** foram evitadas, porque no teclado ABNT2 equivalem ao AltGr e podem colidir com caracteres digitados.

**Trazer a janela para a frente:** sem nenhum truque.
- Nada de `AttachThreadInput` nem de `SendInput`: o app só chama o `raise()` e o `requestActivate()` do Qt.
- **Pelo atalho:** o Windows deixa o processo que recebe o `WM_HOTKEY` vir para a frente, porque a tecla foi a última entrada do usuário.
- **Pelo clique no toast:** o shell dá a mesma permissão ao app dono do ícone.

## DREAVON x Windows (testes nesta máquina)
Só com textos "Lembrete de teste". Nenhum texto real foi registrado.

| Teste | Resultado |
| --- | --- |
| Lembrete em 1 min com o app aberto | toast apareceu (confirmado pelo usuário) |
| Clique no toast | o painel veio para a frente (confirmado pelo usuário) |
| Lembrete em 1 min com o app na bandeja (janela fechada no X) | toast apareceu (confirmado pelo usuário) |
| Dois lembretes no mesmo minuto | um aviso só, "2 lembretes" (confirmado pelo usuário) |
| Indicador 🔔 no cartão e "dispensar" | apareceu e sumiu ao dispensar (confirmado pelo usuário) |
| Atalho com navegador e VS Code em foco | o DREAVON veio para a frente com foco; de novo, ocultou (confirmado pelo usuário). O registro da sessão contou **8 acionamentos** |
| Atalho já em uso nas Configurações (`Ctrl+Alt+Espaço`) | aviso vermelho "Em uso por outro aplicativo" (confirmado pelo usuário) |
| Registro ao abrir | "registro aceito" no log (`dreavon.hotkey`) |
| Desregistro ao fechar | com o app aberto, `Ctrl+Shift+Alt+D` dava "em uso" para outro processo; depois de fechar, "livre" |

## Estados
| Estado | Comportamento |
| --- | --- |
| Não Perturbe ligado | o Windows esconde o toast e o guarda na central; a marca 🔔 fica no cartão até ser vista |
| App na bandeja | os alarmes são conferidos a cada 15 s com a janela oculta; o toast aparece e o clique abre o painel |
| Vários alarmes juntos | um aviso agrupado (até 3 textos + "…e mais N") |
| PC bloqueado | o app continua rodando e o toast segue a regra do Windows para a tela de bloqueio; a marca 🔔 fica no cartão |
| PC suspenso ou app fechado | na volta, um aviso agrupado "atrasado", uma vez só (vencidos há menos de 6 h) |
| Atalho em uso por outro app | aviso na tela de configuração; o DREAVON segue sem atalho até a troca |

## Não verificado
- **Nome no topo do toast:** o usuário não informou qual apareceu. Com o `qml.exe` deve ser o do executável do Qt; com o `dreavon.exe` do instalador deve ser "DREAVON".
- **Itens opcionais**, sem confirmação específica além do "testes ok" geral:
  - Não Perturbe ligado;
  - lembretes atrasados após fechar o app ou suspender o PC;
  - atalho com jogo ou vídeo em tela cheia.
- **PC bloqueado no momento do alarme.**
- **Atalho com a janela de outro app rodando como administrador:** o Windows pode impedir que um app comum venha para a frente dela.
- **Linux:** não compilado aqui. Pela leitura:
  - o D-Bus de `notify()` não mudou;
  - o agrupamento e o indicador só valem no Windows;
  - `GlobalHotkey` não faz nada fora do Windows, e a seção do atalho fica oculta (`supported = false`).

## Pendências
- **Toast com nome e ícone do DREAVON, botões ("Adiar 10 min") e clique com o app fechado:** depende do AUMID e do atalho no Menu Iniciar, que o instalador (passo 7b) deve criar. Aí vale avaliar o toast WinRT.
- **Saber se o Não Perturbe está ligado** (por exemplo, para mudar o texto do indicador): não há API simples e confiável para apps comuns. Hoje o indicador aparece sempre que um alarme toca.
