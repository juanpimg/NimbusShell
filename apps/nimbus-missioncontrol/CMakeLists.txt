# nimbus-missioncontrol — overlay Mission Control/Spaces (F7-T01/T02).
cmake_minimum_required(VERSION 3.21)
project(nimbus-missioncontrol VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Gui Qml Quick DBus)
find_package(LayerShellQt REQUIRED)

qt_add_executable(nimbus-missioncontrol
  main.cpp
  kwinbackend.h
  kwinbackend.cpp
  missioncontrol.qrc
)

target_link_libraries(nimbus-missioncontrol PRIVATE
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
  Qt6::DBus
  LayerShellQt::Interface
)

install(TARGETS nimbus-missioncontrol RUNTIME DESTINATION bin)
install(FILES org.nimbus.missioncontrol.desktop DESTINATION share/applications)
install(FILES kwin/nimbus-mc.js DESTINATION share/kwin/scripts/nimbus-mc/contents/code RENAME main.js)
