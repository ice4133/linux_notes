# 介绍

当下载了unittree_mujoco和unittree_sdk2之后
这个时候，我们进行测试，是否能显示出mujoco的画面

在此之后，我们要下载一个unittree_ros2的包

于是我们开始配置，我们的目的首先是，能够让整个mujoco仿真，有控制命令和传感器数据反馈的topic，所以我们的目的，就是测试好，通信是否正常，能够让mujoco仿真和ros2通信
也就是测试好接口层

# 开始

```shell
# 先安装宇树的接口层的依赖
sudo apt install -y \
  ros-humble-rosidl-generator-dds-idl \
  ros-humble-rmw-cyclonedds-cpp
```

接口层详细链路

/cmd_vel
    ↓
你编写的控制器
    ↓ 生成 LowCmd
/lowcmd → DDS → unitree_mujoco → Go2W
                              ↓
控制器 ← DDS ← /lowstate ← 传感器/关节状态


对接口层和环境介绍
mujoco本体，或者说我们常说的仿真环境，不止是有环境本体，内部还启动了一个sdk2/dds桥，负责发布/lowstate，发布sportmodestate，订阅/lowcmd，把LowCmd转换成Mujoco执行器输入


这样就完全封装成一个黑盒再加上一个输入接口和输出接口，模块化

```shell
# 环境配置

# 配置ros2环境
source /opt/ros/humble/setup.bash

# 配置包环境
source /home/ice/robot_ws/install/setup.bash

# RMW_IMPLEMENTATION=rmw_cyclonedds_cpp：让 ROS 2 使用与 Unitree SDK2 兼容的 CycloneDDS。
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# ROS_DOMAIN_ID=1：DDS 只发现相同 Domain 的参与者。MuJoCo 使用 Domain 1，ROS 2 也必须是 1。
export ROS_DOMAIN_ID=1

# NetworkInterface name="lo"：通信只走本机回环网卡，因为 MuJoCo 和控制程序运行在同一台电脑
export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="lo" priority="default" multicast="default" /></Interfaces></General></Domain></CycloneDDS>'

```




```shell
# 测试，用ros2 topic list查看是否有/lowstate和/sportmodestate
# 首先打开mujoco仿真环境


ros2 topic list --no-daemon

# 能够看到/lowstate和/sportmodestate，说明接口层和mujoco仿真已经通信成功了


```