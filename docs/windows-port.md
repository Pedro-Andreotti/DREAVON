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
| Música (player ativo, capa, controles) | MPRIS via D-Bus (`org.mpris.MediaPlayer2`) | SMTC — `GlobalSystemMediaTransportControlsSessionManager` (WinRT) | `mediaclient.cpp` |
| Rede (tráfego, IP, sinal Wi-Fi) | `/proc/net/dev`, NetworkManager (D-Bus) | `GetIfTable2`/`GetIfEntry2` (IP Helper), WLAN API (`WlanQueryInterface`) | `networkclient.cpp` |
| CPU / carga / uptime | `/proc/stat`, `/proc/loadavg`, `/proc/uptime`, `/proc/cpuinfo` | PDH (Performance Counters), `GetTickCount64`, registro/WMI para o nome do processador | `dashboardclient.cpp` / `plugin.cpp` |
| RAM e swap | `/proc/meminfo` | `GlobalMemoryStatusEx` | idem |
| Disco | `QStorageInfo` / `statvfs` (verificar) | `QStorageInfo` já funciona no Windows | idem |
| Temperaturas (CPU, SSD) | `/sys/class/hwmon` | Sem API padrão; WMI `MSAcpi_ThermalZoneTemperature` é limitado. Avaliar LibreHardwareMonitor | idem |
| GPU | `nvidia-smi`, `/sys/class/drm` | `nvidia-smi` (existe no Windows com driver NVIDIA); contadores PDH "GPU Engine" para os demais | idem |
| Baterias (notebook e periféricos) | UPower e BlueZ (D-Bus) | `GetSystemPowerStatus`; Bluetooth via WinRT (`BluetoothLEDevice`/GATT Battery Service) | `plugin.cpp` |
| Notificações dos lembretes | `org.freedesktop.Notifications` | Notificação toast do Windows (WinRT) ou `QSystemTrayIcon::showMessage` | `plugin.cpp` |
| Nome do modelo do notebook | `/sys/class/dmi/id/product_name` | WMI `Win32_ComputerSystem` | `plugin.cpp` |
| Pastas de dados e cache | `~/.local/share/plasdria`, `~/.cache/plasdria` (via `QStandardPaths`) | `QStandardPaths` já resolve para `%LOCALAPPDATA%` | vários |
| CLIs de IA (`claude`, `codex`, `gemini`, `agy`) | `QProcess` + `QStandardPaths::findExecutable` | Funciona se os CLIs estiverem no PATH; atenção a `.cmd`/`.ps1` e a aspas | `chathistory.cpp`, `plugin.cpp` |
| Atalho global | Atalho do Plasma | `RegisterHotKey` (Win32) ou biblioteca Qt de atalhos globais | novo |
| Casca do widget | Plasmoide (`kpackagetool6`) | Janela frameless Qt Quick com bandeja do sistema (e, se desejado, barra lateral ancorada) | novo |

## Ordem sugerida

1. **Compilar no Windows:** Qt 6 + MSVC (ou MinGW), migrar `bridge.pro` para CMake, remover a dependência de D-Bus atrás de `#ifdef Q_OS_LINUX` e fazer o plugin carregar vazio.
2. **Casca própria:** janela Qt Quick com o `main.qml` adaptado, sem Plasma/Kirigami. Primeiro só o painel geral, com relógio e saudação.
3. **Partes portáveis:** clima, notícias, lembretes, calendário e o chat multi-IA. Testar os CLIs no PATH do Windows.
4. **Sistema:** CPU, RAM, disco e bateria (APIs simples). Depois temperaturas e GPU.
5. **Rede:** tráfego e IP, depois sinal do Wi-Fi.
6. **Música:** SMTC. É a parte com mais trabalho de WinRT.
7. **Extras:** notificações toast, atalho global, bandeja, instalador.

## Pontos em aberto

- Qual casca usar: janela flutuante, barra lateral ou widget na área de trabalho.
- Temperaturas: aceitar um valor aproximado ou depender de uma ferramenta de terceiros.
- Compilador: MSVC ou MinGW (impacta o acesso a WinRT).
- Nome, ícone e identidade visual do DREAVON, que ainda usam os do Plasdria.
