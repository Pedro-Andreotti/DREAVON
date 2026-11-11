# 02 — Casca própria no Windows (passo 2)

Data: 2026-11-11 · Branch: `feat/shell-windows` · Plano: [../passo-2-casca.md](../passo-2-casca.md)

## Resultado
O DREAVON abre no Windows numa janela própria, sem Plasma, com ícone na bandeja. Para abrir:

```powershell
.\build-windows.ps1 -Run
```

O roteiro de teste (etapa 8) passou inteiro; detalhes no fim desta nota.

## O que mudou, por etapa
1. **Configurações locais** (`AppSettings.qml`): as chaves de `config/main.xml` com os mesmos padrões, num `.ini` em `%APPDATA%\DREAVON\settings.ini` (`QtCore.Settings`). A chave da API não entra nesse arquivo.
2. **Janela** (`main.qml`): `Window` sem moldura, fundo escuro com cantos arredondados, arrastável pela barra de título (duplo clique maximiza), redimensionável pelas bordas, mínimo de 340×480. Mantém o `Shell` e os clientes. Saíram `PlasmoidItem`, `Plasmoid.*` e `PlasmaCore`.
3. **Bandeja** (`Qt.labs.platform.SystemTrayIcon`): clique mostra/oculta; o menu tem Mostrar/Ocultar, as 4 ações antigas do plasmoide, Configurações e Sair. O botão fechar só esconde a janela. As mesmas ações estão no clique direito da barra de título.
4. **Configurações** (`SettingsWindow.qml`, `ConfigPage.qml`): janela própria com Geral, Cartões e Aparência, botões OK, Aplicar e Cancelar. As páginas mantêm o padrão `cfg_<chave>` do Plasma; só trocou a raiz (`KCM.SimpleKCM` → `ConfigPage`).
5. **Nome**: plugin `dreavonplugin`, módulo `DREAVON`, classe `DreavonPlugin`, pastas `dreavon/`, `DREAVON_SPOTIFY_COMMAND`, `metadata.json` (`local.dreavon`, versão `0.1.0`, autor Pedro Andreotti), textos e cor padrão `#2f8bff`. Sobram menções ao Plasdria só como crédito ou histórico.
6. **Logo**: `assets/` com a marca, a versão monocromática e o letreiro, todos gerados dos SVGs em `docs/brand/` (novos: `dreavon-wordmark.svg` e `dreavon-mark-mono.svg`); `assets/dreavon.ico` (16 a 256 px) para a bandeja e para o `dreavon.exe`. A pasta `images/` (logos do Plasdria) foi removida.
7. **Chave da API**: classe `CredentialStore` (`native/credentialstore.*`) com `set`, `get`, `remove`, `exists` e `migrateFromSettings`, usando `CredWrite`/`CredRead`/`CredDelete` com o destino `DREAVON/customApiKey`. Detalhes em "Segurança".

## Desvios do plano (decididos durante o passo)
- **Kirigami no Windows**: não faz parte do Qt e não estava instalado. Decisão: um **substituto mínimo** só para o Windows, em `windows/qml/org/kde/kirigami/` (Icon, Separator, FormLayout, FormData, Units e Theme), com um plugin C++ pequeno (`native/kirigamishim/`) para a propriedade anexada `FormData`. O QML continua importando `org.kde.kirigami`; no Linux vale o Kirigami de verdade. Os ícones são um subconjunto do Breeze (LGPL-3.0, aviso em `icons/COPYING-ICONS`). Para usar um ícone novo, siga `icons/README.md`.
- **Como abrir**: o **Controle Inteligente de Aplicativos** do Windows está ativo e bloqueia executáveis sem assinatura, então o `dreavon.exe` compilado não abre. Decisão: abrir pelo `qml.exe` do Qt (assinado) com o ponto de entrada `windows/dreavon.qml`, que define o nome do aplicativo antes de carregar a janela. O `app/main.cpp` (com o ícone em `app/dreavon.rc`) fica para o instalador, quando houver assinatura.
- **Estilo dos controles**: Fusion (`QT_QUICK_CONTROLS_STYLE`), para a paleta escura da janela de configurações valer em qualquer tema do Windows.
- **`ConfigAppearance.qml`**: a lista de cores se chamava `palette`, que colide com a propriedade `palette` dos controles do Qt. Foi renomeada para `accentChoices`.
- O botão de configurações usa o ícone `configure`: o `preferences-system` do Breeze é colorido e virava um quadrado branco com a máscara.

## Segurança da chave da API
- No Windows a chave fica no Gerenciador de Credenciais (tipo genérico, usuário `DREAVON`, persistência só nesta máquina). O `settings.ini` guarda só `customApiKeyTarget=DREAVON/customApiKey`.
- O `ClaudeClient` ganhou `customApiKeyTarget` e lê a chave do cofre **em C++, na hora da requisição**; a chave não passa pelo QML.
- O `CredentialStore` só aceita destinos que começam com `DREAVON/`, para o QML não ler outras credenciais. As mensagens de erro trazem só o código do Windows, nunca a chave.
- Configurações → Geral (com "API Compatível"): campo mascarado, "Salvar/Alterar" e "Remover"; a chave salva nunca é mostrada. O que foi digitado e não salvo é apagado ao abrir e fechar a janela. Aviso em vermelho quando o endpoint não usa `https://` (exceto `localhost`, `127.0.0.1` e `[::1]`).
- Migração: ao abrir, uma `customApiKey` em texto puro no `settings.ini` vai para o cofre e é apagada do arquivo (só é apagada se a gravação no cofre deu certo).
- Outras plataformas: `supported` é falso, as funções devolvem "não suportado nesta plataforma" e a chave segue em texto puro nas configurações, como antes.

## Roteiro de teste (etapa 8) — 11/11/2026
| Item | Resultado |
| --- | --- |
| A janela abre | ok, sem erros de QML no console |
| Relógio, clima, notícias, lembretes e calendário aparecem | ok (Ourinhos, 27 °C, notícias do G1/Poder360, calendário de novembro) |
| Mensagem pelo chat | ok: `/ia claude`, `/model haiku` e "Responda apenas com a palavra: funcionando"; o Claude respondeu "funcionando" e a cota de 5h apareceu. Depois a IA voltou para Antigravity |
| Salvar e ler a chave da API | ok com uma chave falsa: `cmdkey /list:DREAVON*` mostra `DREAVON/customApiKey`, tipo genérico; a leitura devolve a mesma chave; depois foi removida |
| A chave não aparece em arquivos de configuração | ok: nenhuma ocorrência em `%APPDATA%\DREAVON`, `%LOCALAPPDATA%\dreavon` nem no registro (`HKCU\Software\DREAVON`, `HKCU\Software\QtProject`) |
| Fechar para a bandeja e reabrir | ok: fechar esconde a janela com o processo vivo; clicar no ícone (em "Mostrar ícones ocultos") traz a janela de volta |

Testes extras da etapa 7: um servidor falso em `localhost` recebeu `Authorization: Bearer <chave do cofre>`; destinos fora de `DREAVON/` são recusados; a migração moveu a chave e apagou a linha do `.ini`; a chave não aparece na saída do programa.

## Pendências e observações
- **Linux não testado** nesta máquina. As pastas de dados mudaram de `plasdria/` para `dreavon/`: quem usava o Plasdria no Linux não verá o histórico antigo sem copiar a pasta.
- Os testes em `tests/` ainda dependem de qmake e `dbus-run-session`.
- Os alarmes dos lembretes não avisam no Windows: a notificação toast é do passo 7.
- Ícones que faltam no subconjunto do Breeze (`spotify`, `Synchronize`, `preferences-desktop-color`) aparecem vazios; o texto ao lado continua.
- No chat, o texto "Como posso ajudar?" fica por baixo do aviso de erro quando o CLI não está instalado (já era assim na base).
- O texto de ajuda do campo da chave cita `OPENAI_API_KEY`, mas o plugin não lê essa variável (já era assim na base).
- Matar o processo à força deixa um ícone "fantasma" na bandeja até passar o mouse; fechar pelo menu "Sair" não deixa.
- Antes da troca de nome, os testes criaram `%LOCALAPPDATA%\plasdria` (cache de clima). Pode ser apagada.
- As capturas antigas em `docs/` (`banner.png`, `screenshot*.png`) ainda mostram o Plasdria; ficam até haver capturas do DREAVON.
