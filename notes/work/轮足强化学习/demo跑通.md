# unitree_mujoco 与 ROS 2 接口 Demo 跑通

本文用于验证 `unitree_mujoco`、`unitree_ros2` 和 ROS 2 之间的接口层是否正常，适用于：

| Ubuntu 版本 | ROS 2 版本 | 使用方式 |
| --- | --- | --- |
| Ubuntu 22.04 Jammy | ROS 2 Humble | 宇树官方测试并推荐的组合 |
| Ubuntu 24.04 Noble | ROS 2 Jazzy | ROS 官方支持的原生组合；`unitree_ros2` 需要在本机编译验证 |

> 宇树当前公开的 `unitree_ros2` 测试矩阵只明确列出了 Ubuntu 20.04/Foxy 和 Ubuntu 22.04/Humble，没有明确列出 Ubuntu 24.04/Jazzy。因此，24.04 下应使用 Jazzy 原生编译，不要强行安装 Humble 的 Jammy 软件包。如果 Jazzy 遇到上游兼容问题，可以使用本文末尾的 Humble 容器方案。

## 1. 本 Demo 要验证什么

安装好 `unitree_mujoco` 和 `unitree_sdk2` 并能显示 MuJoCo 画面后，继续配置 `unitree_ros2`，验证 ROS 2 能否直接发现模拟器中的 DDS Topic。

接口链路如下：

```text
/cmd_vel
    ↓
自己编写的控制器
    ↓ 生成 LowCmd
/lowcmd → DDS → unitree_mujoco → Go2W
                                  ↓
控制器 ← DDS ← /lowstate ← 关节、IMU 等状态
             ← /sportmodestate ← 机体运动状态
```

`unitree_mujoco` 不只是一个物理仿真窗口，它内部还使用 Unitree SDK2 / DDS：

- 发布 `LowState`；
- 发布 `SportModeState`；
- 订阅 `LowCmd`；
- 将 `LowCmd` 转换为 MuJoCo 执行器输入。

因此，接口层可以看作一个带输入和输出的黑盒。本文首先只验证状态读取，不发送电机控制命令。

## 2. 前置条件

开始前应满足：

```text
[ ] unitree_sdk2 已安装
[ ] unitree_mujoco 已编译
[ ] unitree_mujoco 可以正常打开 Go2W 场景
[ ] 系统是 Ubuntu 22.04 或 Ubuntu 24.04
[ ] 对应版本的 ROS 2 已安装
```

检查系统版本：

```bash
grep -E '^(NAME|VERSION_ID|VERSION_CODENAME)=' /etc/os-release
uname -m
```

本文默认使用 Bash，并默认 `unitree_ros2` 位于：

```text
$HOME/unitree_ros2
```

不要照抄其他电脑的 `/home/用户名/...` 绝对路径。

## 3. 自动选择 Humble 或 Jazzy

打开一个没有加载过其他 ROS 环境的新终端，执行：

```bash
. /etc/os-release

case "$VERSION_ID" in
  "22.04") export UNITREE_ROS_DISTRO=humble ;;
  "24.04") export UNITREE_ROS_DISTRO=jazzy ;;
  *)
    echo "当前只支持 Ubuntu 22.04 或 24.04，实际版本为：$VERSION_ID"
    return 1 2>/dev/null || exit 1
    ;;
esac

echo "Ubuntu $VERSION_ID -> ROS 2 $UNITREE_ROS_DISTRO"
```

对应关系必须是：

```text
Ubuntu 22.04 -> humble
Ubuntu 24.04 -> jazzy
```

检查 ROS 2 是否已经安装：

```bash
test -f "/opt/ros/$UNITREE_ROS_DISTRO/setup.bash" \
  && echo "ROS 2 $UNITREE_ROS_DISTRO 已安装" \
  || echo "尚未安装 ROS 2 $UNITREE_ROS_DISTRO"
```

如果文件不存在，先按照 ROS 2 官方文档安装对应发行版：

- Ubuntu 22.04：[ROS 2 Humble 安装文档](https://docs.ros.org/en/humble/Installation/Ubuntu-Install-Debs.html)
- Ubuntu 24.04：[ROS 2 Jazzy 安装文档](https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html)

不要在 Ubuntu 24.04 的软件源中混装 `ros-humble-*`，也不要在同一个终端先后加载 Humble 和 Jazzy。

## 4. 安装接口层依赖

重新确认 `UNITREE_ROS_DISTRO` 已设置，然后安装与当前系统匹配的包：

```bash
echo "$UNITREE_ROS_DISTRO"

sudo apt update
sudo apt install -y \
  "ros-${UNITREE_ROS_DISTRO}-ros-base" \
  "ros-${UNITREE_ROS_DISTRO}-rmw-cyclonedds-cpp" \
  "ros-${UNITREE_ROS_DISTRO}-rosidl-generator-dds-idl" \
  python3-colcon-common-extensions \
  python3-rosdep \
  libyaml-cpp-dev
```

检查关键包：

```bash
dpkg-query -W \
  "ros-${UNITREE_ROS_DISTRO}-rmw-cyclonedds-cpp" \
  "ros-${UNITREE_ROS_DISTRO}-rosidl-generator-dds-idl"
```

两项都应显示已安装版本。

## 5. 下载并编译 unitree_ros2

### 5.1 下载源码

如果还没有下载：

```bash
cd "$HOME"
git clone https://github.com/unitreerobotics/unitree_ros2.git
```

如果目录已经存在，不要再次克隆，直接检查：

```bash
git -C "$HOME/unitree_ros2" status --short
git -C "$HOME/unitree_ros2" log -1 --oneline
```

### 5.2 初始化 rosdep

`rosdep init` 在一台电脑上通常只需要执行一次：

```bash
sudo rosdep init
```

如果提示 sources list 已存在，说明以前初始化过，不需要重复处理。继续执行：

```bash
rosdep update
```

### 5.3 编译消息接口

```bash
source "/opt/ros/$UNITREE_ROS_DISTRO/setup.bash"

cd "$HOME/unitree_ros2/cyclonedds_ws"

rosdep install \
  --from-paths src \
  --ignore-src \
  --rosdistro "$UNITREE_ROS_DISTRO" \
  -r -y

colcon build \
  --symlink-install \
  --cmake-args -DCMAKE_BUILD_TYPE=Release \
  --packages-select unitree_go unitree_hg unitree_api
```

编译完成后加载工作区：

```bash
source "$HOME/unitree_ros2/cyclonedds_ws/install/setup.bash"
```

验证消息是否存在：

```bash
ros2 interface show unitree_go/msg/LowState
ros2 interface show unitree_go/msg/LowCmd
```

Go2、B2、Go2W 使用 `unitree_go` 消息；G1、H1-2 等机型使用 `unitree_hg` 消息。本文的 Go2W Demo 主要检查 `unitree_go`。

## 6. 检查 unitree_mujoco 的 DDS 配置

打开 `unitree_mujoco/simulate/config.yaml`，确认仿真使用：

```yaml
domain_id: 1
interface: "lo"
```

含义如下：

- `domain_id: 1`：仿真与 ROS 2 必须使用相同 DDS Domain；
- `interface: "lo"`：MuJoCo 与 ROS 2 位于同一台电脑，通信走本机回环网卡；
- 真机通常使用 Domain 0，仿真使用 Domain 1 可以降低误连真机的风险。

检查配置文件中的实际值：

```bash
grep -nE '^[[:space:]]*(domain_id|interface):' \
  "$HOME/unitree_mujoco/simulate/config.yaml"
```

如果你的仓库不在 `$HOME/unitree_mujoco`，把路径替换为实际位置。

## 7. 每个 ROS 2 终端都要加载的环境

每次打开新终端，先重新确定 ROS 2 版本：

```bash
. /etc/os-release

case "$VERSION_ID" in
  "22.04") export UNITREE_ROS_DISTRO=humble ;;
  "24.04") export UNITREE_ROS_DISTRO=jazzy ;;
esac

source "/opt/ros/$UNITREE_ROS_DISTRO/setup.bash"
source "$HOME/unitree_ros2/cyclonedds_ws/install/setup.bash"

export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export ROS_DOMAIN_ID=1
export ROS_LOCALHOST_ONLY=0

export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="lo" priority="default" multicast="default" /></Interfaces></General></Domain></CycloneDDS>'
```

检查最终环境：

```bash
echo "ROS_DISTRO=$ROS_DISTRO"
echo "RMW_IMPLEMENTATION=$RMW_IMPLEMENTATION"
echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
echo "CYCLONEDDS_URI=$CYCLONEDDS_URI"
```

Ubuntu 22.04 应显示 `ROS_DISTRO=humble`，Ubuntu 24.04 应显示 `ROS_DISTRO=jazzy`。

> 不建议一开始就把以上内容全部写进 `~/.bashrc`。当电脑同时存在多个 ROS、仿真和真机网络配置时，全局环境变量很容易造成 DDS 串域或加载错误。先在独立终端手动验证，稳定后再写成单独的环境脚本。

> `unitree_ros2` 仓库自带的部分 `setup*.sh` 仍可能写死 `/opt/ros/foxy`。在 Humble 或 Jazzy 环境中不要直接照搬，应以本节按系统版本加载环境的命令为准。

## 8. 启动和验证

### 8.1 终端 A：启动 MuJoCo

使用你已经验证过的命令启动 Go2W 仿真。例如 C++ 版通常从构建目录启动：

```bash
cd "$HOME/unitree_mujoco/simulate/build"
./unitree_mujoco
```

如果你的版本需要指定机器人或场景，继续使用该仓库 README 对应的启动参数。先确认 MuJoCo 窗口正常、机器人模型加载成功，再进行 ROS 2 检查。

### 8.2 终端 B：查看 Topic

加载第 7 节环境后执行：

```bash
ros2 daemon stop
ros2 topic list --no-daemon | sort
```

重点查找：

```bash
ros2 topic list --no-daemon \
  | grep -E '(^|/)(lowstate|sportmodestate)$'
```

不同版本可能显示为：

```text
/lowstate
/sportmodestate
```

或者带有 `rt` 前缀。应以 `ros2 topic list --no-daemon` 的实际输出为准，不要凭记忆写 Topic 名。

### 8.3 检查消息类型与数据

假设实际 Topic 为 `/lowstate`：

```bash
ros2 topic type /lowstate
ros2 topic info /lowstate --verbose
ros2 topic echo --once /lowstate
```

检查发布频率：

```bash
ros2 topic hz /lowstate
```

观察数秒后按 `Ctrl+C`。如果实际名称不是 `/lowstate`，将命令中的名称换成 Topic 列表显示的名称。

假设实际 Topic 为 `/sportmodestate`：

```bash
ros2 topic type /sportmodestate
ros2 topic echo --once /sportmodestate
```

### 8.4 通过标准

满足以下条件，才能认为 ROS 2 接口层已经跑通：

```text
[ ] MuJoCo 持续运行且没有 DDS 报错
[ ] ROS_DISTRO 与 Ubuntu 版本匹配
[ ] RMW_IMPLEMENTATION 为 rmw_cyclonedds_cpp
[ ] ROS_DOMAIN_ID 与模拟器一致，均为 1
[ ] ROS 2 能发现 lowstate
[ ] lowstate 的消息类型正确
[ ] lowstate 数据持续更新且数值有效
[ ] 能发现并读取 sportmodestate（当前场景支持时）
[ ] 未发送 LowCmd 时机器人不会因为本测试产生额外动作
```

只看到 MuJoCo 画面不代表接口层跑通；只看到 Topic 名但收不到持续数据，也不能算通过。

## 9. 常见问题

### 9.1 Ubuntu 24.04 找不到 `ros-humble-*`

这是正常现象。Ubuntu 24.04 原生使用 Jazzy：

```bash
export UNITREE_ROS_DISTRO=jazzy
```

然后安装 `ros-jazzy-*`。不要给 Noble 强行添加 Jammy 的 ROS 软件源。

### 9.2 `ros2: command not found`

说明当前终端没有加载 ROS 2：

```bash
source "/opt/ros/$UNITREE_ROS_DISTRO/setup.bash"
```

### 9.3 找不到 `unitree_go/msg/LowState`

说明 `unitree_ros2` 消息包没有成功编译或当前终端没有加载工作区：

```bash
source "$HOME/unitree_ros2/cyclonedds_ws/install/setup.bash"
ros2 pkg list | grep -E '^unitree_(go|hg|api)$'
```

### 9.4 Topic 列表中没有 `lowstate`

依次检查：

```bash
echo "$ROS_DISTRO"
echo "$RMW_IMPLEMENTATION"
echo "$ROS_DOMAIN_ID"
ip link show lo
pgrep -af unitree_mujoco
```

重点确认：

1. 模拟器确实在运行；
2. 模拟器与 ROS 2 的 Domain 都是 1；
3. 两端都使用 `lo`；
4. 当前终端使用 CycloneDDS；
5. 没有加载另一个 ROS 发行版或遗留真机网卡配置。

修改环境后再次执行：

```bash
ros2 daemon stop
ros2 topic list --no-daemon
```

### 9.5 `RMW implementation not installed`

安装与当前 ROS 发行版匹配的 CycloneDDS RMW：

```bash
sudo apt install -y \
  "ros-${UNITREE_ROS_DISTRO}-rmw-cyclonedds-cpp"
```

### 9.6 `colcon build` 在 Jazzy 下失败

先确认失败的是依赖缺失还是源码兼容问题：

```bash
cd "$HOME/unitree_ros2/cyclonedds_ws"
rosdep install \
  --from-paths src \
  --ignore-src \
  --rosdistro jazzy \
  -r -y

colcon build \
  --event-handlers console_direct+ \
  --packages-select unitree_go unitree_hg unitree_api
```

保留第一处真实编译错误，不要只看最后一行 `Aborted`。如果错误来自 Jazzy API 与上游 `unitree_ros2` 源码不兼容，使用下一节的 Humble 容器作为兼容方案。

## 10. Ubuntu 24.04 的 Humble 容器兼容方案

只有在 Jazzy 原生编译确实遇到上游兼容问题时，才使用本方案。基本结构是：

```text
Ubuntu 24.04 主机
├── unitree_mujoco：主机运行
└── Ubuntu 22.04 / ROS 2 Humble 容器
    └── unitree_ros2：使用 host 网络访问主机 DDS
```

容器必须使用 host 网络，否则容器自己的 `lo` 与主机回环网卡不是同一个通信环境。示例：

```bash
docker run --rm -it \
  --network host \
  -v "$HOME/unitree_ros2:/workspace/unitree_ros2" \
  osrf/ros:humble-desktop \
  bash
```

进入容器后，安装 Humble 依赖，在 `/workspace/unitree_ros2/cyclonedds_ws` 中编译，然后仍然设置：

```bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export ROS_DOMAIN_ID=1
export CYCLONEDDS_URI='<CycloneDDS><Domain><General><Interfaces><NetworkInterface name="lo" priority="default" multicast="default" /></Interfaces></General></Domain></CycloneDDS>'
```

容器只是 24.04 的兼容退路。能够在 Jazzy 下稳定编译并完成 Topic 验收时，优先使用原生方案。

## 11. 下一步

接口层通过后，再进入控制器或强化学习部署流程：

```text
读取 LowState
    ↓
整理 observation
    ↓
策略网络推理
    ↓
将 action 转换为关节目标
    ↓
生成带限幅、CRC 和安全状态机的 LowCmd
    ↓
先在 MuJoCo 验证，再申请真机测试
```

不要为了测试 Topic 而手工发布随意构造的 `/lowcmd`。低层电机命令必须由带关节映射、限幅、CRC 和退出保护的控制程序生成。

## 12. 参考资料

- [Unitree unitree_ros2](https://github.com/unitreerobotics/unitree_ros2)
- [Unitree unitree_mujoco](https://github.com/unitreerobotics/unitree_mujoco)
- [ROS 2 Humble 官方文档](https://docs.ros.org/en/humble/)
- [ROS 2 Jazzy 官方文档](https://docs.ros.org/en/jazzy/)
