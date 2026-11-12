# Plugin QML nativo do DREAVON (equivalente ao native/bridge.pro).
# Gera a biblioteca "dreavonplugin" em package/contents/ui/bridge, ao lado do qmldir.
cmake_minimum_required(VERSION 3.21)
# Versão do DREAVON (SemVer). É a fonte única: o plugin a expõe ao QML (AppInfo.version, em
# Configurações > Sobre). O package/metadata.json (metadados do plasmoide) precisa ter o mesmo número;
# o CMake confere abaixo e para o build se divergirem.
project(DREAVON VERSION 1.0.0 LANGUAGES CXX)
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/package/metadata.json" dreavon_metadata)
string(JSON dreavon_metadata_version GET "${dreavon_metadata}" KPlugin Version)
if(NOT dreavon_metadata_version STREQUAL PROJECT_VERSION)
    message(FATAL_ERROR "Versão divergente: CMakeLists.txt ${PROJECT_VERSION}, package/metadata.json ${dreavon_metadata_version}.")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Network Concurrent Widgets)
# D-Bus (MPRIS, NetworkManager, UPower, BlueZ, notificações) só existe no Linux.
# Ao ligar Qt6::DBus, o Qt define QT_DBUS_LIB, que liga o código correspondente.
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    find_package(Qt6 REQUIRED COMPONENTS DBus)
endif()

add_library(dreavonplugin MODULE
    native/plugin.cpp
    native/dashboardclient.cpp native/dashboardclient.h
    native/chathistory.cpp native/chathistory.h
    native/mediaclient.cpp native/mediaclient.h
    native/networkclient.cpp native/networkclient.h
    native/credentialstore.cpp native/credentialstore.h
    native/globalhotkey.cpp native/globalhotkey.h
    native/autostart.cpp native/autostart.h
)

target_link_libraries(dreavonplugin PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Network Qt6::Concurrent)
if(TARGET Qt6::DBus)
    target_link_libraries(dreavonplugin PRIVATE Qt6::DBus)
endif()
if(WIN32)
    # Gerenciador de Credenciais (CredWrite, CredRead, CredDelete), contadores PDH e
    # GetPerformanceInfo (passo 4: sistema no Windows).
    target_sources(dreavonplugin PRIVATE native/systeminfo_win.cpp native/systeminfo_win.h)
    # cfgmgr32: lista de aparelhos conectados (cartão Dispositivos); hid e setupapi: bateria Logitech (HID++).
    target_link_libraries(dreavonplugin PRIVATE advapi32 pdh psapi cfgmgr32 hid setupapi)
    # Rede (passo 5): iphlpapi (contadores, melhor rota, endereços), wlanapi (SSID e sinal), ws2_32.
    target_sources(dreavonplugin PRIVATE native/networkinfo_win.cpp native/networkinfo_win.h)
    target_link_libraries(dreavonplugin PRIVATE iphlpapi wlanapi ws2_32)
    # Música (passo 6): sessão de mídia do Windows (SMTC) por C++/WinRT, com os cabeçalhos do próprio
    # Windows SDK (pasta cppwinrt, já no INCLUDE do MSVC); windowsapp liga as APIs WinRT.
    target_sources(dreavonplugin PRIVATE native/mediainfo_win.cpp native/mediainfo_win.h)
    target_link_libraries(dreavonplugin PRIVATE windowsapp)
    # Em C++17, o C++/WinRT usa <experimental/coroutine>, que o MSVC atual recusa; só este arquivo
    # compila em C++20 (o resto do projeto segue em C++17).
    set_source_files_properties(native/mediainfo_win.cpp PROPERTIES COMPILE_OPTIONS "/std:c++20")
    # Atalho global (passo 7a): RegisterHotKey numa janela só de mensagens (user32, já ligada por padrão).
    target_sources(dreavonplugin PRIVATE native/hotkey_win.cpp native/hotkey_win.h)
endif()

if(MSVC)
    # Fontes em UTF-8 com textos em português; sem /utf-8 o MSVC usa a página de código local.
    target_compile_options(dreavonplugin PRIVATE /utf-8)
endif()
target_compile_definitions(dreavonplugin PRIVATE DREAVON_VERSION="${PROJECT_VERSION}")

# Sem prefixo "lib" e na pasta do qmldir, para "plugin dreavonplugin" ser encontrado.
set(bridge_dir "${CMAKE_CURRENT_SOURCE_DIR}/package/contents/ui/bridge")
set_target_properties(dreavonplugin PROPERTIES
    PREFIX ""
    LIBRARY_OUTPUT_DIRECTORY "${bridge_dir}"
    RUNTIME_OUTPUT_DIRECTORY "${bridge_dir}")
foreach(config Debug Release RelWithDebInfo MinSizeRel)
    string(TOUPPER "${config}" config_upper)
    set_target_properties(dreavonplugin PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY_${config_upper} "${bridge_dir}"
        RUNTIME_OUTPUT_DIRECTORY_${config_upper} "${bridge_dir}")
endforeach()

# Substituto mínimo do Kirigami, só no Windows (o Linux usa o Kirigami do KDE).
# O plugin fica ao lado do qmldir em windows/qml/org/kde/kirigami.
if(WIN32)
    add_library(kirigamishim MODULE native/kirigamishim/kirigamishim.cpp)
    target_link_libraries(kirigamishim PRIVATE Qt6::Core Qt6::Qml)
    if(MSVC)
        target_compile_options(kirigamishim PRIVATE /utf-8)
    endif()
    set(kirigami_dir "${CMAKE_CURRENT_SOURCE_DIR}/windows/qml/org/kde/kirigami")
    set_target_properties(kirigamishim PROPERTIES PREFIX ""
        LIBRARY_OUTPUT_DIRECTORY "${kirigami_dir}" RUNTIME_OUTPUT_DIRECTORY "${kirigami_dir}")
    foreach(config Debug Release RelWithDebInfo MinSizeRel)
        string(TOUPPER "${config}" config_upper)
        set_target_properties(kirigamishim PROPERTIES
            LIBRARY_OUTPUT_DIRECTORY_${config_upper} "${kirigami_dir}"
            RUNTIME_OUTPUT_DIRECTORY_${config_upper} "${kirigami_dir}")
    endforeach()
endif()

# Inicializador: abre o main.qml numa janela própria, com ícone na bandeja.
add_executable(dreavon WIN32 app/main.cpp app/dreavon.rc)
target_link_libraries(dreavon PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Qml)
target_compile_definitions(dreavon PRIVATE DREAVON_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}")
if(MSVC)
    target_compile_options(dreavon PRIVATE /utf-8)
endif()
add_dependencies(dreavon dreavonplugin)
if(TARGET kirigamishim)
    add_dependencies(dreavon kirigamishim)
endif()
