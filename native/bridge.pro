QT += core qml network gui concurrent
# D-Bus (MPRIS, NetworkManager, UPower, BlueZ) só existe no Linux.
linux: QT += dbus
TEMPLATE = lib
CONFIG += plugin c++17
TARGET = dreavonplugin
SOURCES += plugin.cpp dashboardclient.cpp chathistory.cpp mediaclient.cpp networkclient.cpp credentialstore.cpp
HEADERS += dashboardclient.h chathistory.h mediaclient.h networkclient.h credentialstore.h
win32: LIBS += -ladvapi32
DESTDIR = $$PWD/../package/contents/ui/bridge
