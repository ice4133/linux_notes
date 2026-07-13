# 下载conda本体，base
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh

source ~/.bashrc

conda --version
conda info


# 配置conda环境
// dev 是环境名字
conda create -n dev python=3.12

conda activate dev

conda install numpy pandas

conda deactivate


# 取消一进入，base环境就激活的设置
conda config --show auto_activate_base

conda config --set auto_activate_base false
