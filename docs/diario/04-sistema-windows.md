# 04 — Sistema no Windows (passo 4)

Data: 2026-11-11 · Branch: `feat/sistema-windows` · Máquina de teste: notebook (CPU de 6 núcleos e 12 threads, 23,35 GiB de RAM, GPU integrada + GPU dedicada, Windows 11 26H2)

## Resumo
CPU, memória, swap, disco, uptime, processos, modelo da CPU, nome do computador, versão do sistema, bateria, GPU e temperatura do SSD agora vêm de APIs do Windows. A temperatura da CPU fica **indisponível** (decisão do usuário: não há fonte nativa sem administrador). Tudo é leve: APIs do Win32, registro (lido uma vez) e contadores PDH já abertos, sem WMI e sem abrir processos a cada ciclo.

## O que mudou
| Arquivo | Mudança | Motivo |
| --- | --- | --- |
| `native/systeminfo_win.h/.cpp` (novo, só Windows) | Leituras do sistema: `GetSystemTimes`, `GlobalMemoryStatusEx`, `GetPerformanceInfo`, `GetTickCount64`, `GetSystemPowerStatus`, registro, PDH ("Paging File", "GPU Engine") e `IOCTL_STORAGE_QUERY_PROPERTY` | Os arquivos de `/proc` e `/sys` não existem no Windows |
| `native/dashboardclient.cpp` | `machineName`, `updateSystemDetails`, `updateMetrics` (CPU, memória, bateria, GPU) com `#ifdef Q_OS_WIN`; o caminho do Linux ficou intacto no `#else` | Usar as leituras do Windows sem mudar o Linux |
| `CMakeLists.txt` | `systeminfo_win.cpp` e as bibliotecas `pdh` e `psapi` só no `WIN32` | Compilar só no Windows |
| `package/contents/ui/SystemCard.qml` (QML compartilhado) | Sem "load average", a linha "Carga" vira "Processos" com só o número | O Windows não tem load average; no Linux `load` sempre vem preenchido, então nada muda lá |

Detalhes das fontes:
- **CPU:** `GetSystemTimes`, pela diferença entre leituras (o tempo de kernel já inclui o ocioso).
- **Memória:** `GlobalMemoryStatusEx` (`ullAvailPhys`, equivalente ao `MemAvailable`).
- **Swap:** `ullTotalPageFile` é o limite de commit, não o swap. O tamanho dos arquivos de paginação é `ullTotalPageFile − ullTotalPhys`, e o uso vem de `\Paging File(_Total)\% Usage`.
- **Contadores PDH:** usam `PdhAddEnglishCounter`, porque neste Windows em português os conjuntos de contadores têm nomes traduzidos.
- **Disco:** `QStorageInfo::root()` já pega a unidade `C:` (conferido).
- **Sistema:** "Windows 11 Version 26H2 · compilação 26300.9974". A palavra "kernel" (do Linux) não aparece no Windows.
- **Bateria:**
  - `GetSystemPowerStatus` dá percentual e estado: Carregando, Carregada, Conectada ou Na bateria (com tempo restante).
  - PC de mesa (`BatteryFlag` 128) fica "Sem bateria" com percentual `-1`, nunca 0%.
- **GPU:** decisão do usuário, contadores PDH "GPU Engine" primeiro.
  - Mesmo critério do Gerenciador de Tarefas: soma por adaptador e tipo de mecanismo, pega o maior.
  - Cobre as duas GPUs. O `nvidia-smi` só entra se o PDH não responder.
  - Motivo: o `nvidia-smi` custa ~74 ms por chamada, rodava a cada 2 s, vê só a NVIDIA e, em notebook, pode manter a GPU dedicada acordada.
  - Conferido: com o PDH, o `nvidia-smi` não é mais aberto.
- **Temperatura do SSD:** consulta do próprio driver de armazenamento ao disco que contém o Windows (`StorageDeviceTemperatureProperty`), sem administrador, guardada por 10 s.

## DREAVON x referência
Referências: contadores de desempenho do Windows (`Get-CimInstance`, as mesmas fontes do Gerenciador de Tarefas: a CPU do Gerenciador é o "% Processor Utility"), `Win32_OperatingSystem`, `Win32_LogicalDisk`, `Win32_PageFileUsage`, `Win32_Battery`, `Win32_Processor`, `Win32_ComputerSystem` e o registro. Leituras simultâneas a cada ~2 s, com 10 s de carga (um laço ocupado por thread).

| Dado | DREAVON | Referência | Diferença |
| --- | --- | --- | --- |
| CPU em repouso | 12–15% | % Processor Time 2–12% · % Processor Utility 8–19% | até ~10 pontos, conforme o instante e a janela de medição (DREAVON mede 2 s; a própria consulta CIM gera carga) |
| CPU sob carga | 92–100% | Processor Time 100% · Processor Utility 108–109% | 0–8 pontos; o "Utility" passa de 100% com turbo e o Gerenciador limita a 100% |
| Memória usada / total | 18,67–19,23 / 23,35 GiB | 18,70–19,19 / 23,35 GiB | ≤ 0,05 GiB |
| Disco `C:` | 245,7 / 475,9 GiB (51,6%) | 245,7 / 475,9 GiB (51,6%) | nenhuma |
| Swap (`pagefile.sys`) | 0,93 / 8,00 GiB | 0,93 / 8 GiB | nenhuma |
| Uptime | 7h 11–12min | 7h 12min (`LastBootUpTime` e contador "System Up Time") | ≤ 1 min (arredondamento no instante) |
| Processos | 455–482 | 455–482 nos mesmos instantes | nenhuma no mesmo instante |
| Modelo da CPU / threads | nome do processador · 12 | igual (`Win32_Processor`) | nenhuma |
| Modelo do computador | modelo do fabricante | igual (`Win32_ComputerSystem.Model` e registro) | nenhuma |
| Sistema | Windows 11 Version 26H2 · compilação 26300.9974 | Windows 11 Home Single Language · 26H2 · 26300.9974 | nenhuma |
| Bateria (na tomada) | 100% · "Carregada" | 100% · `BatteryStatus` 2 (na tomada) | nenhuma |
| GPU | 7–9% (outra leitura: 23–25%) | 6–7% no mesmo critério | ~1–2 pontos (a referência é arredondada para inteiro e lida em outro instante) |
| Temperatura do SSD | 40–50 °C | sem referência sem administrador (`Get-StorageReliabilityCounter` negou acesso) | **não verificado** contra referência |
| Temperatura da CPU | — (indisponível) | — | indisponível por decisão |

## Não verificado
- **Bateria descarregando** (fora da tomada): o teste foi pulado. Só "na tomada, 100%" foi comparado.
- **Janela do Gerenciador de Tarefas:** o Gerenciador novo expõe só 15 elementos à automação de interface e nenhum com os totais. A comparação usou os contadores que ele usa, não a janela.
- **Temperatura do SSD contra referência:** a referência do PowerShell exige administrador. O próprio Windows mostra a temperatura em Configurações > Sistema > Armazenamento > Discos e volumes > Propriedades, para conferir à mão.
- **PC de mesa sem bateria:** o caminho "Sem bateria" não foi testado (a máquina é notebook).
- **Alternativa `nvidia-smi`** (quando o PDH falha): não exercitada, porque aqui o PDH respondeu.
- **Linux:** não testado nesta máquina; o código do Linux ficou no `#else` sem mudança, e a única mudança de QML não altera o Linux.

## Decisão das temperaturas (tomada neste passo)
Opções avaliadas, sem administrador, nesta máquina:

| Fonte | CPU | SSD | Administrador | Risco |
| --- | --- | --- | --- | --- |
| PDH "Thermal Zone Information" | sem instâncias aqui | — | não | nenhum |
| WMI `MSAcpi_ThermalZoneTemperature` | "Sem suporte" aqui | — | em geral sim | nenhum |
| Consulta do driver de armazenamento (`StorageDeviceTemperatureProperty`) | — | **41 °C** | **não** | nenhum, API nativa |
| LibreHardwareMonitor + driver PawnIO | sim | sim | sim (instalar o driver uma vez) | driver de kernel (assinado pela Microsoft, mas é mais superfície de ataque) e dependência .NET num app Qt. O antigo WinRing0 é marcado como vulnerável pelo Defender (CVE-2020-14979) |

**Escolha do usuário:** SSD pela API nativa; CPU indisponível. Nada foi baixado nem instalado para isso.

## Pendências
- Temperatura da CPU: só com uma solução de terceiros com driver (LHM + PawnIO). Precisa de proposta e decisão próprias.
- Testar a bateria fora da tomada e o caminho de PC de mesa.
- Dispositivos e periféricos (USB, bateria de Bluetooth): fora deste passo. O cartão mostra só o próprio notebook (pelo nome do modelo, 100%) e "Nenhum dispositivo…" para o resto, sem quebrar.
- O tempo restante da bateria (`BatteryLifeTime`) só aparece fora da tomada; não foi visto funcionando.
