cmake_minimum_required(VERSION 3.20)

project(macosdockeffects LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 REQUIRED COMPONENTS Core DBus Gui Qml)
find_package(KF6Service REQUIRED)
find_package(KF6WindowSystem REQUIRED)
find_package(KF6Solid REQUIRED)
find_package(KF6I18n REQUIRED)
find_package(KF6KIO REQUIRED)

add_library(macosdockeffectsplugin MODULE
    blurregion.cpp
    blurregion.h
    desktopidutils.h
    kdeconnectsharemonitor.cpp
    kdeconnectsharemonitor.h
    launcherprogressmonitor.cpp
    launcherprogressmonitor.h
    plugin.cpp
    removablevolumesmodel.cpp
    removablevolumesmodel.h
    windowactions.cpp
    windowactions.h
)

target_link_libraries(macosdockeffectsplugin PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
    Qt6::Qml
    KF6::Service
    KF6::WindowSystem
    KF6::Solid
    KF6::I18n
    KF6::KIOGui
)

set_target_properties(macosdockeffectsplugin PROPERTIES
    LIBRARY_OUTPUT_NAME macosdockeffectsplugin
)
