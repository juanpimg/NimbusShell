# F8-T02/T04/T05 — build del probe headless en /tmp (nunca instalado).
cmake_minimum_required(VERSION 3.29)
project(nimbus_kcm_probe LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core DBus)
find_package(KF6Config REQUIRED)
find_package(KF6CoreAddons REQUIRED)
find_package(KF6KCMUtils REQUIRED)
find_package(KF6I18n REQUIRED)

add_executable(save_probe
    save_probe.cpp
    ../../../packages/kcm/kcm_nimbus/src/nimbusmodule.cpp
    ../../../packages/kcm/kcm_nimbus/src/nimbusmodule.h
)
target_include_directories(save_probe PRIVATE
    ../../../packages/kcm/kcm_nimbus/src
)
target_link_libraries(save_probe PRIVATE
    Qt6::Core
    Qt6::DBus
    KF6::ConfigCore
    KF6::CoreAddons
    KF6::KCMUtilsQuick
    KF6::I18n
)
