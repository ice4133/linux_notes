




```python


# 第一部分，导入库
from launch import LaunchDescription
from launch.actions import ExecuteProcess, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from ament_index_python.packages import get_package_share_directory
# 去我自己的/opt/ros/humble/lib/python3.10/site-packages/launch里面查找LaunchDescription.py
# 其余同理也是一样的，但我发现好像没有大小写区分
# cmakelists和.xml文件看到需要找到这个库，于是它就找到了，真是强大




import os
# 在/usr/lib/python3.10/os.py
# 默认就是python3.10.12版本



# 第二部分，总指挥部与路径定义
def generate_launch_description():
    # ===================== 基础路径定义（保留你的原有配置，一行没改） =====================
    WS_PATH = "/home/ice/my_dog/dog_ws"
    SRC_ROBOT_PATH = os.path.join(WS_PATH, "src", "robot", "robot")  # 源码路径
    INSTALL_ROBOT_PATH = os.path.join(WS_PATH, "install", "robot", "lib", "robot")  # 安装路径
    """
    WS_PATH是工作区根目录
    SRC_ROBOT_PATH是源码路径，包含你的imu_process_node.py等源代码文件
    INSTALL_ROBOT_PATH是安装路径，包含编译后的unitree_go_1.py
    避免在每个位置硬编码路径，一旦路径变化只需改一处，提高代码可维护性

    这三个变量都是ros2规定的变量，不能更改
    """



    # ===================== 修复：MID360雷达驱动启动 + 解决段错误exit code -11 =====================
    livox_share_dir = get_package_share_directory('livox_ros_driver2')
    livox_launch_path = os.path.join(
        livox_share_dir,
        'launch_ROS2',
        'msg_MID360_launch.py'
    )
    # get_package_share_directory ROS 2 官方提供的标准函数，作用：根据功能包名称，自动获取该包的「共享安装目录」
    # 'livox_ros_driver2'：是 Livox 官方 ROS 2 激光雷达驱动的功能包名（必须提前编译安装）
    # 返回的是路径/install/livox_ros_driver2/share/livox_ros_driver2

    # 拼接官方雷达启动文件的完整路径
    # os.path.join 是 Python 内置的跨平台路径拼接函数
    # 得到绝对路径/install/livox_ros_driver2/share/livox_ros_driver2/launch_ROS2/msg_MID360_launch.py
    # 精准定位到 Livox 官方提供的 Mid360 启动文件
    


    mid360_driver = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(livox_launch_path),
        launch_arguments={
            'enable_imu': 'True',
            'xfer_format': '1'
        }.items()
    )
    #IncludeLaunchDescription 是 ROS 2 官方提供的标准函数，作用：在当前 Launch 文件中「包含」另一个 Launch 文件 也就是打开官方雷达启动文件


    # PythonLaunchDescriptionSource(livox_launch_path)
    # 声明：要引入的是「Python 格式」的 Launch 文件
    # 参数：第二步拼接好的官方启动文件路径

    # launch_arguments：传递参数给官方启动脚本
    # 启动雷达内置IMU功能（enable_imu=True）
    # 初步传输数据
    # 设置数据传输格式（xfer_format=1，表示使用ROS消息格式
    # .items() 必须把字典转为 可迭代的键值对元组


    # mid360_driver就可以看成一个对象，如果启动
    # 那么就会自动找到 Livox 官方驱动、启动 Mid360 激光雷达、开启 IMU 数据输出、发布 Livox 自定义格式的点云数据


    # 以模块化的方式，复用 Livox 官方 ROS 2 驱动的启动逻辑，启动 Mid360 雷达，并配置「开启 IMU + 自定义点云格式」











    # ===================== 核心修复：电机控制节点 极简配置 无密码+无冲突+权限足够 =====================
    # 改动1：删除prefix的chmod命令（已经加入dialout组，串口权限永久生效）
    # 改动2：仅保留 sudo -E 提权，无密码执行，保留ROS2环境变量
    # 改动3：无任何多余配置，彻底解决双重sudo冲突+密码卡死问题
    motor_control_node = ExecuteProcess(
        cmd=[
            "/usr/bin/sudo", "-E",  # 仅这一个sudo，无密码+保留环境变量，完美适配ROS2
            "/usr/bin/python3.8",
            os.path.join(INSTALL_ROBOT_PATH, "unitree_go_1.py")
        ],
        output="screen",
        emulate_tty=True,  # 新增：解决ROS2无交互终端导致的进程卡死，关键参数！
    )
    # ROS 2 官方启动动作：专门用于在启动文件中执行外部系统命令 / 独立进程
    # 其实就是调用宇数的sdk进行控制电机
    # 它不是 ROS 2 节点，是直接调用系统命令运行外部程序
    # 最终 motor_control_node 是一个可执行进程对象，会被加入 LaunchDescription 运行


    # 核心命令参数：cmd=[] （最关键）
    # /usr/bin/sudo Linux 系统提权命令，获取 root 管理员权限，普通用户没有权限，不加这行，会导致无法控制电机
    # -E sudo 的核心参数：保留当前用户的环境变量

    # /usr/bin/python3.8
    # 指定固定 Python 版本 这个必须根据自己的系统环境来修改

    # os.path.join(INSTALL_ROBOT_PATH, "unitree_go_1.py") 拼接电机控制主脚本的绝对路径

    # output="screen" ROS 2 官方参数，表示将该进程的输出直接打印到终端屏幕，方便调试和查看日志
    #把电机控制脚本的所有日志、报错、打印信息，直接输出到当前 ROS 2 启动终端作用：方便调试电机故障、查看机器人关节状态、定位硬件问题

    # emulate_tty=True 新增参数，作用：模拟一个交互式终端环境，解决ROS2无交互终端导致的进程卡死问题
    # 这个参数非常关键，因为ROS2默认启动环境没有真正的终端，如果被启动的进程（比如电机控制脚本）需要交互式终端支持（比如等待输入、输出日志等），就会因为没有终端而卡死

    # ROS 2 启动时 → 用 sudo 提权 + 保留 ROS 环境 → 调用 Python3.8 → 运行 Go1 电机控制脚本 → 终端打印日志 → 模拟终端避免卡死 → 机器人电机正常工作。





    # ===================== 保留你的原有IMU节点配置（无需修改） =====================
    imu_process_node = ExecuteProcess(
        cmd=[
            "python3",
            os.path.join(SRC_ROBOT_PATH, "imu_process_node.py")
        ],
        output="screen",
        log_cmd=True
    )
    # ExecuteProcess 它不是 ROS 2 官方的 Node 动作，而是直接跑 Python 脚本 用于执行外部系统命令、

    # python3调用系统默认 Python 3 解释器运行脚本  和上一段电机代码的 /usr/bin/python3.8 区别：这个 IMU 脚本无严格 Python 版本限制，不需要锁定版本
    # 这个好像可以不用修改，因为好像有python3
    # os.path.join(SRC_ROBOT_PATH, "imu_process_node.py") 拼接 IMU 预处理节点脚本的绝对路径

    # output="screen" 直接将 IMU 预处理节点的输出打印到终端，方便调试和查看日志
    # log_cmd=True 启动时在终端打印完整的执行命令

    # ROS 2 启动 → 调用默认 Python3 → 运行源码目录中的 IMU 处理脚本 → 终端实时打印日志 + 启动命令 → 脚本持续处理 IMU 数据并发布 ROS 2 话题。
    # 二次处理数据，发布到ROS2话题上，供其他节点订阅使用，可以直接供机器人使用


    # ===================== 整合节点 + 优化启动顺序（解决进程间依赖卡死） =====================
    return LaunchDescription([
        motor_control_node,     # 优先启动电机节点，无串口抢占问题
        mid360_driver,          # 再启动雷达驱动
        imu_process_node,       # 最后启动IMU预处理
    ])
```