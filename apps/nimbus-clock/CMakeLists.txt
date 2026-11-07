# nimbus-clock — app Reloj estilo macOS F10-T01 (Qt6 Quick, sin KF).
cmake_minimum_required(VERSION 3.21)
project(nimbus-clock VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Gui Qml Quick Test)

qt_add_executable(nimbus-clock
  main.cpp
  clockbackend.h
  clockbackend.cpp
  clock.qrc
)

target_link_libraries(nimbus-clock PRIVATE
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
)

install(TARGETS nimbus-clock RUNTIME DESTINATION bin)
install(FILES org.nimbus.clock.desktop DESTINATION share/applications)
install(FILES ../../assets/nimbus-clock.svg DESTINATION share/icons/hicolor/scalable/apps RENAME nimbus-clock.svg)

enable_testing()

qt_add_executable(tst_clock
  tests/tst_clock.cpp
  clockbackend.h
  clockbackend.cpp
)
target_link_libraries(tst_clock PRIVATE
  Qt6::Gui
  Qt6::Test
)
add_test(NAME tst_clock COMMAND tst_clock)
