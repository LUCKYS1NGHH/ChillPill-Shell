cmake_minimum_required(VERSION 3.16)
project(PillBackend VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core DBus Qml)

qt_add_qml_module(PillBackend
    URI PillBackend
    VERSION 1.0
    PLUGIN_TARGET PillBackendPlugin
    SOURCES
        backend/WifiController.h
        backend/WifiController.cpp
        backend/WifiNetworkModel.h
        backend/WifiNetworkModel.cpp
        backend/BandwidthMonitor.h
        backend/BandwidthMonitor.cpp
        backend/BluetoothPairingAgent.h
        backend/BluetoothPairingAgent.cpp
        backend/BluetoothController.h
        backend/BluetoothController.cpp
        backend/BluetoothDeviceModel.h
        backend/BluetoothDeviceModel.cpp
)

target_include_directories(PillBackend PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/backend)

target_link_libraries(PillBackend PRIVATE Qt6::Core Qt6::DBus Qt6::Qml)

set_target_properties(PillBackend PillBackendPlugin PROPERTIES
    BUILD_WITH_INSTALL_RPATH TRUE
    INSTALL_RPATH "$ORIGIN"
)

add_custom_command(TARGET PillBackendPlugin POST_BUILD
    COMMAND sed -i "/^prefer/d" ${CMAKE_CURRENT_BINARY_DIR}/qmldir
    COMMENT "Stripping prefer line from generated qmldir"
)

# Install plugin library and QML registration files
install(TARGETS PillBackend PillBackendPlugin
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/qml/PillBackend
)
install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/qmldir
  ${CMAKE_CURRENT_BINARY_DIR}/PillBackend.qmltypes
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/qml/PillBackend
)
