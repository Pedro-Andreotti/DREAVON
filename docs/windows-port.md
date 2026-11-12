# DREAVON — plano de adaptação para Windows

Base: [Plasdria](https://github.com/PietroAlexandria/Plasdria) (widget KDE Plasma 6, QML + C++/Qt 6).
Levantamento feito a partir do README e de uma busca por APIs específicas de Linux em `native/*.cpp`. O plano começou com hipóteses; o que foi feito e testado em cada passo está nos [diários](diario/).

> **Estado no 1.0.0:** os passos 1 a 7 estão concluídos. A versão 1.0.0 é para **uso pessoal no Windows**: sem instalador e sem assinatura, aberta pelo `qml.exe` do Qt com os scripts de `tools/`. Ficaram fora: temperatura da CPU, bateria do fone Bluetooth e de aparelhos BLE, troca do shim do Kirigami e testes no Linux. Ver o [CHANGELOG](../CHANGELOG.md) e o [diário 11](diario/11-release-1-0-0.md).

## Visão geral

| Camada | Estado | Observação |
| --- | --- | --- |
| Interface QML (`package/contents/ui`) | Feito (passo 2) | Janela própria em Qt Quick, com bandeja; Kirigami substituído por um shim só do Windows |
| Núcleo C++ (`native/`) | Feito (passos 1 a 7) | Código do Windows atrás de `Q_OS_WIN`; D-Bus atrás de `QT_DBUS_LIB`; Linux sem mudança de comportamento (não testado) |
| Empacotamento (`install.sh`, `build.sh`, `kpackagetool6`) | Uso local (passo 7b) | CMake + `build-windows.ps1`; sem instalador nem assinatura; atalho e início com o Windows por `tools/install-local.ps1` |

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
| Notificações dos lembretes | `org.freedesktop.Notifications` | `showMessage` do ícone da bandeja (toast no Windows 10/11), feito no passo 7a; com o atalho do uso local (7b), o toast mostra o nome e o ícone do DREAVON | `dashboardclient.cpp`, `main.qml` |
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
7. **Extras:** notificações toast e atalho global (7a, feitos); bandeja (feita no passo 2); uso local com atalho e AUMID (7b, feito). Instalador e assinatura ficaram fora: o DREAVON roda só na máquina do autor, sem certificado (diário 10).

## Pontos em aberto

- ~~Qual casca usar: janela flutuante, barra lateral ou widget na área de trabalho~~: janela própria com bandeja (passo 2).
- Temperaturas: a do SSD veio do driver de armazenamento (passo 4); a da CPU segue indisponível sem administrador ou ferramenta de terceiros (fora do 1.0.0).
- ~~Compilador: MSVC ou MinGW (impacta o acesso a WinRT)~~: MSVC desde o passo 1; o WinRT é usado por C++/WinRT do Windows SDK (passo 6).
- ~~Nome, ícone e identidade visual do DREAVON~~: trocados no passo 2.
