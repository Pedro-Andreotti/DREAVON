# 07 — Cartão "Música" no Windows

Data: 2026-11-12 · Branch: `feat/musica-windows`

## Causa
No Windows, o cartão de Música só mostrava a última música salva (`media.json`), sem nada ao vivo:
- `native/mediaclient.cpp` fala com os players pelo **MPRIS**, via D-Bus. Esse código fica atrás de `QT_DBUS_LIB` e não existe no Windows.
- Por isso `poll()` não fazia nada, e os controles (`call`, `setPlayerProperty`) só agendavam uma nova consulta.
- O código marcava o ponto com `TODO(Windows)`: a fonte prevista era a sessão de mídia do Windows (SMTC).

## O que foi implementado
| Arquivo | Mudança | Motivo |
| --- | --- | --- |
| `native/mediainfo_win.h/.cpp` (novo) | `MediaInfoWin::Session`: lê o `GlobalSystemMediaTransportControlsSessionManager` por C++/WinRT (sessão atual, propriedades, `PlaybackInfo`, `TimelineProperties`, capa) e executa os controles (`TryTogglePlayPauseAsync`, `TrySkipNext/PreviousAsync`, `TryChangePlaybackPositionAsync`, `TryChangeShuffleActiveAsync`, `TryChangeAutoRepeatModeAsync`). Também `appLabel()` (nome amigável do app) e `spotifyProtocolRegistered()` | API documentada do sistema; o cabeçalho não expõe nenhum tipo WinRT, então o resto do código continua só com Qt |
| `native/mediaclient.h/.cpp` | No Windows (`#ifdef Q_OS_WIN`): `applyWin()` faz o papel do `apply()` do Linux; os controles vão para o SMTC; a capa recebida em stream vai para o cache já existente (`cacheArtData`); o Spotify é aberto pelo protocolo `spotify:` (`openSpotifyUri`). A limpeza do cache virou a função `pruneArt()`, usada pelos dois sistemas, com a mesma regra | Mesmas propriedades e o mesmo `MediaCard.qml` nos dois sistemas |
| `CMakeLists.txt` | `mediainfo_win.cpp` e `windowsapp`, só no `WIN32`; esse arquivo compila em `/std:c++20` | Biblioteca do sistema (SDK do Windows), sem dependência de terceiros (ver "Decisões") |

O QML não mudou. O cartão já esconde o volume quando ele é `-1`, e o aleatório e o repetir quando o app não os informa.

### Como funciona
- **Por eventos, sem consulta periódica.** O app se inscreve em:
  - `CurrentSessionChanged` e `SessionsChanged` do gerenciador;
  - `MediaPropertiesChanged`, `PlaybackInfoChanged` e `TimelinePropertiesChanged` da sessão.

  Cada evento pede uma leitura. Eventos seguidos se juntam numa só.
- **Fora da thread da interface.** As leituras e os controles rodam em threads do `QThreadPool`, com apartamento COM MTA, onde esperar uma operação assíncrona (`get()`) é permitido. O resultado volta para a thread da interface por fila (`Qt::QueuedConnection`). Se o cliente for destruído no meio, nada é entregue.
- **Posição:** vem da `TimelineProperties` com o horário da medição (`LastUpdatedTime`). Entre eventos, o tick local de 500 ms continua extrapolando, como no Linux.
- **Sessão escolhida:** a "atual" do Windows, a mesma do controle de mídia da barra de tarefas. Se não houver, a primeira que estiver tocando ou, na falta dela, a primeira aberta.
- **Capa:** chega como stream e é lida só quando a música muda, ou enquanto ainda não veio, com limite de 5 MB. Vai para o mesmo cache de capas (`~/.cache/dreavon/art` em `QStandardPaths`), com nome em hash e a mesma limpeza: as 150 mais recentes.
- **Player fechado:** o cartão mantém a "última música lembrada" (`playerGone()` e `media.json`), como no Linux.
- **Indisponível:**
  - o SMTC não dá o volume do player, então `volume` fica `-1` e a barra de volume some;
  - aleatório e repetir só aparecem quando o app os informa (`IsShuffleEnabled`/`IsRepeatEnabled` e valor presente);
  - nenhum valor é inventado.
- **Spotify:**
  - `openSpotify()`, `raise()` (quando o player é o Spotify) e a retomada com o player fechado abrem `spotify:` por `QDesktopServices::openUrl`, que é ShellExecute, sem `cmd.exe`;
  - só endereços fixos: `spotify:` ou uma faixa no formato `spotify:track:<22 caracteres>`, conferida por expressão regular;
  - quando o Spotify aparece no SMTC, o app manda play depois de 1,5 s e, se for a mesma música, volta à posição lembrada;
  - `spotifyInstalled` = protocolo `spotify:` registrado. Vale para o instalador e para a versão da Microsoft Store.
- **Outros apps fechados** (navegadores etc.): não há um jeito seguro e genérico de reabri-los na mesma música. O play com a música lembrada de um deles não faz nada, em vez de deixar o cartão em "abrindo" por 30 s.
- **Diagnóstico:** categoria `dreavon.media`, desligada por padrão (`QT_LOGGING_RULES="dreavon.media.info=true"`). Registra só duração das leituras, eventos juntados, tamanho da capa em bytes e "aceito/recusado" dos controles. Nunca título, artista ou identificadores.

## Decisões e alternativas
**C++/WinRT x COM/WinRT cru** (escolha do usuário: C++/WinRT)

| Critério | C++/WinRT | COM/WinRT cru (ABI + WRL) |
| --- | --- | --- |
| Dependência | cabeçalhos do próprio Windows SDK (`Include\<versão>\cppwinrt`) + `windowsapp.lib` | cabeçalhos ABI do SDK + `runtimeobject.lib` |
| Código | ~300 linhas, com tipos verificados; strings, referências e eventos (`auto_revoke`) gerenciados | 3 a 4 vezes maior: `HSTRING`, `QueryInterface` e callbacks de cada operação feitos à mão |
| Integração com Qt/MSVC | o build do Qt já usa `/EHsc`, `/permissive-` e `/Zc:__cplusplus`; só este arquivo precisa de C++20 (abaixo) | sem exigência de padrão |
| Custo de build | um arquivo pesado (alguns segundos a mais) | um pouco mais leve |
| Tempo de resposta | igual: é a mesma API do sistema | igual |

**C++20 só num arquivo:** em C++17, o C++/WinRT recorre ao `<experimental/coroutine>`, que o MSVC 14.51 recusa (erro STL1011). `mediainfo_win.cpp` compila com `/std:c++20` por `set_source_files_properties`, e o resto do projeto segue em C++17. O MSVC avisa que o padrão foi trocado (D9025); o aviso é esperado.

**Abrir o Spotify** (escolha do usuário: URI `spotify:`): nesta máquina o Spotify é da Microsoft Store (pacote `SpotifyAB`). O executável fica numa pasta protegida (`WindowsApps`) e não há `Spotify.exe` em `%APPDATA%`. O protocolo funciona com as duas versões e também traz o Spotify para a frente quando ele já está aberto.

**Sem processos externos:** nada de PowerShell nem de outro programa para ler a mídia. As leituras e os controles são chamadas diretas à API.

## DREAVON x Windows
Testes com o Spotify (versão da Store) e o Opera, nesta máquina. Os dados reais não foram registrados: títulos aparecem só como hash curto e tamanho.

**Leitura**

| Item | DREAVON | Controle de mídia do Windows | Resultado |
| --- | --- | --- | --- |
| Título, artista | lidos (Spotify: título e artista; Opera/YouTube: título longo, 74 caracteres) | mesmo texto | igual (conferido pelo usuário) |
| Estado (tocando/pausado) | acompanha | mesmo estado | igual (conferido pelo usuário) |
| Posição e duração | da linha do tempo, avançando pelo tick | mesma posição | igual (conferido pelo usuário) |
| Capa | arquivo local no cache (Spotify e YouTube) | mesma capa | igual |
| Nome do player | "Spotify", "Opera" | — | rótulo amigável a partir do AppUserModelId |

**Controles no Spotify:** todos foram aceitos.

| Controle | Aceito | Tempo até o evento de volta |
| --- | --- | --- |
| play/pause (pausar e voltar) | sim | 3 a 290 ms (a primeira leitura já reflete o novo estado) |
| próxima | sim | 3 a 190 ms; a música nova chega em até ~200 ms |
| anterior | sim | volta ao início da música (comportamento do Spotify) |
| posição (ir para 0:30) | sim | 3 a 70 ms |
| aleatório (desligar e religar) | sim | < 1 s |
| repetir (Nenhum → Tudo → Esta música → Nenhum) | sim | < 1 s |

- **Chamadas:** cada controle volta do app em menos de 1 ms (é só o pedido). A mudança aparece no próximo evento.
- **Estado devolvido:** depois dos testes, o aleatório e o repetir voltaram ao que o usuário usava.
- **Botões no cartão:** usados pelo usuário no app aberto (`build-windows.ps1 -Run`), com sucesso.

**Navegadores**
- O Opera (Chromium) aparece no SMTC com o que o site informa pela "Media Session" da página.
- **YouTube:** título, canal (como artista), capa, posição e seek. Próxima, anterior, aleatório e repetir vêm desligados, e o cartão os esconde ou apaga.
- **Netflix:** o site não preenche a Media Session. O navegador manda só o nome do site como título, sem artista e sem capa. O cartão mostra exatamente isso, com o ícone padrão no lugar da capa. O controle de mídia do Windows mostra o mesmo (conferido pelo usuário). Serviu também de teste para "música sem capa".
- Chrome e Edge usam o mesmo mecanismo (Chromium), mas não foram testados (ver abaixo).

**Estados** (monitor de 8 min, uma linha por segundo, só rótulos e números):

| Situação | Resultado |
| --- | --- |
| Troca de player | Spotify → Opera → Spotify: o cartão acompanhou cada troca de sessão atual |
| Troca de música | nova música, capa e duração em menos de 1 s |
| Fechar o Spotify | o cartão passou para a sessão que sobrou (o Opera pausado). Quando ela também sumiu, ficou com a última música lembrada, pausada |
| Reabrir o Spotify | voltou com a mesma música e depois tocou (confirmado pelo usuário) |
| Nada tocando / sem capa / título longo | sem travar; ícone padrão sem capa; título longo em até duas linhas, cortado com reticências pelo cartão |

**Custo** (60 s com música tocando, 12 núcleos lógicos):
- **Só o `MediaClient`:** 234 ms de CPU = **0,39% de um núcleo**, 0,03% da CPU total.
  - Leituras: 8 em 30 s de música sem ação. O Spotify manda eventos de linha do tempo de tempos em tempos.
  - Duração: de 0 a 32 ms cada, média de 4 ms.
- **DREAVON inteiro aberto:** ~32% de um núcleo (3,5% do total), **igual com a música pausada (31,9%) e tocando (31,8%)**. Esse custo não vem da música (ver "Pendências").

**Linux:** não testado nesta máquina. Pela leitura do código:
- `mediainfo_win.*` e `windowsapp` só entram em `WIN32`;
- no `mediaclient.cpp`, todo código novo fica atrás de `#ifdef Q_OS_WIN`, ou em `#elif defined(Q_OS_WIN)` depois do ramo `QT_DBUS_LIB`;
- o timer de consulta e o `poll()` inicial continuam no Linux (`#else` / `#ifndef Q_OS_WIN`);
- `pruneArt()` é o mesmo trecho que estava no lambda de `cacheArt()`, com a mesma regra.

## Não verificado
- **Spotify do instalador** (fora da Store), VLC, Media Player do Windows, Chrome e Edge: nenhum aberto nos testes.
- **Tela de bloqueio:** a comparação foi feita com o controle de mídia da barra de tarefas.
- **`raise()` com o Spotify já aberto**, trazendo-o para a frente pelo protocolo, testado isoladamente.
- **Retomada na posição lembrada:** o Spotify reabriu com a mesma música e tocou, mas a volta ao segundo exato não foi medida.
- **Play com música lembrada de um navegador e o player fechado:** a correção (não ficar em "abrindo") entrou depois dos testes. Foi compilada, mas não testada no app.
- **App que recusa um controle** ("recusado" no registro): todos os testes foram aceitos.
- **Linux:** não compilado aqui, só a leitura do código.

## Pendências
- **CPU do app aberto:** ~32% de um núcleo mesmo com a música pausada. Vem de outra parte da interface, provavelmente animações (ícones do clima, gráficos em `Canvas`). Vale investigar numa etapa própria.
- **Trazer outros apps para a frente:** o SMTC não faz isso. Apps da Store poderiam ser ativados pelo AppUserModelId (`IApplicationActivationManager`); navegadores, pela janela do processo.
- **Volume do player:** o SMTC não oferece. Só seria possível pelo volume da sessão de áudio do app (WASAPI), fora do escopo deste passo (volume do sistema).
- **Escolha da sessão:** hoje é a "atual" do Windows. Se o usuário preferir o Spotify sempre que estiver aberto (como a ordem do Linux), isso é um ajuste pequeno em `pick()`.
