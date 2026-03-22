查阅正点原子文档
/home/ice/Core/文件/zhengdian-linux/MP157PDF合集/09、文档教程(非常重要)



# NFS和SSH
```bash
# 先创建一个文件夹
mkdir -p ~/linux/nfs

sudo apt install nfs-kernel-server rpcbind

sudo vim /etc/exports # 给全局文件配置

/home/ice/linux/nfs *(rw,sync,no_root_squash) # 在此文件中输入这一行

sudo /etc/init.d/nfs-kernel-server restart

```


```bash
sudo apt install openssh-server # 下载ssh服务端

```



# 下载交叉编译工具
https://developer.arm.com/tools-and-software/open-source-software/developer-
tools/gnu-toolchain/gnu-a/downloads

```bash
# 进入这个链接，下载对应的交叉编译工具，解压到指定目录

sudo mkdir /usr/local/arm_linux # 创建一个文件夹放置交叉编译工具

sudo cp gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf.tar.xz /usr/local/arm_linux/ -f

# 进入该文件夹，并解压

# 配置环境变量
sudo vim /etc/profile


# 输入
export PATH=$PATH:/usr/local/arm_linux/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin

# 生效
source /etc/profile # 好像一定要重启ubuntu


# 下载依赖包
sudo apt update # 先更新，否则安装库可能会出错

sudo apt install lsb-core lib32stdc++6 # 安装库


# 验证
arm-none-linux-gnueabihf-gcc --version

```

1、arm 表示这是编译 arm 架构代码的编译器。
2、none 表示厂商，一般半导体厂商会修改通用的交叉编译器，此处就是半导体厂商的名
字，ARM 自己做的交叉编译这里为 none，表示没有厂商。
3、linux 表示运行在 linux 环境下。
4、gnueabihf 表示嵌入式二进制接口，后面的 hf 是 hard float 的缩写，也就是硬件浮点，说
明此交叉编译工具链支持硬件浮点。
5、gcc 表示是 gcc 工具。



# 串口安装
```bash

# 免驱动
watch -n 1 lsusb
```
# stm32cubeprogrammer安装以及相关配置 （烧录）

下载stm32cubeprogrammer
```bash
cd /home/ice/Apps/cubepro/Drivers/rules

sudo cp * /etc/udev/rules.d/ # 配置DFU

# 测试stlink
ls /dev/stlink* # 必须插上stlink


```


# 编译软件下载
```bash

# stm32wrapper4dbg 下载

unzip stm32wrapper4dbg-master.zip

cd stm32wrapper4dbg-master

make

sudo cp stm32wrapper4dbg /usr/bin

stm32wrapper4dbg -s # 测试是否安装成功




sudo apt-get install device-tree-compiler # 安装dtc工具 设备数编译工具
```

