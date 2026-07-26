# SONIC / HEFT-WPC 原生 Ubuntu 24.04 环境配置指南

本文档用于在 **Ubuntu 24.04 LTS x86_64 原生系统**（非 Docker）上配置本仓库的
SONIC 训练及 HEFT-WPC 重载荷微调环境。

> Ubuntu 24.04 默认的系统 Python 是 3.12，但 Isaac Sim 5.1 和本项目固定使用
> Python 3.11。不要替换 `/usr/bin/python3`，也不要把训练依赖安装进系统 Python；
> 本文使用独立 Conda 环境 `sonic_z`。

## 1. 版本与兼容性

| 组件 | 版本 |
| --- | --- |
| 操作系统 | Ubuntu 24.04 LTS（x86_64） |
| Python | 3.11（Conda 环境） |
| Isaac Sim | 5.1.0 |
| Isaac Lab | 2.3.2 |
| PyTorch | 2.7.0 + CUDA 12.8 |
| Conda 环境名 | `sonic_z` |

Ubuntu 24.04 在 Isaac Sim 5.1 的官方支持范围内。本仓库代码以 Isaac Lab 2.3.2
为基准，因此这里不升级到 Isaac Lab 3.x；即使官网已有更新版本，也不要随意替换，
否则可能遇到破坏性 API 变更。

官方资料：

- [Isaac Sim 5.1 系统要求](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/installation/requirements.html)
- [Isaac Sim 5.1 Python 安装](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/installation/install_python.html)
- [Isaac Lab v2.3.2](https://github.com/isaac-sim/IsaacLab/tree/v2.3.2)
- [Isaac Lab v2.3.2 Pip 安装说明](https://isaac-sim.github.io/IsaacLab/v2.3.2/source/setup/installation/pip_installation.html)

## 2. 检查系统和硬件

```bash
source /etc/os-release
echo "$PRETTY_NAME"
uname -m
ldd --version | head -n 1
free -h
df -h "$HOME"
```

应确认：

- 系统为 Ubuntu 24.04；
- 架构为 `x86_64`；
- GLIBC 不低于 2.35（Ubuntu 24.04 默认是 2.39）；
- 安装目录至少预留 50 GB，训练及缓存建议预留更多空间；
- 建议至少 32 GB 内存，复杂训练任务需要更多内存和显存。

### 2.1 检查 NVIDIA GPU 和驱动

```bash
nvidia-smi
```

命令必须能正常显示 GPU、驱动和显存。Isaac Sim 5.1 官方 x86_64 测试驱动为
Linux 580.65.06；优先使用 Ubuntu 24.04 当前推荐的生产驱动。如果已有驱动且
`nvidia-smi` 正常，不要重复安装或降级。

查看 Ubuntu 推荐驱动：

```bash
sudo apt update
sudo apt install -y ubuntu-drivers-common
ubuntu-drivers devices
```

仅当机器没有可用驱动时，才执行自动安装并重启：

```bash
sudo ubuntu-drivers install
sudo reboot
```

重启后再次运行 `nvidia-smi`。如果启用了 Secure Boot，驱动安装过程可能要求
注册 MOK；未完成注册会导致内核模块无法加载。

> 不需要安装完整的系统 CUDA Toolkit。后面安装的 PyTorch wheel 自带 CUDA
> 用户态运行库；系统只需要兼容的 NVIDIA 驱动。不要同时混用 Ubuntu、CUDA
> 仓库和 `.run` 文件安装驱动。

## 3. 安装 Ubuntu 24.04 基础依赖

```bash
sudo apt update
sudo apt install -y \
  build-essential \
  cmake \
  git \
  git-lfs \
  curl \
  wget \
  unzip \
  libgl1 \
  libglib2.0-0 \
  libegl1 \
  libx11-6 \
  libxext6 \
  libxi6 \
  libxrandr2 \
  libxrender1 \
  libsm6

git lfs install
```

如果只进行 headless 训练，这些图形运行库仍建议保留，因为 Isaac Sim 的部分
扩展会在启动时动态加载它们。

## 4. 安装 Conda 并创建 Python 3.11 环境

如果机器尚未安装 Conda，可为当前用户安装 Miniconda（不需要 `sudo`）：

```bash
curl -fL \
  https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
  -o /tmp/Miniconda3-latest-Linux-x86_64.sh

bash /tmp/Miniconda3-latest-Linux-x86_64.sh -b -p "$HOME/miniconda3"
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda init bash
```

`conda init bash` 只需执行一次；当前终端仍可直接 `source conda.sh`，不必退出重进。

如果机器已有 Miniconda/Miniforge，可跳过上述安装，先找到初始化脚本：

```bash
find "$HOME" -maxdepth 3 -path '*/etc/profile.d/conda.sh' -print
```

以下命令假设 Conda 安装在 `$HOME/miniconda3`：

```bash
export CONDA_SH="$HOME/miniconda3/etc/profile.d/conda.sh"
test -f "$CONDA_SH" || { echo "找不到 $CONDA_SH，请先安装 Conda 或修改路径"; exit 1; }

source "$CONDA_SH"
conda create -n sonic_z python=3.11 -y
conda activate sonic_z

which python
python --version
python -m pip install --upgrade pip setuptools wheel
```

预期 Python 路径位于 Conda 环境中，且版本为 `Python 3.11.x`，不能是 Ubuntu
24.04 系统自带的 `Python 3.12.x`。

## 5. 安装 Isaac Sim 5.1 和 PyTorch

确保已经激活 `sonic_z`：

```bash
source "$CONDA_SH"
conda activate sonic_z

python -m pip install \
  "isaacsim[all,extscache]==5.1.0" \
  --extra-index-url https://pypi.nvidia.com

python -m pip install \
  torch==2.7.0 \
  torchvision==0.22.0 \
  --index-url https://download.pytorch.org/whl/cu128
```

检查 PyTorch、CUDA 和 GPU：

```bash
python - <<'PY'
import torch

print("PyTorch:", torch.__version__)
print("CUDA runtime:", torch.version.cuda)
print("CUDA available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("GPU:", torch.cuda.get_device_name(0))
PY
```

预期包含 `2.7.0+cu128`、`12.8` 和 `CUDA available: True`。如果结果为
`False`，先解决驱动或 GPU 权限问题，不要继续安装上层训练依赖。

### 5.1 验证 Isaac Sim Python 包

```bash
export OMNI_KIT_ACCEPT_EULA=YES

python - <<'PY'
from importlib.metadata import version
import isaacsim

print("Isaac Sim Python package:", version("isaacsim"))
PY
```

这里先验证 Python 包和版本。不要在此处直接启动默认
`SimulationApp({"headless": True})`：它会加载完整的 Isaac-Sim Python
experience，在部分新显卡/驱动组合上可能触发与训练无关的 RTX 后台线程崩溃。
安装 Isaac Lab 后，以下文的 `create_empty.py --headless` 作为实际的 GPU、PhysX
和 headless 联合验证；该命令使用训练所需的精简
`isaaclab.python.headless.kit` experience。

## 6. 安装 Isaac Lab 2.3.2

将 Isaac Lab 放在 SONIC 仓库旁边，避免嵌套仓库：

```bash
export ISAACLAB_DIR="$HOME/IsaacLab"

git clone \
  --branch v2.3.2 \
  --depth 1 \
  https://github.com/isaac-sim/IsaacLab.git \
  "$ISAACLAB_DIR"

source "$CONDA_SH"
conda activate sonic_z
cd "$ISAACLAB_DIR"

# flatdict 4.0.1 的旧构建脚本不能在新版 pip 的隔离构建环境中找到
# pkg_resources，先用当前环境构建它。
python -m pip install --no-build-isolation flatdict==4.0.1

# Isaac Lab 2.3.2 声明的 Starlette 0.49.1 与 Isaac Sim 5.1 固定的
# FastAPI 0.115.7 不兼容；训练不需要 0.49.1 的新接口。
sed -i 's/"starlette==0.49.1"/"starlette==0.45.3"/' \
  source/isaaclab/setup.py

# 非交互终端的 TERM=dumb 会使 isaaclab.sh 顶部的 tabs 命令提前退出。
TERM=xterm ./isaaclab.sh --install none
```

`none` 表示不额外安装 RSL-RL、SKRL 和 RL-Games；SONIC 使用自己的 TRL/PPO
训练栈，这样可以减少依赖冲突。

验证 Isaac Lab：

```bash
python -c "import isaaclab; print('Isaac Lab import OK')"
python scripts/tutorials/00_sim/create_empty.py --headless
```

如果 `$HOME/IsaacLab` 已存在，不要再次 `git clone`。进入该目录并用
`git describe --tags --always` 确认版本是 v2.3.2。

## 7. 安装 SONIC 训练依赖

先定位仓库；如果当前文档就在仓库根目录，可以直接使用当前目录：

```bash
export SONIC_REPO="$(pwd)"
test -f "$SONIC_REPO/gear_sonic/pyproject.toml" || {
  echo "当前目录不是 SONIC 仓库根目录，请修改 SONIC_REPO"
  exit 1
}

source "$CONDA_SH"
conda activate sonic_z
cd "$SONIC_REPO"

git lfs install
git lfs pull
python -m pip install -e "gear_sonic[training]"
python -m pip install pytest

# 恢复 Isaac Sim 5.1 的精确公共依赖。Isaac Lab/训练工具的宽松依赖
# 可能在安装期间把它们升级。
python -m pip install --force-reinstall --no-deps \
  onnx==1.18.0 \
  click==8.1.7 \
  fastapi==0.115.7 \
  starlette==0.45.3 \
  psutil==5.9.8 \
  typing_extensions==4.12.2 \
  ipython==8.37.0 \
  wandb==0.19.11

python -m pip install --no-deps -e "$ISAACLAB_DIR/source/isaaclab"
python -m pip check
```

注意，可编辑安装的正确写法是 `gear_sonic[training]`，不是
`gear_sonic/[training]`。

## 8. 完整验证

```bash
source "$CONDA_SH"
conda activate sonic_z
cd "$SONIC_REPO"

python check_environment.py --training

python -m pytest \
  gear_sonic/tests/test_payload_state.py \
  gear_sonic/tests/test_window_load_capacity.py \
  -q

python -c "import torch, isaaclab, gear_sonic; print('SONIC environment OK')"
```

环境检查应覆盖 Python 3.11、Git LFS、CUDA、PyTorch、Isaac Lab、
`gear_sonic`、Hydra、TRL、Transformers、Accelerate 和 W&B。

## 9. 配置本仓库启动脚本

部分旧启动脚本写死了 `/root/miniconda3`。在当前原生用户环境中，优先向脚本
传入下列变量：

```bash
export SONIC_CONDA_ENV=sonic_z
export CONDA_SH="$HOME/miniconda3/etc/profile.d/conda.sh"
export SONIC_REPO="$(pwd)"
export OMNI_KIT_ACCEPT_EULA=YES
```

可以将前三项按本机实际路径写入 `~/.bashrc`；EULA 变量是否持久化由使用者自行
决定。启动脚本如果仍直接 `source /root/miniconda3/...` 且不读取 `CONDA_SH`，
需要将脚本中的路径改为 `$HOME/miniconda3/etc/profile.d/conda.sh`。

## 10. Ubuntu 24.04 常见问题

### 错误使用系统 Python 3.12

现象包括 `No matching distribution found for isaacsim` 或安装到了
`~/.local/lib/python3.12`。检查：

```bash
source "$CONDA_SH"
conda activate sonic_z
which python
python --version
python -m pip --version
```

三个路径都应指向同一个 `sonic_z` 环境。不要使用 `sudo pip install`。

### `torch.cuda.is_available() == False`

```bash
nvidia-smi
echo "${CUDA_VISIBLE_DEVICES:-未设置}"
python -c "import torch; print(torch.__version__, torch.version.cuda, torch.cuda.is_available())"
```

通常原因是驱动未加载、Secure Boot 阻止内核模块、当前进程未获得 GPU，或驱动
版本不兼容，而不是缺少系统 CUDA Toolkit。

### Isaac Sim 报缺少 `.so` 图形库

重新执行第 3 节的 `apt install`。桌面环境还应确认 Vulkan 能识别 NVIDIA GPU；
可安装 `vulkan-tools` 后运行：

```bash
sudo apt install -y vulkan-tools
vulkaninfo --summary
```

### `ModuleNotFoundError: No module named 'isaaclab'`

确认环境和安装目录：

```bash
source "$CONDA_SH"
conda activate sonic_z
cd "$ISAACLAB_DIR"
./isaaclab.sh --install none
python -c "import isaaclab"
```

### `trl` 或 `transformers` 依赖冲突

不要复用其他项目的环境。在 `sonic_z` 中重新安装本仓库声明的训练依赖：

```bash
python -m pip install -e "$SONIC_REPO/gear_sonic[training]" --upgrade
python -m pip check
```

### Git LFS 文件只是文本指针

```bash
cd "$SONIC_REPO"
git lfs install
git lfs pull
git lfs status
```

## 11. 配置完成后的边界

完成本文档后，环境应能够：

- 使用 CUDA PyTorch；
- 导入并以 headless 模式启动 Isaac Sim；
- 导入 Isaac Lab 2.3.2；
- 导入 SONIC 训练代码；
- 运行 HEFT-WPC 纯计算测试。

动作数据、SMPL 数据、SONIC checkpoint 和正式 WPC 训练属于后续步骤，不在本
文档的环境配置范围内。
