
# 极速体验
找到烧录文件

打开stm32cubeprogrammer，烧录到对应的设备上就可以了

烧录完记住关闭串口otg，也就是programmer中的关闭

# 1.启动

## 单片机是怎么启动的？
单片机上电后，程序计数器（PC）会被设置为一个固定的地址，这个地址通常是单片机内置的引导程序所在的位置。引导程序会执行一些初始化操作，比如设置时钟、配置内存等，然后从预定的存储位置（通常是闪存）加载用户程序到内存中，并将程序计数器指向用户程序的入口地址，开始执行用户程序。


## Linux是怎么启动的？
linux系统相比于单片机，很大

往往需要借助一些外部设备来完成启动过程

SD卡、eMMC、SPI NOR Flash等存储设备，或者通过网络启动（PXE）等方式来加载操作系统内核和文件系统。

不同的半导体厂商和不同的处理器架构可能会有不同的启动流程和引导程序


STM32MP1 内部有一段 ST 自己编写的 ROM 代码，这段 ROM 代码上
电以后就会自动运行，
ROM会先初始化一些硬件资源，比如时钟、内存控制器等，然后读取一些引脚的电平状态来确定启动模式，
ROM 代码会读取 BOOT0~BOOT2 这三个引脚电平，获取启动模式信息，
比如读取到是从 EMMC 启动的，那么 ROM 代码就会从 EMMC 中读取相关程序


![alt text](./pictures/image.png)



linux 系统自身编译出来就是一个镜像文件，但是这个镜像文件要运行是需要一
大堆的“小弟”来辅助。

![alt text](./pictures/image2.png)
编写这些镜像文件，并且烧录就可以了

移植不如说是配置，
不同厂家的芯片，启动方式不同，配置的内容也不同，
配置好这些镜像文件，烧录到对应的设备上，就可以运行了


总流程如下：
![alt text](./pictures/image3.png)

**ROM Code→FSBL→SSBL→Linux kernel→rootfs**

有一个需要注意的是，TFA和uboot、linux kernel、rootfs之间，版本必须适配，否则可能会出现启动失败的情况
这和之前链接器需要和编译器适配意义一样，版本不适配可能会导致一些功能无法使用，甚至启动失败


# 2.TF-A 移植 

## TF-A 初探
TF-A（Trusted Firmware-A）是一个开源的、由Arm公司主导开发的可信固件项目，旨在为Arm架构的系统提供一个安全的启动环境。TF-A实现了Arm架构的安全启动规范，提供了一个可信的引导环境，确保系统在启动过程中能够验证和加载可信的固件和操作系统。


ARM开发的TF-A
ST 基于ARM开发的TF-A进行移植
想要开发mp157,再来一个对应的补丁包，这样会适应st官方的开发环境，减少一些不必要的麻烦

但是如果开发自己的mp157，可能就需要自己移植TF-A了，这样就需要自己编写一些代码来适配TF-A和自己的硬件平台了


## 移植（使用极速版）

直接找到三个镜像文件，和一个烧录文件，用stm32cubeprogrammer烧录到对应的设备上就可以了

## 移植 （源码编译）

+ 去官网下载TF-A的源码 例如：MP1-DEV-SRC
版本很重要，必须和后续的uboot、linux kernel、rootfs版本适配，否则可能会出现启动失败的情况
这就好像不同平台需要与之适配的编译器一样，版本不适配可能会导致一些功能无法使用，甚至启动失败

这里根据正点原子教程，下载2.0.0版本的TF-A源码

下载完成了之后，一直cd
```bash
linux-stm32mp-5.4.31-r0       tf-a-stm32mp-ssp-2.2.r1-r0
optee-os-stm32mp-3.9.0.r1-r0  u-boot-stm32mp-2020.01-r0
tf-a-stm32mp-2.2.r1-r0

# 一共有这五个文件夹，分别是：
# 1、linux-stm32mp-5.4.31-r0：这是Linux内核的源代码，版本是5.4.31。
# 2、optee-os-stm32mp-3.9.0.r1-r0：这是OP-TEE OS的源代码，版本是3.9.0。
# 3、tf-a-stm32mp-ssp-2.2.r1-r0：这是TF-A的源代码，版本是2.2。 
# 4、u-boot-stm32mp-2020.01-r0：这是U-Boot的源代码，版本是2020.01。
# 5、tf-a-stm32mp-2.2.r1-r0：这是TF-A的源代码，版本是2.2。

```



+ 打补丁

下载的是arm的源码，或许有st的修改，但至少没有修改到stm32mp157devkit的相关代码，所以需要打补丁来适配stm32mp157devkit
```bash

tar -vxf tf-a-stm32mp-2.2.r1-r0.tar.gz  # 根据自己情况，解压文件

cd tf-a-stm32mp-2.2.r1-r0

for p in `ls -1 ../*.patch`; do patch -p1 < $p; done # 打补丁

# bl1   bl31    CONTRIBUTING.md  drivers  lib          make_helpers  services
# bl2   bl32    dco.txt          fdts     license.rst  plat          tools
# bl2u  common  docs             include  Makefile     readme.rst

# 以上是打完补丁之后的文件结构，bl1、bl2、bl31、bl32分别是TF-A的不同阶段的引导程序，common是一些公共代码，drivers是驱动代码，fdts是设备树文件，include是头文件，plat是平台相关代码，tools是一些工具代码等。


# 我们真正需要的东西是包含了补丁文件的以下文件
# 0001-st-update-v2.2-r2.0.0.patch  series
# Makefile.sdk                      tf-a-stm32mp-2.2.r1
# README.HOW_TO.txt                 tf-a-stm32mp-2.2.r1-r0.tar.gz



# 因为一些原因，我们把这个文件拷贝到另一个干净的目录中

```


+ 编译TF-A

```bash

# 第一步，修改Makefile.sdk文件，修改里面的编译器路径，指向我们之前安装的交叉编译器

arm-none-linux-gnueabihf-  # 替换成这个

arm-none-linux-gnueabihf-gcc --version # 验证一下编译器是否存在和正确


# 第二步，编译TF-A
cd tf-a-stm32mp-2.2.r1

make -f ../Makefile.sdk -j8 all


cd ..

# 此时你会看到build文件夹，而烧录所需要的两个文件就在这里面，一个串口、一个是最终烧录文件

# 当然就这样肯定不行，因为现在才移植到st官方这一步，还需要移植到atk
```

+ 移植到atk



## 移植 （训练）




# uboot移植

## 介绍uboot
uboot 的功能是引导，启动linux内核

不同芯片，启动方式不一样，重点是DDR初始化


uboot 官方

soc原厂

开发版厂商  


## 快速使用（烧录版）


## 详细讲解


## 训练