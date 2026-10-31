# fake-sni — servicio SNI falso para el test nested F3-T07.
cmake_minimum_required(VERSION 3.21)
project(fake-sni VERSION 0.1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core DBus Gui)
add_executable(fake-sni fake-sni.cpp)
target_link_libraries(fake-sni PRIVATE Qt6::Core Qt6::DBus Qt6::Gui)
