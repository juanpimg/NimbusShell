# nimbus-welcome — wizard de primer arranque F9-T02 (Qt6 Quick, sin KF).
cmake_minimum_required(VERSION 3.21)
project(nimbus-welcome VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Gui Qml Quick Test)

qt_add_executable(nimbus-welcome
  main.cpp
  welcomebackend.h
  welcomebackend.cpp
  welcome.qrc
)

target_link_libraries(nimbus-welcome PRIVATE
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
)

# Test de persistencia/progreso (QSettings .ini + índices de paso).
qt_add_executable(tst_welcome
  tests/tst_welcome.cpp
  welcomebackend.h
  welcomebackend.cpp
)
target_link_libraries(tst_welcome PRIVATE Qt6::Gui Qt6::Test)
add_test(NAME tst_welcome COMMAND tst_welcome)
enable_testing()

install(TARGETS nimbus-welcome RUNTIME DESTINATION bin)
install(FILES org.nimbus.welcome.desktop DESTINATION share/applications)
