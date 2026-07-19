# 1. 安装系统依赖
sudo apt update

sudo apt install -y \
    git wget tar cmake make g++ build-essential pkg-config \
    libyaml-cpp-dev libspdlog-dev libboost-all-dev \
    libglfw3-dev libeigen3-dev libfmt-dev mesa-utils

# 2. 创建工作空间
mkdir -p ~/robot_ws/src
cd ~/robot_ws/src

# 3. 下载和安装unitree_sdk2
git clone https://github.com/unitreerobotics/unitree_sdk2.git

cd unitree_sdk2
mkdir -p build
cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/opt/unitree_robotics

make -j$(nproc)
sudo make install

# 4. 安装MuJoCo 3.3.6
mkdir -p ~/.mujoco
cd /tmp

wget \
https://github.com/google-deepmind/mujoco/releases/download/3.3.6/mujoco-3.3.6-linux-x86_64.tar.gz

tar -xzf mujoco-3.3.6-linux-x86_64.tar.gz \
    -C ~/.mujoco

# 5. 下载unitree_mujoco
cd ~/robot_ws/src

git clone https://github.com/unitreerobotics/unitree_mujoco.git

# 6. 创建MuJoCo软链接
cd ~/robot_ws/src/unitree_mujoco/simulate

ln -sfn \
    ~/.mujoco/mujoco-3.3.6 \
    mujoco

# 7. 编译
cmake -S . -B build \
    -DCMAKE_BUILD_TYPE=Release

cmake --build build -j$(nproc)

# 8. 启动Go2W
cd build

./unitree_mujoco \
    -r go2w \
    -s scene.xml