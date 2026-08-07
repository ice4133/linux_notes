# 使用ubuntu本身来制作
准备一个8GB以上的u盘
```bash

# 下载镜像源
https://releases.ubuntu.com/jammy/?utm_source=chatgpt.com
# 下载制作软件
sudo apt update
sudo apt install usb-creator-gtk


# 插入usb，看是否存在
lsblk

nvme0n1   512G   # 你的系统盘
sda        32G   # U盘




# 打开终端
usb-creator-gtk
# 搜索
Source disc image
# 选择，想要哪个
ubuntu-24.04.3-desktop-amd64.iso
# 确认
Disk to use
# 制作
Make Startup Disk



# 完成后，输入下面指令，把u盘拔出
sudo eject /dev/sdX
```