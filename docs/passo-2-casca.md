# Passo 2 — Casca própria para o Windows

Objetivo: abrir o painel do DREAVON numa janela Qt Quick comum, sem Plasma, com o chat e os cartões que já funcionam sem D-Bus (clima, notícias, lembretes, calendário).

## Onde está a dependência do Plasma
Levantamento do código atual (`package/contents/ui`):

| Dependência | Onde | O que fazer |
| --- | --- | --- |
| `PlasmoidItem`, `Plasmoid.*` e `PlasmaCore` | só em `main.qml` | substituir por uma `Window` (ver abaixo) |
| `Plasmoid.configuration` (24 chaves em `config/main.xml`) | `main.qml` | trocar por um objeto de configuração salvo em arquivo |
| `Plasmoid.contextualActions` (4 ações do menu) | `main.qml` | virar menu de contexto da janela e da bandeja |
| `org.kde.kcmutils` (`SimpleKCM`) | `ConfigGeneral`, `ConfigAppearance`, `ConfigCards` | trocar por uma janela de configurações própria |
| `org.kde.kirigami` | 17 arquivos, em geral só ícones | decidir (ver "Decisões") |
| `Shell.qml` (525 linhas) | já é independente do Plasma | reaproveitar como está |

O `tools/preview.qml` já abre o widget numa `Window` comum com um objeto `cfg` simulado. Ele é o ponto de partida.

## Etapas
1. **`Settings` local:** um objeto QML com as 24 chaves de `main.xml` e seus padrões, salvo em `%APPDATA%\DREAVON` (JSON ou `QSettings`). O `main.qml` passa a ler dele no lugar de `Plasmoid.configuration`.
2. **`main.qml` como `Window`:** sem moldura do sistema, fundo escuro com cantos arredondados, arrastável, com tamanho mínimo. Mantém o `Shell` e os clientes (`ClaudeClient`, `DashboardClient`, `MediaClient`, `NetworkClient`).
3. **Bandeja do sistema:** `SystemTrayIcon` (Qt Labs) com mostrar/ocultar e sair, e as 4 ações do menu que hoje são `contextualActions`.
4. **Configurações:** janela própria com as mesmas três páginas, sem o `KCM`.
5. **Ícone do aplicativo:** `.ico` gerado a partir de `docs/brand/dreavon-mark.svg`.
6. **Roteiro de teste:** abrir a janela, ver relógio/clima/notícias/lembretes, enviar uma mensagem pelo chat, fechar para a bandeja e reabrir.

## Decisões (a confirmar)
- **Tipo de casca.** Recomendação: **janela flutuante com ícone na bandeja** para começar, por ser a mais simples e a mais próxima do `preview.qml`. Barra lateral ancorada e widget na área de trabalho ficam para depois, porque exigem API do Windows (appbar, camada do desktop).
- **Kirigami.** Recomendação: **manter no passo 2** para reduzir o risco e só remover quando tudo abrir; ele existe para Windows, mas precisa ser empacotado no instalador. A troca dos ícones fica para uma etapa própria.
- **Nome interno.** `Plasdria` e `local.plasdria` ainda aparecem no código. Trocar junto com o passo 2 evita fazer a mesma mudança duas vezes.

## Segurança
A chave da API compatível (`customApiKey`) hoje fica na configuração do Plasma. No Windows, não guardar em texto puro no arquivo de configurações: preferir o Gerenciador de Credenciais do Windows.

## Fora do escopo deste passo
Música (SMTC), rede, sistema (CPU, RAM, disco, bateria), temperaturas, notificações toast e instalador: passos 3 a 7 do roadmap.
