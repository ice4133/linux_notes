# 怎么写
1. 导入库文件
2. 初始化客户端库
3. 新建节点对象
4. spin循环节点
5. 关闭客户端库

# 第一步
```bash
cd ros2_ws/src

# 必须在src目录下创建包，否则会报错
ros2 pkg create your_package_name --build-type ament_cmake --dependencies rclcpp --node-name your_node_name




```
与此同时，配置环境
ctrl + shift + p
UI: Configure Language Specific Settings

在include中添加
/opt/ros/humble/**


同时把cpp修改到c++17

# 第二步

在your_package_name/src/your_node_name.cpp文件中编写代码：
```cpp
#include "rclcpp/rclcpp.hpp"


int main(int argc, char **argv)
{
    rclcpp::init(argc, argv);
    /*产生一个Wang2的节点*/
    auto node = std::make_shared<rclcpp::Node>("wang2");
    // 打印一句自我介绍
    RCLCPP_INFO(node->get_logger(), "大家好，我是单身狗wang2.");
    /* 运行节点，并检测退出信号*/
    rclcpp::spin(node);
    rclcpp::shutdown();
    return 0;
}
``` 






# 第三步

```bash
cd ros2_ws
colcon build --packages-select your_package_name
source install/setup.bash
ros2 run your_package_name your_node_name
```




# 讲解

--dependencies rclcpp  # 依赖rclcpp库，这个库提供了ROS2 C++客户端库的功能

在 package.xml 中添加记录：
它会加上一行 <depend>rclcpp</depend>。这相当于一份“外部清单”，当别人拿到你的代码时，系统通过这份清单就知道要先安装 rclcpp 才能运行你的程序。

在 CMakeLists.txt 中添加配置：
它会自动写上 find_package(rclcpp REQUIRED)。这告诉编译器去系统路径下寻找 rclcpp 的头文件（.hpp）和库文件（.so）。

就好比keil中，添加了一个库文件，编译器就知道去哪里找这个库的函数实现了。




rclcpp rcl是指ROS Client Library，cpp是指C++版本的客户端库。rclcpp提供了ROS2 C++开发的核心功能，包括节点管理、话题通信、服务调用、参数服务器等。通过使用rclcpp，开发者可以方便地创建和管理ROS2节点，实现各种功能和通信机制。

相当于一个大型的库，里面包含了很多功能函数，开发者通过调用这些函数来实现自己的ROS2应用程序。就好比在C++中使用标准库一样，rclcpp提供了丰富的功能，让开发者能够更高效地开发ROS2应用。