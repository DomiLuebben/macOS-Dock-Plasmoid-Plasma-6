cmake_minimum_required(VERSION 3.20)

project(macosdockeffects LANGUAGES CXX)

include(CTest)

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

if(BUILD_TESTING)
    find_package(Qt6 REQUIRED COMPONENTS Test QmlTools)

    add_executable(removablevolumesmodeltest
        tests/removablevolumesmodeltest.cpp
        removablevolumesmodel.cpp
        removablevolumesmodel.h
    )
    add_executable(desktopidutilstest
        tests/desktopidutilstest.cpp
        desktopidutils.h
    )
    target_compile_definitions(removablevolumesmodeltest PRIVATE
        TEST_DATA="${CMAKE_CURRENT_SOURCE_DIR}/tests/data/removable-volumes.xml"
    )
    target_include_directories(removablevolumesmodeltest PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}"
    )
    target_link_libraries(removablevolumesmodeltest PRIVATE
        Qt6::Core
        Qt6::DBus
        Qt6::Test
        KF6::Solid
        KF6::I18n
        KF6::KIOGui
    )
    target_include_directories(desktopidutilstest PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}"
    )
    target_link_libraries(desktopidutilstest PRIVATE
        Qt6::Core
        Qt6::Test
    )

    add_test(NAME removablevolumesmodeltest
        COMMAND removablevolumesmodeltest
    )
    add_test(NAME desktopidutilstest
        COMMAND desktopidutilstest
    )
    add_test(NAME removablevolumedragqmltest
        COMMAND Qt6::qmltestrunner
            -input "${CMAKE_CURRENT_SOURCE_DIR}/tests/tst_removablevolumedrag.qml"
    )
    add_test(NAME appgroupstoreqmltest
        COMMAND Qt6::qmltestrunner
            -input "${CMAKE_CURRENT_SOURCE_DIR}/tests/tst_appgroupstore.qml"
    )
    add_test(NAME appgrouppopupqmltest
        COMMAND Qt6::qmltestrunner
            -input "${CMAKE_CURRENT_SOURCE_DIR}/tests/tst_appgrouppopup.qml"
    )
    add_test(NAME progresscontrollerqmltest
        COMMAND Qt6::qmltestrunner
            -input "${CMAKE_CURRENT_SOURCE_DIR}/tests/tst_progresscontroller.qml"
    )
    add_test(NAME configgeneralqmltest
        COMMAND Qt6::qmltestrunner
            -input "${CMAKE_CURRENT_SOURCE_DIR}/tests/tst_configgeneral.qml"
    )
    add_test(NAME dockitemscaleqmltest
        COMMAND Qt6::qmltestrunner
            -input "${CMAKE_CURRENT_SOURCE_DIR}/tests/tst_dockitemscale.qml"
    )
    add_test(NAME dockitemfocusqmltest
        COMMAND Qt6::qmltestrunner
            -input "${CMAKE_CURRENT_SOURCE_DIR}/tests/tst_dockitemfocus.qml"
    )
    set_tests_properties(
        removablevolumedragqmltest
        appgroupstoreqmltest
        appgrouppopupqmltest
        progresscontrollerqmltest
        configgeneralqmltest
        dockitemscaleqmltest
        dockitemfocusqmltest
        PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
    )
endif()
