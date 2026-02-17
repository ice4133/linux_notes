cmake_minimum_required(VERSION 3.16)
project(qt6_template)

# 自动处理 Qt 的 MOC (元对象编译器) 等核心机制
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

# 寻找 Qt 6 库中的 Widgets 模块
find_package(Qt6 REQUIRED COMPONENTS Widgets)

# 定义你的可执行程序
add_executable(qt6_template main.cpp)

# 链接 Qt 6 的库文件
target_link_libraries(qt6_template PRIVATE Qt6::Widgets)