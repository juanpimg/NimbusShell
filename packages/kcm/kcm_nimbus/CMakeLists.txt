# F8-T01 — KCM Nimbus. CMake autocontenido sin ECM (Ruling F8-T01-NOECM):
# el host no trae extra-cmake-modules y no se instala nada en él (AGENTS.md).
# Replica el layout de kcmutils_add_qml_kcm: QML en qrc :/kcm/kcm_nimbus/ui/*
# + plugin en <plugindir>/plasma/kcms/systemsettings/ + .desktop en applications.
cmake_minimum_required(VERSION 3.29)
project(kcm_nimbus VERSION 0.1 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(GNUInstallDirs)

# Rutas KDE sin KDEInstallDirs (ECM ausente): equivalen en CachyOS/Arch.
set(KDE_INSTALL_APPDIR ${CMAKE_INSTALL_DATADIR}/applications)
set(KDE_INSTALL_PLUGINDIR ${CMAKE_INSTALL_LIBDIR}/qt6/plugins)
set(KCM_NAMESPACE plasma/kcms/systemsettings)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml DBus Widgets)
find_package(KF6Config REQUIRED)
find_package(KF6CoreAddons REQUIRED)
find_package(KF6KCMUtils REQUIRED)
find_package(KF6I18n REQUIRED)

qt_add_library(kcm_nimbus MODULE
    src/nimbusmodule.cpp
    src/nimbusmodule.h
)

# QML embebido: mismo prefijo que genera __kcmutils_target_qml_sources
# (alias = nombre del fichero, SIN subdir ui/: el cargador pide main.qml).
qt_add_resources(KCM_QML_RESOURCES kcm_nimbus.qrc)
target_sources(kcm_nimbus PRIVATE ${KCM_QML_RESOURCES})

target_link_libraries(kcm_nimbus PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Qml
    Qt6::DBus
    KF6::ConfigCore
    KF6::CoreAddons
    KF6::KCMUtilsQuick
    KF6::I18n
)

set_target_properties(kcm_nimbus PROPERTIES
    PREFIX ""
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/${KCM_NAMESPACE}"
)

install(TARGETS kcm_nimbus DESTINATION ${KDE_INSTALL_PLUGINDIR}/${KCM_NAMESPACE})
install(FILES kcm_nimbus.desktop DESTINATION ${KDE_INSTALL_APPDIR})
# Fallback KPackage (por si el cargador busca share/kpackage/kcms/):
install(DIRECTORY ui/ DESTINATION ${CMAKE_INSTALL_DATADIR}/kpackage/kcms/kcm_nimbus/ui)
install(FILES package-metadata.json DESTINATION ${CMAKE_INSTALL_DATADIR}/kpackage/kcms/kcm_nimbus RENAME metadata.json)
