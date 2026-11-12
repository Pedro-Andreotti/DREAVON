# 09 — Uso de CPU em repouso no Windows

Data: 2026-11-12 · Branch: `perf/uso-de-cpu`

## Problema
O DREAVON aberto usava ~32% de um núcleo (diário 07), igual com a música tocando e pausada. O `MediaClient` sozinho gastava 0,39%, então o custo vinha de outra parte.

## Como foi medido
- **Roteiro de medição** (fora do repositório): abre o DREAVON de verdade (`main.qml`, com as configurações reais) e põe a janela num de quatro estados:
  - **na frente, em foco** (`showPanel()`);
  - **atrás de outra janela**: uma janela comum aberta por cima, com o foco;
  - **minimizada**;
  - **oculta na bandeja** (`hide()`).
- **CPU:** depois de 20 s de aquecimento, mede o tempo de CPU do processo (`TotalProcessorTime`) por 60 s. Os valores estão em **% de um núcleo**; a máquina tem 12 núcleos lógicos, então a CPU total é 1/12 disso.
- **Quadros desenhados:** conta os quadros da janela no mesmo intervalo (sinal `frameSwapped`).
- **Backend gráfico** (`QSG_INFO=1`): D3D11 na **GPU integrada AMD**, com o laço de renderização em thread separada (`threaded render loop`). A tela é de **120 Hz** (vsync de 8,33 ms).
- **Medição limpa:** a última rodada foi feita com o PC parado, sem mouse nem teclado. Nas anteriores, o uso de outros apps tirava o foco do DREAVON e misturava os estados (ver "Variação").

## Causa medida
**A animação do ícone do clima no topo do painel** (`WeatherIcon`, sol girando, nuvem, gotas, raio):
- **Animações contínuas:** eram `RotationAnimator` e `SequentialAnimation` com `loops: Animation.Infinite`. Enquanto uma animação roda, o Qt Quick redesenha **a janela inteira** (1280×800, semitransparente) a cada quadro da tela: **120 quadros por segundo**, contados.
- **Também minimizada:** a condição era `root.visible`, a visibilidade do *item* e não da janela. Por isso a animação seguia **com a janela minimizada** (40% de um núcleo). Oculta, o Qt para de desenhar, mas as animações continuavam avançando.
- **Prova:** desligar só essa animação, por um interruptor temporário (um argumento de linha de comando que não ficou no código), derrubou a CPU de **37,5% para 3,2%** com a janela na frente e de **36,2% para 2,1%** minimizada. Os quadros caíram de 120 para ~5 por segundo; esses ~5 vêm do relógio, da rede e do sistema.

**Segunda causa, menor:** os anéis do cartão Sistema (`Ring`) animam a mudança de valor por 400 ms a cada 2 s e redesenham o `Canvas` em JavaScript em cada passo, mesmo com a janela oculta ou minimizada.

**O que não era:**
- **Clientes do C++:** medidos sozinhos, sem janela: métricas do sistema 0,31%, rede 0,07%, música 0,00% de um núcleo.
- **`nvidia-smi`:** no Windows a GPU é lida pelo PDH, e o `nvidia-smi` só entra se o PDH falhar.
- **Outras animações infinitas** (chat, ícone compacto, capa da música): só rodam com o chat ocupado ou o player abrindo.
- **Timers do QML:** são de 15 s a 15 min.

## O que mudou
| Arquivo | Mudança | Motivo |
| --- | --- | --- |
| `package/contents/ui/WeatherIcon.qml` | As animações viraram funções de um relógio único (`phase`), avançado por um `Timer` de **15 quadros/s** (sol e nuvem) ou **20** (chuva, neve e raio), e **só com a janela em foco** (`Window.active`). Mesmas curvas e durações: sol a 28 s por volta, nuvem 5↔8 px com `InOutSine` em 2,2 s, gotas com `InQuad` em 0,7 s e as mesmas pausas, piscar do raio em 1,83 s | O custo de um quadro é o da janela inteira; num ícone de 42 px com movimentos de menos de 1 px por quadro (sol e nuvem), 15 quadros/s têm o mesmo visual que 120 |
| `package/contents/ui/Ring.qml` | A transição do valor (`Behavior`) só roda com a janela visível e não minimizada; senão, o valor muda direto | Não redesenhar o `Canvas` a cada 2 s para ninguém ver |

Nada mudou no C++ nem nos intervalos de atualização dos dados.

**Visual:** conferido pelo usuário com `build-windows.ps1 -Run` ("está tudo certo"):
- clima animando em foco e parando ao trocar de app;
- anéis com transição;
- rede, música e lembretes;
- atalho global e bandeja.

## Antes e depois
Rodada final com o PC parado. O clima estava com **chuva** (o caso mais caro, a 20 quadros/s).

| Estado | Antes: % de um núcleo (% da CPU total) | Depois: % de um núcleo (% da CPU total) | Quadros por segundo (antes → depois) |
| --- | --- | --- | --- |
| Na frente, em foco | 42,1% (3,51%) | **9,5% (0,79%)** | 120 → 24 |
| Atrás de outra janela, sem foco | 45,1% (3,76%) | **2,0% (0,16%)** | ~120 → 4 |
| Minimizada | 40,3% (3,36%) | **1,9% (0,16%)** | ~120 → 4 |
| Oculta na bandeja | 2,4% (0,20%) | **0,9% (0,07%)** | 0 → 0 |

- **Em foco com sol ou nuvem** (15 quadros/s), numa rodada anterior: **6,0%** de um núcleo (0,50% do total), 11 quadros/s.
- **Antes:** a medição de base usou o caso "atrás" só com `lower()`, sem outra janela por cima. Com a animação contínua, isso não muda o resultado: o custo era o mesmo com ou sem foco.

**Onde ficou e por quê:**
- **Oculta (0,9%):** sobram os timers de dados, que continuam rodando para o painel abrir atualizado: métricas a cada 2 s, rede a cada 1 s, dispositivos e relógio. É praticamente zero (0,07% da CPU total).
- **Minimizada e atrás (~2%):** o Qt ainda redesenha a janela ~4 vezes por segundo, quando o relógio, a rede e o sistema mudam. Ele não sabe que a janela está coberta.
- **Em foco (6% a 9,5%):** é o preço da animação do clima, a 15 ou 20 quadros/s, mais as atualizações de dados. Cada quadro redesenha a janela inteira.

### Variação
- **De uma rodada para outra:** a mesma condição variou de 1 a 3 pontos, por causa do resto do sistema (navegador, música, rede).
- **Foco "roubado":** em duas rodadas, o uso do PC durante a medição tirou o foco da janela "na frente" ou devolveu o foco à janela "atrás". O registro do roteiro mostrou isso: "na frente" sem foco deu 3,3%; "atrás" com foco e chuva a 30 quadros/s deu 12,4%. Por isso a rodada final foi feita com o PC parado, e o caso "atrás" passou a ter uma janela por cima com o foco.

## Não verificado
- **Linux:** não testado. A mudança é só no QML, que também é a casca do Linux. O visual é o mesmo, mas a animação do clima agora para quando a janela perde o foco, lá também.
- **Neve e tempestade:** o código cobre os dois casos, mas no teste o clima tinha só nuvem, sol e chuva.
- **Monitor de 60 Hz:** antes, o custo seria ~metade do medido aqui, que é de 120 Hz. Depois, não muda, porque o ritmo agora é fixo (15/20 quadros/s).
- **Tela cheia de outro app e notebook na bateria.**

## Pendências
- **Minimizada ou atrás (~2%):** dá para reduzir mais escondendo o conteúdo da janela minimizada. Isso pode afetar a miniatura da barra de tarefas e precisa de teste visual; ficou de fora por ser pouco ganho (0,16% da CPU total).
- **Timers de dados com a janela oculta:** métricas e rede poderiam ficar mais espaçadas. O ganho máximo é ~0,4% de um núcleo (o custo medido dos clientes), e o painel abriria com o gráfico de rede incompleto.
