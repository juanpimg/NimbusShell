cmake_minimum_required(VERSION 3.21)
project(nimbus-wallpaper LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Gui Qml Quick)
find_package(LayerShellQt REQUIRED)
find_package(KF6WindowSystem REQUIRED)

add_executable(nimbus-wallpaper main.cpp)
target_link_libraries(nimbus-wallpaper PRIVATE
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    KF6::WindowSystem
    LayerShellQt::Interface
)

install(TARGETS nimbus-wallpaper RUNTIME DESTINATION bin)
