cmake_minimum_required(VERSION 3.20)

project(macosdockeffects LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core DBus Gui Qml Quick)
find_package(KF6WindowSystem REQUIRED)

add_library(macosdockeffectsplugin MODULE
    blurregion.cpp
    blurregion.h
    plugin.cpp
    windowactions.cpp
    windowactions.h
)

target_link_libraries(macosdockeffectsplugin PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    KF6::WindowSystem
)

set_target_properties(macosdockeffectsplugin PROPERTIES
    LIBRARY_OUTPUT_NAME macosdockeffectsplugin
)
