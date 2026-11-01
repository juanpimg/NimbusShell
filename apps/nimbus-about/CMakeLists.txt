# nimbus-about — ventana "Acerca de Nimbus" F10-T01 (Qt6 Quick, sin KF).
cmake_minimum_required(VERSION 3.21)
project(nimbus-about VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Gui Qml Quick Test)

qt_add_executable(nimbus-about
  main.cpp
  aboutbackend.h
  aboutbackend.cpp
  about.qrc
)

target_link_libraries(nimbus-about PRIVATE
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
)

install(TARGETS nimbus-about RUNTIME DESTINATION bin)
install(FILES org.nimbus.about.desktop DESTINATION share/applications)
install(FILES ../../assets/nimbus-about.svg DESTINATION share/icons/hicolor/scalable/apps RENAME nimbus-about.svg)

enable_testing()
