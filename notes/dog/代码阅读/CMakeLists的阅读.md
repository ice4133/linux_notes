```cmake

cmake_minimum_required(VERSION 3.8)
# 指定CMake的最低版本要求为3.8,自己的cmake版本需要大于等于3.8才能使用这个CMakeLists.txt文件



project(unitree_legged_msgs)
# 项目名称，任意修改

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()
# 如果编译器是GCC或Clang，添加编译选项：-Wall（所有警告）、-Wextra（额外警告）、-Wpedantic（严格模式警告）





# find dependencies
find_package(ament_cmake REQUIRED)
find_package(std_msgs REQUIRED)
find_package(rosidl_default_generators REQUIRED)
# 查找依赖包，ament_cmake是ROS 2的构建系统，std_msgs是ROS 2的标准消息包，rosidl_default_generators是ROS 2的接口生成器包
# 在本地电脑上查找这些包，如果找不到会报错并停止编译





set(msg_files
  "msg/MotorState.msg"
)
# 自定义一个变量




rosidl_generate_interfaces(${PROJECT_NAME}
  ${msg_files}
  DEPENDENCIES std_msgs
  ADD_LINTER_TESTS
)
# 这是这段代码里最重要的 ROS 2 专属命令
# 它的逻辑是：拿着刚才定义的 msg_files ，自动帮你生成底层通信所需的 C++ 代码
# 添加代码检查测试





ament_export_dependencies(rosidl_default_runtime)
# 导出依赖项，rosidl_default_runtime是ROS 2的接口运行时包
# 这也是 ROS 2 专属。它负责“对外声明”：如果有其他 ROS 包想调用我这个 unitree_legged_msgs 包，那么它们在运行的时候也必须带上 rosidl_default_runtime 这个运行库





if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  # the following line skips the linter which checks for copyrights
  # comment the line when a copyright and license is added to all source files
  set(ament_cmake_copyright_FOUND TRUE)
  # the following line skips cpplint (only works in a git repo)
  # comment the line when this package is in a git repo and when
  # a copyright and license is added to all source files
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()
# 判断当前是不是处于“测试编译模式”。里面的 set(ament_cmake_copyright_FOUND TRUE) 等语句是用来跳过某些特定的版权和代码格式检查工具的 。






ament_package()
# ROS 2 包的终极收尾动作，表示这个包是一个 ROS 包，并且会自动处理依赖关系和安装规则等细节

```



以下是robot的cmakelists
```cmake

cmake_minimum_required(VERSION 3.8)
project(robot)

# 编译选项（可选，增强代码规范性）
if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# 查找ROS2核心依赖（Python节点必需）
find_package(ament_cmake REQUIRED)
find_package(ament_cmake_python REQUIRED)
find_package(rclpy REQUIRED)
find_package(std_msgs REQUIRED)

# 安装Python模块（ROS2 Humble兼容，无DIRECTORY参数）
ament_python_install_package(${PROJECT_NAME})
# 这是一个 ROS 2 特有的专属语法，负责把你写的 Python 包安装到系统的特定目录中，让 ROS 2 环境能像识别标准 Python 库一样找到你的代码 




# ========== 新增：安装SDK的so库到robot包的运行目录 ==========
# 用途: Unitree 电机 SDK 的网络库文件
install(DIRECTORY
  resource/${PROJECT_NAME}/sdk_lib/
  DESTINATION lib/${PROJECT_NAME}/
  FILES_MATCHING PATTERN "*.so"
)
# 这是一个包含多个参数的安装指令。它的底层逻辑是：去代码仓库的 resource/robot/sdk_lib/ 目录下扫描 ；过滤并只挑出后缀为 .so 的动态链接库文件（从注释看，这里存放的是 Unitree 电机底层的网络通信库） ；然后把它们拷贝安装到系统运行时的 lib/robot/ 目录下 。这一步极其关键，有了它，你的上层逻辑才能正确调用底层硬件接口进行底盘和电机的调试





# 配置节点可执行文件（与setup.py的entry_points完全对应）
install(PROGRAMS
  # ${PROJECT_NAME}/serial_node.py
  ${PROJECT_NAME}/imu_process_node.py
  ${PROJECT_NAME}/unitree_go_1.py  # 新增：电机初始化脚本
  ${PROJECT_NAME}/manual.py
  DESTINATION lib/${PROJECT_NAME}
)
# 这段指令负责把你写的具体业务脚本（如处理 IMU 数据的 imu_process_node.py、初始化电机的 unitree_go_1.py、以及手动控制脚本 manual.py）标记为可执行程序，并安装到 lib/robot/ 目录下 。这就解释了为什么当你在终端输入类似 ros2 run robot unitree_go_1.py 时，系统能准确找到并运行这个特定的脚本


# 安装launch文件（如果存在launch目录则保留）
if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/launch)
  install(DIRECTORY
    launch
    DESTINATION share/${PROJECT_NAME}/
  )
endif()
#如果存在，就把整个 launch 文件夹原封不动地安装到 share/robot/ 目录下 。Launch 文件通常用于一次性启动上述的多个节点.



# 测试相关（可选）
if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  ament_lint_auto_find_test_dependencies()
endif()
# 这段逻辑会自动寻找相关的代码规范测试依赖

# 声明功能包类型
ament_package()
```