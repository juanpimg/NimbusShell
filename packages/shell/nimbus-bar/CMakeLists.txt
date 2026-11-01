# NimbusBar — barra superior layer-shell 24pt (F3-T03, R-TOPBAR-LAYER).
# Contrato: docs/design/tahoe-design-contract.md §3 "Menu bar: 24pt".
cmake_minimum_required(VERSION 3.21)
project(nimbus-bar VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Gui Qml Quick DBus Network)
find_package(LayerShellQt REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(DBUS1 REQUIRED IMPORTED_TARGET dbus-1)

qt_add_executable(nimbus-bar main.cpp commandrunner.h
    appmenumodel.h appmenumodel.cpp
    statusnotifiermodel.h statusnotifiermodel.cpp
    notificationserver.h notificationserver.cpp
    mprismodel.h mprismodel.cpp
    weathermodel.h weathermodel.cpp
    batteryinfo.h osdbridge.h bar.qrc)

target_link_libraries(nimbus-bar PRIVATE
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
  Qt6::DBus
  Qt6::Network
  PkgConfig::DBUS1
  LayerShellQt::Interface
)

install(TARGETS nimbus-bar RUNTIME DESTINATION bin)
