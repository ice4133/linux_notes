# GEAR-SONIC 最小 Demo 环境配置手册（原生 Ubuntu 24.04）

本文档用于在原生 Ubuntu 24.04 x86_64 桌面工作站上运行 NVIDIA
GEAR-SONIC 官方最小 Demo：

```text
MuJoCo Python 仿真
        ↕ Unitree SDK2 / DDS
SONIC C++ TensorRT 推理
        + 官方 ONNX 权重
```

本阶段不安装 Isaac Lab，不训练 SONIC，也不要求 ROS 2。ROS 2 工作空间
`~/g1_contact_ws` 与上游 SONIC 仓库保持分离。

## 1. 目标和非目标

完成后应能做到：

1. 打开 MuJoCo G1 仿真窗口；
2. 启动 SONIC C++ 推理程序；
3. C++ 推理程序与 MuJoCo 通过 Unitree SDK2/DDS 通信；
4. G1 在仿真中落地、保持平衡并执行官方参考动作。

当前不做 Isaac Lab / Isaac Sim、SONIC 训练或微调、ROS 2 接口、黑板和接触
状态算法以及真机控制。

## 2. 推荐版本

| 组件 | 推荐/要求 |
| --- | --- |
| 系统 | 原生 Ubuntu 24.04 LTS x86_64 |
| Python（MuJoCo） | 官方脚本管理的 Python 3.10 |
| NVIDIA 驱动 | 能支持 CUDA 12.6；使用 Ubuntu 推荐的生产驱动 |
| CUDA | CUDA Toolkit 12.6 |
| TensorRT（桌面 x86_64） | 10.13，必须匹配官方要求 |
| Git | 支持 Git LFS |
| GPU | 支持 CUDA/TensorRT 的 NVIDIA GPU |
| 显示 | 原生 X11 或 Wayland |

GEAR-SONIC 官方部署文档支持 Ubuntu 20.04/22.04/24.04，但桌面 x86_64 必须
使用 TensorRT 10.13。不要使用 Jetson/G1 Orin 所需的 TensorRT 10.7。

## 3. 目录规划

```text
~/
├── g1_contact_ws/                 # 自己的 ROS 2 工程，暂时不参与 Demo
└── g1_sonic/
    └── GR00T-WholeBodyControl/    # NVIDIA 官方仓库
```

不要把 `GR00T-WholeBodyControl` 放进 `g1_contact_ws/src`，它不是普通的
ROS 2 package。

## 4. 检查 Ubuntu 和硬件

```bash
cat /etc/os-release
uname -m
lspci | grep -i nvidia
```

应确认系统是 Ubuntu 24.04、架构是 `x86_64`，并且 PCI 设备中能看到 NVIDIA
GPU。

## 5. 安装 NVIDIA 驱动

如果升级系统后 `nvidia-smi` 已能正确识别 GPU，可跳过安装，只做本节末尾的
检查。不要同时混用 Ubuntu 软件源驱动、NVIDIA `.run` 安装包和其他第三方驱动。

查看 Ubuntu 推荐驱动：

```bash
sudo apt update
sudo apt install -y ubuntu-drivers-common
ubuntu-drivers devices
```

自动安装推荐驱动：

```bash
sudo ubuntu-drivers install
sudo reboot
```

重启后检查：

```bash
nvidia-smi
lsmod | grep nvidia
```

若驱动模块没有加载且机器启用了 Secure Boot，执行：

```bash
mokutil --sb-state
```

此时通常需要在安装驱动时设置 MOK 密码，并在重启后的固件界面完成
`Enroll MOK`；也可以在确认安全策略后关闭 Secure Boot。不要在驱动未正常加载
时继续安装 TensorRT。

## 6. 安装基础工具

```bash
sudo apt update
sudo apt install -y \
  build-essential \
  cmake \
  ninja-build \
  git \
  git-lfs \
  curl \
  wget \
  python3 \
  python3-venv \
  python3-pip \
  pkg-config \
  mesa-utils \
  pciutils \
  mokutil
```

```bash
git lfs install
git --version
git lfs version
cmake --version
python3 --version
```

不必提前手工安装 `uv` 和 `just`：官方脚本会分别安装它们。

## 7. 安装 CUDA Toolkit 12.6

CUDA 12.4 没有发布到 Ubuntu 24.04 的 NVIDIA APT 仓库；该仓库从 CUDA
12.5 开始提供 Ubuntu 24.04 软件包。这里选择成熟且仍属于 CUDA 12.x 的
CUDA 12.6。以下命令只安装 Toolkit，不会主动替换已验证工作的显卡驱动：

```bash
cd /tmp
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update
sudo apt install -y cuda-toolkit-12-6
```

配置当前终端：

```bash
export CUDA_HOME=/usr/local/cuda-12.6
export CUDAToolkit_ROOT=/usr/local/cuda-12.6
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}
```

```bash
nvcc --version
nvidia-smi
```

`nvidia-smi` 中的 CUDA Version 是驱动支持的最高 CUDA 版本；本机 Toolkit
版本以 `nvcc --version` 为准。确认无误后，将上面的四条 `export` 加到
`~/.bashrc`。

不要为了安装 Toolkit 使用不带版本的 `cuda` 元包；它可能连同驱动一起升级。

## 8. 安装 TensorRT 10.13

从 NVIDIA Developer 下载 Linux x86_64、CUDA 12.x 对应的 TensorRT 10.13
TAR 包。必须使用 10.13，并建议使用 TAR 而不是 DEB。

```bash

# https://developer.download.nvidia.com/compute/machine-learning/tensorrt/10.13.3/tars/TensorRT-10.13.3.9.Linux.x86_64-gnu.cuda-12.9.tar.gz?t=eyJscyI6ImdzZW8iLCJsc2QiOiJodHRwczovL3d3dy5nb29nbGUuY29tLyJ9

# cd ~/Downloads

#wget -c --tries=20 --timeout=60 \
#  "https://developer.nvidia.com/downloads/compute/machine-learning/tensorrt/10.13.3/tars/TensorRT-10.13.3.9.Linux.x86_64-gnu.cuda-12.9.tar.gz"
mkdir -p ~/opt
tar -xf ~/Downloads/TensorRT-10.13.x.x.Linux.x86_64-gnu.cuda-12.x.tar.gz \
  -C ~/opt
ln -sfn ~/opt/TensorRT-10.13.x.x ~/TensorRT
```

文件名和解压目录名需替换为实际版本。配置当前终端：

```bash
export TensorRT_ROOT=$HOME/TensorRT
export PATH=$TensorRT_ROOT/bin:$PATH
export LD_LIBRARY_PATH=$TensorRT_ROOT/lib:${LD_LIBRARY_PATH:-}
```

有些 TAR 包使用 `lib64`；若 `$TensorRT_ROOT/lib` 不存在，把上面的 `lib`
改为 `lib64`。

```bash
ls "$TensorRT_ROOT/include/NvInfer.h"
find "$TensorRT_ROOT" -maxdepth 2 -name 'libnvinfer.so*'
```

确认后，将 TensorRT 的三条环境变量设置加入 `~/.bashrc`。

## 9. 克隆 GEAR-SONIC

不要在 Conda 环境中安装。若安装过 Conda，先执行 `conda deactivate`；命令不
存在时忽略即可。

```bash
mkdir -p ~/g1_sonic
cd ~/g1_sonic
git clone https://github.com/NVlabs/GR00T-WholeBodyControl.git
cd GR00T-WholeBodyControl
git lfs pull
git lfs status
```

如果网格、模型或二进制文件只有几十到几百字节，通常说明 Git LFS 文件仍是
指针，需先解决 LFS 下载问题。

## 10. 创建 MuJoCo Python 环境

```bash
cd ~/g1_sonic/GR00T-WholeBodyControl
bash install_scripts/install_mujoco_sim.sh
source ~/.local/bin/env
source .venv_sim/bin/activate
```

官方脚本会安装 `uv`、由 `uv` 管理的 Python 3.10，创建 `.venv_sim`，并安装
`gear_sonic[sim]` 和仓库内的 `unitree_sdk2_python`。脚本会删除旧
`.venv_sim` 后重建，不要在加入自定义包后随意重复运行。

```bash
which python
python --version
python -c "import mujoco; print('MuJoCo', mujoco.__version__)"
python -c "import pinocchio; print('Pinocchio OK')"
python -c "from unitree_sdk2py.core.channel import ChannelFactoryInitialize; print('Unitree SDK2 OK')"
```

不要混用 Conda 与 `.venv_sim`，也不要把 Isaac Lab 安装进 `.venv_sim`。

## 11. 下载官方 SONIC 权重

保持 `.venv_sim` 激活并位于仓库根目录：

```bash
uv pip install huggingface_hub
python download_from_hf.py
```

```bash
ls -lh gear_sonic_deploy/policy/release
ls -lh gear_sonic_deploy/planner/target_vel/V2
```

至少应有：

```text
gear_sonic_deploy/policy/release/model_encoder.onnx
gear_sonic_deploy/policy/release/model_decoder.onnx
gear_sonic_deploy/policy/release/observation_config.yaml
gear_sonic_deploy/planner/target_vel/V2/planner_sonic.onnx
```

不要执行 `python download_from_hf.py --training`，否则可能下载训练 checkpoint
和约 30 GB 的 SMPL 数据。低延迟版本可用：

```bash
python download_from_hf.py --low-latency
```

## 12. 编译 C++ SONIC 推理程序

```bash
deactivate
cd ~/g1_sonic/GR00T-WholeBodyControl/gear_sonic_deploy
echo "$CUDA_HOME"
echo "$TensorRT_ROOT"
nvcc --version
```

确认变量和版本正确后：

```bash
chmod +x scripts/install_deps.sh
./scripts/install_deps.sh
source scripts/setup_env.sh
just build
just --version
cd ..
python3 check_environment.py
```

如果环境检查需要 Python 包，可在 `.venv_sim` 中运行检查；C++ 构建和运行应
保持 Conda 关闭。

## 13. 运行官方 Demo

使用两个全新终端。最小 Demo 不需要加载 ROS 2。

终端 1，运行 MuJoCo：

```bash
cd ~/g1_sonic/GR00T-WholeBodyControl
source .venv_sim/bin/activate
python gear_sonic/scripts/run_sim_loop.py
```

终端 2，运行 C++ SONIC：

```bash
cd ~/g1_sonic/GR00T-WholeBodyControl/gear_sonic_deploy
source scripts/setup_env.sh
bash deploy.sh sim
```

操作顺序：

1. 在终端 2 按 `]` 启动策略；
2. 点击 MuJoCo Viewer，在 Viewer 中按 `9` 让 G1 落地；
3. 回到终端 2 按 `T` 执行当前参考动作；
4. 按 `N` / `P` 切换动作，按 `R` 重置；
5. 按 `O` 停止控制并退出。

低延迟权重：

```bash
bash deploy.sh \
  --cp policy/low_latency/model \
  --obs-config policy/low_latency/observation_config.yaml \
  sim
```

## 14. 验收清单

```text
[ ] 系统是原生 Ubuntu 24.04 x86_64
[ ] nvidia-smi 能识别 NVIDIA GPU
[ ] NVIDIA 内核模块已加载，Secure Boot 未阻止驱动
[ ] nvcc --version 显示 CUDA 12.6
[ ] TensorRT_ROOT 指向 TensorRT 10.13
[ ] NvInfer.h 与 libnvinfer.so 存在
[ ] Git LFS 文件已完整拉取
[ ] .venv_sim 使用 Python 3.10
[ ] Python 可以 import mujoco、pinocchio 和 Unitree SDK2
[ ] MuJoCo Viewer 能打开
[ ] 默认 ONNX 权重和 planner 已下载
[ ] just build 成功
[ ] deploy.sh sim 能启动
[ ] C++ 推理能与 MuJoCo 通信
[ ] G1 能落地并执行官方动作
```

## 15. 常见问题

### 15.1 `nvidia-smi` 失败

```bash
lspci | grep -i nvidia
lsmod | grep nvidia
journalctl -k -b | grep -iE 'nvidia|nouveau|secure'
mokutil --sb-state
```

先处理驱动、内核模块或 Secure Boot，不要用安装 Python/CUDA 包来修复驱动。

### 15.2 `nvcc: command not found`

```bash
ls /usr/local/cuda*/bin/nvcc
echo "$CUDA_HOME"
echo "$PATH"
```

确认 Toolkit 已安装，且 `$CUDA_HOME/bin` 已加入 `PATH`。

### 15.3 `NvInfer.h` 或 `libnvinfer.so` 找不到

```bash
echo "$TensorRT_ROOT"
find "$TensorRT_ROOT" -name NvInfer.h
find "$TensorRT_ROOT" -name 'libnvinfer.so*'
```

检查 TAR 包使用 `lib` 还是 `lib64`，并重新执行 `source scripts/setup_env.sh`。

### 15.4 ONNX、mesh 文件很小或无法解析

```bash
git lfs pull
git lfs status
```

### 15.5 MuJoCo Viewer 无法打开

```bash
echo "$XDG_SESSION_TYPE"
echo "$DISPLAY"
echo "$WAYLAND_DISPLAY"
glxinfo -B
```

在 Wayland 下出问题时，可从登录界面选择 “Ubuntu on Xorg” 复测。远程 SSH
终端还需正确配置图形转发或在本机桌面会话中运行。

### 15.6 DDS 无法连接

确保 MuJoCo 和 C++ 部署程序运行在同一台主机，并使用全新终端。检查是否遗留
了 ROS 2/DDS 配置：

```bash
env | grep -E 'CYCLONEDDS|ROS_DOMAIN|RMW_IMPLEMENTATION'
```

最小 Demo 不需要 ROS 2；临时取消错误的自定义网卡或 domain 配置后重试。

### 15.7 编译成功但机器人动作异常

桌面端必须使用 TensorRT 10.13，并保证 ONNX 权重和
`observation_config.yaml` 来自同一发布版本。不要混用默认与低延迟模型配置。

### 15.8 Conda 导致动态库冲突

构建和运行 C++ SONIC 前退出 Conda，不要混用 Conda 的 CUDA、TensorRT 或
`libstdc++` 与系统部署环境。

## 16. Demo 跑通后的下一步

1. 在 MuJoCo 场景中增加固定黑板 geom；
2. 设计手掌接近黑板的参考动作或上肢目标；
3. 从 MuJoCo 读取手臂关节 `q`、`dq`、执行器力矩；
4. 读取 MuJoCo 接触法向力，仅作为训练标签和评测真值；
5. 接触检测算法只使用 `q`、`dq` 和力矩；
6. 仿真验证后再接入 `~/g1_contact_ws` 的 ROS 2 节点。

## 17. 官方资料

- [GEAR-SONIC 部署安装](https://nvlabs.github.io/GR00T-WholeBodyControl/getting_started/installation_deploy.html)
- [GEAR-SONIC MuJoCo Quick Start](https://nvlabs.github.io/GR00T-WholeBodyControl/getting_started/quickstart.html)
- [GEAR-SONIC 权重下载](https://nvlabs.github.io/GR00T-WholeBodyControl/getting_started/download_models.html)
- [NVIDIA CUDA Linux 安装指南](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)
- [Ubuntu 24.04 CUDA 软件源](https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/)
- [项目代码仓库](https://github.com/NVlabs/GR00T-WholeBodyControl)
