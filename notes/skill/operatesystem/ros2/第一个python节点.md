# 第一步

```bash
# 创建一个新的 ROS 2 工作空间
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws/src


# 创建一个自己的 ROS 包
ros2 pkg create --build-type ament_python my_test_pkg

# my_test_pkg是自己的包名，可以根据自己的需要修改，--build-type ament_python表示这个包是一个Python包。

# ros2 pkg create命令会在当前目录下创建一个新的ROS包，包含一些基本的文件和目录结构。你可以在这个包中添加自己的Python代码来实现ROS节点的功能。
```

# 第二步

打开vscode,打开my_test_pkg文件夹，

在my_test_pkg文件夹下创建一个新的python文件，命名为my_test_node.py，并添加以下代码：

```python
import rclpy
from rclpy.node import Node

class TestNode(Node):
    def __init__(self):
        super().__init__('my_test_node')
        self.get_logger().info('Hello ROS 2! 测试节点已成功启动。')

def main(args=None):
    rclpy.init(args=args)
    node = TestNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()
```



再修改setup.py文件，添加以下内容：

```python  

'test_executable = my_test_pkg.test_node:main'

```

# 第三步

最后，在终端中运行以下命令来构建工作空间：

```bash
colcon build --packages-select my_test_pkg
# 构建完成后，运行以下命令来源环境变量：
source install/setup.bash  
# 运行测试节点
ros2 run my_test_pkg test_executable

# my_test_pkg是自己定义的包名，test_executable是setup.py中定义的可执行文件名称。

```