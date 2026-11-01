# nimbus-help — visor offline F11-T06 (Qt6 Quick, sin KF).
# Dos binarios separados (nimbus-about + nimbus-help); --tab elige pestaña.
cmake_minimum_required(VERSION 3.21)
project(nimbus-help VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Gui Qml Quick Test)

qt_add_executable(nimbus-help
  main.cpp
  helpbackend.h
  helpbackend.cpp
  help.qrc
)

target_link_libraries(nimbus-help PRIVATE
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
)

install(TARGETS nimbus-help RUNTIME DESTINATION bin)
install(FILES org.nimbus.help.desktop DESTINATION share/applications)
install(FILES ../../assets/nimbus-help.svg DESTINATION share/icons/hicolor/scalable/apps RENAME nimbus-help.svg)
install(FILES ../../docs/user-guide/README.md ../../docs/user-guide/shortcuts.md
        DESTINATION share/nimbus/user-guide)

enable_testing()
