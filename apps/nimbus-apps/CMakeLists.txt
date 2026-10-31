cmake_minimum_required(VERSION 3.20)
project(nimbus-apps VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Quick Qml DBus)

qt_add_executable(nimbus-apps
    main.cpp
    appmodel.h appmodel.cpp
)
qt_add_qml_module(nimbus-apps
    URI Nimbus.Apps
    VERSION 1.0
    QML_FILES qml/AppsWindow.qml
    RESOURCE_PREFIX /
)

target_link_libraries(nimbus-apps PRIVATE
    Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Quick Qt6::Qml Qt6::DBus)

install(TARGETS nimbus-apps RUNTIME DESTINATION bin)
install(FILES org.nimbus.Apps.desktop DESTINATION share/applications)
