# Plugin QML nativo do DREAVON (equivalente ao native/bridge.pro).
# Gera a biblioteca "dreavonplugin" em package/contents/ui/bridge, ao lado do qmldir.
cmake_minimum_required(VERSION 3.21)
project(DREAVON LANGUAGES CXX)

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
    target_link_libraries(dreavonplugin PRIVATE advapi32 pdh psapi)
endif()

if(MSVC)
    # Fontes em UTF-8 com textos em português; sem /utf-8 o MSVC usa a página de código local.
    target_compile_options(dreavonplugin PRIVATE /utf-8)
endif()

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
