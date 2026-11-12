# DREAVON — plano de adaptação para Windows

Base: [Plasdria](https://github.com/PietroAlexandria/Plasdria) (widget KDE Plasma 6, QML + C++/Qt 6).
Levantamento feito a partir do README e de uma busca por APIs específicas de Linux em `native/*.cpp`. **Os itens abaixo são hipóteses de trabalho e precisam ser validados na implementação.**

## Visão geral

| Camada | Estado | Observação |
| --- | --- | --- |
| Interface QML (`package/contents/ui`) | Reaproveitável | Usa Kirigami e `PlasmoidItem`/Plasma; precisa de uma janela própria (Qt Quick) e troca dos componentes específicos do Plasma |
| Núcleo C++ (`native/`) | Parcialmente portável | Parte usa Qt puro (rede, JSON, `QProcess`); parte lê `/proc`, `/sys` e D-Bus |
| Empacotamento (`install.sh`, `build.sh`, `kpackagetool6`) | Reescrever | Sem Plasma no Windows; trocar por CMake/qmake + instalador |

## Mapeamento Linux → Windows

| Função | Linux (hoje) | Windows (alvo) | Arquivo |
| --- | --- | --- | --- |
| Música (player ativo, capa, controles) | MPRIS via D-Bus (`org.mpris.MediaPlayer2`) | SMTC — `GlobalSystemMediaTransportControlsSessionManager` (C++/WinRT, feito no passo 6) | `mediaclient.cpp`, `mediainfo_win.cpp` |
| Rede (tráfego, IP, sinal Wi-Fi) | `/proc/net/dev`, NetworkManager (D-Bus) | `GetIfTable2`/`GetIfEntry2` (IP Helper), WLAN API (`WlanQueryInterface`) | `networkclient.cpp` |
| CPU / carga / uptime | `/proc/stat`, `/proc/loadavg`, `/proc/uptime`, `/proc/cpuinfo` | PDH (Performance Counters), `GetTickCount64`, registro/WMI para o nome do processador | `dashboardclient.cpp` / `plugin.cpp` |
| RAM e swap | `/proc/meminfo` | `GlobalMemoryStatusEx` | idem |
| Disco | `QStorageInfo` / `statvfs` (verificar) | `QStorageInfo` já funciona no Windows | idem |
| Temperaturas (CPU, SSD) | `/sys/class/hwmon` | Sem API padrão; WMI `MSAcpi_ThermalZoneTemperature` é limitado. Avaliar LibreHardwareMonitor | idem |
| GPU | `nvidia-smi`, `/sys/class/drm` | `nvidia-smi` (existe no Windows com driver NVIDIA); contadores PDH "GPU Engine" para os demais | idem |
| Baterias (notebook e periféricos) | UPower e BlueZ (D-Bus) | `GetSystemPowerStatus`; Bluetooth via WinRT (`BluetoothLEDevice`/GATT Battery Service) | `plugin.cpp` |
| Notificações dos lembretes | `org.freedesktop.Notifications` | `showMessage` do ícone da bandeja (toast no Windows 10/11), feito no passo 7a; toast WinRT fica para depois do instalador | `dashboardclient.cpp`, `main.qml` |
| Nome do modelo do notebook | `/sys/class/dmi/id/product_name` | WMI `Win32_ComputerSystem` | `plugin.cpp` |
| Pastas de dados e cache | `~/.local/share/dreavon`, `~/.cache/dreavon` (via `QStandardPaths`) | `QStandardPaths` já resolve para `%LOCALAPPDATA%` | vários |
| CLIs de IA (`claude`, `codex`, `gemini`, `agy`) | `QProcess` + `QStandardPaths::findExecutable` | Funciona se os CLIs estiverem no PATH; atenção a `.cmd`/`.ps1` e a aspas | `chathistory.cpp`, `plugin.cpp` |
| Atalho global | Atalho do Plasma | `RegisterHotKey` (Win32) numa janela só de mensagens, feito no passo 7a | `globalhotkey.cpp`, `hotkey_win.cpp` |
| Casca do widget | Plasmoide (`kpackagetool6`) | Janela frameless Qt Quick com bandeja do sistema (e, se desejado, barra lateral ancorada) | novo |

## Ordem sugerida

1. **Compilar no Windows:** Qt 6 + MSVC (ou MinGW), migrar `bridge.pro` para CMake, remover a dependência de D-Bus atrás de `#ifdef Q_OS_LINUX` e fazer o plugin carregar vazio.
2. **Casca própria:** janela Qt Quick com o `main.qml` adaptado, sem Plasma/Kirigami. Primeiro só o painel geral, com relógio e saudação.
3. **Partes portáveis:** clima, notícias, lembretes, calendário e o chat multi-IA. Testar os CLIs no PATH do Windows.
4. **Sistema:** CPU, RAM, disco e bateria (APIs simples). Depois temperaturas e GPU.
5. **Rede:** tráfego e IP, depois sinal do Wi-Fi.
6. **Música:** SMTC. É a parte com mais trabalho de WinRT.
7. **Extras:** notificações toast e atalho global (7a, feitos); bandeja (feita no passo 2); instalador e assinatura (7b).

## Pontos em aberto

- Qual casca usar: janela flutuante, barra lateral ou widget na área de trabalho.
- Temperaturas: aceitar um valor aproximado ou depender de uma ferramenta de terceiros.
- ~~Compilador: MSVC ou MinGW (impacta o acesso a WinRT)~~: MSVC desde o passo 1; o WinRT é usado por C++/WinRT do Windows SDK (passo 6).
- ~~Nome, ícone e identidade visual do DREAVON~~: trocados no passo 2.
