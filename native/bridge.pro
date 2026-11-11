QT += core qml network gui concurrent
# D-Bus (MPRIS, NetworkManager, UPower, BlueZ) só existe no Linux.
linux: QT += dbus
TEMPLATE = lib
CONFIG += plugin c++17
TARGET = plasdriaplugin
SOURCES += plugin.cpp dashboardclient.cpp chathistory.cpp mediaclient.cpp networkclient.cpp
HEADERS += dashboardclient.h chathistory.h mediaclient.h networkclient.h
DESTDIR = $$PWD/../package/contents/ui/bridge
