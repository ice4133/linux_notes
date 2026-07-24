# 介绍
这个用于配置current-robotics真机上的算法代码


# SONIC / HEFT-WPC 训练环境配置指南

本文档用于配置本仓库的 SONIC 训练及 HEFT-WPC 重载荷微调环境。

> 本工程的训练环境不使用仓库内的 `venv/bin/activate`。训练依赖
> Isaac Sim 和 Isaac Lab，推荐安装到独立 Conda 环境 `sonic_z`。

## 1. 推荐版本

| 组件 | 推荐版本 |
| --- | --- |
| 操作系统 | Ubuntu 22.04 |
| Python | 3.11 |
| Isaac Sim | 5.1.0 |
| Isaac Lab | 2.3.2 |
| PyTorch | 2.7.0 + CUDA 12.8 |
| Conda 环境名 | `sonic_z` |

本仓库标注使用 Isaac Lab 2.3.2，训练环境要求 Python 3.11。不要直接安装
Isaac Sim 6.x 或 Isaac Lab 3.x，因为新版本存在破坏性 API 变化，未必兼容
本仓库代码。

相关资料：

- [Isaac Lab v2.3.2](https://github.com/isaac-sim/IsaacLab/tree/v2.3.2)
- [Isaac Lab v2.3.2 Pip 安装说明](https://isaac-sim.github.io/IsaacLab/v2.3.2/source/setup/installation/pip_installation.html)
- [Isaac Sim 5.1 系统要求](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/installation/requirements.html)

## 2. 检查基础条件

### 2.1 检查 GPU 和驱动

```bash
nvidia-smi
```

命令应能显示 NVIDIA GPU、显存和驱动版本。如果命令失败，或者服务器驱动
明显过旧，应先联系服务器管理员。

不需要单独安装完整 CUDA Toolkit。后续安装的 PyTorch wheel 会携带 CUDA
用户态运行库，但系统必须有可用的 NVIDIA 驱动。

### 2.2 检查系统

```bash
lsb_release -ds
ldd --version | head -1
df -h
git lfs version
```

Isaac Sim Pip 安装要求 GLIBC 2.35 或更高。Ubuntu 22.04 默认提供 GLIBC 2.35。

## 3. 创建 Conda 环境

当前机器的 Miniconda 初始化脚本位于：

```text
/home/ice/miniconda3/etc/profile.d/conda.sh
```

创建并激活环境：

```bash
source /home/ice/miniconda3/etc/profile.d/conda.sh

conda create -n sonic_z python=3.11 -y
conda activate sonic_z

which python
python --version
```

预期输出类似：

```text
/home/ice/miniconda3/envs/sonic_z/bin/python
Python 3.11.x
```

升级基础安装工具：

```bash
python -m pip install --upgrade pip setuptools wheel
```

## 4. 安装 Isaac Sim 5.1

```bash
python -m pip install \
  "isaacsim[all,extscache]==5.1.0" \
  --extra-index-url https://pypi.nvidia.com
```

该步骤需要下载数 GB 文件，耗时取决于网络速度。

安装与 Isaac Sim 5.1 配套的 PyTorch：

```bash
python -m pip install \
  torch==2.7.0 \
  torchvision==0.22.0 \
  --index-url https://download.pytorch.org/whl/cu128
```

检查 PyTorch 和 CUDA：

```bash
python -c "import torch; print(torch.__version__); print(torch.version.cuda); print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))"
```

预期结果：

```text
2.7.0+cu128
12.8
True
<GPU 名称>
```

如果 `torch.cuda.is_available()` 为 `False`，先检查 NVIDIA 驱动和当前作业的
GPU 权限，不要继续安装上层训练依赖。

### 4.1 首次启动 Isaac Sim

```bash
export OMNI_KIT_ACCEPT_EULA=YES

python - <<'PY'
from isaacsim import SimulationApp

app = SimulationApp({"headless": True})
print("Isaac Sim headless launch OK")
app.close()
PY
```

首次启动可能会下载扩展并构建 shader cache，耗时十几分钟属于正常情况。

## 5. 安装 Isaac Lab 2.3.2

建议将 Isaac Lab 克隆到 SONIC 仓库外：

```bash
cd /home/ice

git clone \
  --branch v2.3.2 \
  --depth 1 \
  https://github.com/isaac-sim/IsaacLab.git
```

安装 Isaac Lab 核心扩展：

```bash
source /home/ice/miniconda3/etc/profile.d/conda.sh
conda activate sonic_z

cd /home/ice/IsaacLab
./isaaclab.sh --install none
```

这里使用 `none`，因为 SONIC 使用自己的 TRL/PPO 训练栈，不需要 Isaac Lab
额外安装 RSL-RL、SKRL、RL-Games 等训练框架，可以减少依赖冲突。

验证导入：

```bash
python -c "import isaaclab; print('Isaac Lab import OK')"
```

运行 Isaac Lab 官方空场景测试：

```bash
cd /home/ice/IsaacLab
python scripts/tutorials/00_sim/create_empty.py --headless
```

如果程序能够启动仿真并正常退出，说明 Isaac Sim 和 Isaac Lab 主体安装成功。

## 6. 安装 SONIC 训练依赖

回到本仓库：

```bash
source /home/ice/miniconda3/etc/profile.d/conda.sh
conda activate sonic_z
cd /home/ice/sonic
```

拉取 Git LFS 文件：

```bash
git lfs install
git lfs pull
```

安装 SONIC 训练依赖：

```bash
python -m pip install -e "gear_sonic[training]"
python -m pip install pytest
```

注意：部分旧文档写成了 `gear_sonic/[training]`，正确写法是：

```text
gear_sonic[training]
```

## 7. 验证完整训练环境

运行仓库自带的训练环境检查：

```bash
cd /home/ice/sonic
conda activate sonic_z
python check_environment.py --training
```

应通过以下检查：

- Python 3.11
- Git LFS
- CUDA
- PyTorch
- Isaac Lab
- `gear_sonic`
- Hydra
- TRL
- Transformers
- Accelerate
- W&B

然后运行 HEFT-WPC 的纯计算单元测试：

```bash
python -m pytest \
  gear_sonic/tests/test_payload_state.py \
  gear_sonic/tests/test_window_load_capacity.py \
  -q
```

这两个测试主要验证 WPC 状态机、受力计算和窗口载荷标签查询。

## 8. 配置本仓库启动脚本

本仓库部分 WPC 启动脚本默认使用 `/root/miniconda3`，但当前机器的 Conda
位于 `/home/ice/miniconda3`。启动前应设置：

```bash
export SONIC_CONDA_ENV=sonic_z
export CONDA_SH=/home/ice/miniconda3/etc/profile.d/conda.sh
export SONIC_REPO=/home/ice/sonic
export OMNI_KIT_ACCEPT_EULA=YES
```

激活并做最终导入检查：

```bash
source "$CONDA_SH"
conda activate "$SONIC_CONDA_ENV"

which python
python --version
python -c "import torch, isaaclab, gear_sonic; print('SONIC environment OK')"
```

出现以下输出即表示 Python 环境主体配置完成：

```text
SONIC environment OK
```

## 9. 常见错误

### `ModuleNotFoundError: No module named 'isaaclab'`

通常是没有激活正确环境：

```bash
source /home/ice/miniconda3/etc/profile.d/conda.sh
conda activate sonic_z
which python
python -c "import isaaclab"
```

### `torch.cuda.is_available() == False`

依次检查：

```bash
nvidia-smi
echo "$CUDA_VISIBLE_DEVICES"
python -c "import torch; print(torch.__version__, torch.version.cuda)"
```

这通常是驱动、容器 GPU 映射或集群作业没有分配 GPU 导致的，不一定是
PyTorch 安装错误。

### `No matching distribution found for isaacsim`

确认：

- 系统是 Linux x86_64；
- Python 是 3.11；
- 命令包含 `--extra-index-url https://pypi.nvidia.com`；
- 当前激活的是 `sonic_z`，而不是其他 Conda 环境。

### `trl` 或 `transformers` 依赖冲突

不要把 SONIC 安装到其他项目使用的 Python 环境中。确认当前环境：

```bash
conda activate sonic_z
python -m pip install -e "gear_sonic[training]" --upgrade
```

### 首次启动长时间没有输出

Isaac Sim 首次启动需要下载扩展、初始化缓存和编译 shader。先观察网络、
磁盘和进程状态，不要立即强制终止。

## 10. 配置完成后的边界

完成本文档后，环境应当能够：

- 导入并启动 Isaac Sim；
- 导入 Isaac Lab；
- 导入 SONIC 训练代码；
- 使用 CUDA PyTorch；
- 运行 HEFT-WPC 纯计算测试。

动作数据、SMPL 数据、SONIC checkpoint 和正式 WPC 训练属于后续步骤，
不在本文档的环境配置范围内。
