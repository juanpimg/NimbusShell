# nimbus-spotlight — overlay Spotlight con backend KRunner (F6-T01 Plan B).
cmake_minimum_required(VERSION 3.21)
project(nimbus-spotlight VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Gui Qml Quick DBus Test)
find_package(KF6Runner REQUIRED)
find_package(LayerShellQt REQUIRED)

qt_add_executable(nimbus-spotlight
  main.cpp
  krunnerbackend.h
  krunnerbackend.cpp
  nimbusindex.h
  nimbusindex.cpp
  spotlight.qrc
)

target_link_libraries(nimbus-spotlight PRIVATE
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
  Qt6::DBus
  KF6::Runner
  LayerShellQt::Interface
)

# Test unitario del índice local (fuzzy, calculadora, .desktop, perf 10k).
qt_add_executable(tst_index
  tests/tst_index.cpp
  nimbusindex.h
  nimbusindex.cpp
)
target_link_libraries(tst_index PRIVATE Qt6::Gui Qt6::DBus Qt6::Test)
target_compile_definitions(tst_index PRIVATE
  NIMBUS_FIXTURES="${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures")
add_test(NAME tst_index COMMAND tst_index)
enable_testing()

install(TARGETS nimbus-spotlight RUNTIME DESTINATION bin)
install(FILES org.nimbus.spotlight.desktop DESTINATION share/applications)
