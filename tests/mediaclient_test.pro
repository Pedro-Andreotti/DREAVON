QT += core gui network dbus testlib
CONFIG += console testcase c++17
CONFIG -= app_bundle
TEMPLATE = app
TARGET = mediaclient_test
SOURCES += mediaclient_test.cpp ../native/mediaclient.cpp
HEADERS += ../native/mediaclient.h
