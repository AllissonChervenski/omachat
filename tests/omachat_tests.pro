QT += core gui testlib
CONFIG += c++17 testcase
TARGET = omachat_tests
TEMPLATE = app
INCLUDEPATH += ../src
HEADERS += ../src/backend.h
SOURCES += omachat_tests.cpp ../src/backend.cpp
