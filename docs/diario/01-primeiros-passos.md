# 01 — Primeiros passos do DREAVON

Data: 2026-11-11

## O que já foi feito
- Repositório criado em `Pedro-Andreotti/DREAVON`, com o histórico original do Plasdria (12 commits).
- Remoto `upstream` aponta para `PietroAlexandria/Plasdria` (para acompanhar o projeto original) e `origin` para o DREAVON.
- Licença MIT mantida, com o copyright de Pietro Alexandria, do PRAGUS e da adaptação.
- Plano de adaptação em [../windows-port.md](../windows-port.md).

## Preparar o ambiente no Windows
Conferir (e instalar o que faltar):
- [x] Git for Windows (`git --version`)
- [x] Visual Studio Build Tools (instalado o 2026 / MSVC 14.51), carga "Desenvolvimento para desktop com C++" + componente "SDK do Windows 11 (10.0.26100)"
- [x] CMake e Ninja (`winget install Kitware.CMake Ninja-build.Ninja`)
- [x] Qt 6 para MSVC 2022 64-bit (instalado o 6.11.3 LTS em `C:\Qt\6.11.3\msvc2022_64`), com qtbase, qtdeclarative, qtsvg, qttools e qttranslations
- [ ] Extensões do VS Code: C/C++, CMake Tools e Qt Extension Pack (ou QML)

Atenção: o Qt para Windows até traz o módulo `Qt6DBus`, mas não existe barramento D-Bus no Windows (MPRIS, NetworkManager, UPower e BlueZ são do Linux). Por isso o D-Bus só é ligado no Linux.

## Passo 1 — Compilar o plugin no Windows (meta: carregar "vazio")
1. Criar `CMakeLists.txt` equivalente ao `native/bridge.pro` (módulos: Core, Qml, Network, Gui, Concurrent; D-Bus só se Linux).
2. Isolar o código de D-Bus e de `/proc` e `/sys` com `#ifdef Q_OS_LINUX` em `mediaclient.cpp`, `networkclient.cpp`, `dashboardclient.cpp` e `plugin.cpp`, com implementações vazias para Windows.
3. Compilar e corrigir os erros até gerar o plugin sem funções de sistema.
4. Registrar o resultado aqui: erros encontrados e como foram resolvidos.

## Passo 2 — Casca própria
Janela Qt Quick com o `main.qml` adaptado, sem Plasma/Kirigami. Começar só pelo painel geral (relógio e saudação). Ver `tools/preview.qml` como ponto de partida, já que ele renderiza o widget fora do Plasma.

## Decisões em aberto
- Tipo de casca: janela flutuante, barra lateral ou widget na área de trabalho.
- Compilador: MSVC (recomendado por causa do WinRT) ou MinGW.
- Nome, ícone e identidade visual do DREAVON.

## Registro de implementação
(preencher conforme avançar: o que mudou, em quais arquivos e por quê)

### 2026-11-11 — Passo 1 concluído: o plugin compila e carrega no Windows
Branch `feat/cmake-build-windows`.

**Ambiente**
- O MSVC já estava instalado (Build Tools 2026, MSVC 14.51), mas sem o SDK do Windows. O SDK foi adicionado pelo Visual Studio Installer (`setup.exe modify --add Microsoft.VisualStudio.Component.Windows11SDK.26100`).
- CMake 4.4 e Ninja 1.13 pelo `winget`.
- Qt 6.11.3 (LTS) para `msvc2022_64`. O aqtinstall 3.3.0 não entende o layout novo do repositório do Qt (`qt6_6113/qt6_6113_msvc2022_64/`), então os `.7z` oficiais foram baixados direto de download.qt.io (com conferência do SHA-1) e extraídos em `C:\Qt\6.11.3\msvc2022_64`. O binário do Qt 2022 funciona com o MSVC 14.5x.

**Código**
- `CMakeLists.txt` (raiz): equivalente ao `native/bridge.pro`. Gera `plasdriaplugin.dll` em `package/contents/ui/bridge`, ao lado do `qmldir`. Liga `Qt6::DBus` só no Linux e usa `/utf-8` no MSVC (os textos em português estão em UTF-8).
- `build-windows.ps1`: carrega o `vcvars64.bat`, configura com Ninja e compila. Uso: `.\build-windows.ps1` (ou `-Config Debug`, `-QtDir ...`).
- `native/bridge.pro`: `dbus` só no Linux (`linux: QT += dbus`).
- `mediaclient.cpp`, `networkclient.cpp`, `dashboardclient.cpp`: todo o código de D-Bus fica atrás de `#ifdef QT_DBUS_LIB`. Esse macro é definido pelo próprio Qt quando o módulo DBus é ligado (no qmake e no CMake), então o Linux continua igual. No Windows essas funções ficam vazias, com `TODO(Windows)` (SMTC, notificação toast, `GetSystemPowerStatus`, baterias Bluetooth).
- Leituras de `/proc` e `/sys` não impedem a compilação: o `QFile::open` só falha em tempo de execução e o valor fica vazio. Elas serão trocadas nos passos 4 e 5.
- `plugin.cpp` e `chathistory.cpp` não precisaram de mudança.

**Resultado**
- Compilou de primeira, sem erros (8/8 passos do Ninja).
- Teste de carga: um QML que importa `bridge` e cria `DashboardClient`, `MediaClient`, `NetworkClient` e `ChatClient` rodou com `qml.exe` (`QT_QPA_PLATFORM=offscreen`, `QT_FORCE_STDERR_LOGGING=1`). Todos os tipos foram criados; o IP local e a checagem de conexão já funcionam.
- Observação: no Windows o `console.log` vai para o depurador; para ver no terminal, use `QT_FORCE_STDERR_LOGGING=1`.
- Pendente: os testes em `tests/` ainda usam qmake e `dbus-run-session` (Linux). Adaptar depois.
