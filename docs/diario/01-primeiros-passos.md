# 01 — Primeiros passos do DREAVON

Data: 2026-11-11

## O que já foi feito
- Repositório criado em `Pedro-Andreotti/DREAVON`, com o histórico original do Plasdria (12 commits).
- Remoto `upstream` aponta para `PietroAlexandria/Plasdria` (para acompanhar o projeto original) e `origin` para o DREAVON.
- Licença MIT mantida, com o copyright de Pietro Alexandria, do PRAGUS e da adaptação.
- Plano de adaptação em [../windows-port.md](../windows-port.md).

## Preparar o ambiente no Windows
Conferir (e instalar o que faltar):
- [ ] Git for Windows (`git --version`)
- [ ] Visual Studio Build Tools 2022, carga "Desenvolvimento para desktop com C++" (MSVC + SDK do Windows)
- [ ] CMake (`cmake --version`) e Ninja
- [ ] Qt 6 para MSVC 2022 64-bit, pelo instalador oficial, com os módulos Qt Quick/Qml (Declarative), Network e Concurrent
- [ ] Extensões do VS Code: C/C++, CMake Tools e Qt Extension Pack (ou QML)

Atenção: o Qt para Windows não traz o módulo **D-Bus** (`QT += dbus`). Hoje o `native/bridge.pro` o exige, então ele precisa virar opcional só no Linux.

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
