# Passo 2 — Casca própria para o Windows

Objetivo: abrir o painel do DREAVON numa janela Qt Quick comum, sem Plasma, com o chat e os cartões que já funcionam sem D-Bus (clima, notícias, lembretes, calendário). Neste passo também entram a troca do nome e da logo e a melhoria de segurança da chave da API.

## Decisões (confirmadas em 11/11/2026)
1. **Casca:** janela flutuante com ícone na bandeja do sistema. Barra lateral ancorada e widget na área de trabalho ficam para depois.
2. **Kirigami:** mantido neste passo. A troca dos ícones fica para uma etapa própria, depois que tudo abrir.
3. **Nome e logo:** trocar `Plasdria` por `DREAVON` no código, nos pacotes e nos recursos visuais, e usar a marca do DREAVON no lugar da logo herdada.
4. **Segurança:** a chave da API compatível deixa de ficar em texto puro; passa para o Gerenciador de Credenciais do Windows.

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
1. **`Settings` local:** um objeto QML com as 24 chaves de `config/main.xml` e seus padrões, salvo em `%APPDATA%\DREAVON` (JSON ou `QSettings`). O `main.qml` passa a ler dele no lugar de `Plasmoid.configuration`. A chave `customApiKey` **não** entra nesse arquivo (ver etapa 7).
2. **`main.qml` como `Window`:** sem moldura do sistema, fundo escuro com cantos arredondados, arrastável, com tamanho mínimo. Mantém o `Shell` e os clientes (`ClaudeClient`, `DashboardClient`, `MediaClient`, `NetworkClient`).
3. **Bandeja do sistema:** `SystemTrayIcon` (Qt Labs) com mostrar/ocultar e sair, e as 4 ações do menu que hoje são `contextualActions`. Fechar a janela leva para a bandeja.
4. **Configurações:** janela própria com as mesmas três páginas, sem o `KCM`. O Kirigami continua nos componentes.
5. **Nome:** trocar `Plasdria` por `DREAVON` (ver "Escopo da troca de nome").
6. **Logo e ícone:** trocar os recursos visuais herdados pela marca do DREAVON e gerar o `.ico` a partir de `docs/brand/dreavon-mark.svg`.
7. **Segurança da chave da API:** guardar a chave no Gerenciador de Credenciais do Windows (ver "Segurança").
8. **Roteiro de teste:** abrir a janela, ver relógio/clima/notícias/lembretes, enviar uma mensagem pelo chat, salvar e ler a chave da API, fechar para a bandeja e reabrir.

## Escopo da troca de nome
Levantamento das ocorrências de `Plasdria` (19 arquivos):

| O que | Hoje | Novo |
| --- | --- | --- |
| Plugin QML | `plasdriaplugin`, módulo `Plasdria` (`qmldir`, `CMakeLists.txt`, `bridge.pro`), classe `PlasdriaPlugin` | `dreavonplugin`, módulo `DREAVON`, `DreavonPlugin` |
| Dados e cache | `plasdria/` em `GenericDataLocation` e `GenericCacheLocation` (`plugin.cpp`, `mediaclient.cpp`, `dashboardclient.cpp`) | `dreavon/` (no Windows: `%LOCALAPPDATA%\DREAVON`) |
| Variável de ambiente | `PLASDRIA_SPOTIFY_COMMAND` | `DREAVON_SPOTIFY_COMMAND` |
| Pacote Plasma | `local.plasdria`, `Name`, `Icon` em `package/metadata.json` | `local.dreavon`, `DREAVON`; autor e versão do projeto |
| Textos da interface | tooltip em `main.qml`, nomes das cores em `ConfigAppearance.qml` ("Plasdria (azul)" etc.), título da notificação | DREAVON; a cor padrão passa de `#3daee9` (azul do Plasma) para o azul elétrico `#2f8bff` |
| Scripts e testes | `build.sh`, `install.sh`, `tests/*` | renomear os textos; os scripts do plasmoide viram legado Linux (remoção decidida depois) |
| Documentação | `README.md`, `CONTRIBUTING.md`, `docs/*` | manter as menções ao Plasdria como **crédito** (origem do projeto) e trocar as demais |

Os créditos no `LICENSE` e a seção "Baseado no Plasdria" do README **não** mudam.

## Escopo da troca de logo
- `package/contents/ui/assets/`: `icon.png`, `mark.png`, `mark-mono.png` e `wordmark.png` pelas versões do DREAVON (marca, versão monocromática e nome).
- `images/`: logos e ícones originais do Plasdria; substituir pelos do DREAVON ou remover.
- `docs/banner.png`, `docs/screenshot.png` e `docs/screenshot-narrow.png` mostram o Plasdria; remover ou substituir por capturas do DREAVON quando houver interface no Windows. O README já não usa essas imagens.
- Ícone do aplicativo e da bandeja: `.ico` gerado da marca.

## Segurança
Hoje a chave da API compatível (`customApiKey`, usada em `plugin.cpp` para o cabeçalho de autorização) fica na configuração do Plasma, em texto puro.

- **Onde guardar:** Gerenciador de Credenciais do Windows (`CredWrite`, `CredRead` e `CredDelete`, do `wincred.h`), com o nome de destino `DREAVON/customApiKey`. A chave fica protegida pela conta do usuário do Windows.
- **Como:** uma classe C++ pequena no plugin (por exemplo `CredentialStore`), exposta ao QML com `set`, `get`, `remove` e `exists`. Em outras plataformas, a mesma interface devolve "não suportado" e mantém o comportamento atual.
- **Configurações:** o arquivo de configurações guarda só o nome do destino, nunca a chave. A tela de configurações mostra o campo mascarado, com "alterar" e "remover".
- **Migração:** se existir uma chave em texto puro na configuração antiga, mover para o Gerenciador de Credenciais e apagar o valor antigo.
- **Cuidados:** não registrar a chave em logs, nem no `console.log`, nem nas mensagens de erro; avisar quando a URL da API não for `https://` (exceto `localhost`).

## Fora do escopo deste passo
Música (SMTC), rede, sistema (CPU, RAM, disco, bateria), temperaturas, notificações toast e instalador: passos 3 a 7 do roadmap. Trocar o Kirigami: etapa futura.
