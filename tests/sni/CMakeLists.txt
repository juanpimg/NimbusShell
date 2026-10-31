# fake-sni — servicio SNI falso para el test nested F3-T07.
cmake_minimum_required(VERSION 3.21)
project(fake-sni VERSION 0.1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core DBus Gui)
find_package(PkgConfig REQUIRED)
pkg_check_modules(DBUS1 REQUIRED IMPORTED_TARGET dbus-1)
add_executable(fake-sni fake-sni.cpp)
target_link_libraries(fake-sni PRIVATE Qt6::Core Qt6::DBus Qt6::Gui)
# probe-model: StatusNotifierModel REAL contra mini-watcher (unregister).
add_executable(model-probe
  probe-model.cpp
  ../../packages/shell/nimbus-bar/statusnotifiermodel.cpp
  ../../packages/shell/nimbus-bar/statusnotifiermodel.h)
target_include_directories(model-probe PRIVATE
  ../../packages/shell/nimbus-bar)
target_link_libraries(model-probe PRIVATE
  Qt6::Core Qt6::DBus Qt6::Gui PkgConfig::DBUS1)
