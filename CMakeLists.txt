cmake_minimum_required(VERSION 3.16)
project(IslandBackend VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core DBus Qml)

qt_add_qml_module(IslandBackend
    URI IslandBackend
    VERSION 1.0
    SOURCES
        backend/WifiController.h
        backend/WifiController.cpp
        backend/WifiNetworkModel.h
        backend/WifiNetworkModel.cpp
)

target_include_directories(IslandBackend PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/backend)

target_link_libraries(IslandBackend PRIVATE Qt6::Core Qt6::DBus Qt6::Qml)

add_custom_command(TARGET IslandBackendplugin POST_BUILD
    COMMAND sed -i "/^prefer/d" ${CMAKE_CURRENT_BINARY_DIR}/qmldir
    COMMENT "Stripping prefer line from generated qmldir"
)
