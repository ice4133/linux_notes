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
