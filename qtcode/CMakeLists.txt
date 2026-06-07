cmake_minimum_required(VERSION 3.16)
project(EnviroTrend_demo LANGUAGES CXX)

# C++ 标准
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 查找 Qt5 组件
find_package(Qt5 REQUIRED COMPONENTS Core Gui Widgets Qml Quick Sql)

# 宏定义
add_definitions(-DQT_DEPRECATED_WARNINGS)

# 如果是开发板架构，定义 IS_BOARD（同时兼容 32 位 arm 与 64 位 aarch64）
if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm" OR CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    add_definitions(-DIS_BOARD)
endif()

# 源文件
set(SOURCES
    main.cpp
    src/core/coremanager.cpp
    src/core/backstage.cpp
    src/core/networkmanager.cpp
    src/core/logger.cpp
    src/sensor/dht11.cpp
    src/sensor/lightsensor.cpp
    src/sensor/zpsensor.cpp
    src/sensor/mq135sensor.cpp
    src/tool/screenshotmanager.cpp
)

# 头文件
set(HEADERS
    src/sensor/abstractsensor.h
    src/core/coremanager.h
    src/sensor/dht11.h
    src/core/backstage.h
    src/core/networkmanager.h
    src/core/logger.h
    src/sensor/lightsensor.h
    src/sensor/zpsensor.h
    src/sensor/mq135sensor.h
    src/tool/screenshotmanager.h
)

# 资源文件
set(RESOURCES
    qml.qrc
)

# 自动处理 moc, uic, rcc
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# 添加可执行文件
add_executable(${PROJECT_NAME} ${SOURCES} ${HEADERS} ${RESOURCES}
    src/pySrc/predict.py)

# 链接 Qt 库
target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt5::Core
    Qt5::Gui
    Qt5::Widgets
    Qt5::Qml
    Qt5::Quick
    Qt5::Sql
)

# 包含路径（如果需要）
target_include_directories(${PROJECT_NAME} PRIVATE src)
