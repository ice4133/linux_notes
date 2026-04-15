仅举例动态模块的编写和烧录步骤

第一步：写好相对应的驱动代码
第二步：编译linux内核源码，生成一个对应的镜像文件，要求stm32mp157中的内核版本和我们在ubuntu编译的内核版本一致
第三步：编写Makefile文件，编译生成一个ko文件
第四步：将生成的ko文件烧录到stm32mp157中）
第五步：在stm32mp157中加载ko文件，验证驱动是否正常工作




# 第一步
编写驱动代码，代码如下：

```c
#include <linux/init.h>   // 包含宏定义，比如 __init 和 __exit
#include <linux/module.h> // 包含加载模块需要的宏和函数

// 1. 进门动作：驱动加载时执行的函数
static int __init hello_init(void)
{
    // printk 是内核里的 printf，KERN_INFO 是打印优先级
    printk(KERN_INFO "Hello MP157! The driver is loaded.\n");
    return 0; // 返回 0 表示加载成功
}

// 2. 出门动作：驱动卸载时执行的函数
static void __exit hello_exit(void)
{
    printk(KERN_INFO "Goodbye MP157! The driver is removed.\n");
}

// 3. 登记注册：告诉内核，哪个是进门函数，哪个是出门函数
module_init(hello_init);
module_exit(hello_exit);

// 4. 签署协议：声明这是一个开源模块（不写内核会疯狂警告）
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("A simple Hello World driver");
```
# 第二步
编译linux内核源码，生成一个对应的镜像文件，要求stm32mp157中的内核版本和我们在ubuntu编译的内核版本一致。具体步骤如下：

直接在终端里面使用即可
```bash
./xxx.sh



# 编译得到一个zImage和一个dtb文件，分别是内核镜像和设备树文件
# 内核镜像 (zImage)	arch/arm/boot/zImage (假设你是 ARM 架构)
# 设备树 (.dtb)	arch/arm/boot/dts/xxx.dtb
# 中间产物 (vmlinux)
# 中间产物再进行压缩得到 zImage和dtb文件
```


# 第三步
编写Makefile文件，编译生成一个ko文件。Makefile内容如下：
```makefile
# 1. 指向你截图里的那个内核源码文件夹的绝对路径（请根据实际路径修改）
# 必须是编译过的内核源码树！
KERNELDIR := /home/ice/linux/origin_code/linux/linux-5.4.31


# 2. 获取当前你写代码的目录
CURRENT_PATH := $(shell pwd)

# 3. 告诉编译器，把 hello.c 编译成模块 hello.o
obj-m := hello.o

# 4. 默认的编译动作
build: kernel_modules

# -C 表示跳转到内核源码目录去借用它的编译环境
# M= 表示编译完后把生成的 .ko 文件放回当前目录
kernel_modules:
	$(MAKE) -C $(KERNELDIR) M=$(CURRENT_PATH) modules

# 5. 清理编译垃圾的动作
clean:
	$(MAKE) -C $(KERNELDIR) M=$(CURRENT_PATH) clean
```


# 第四步
```bash
# 先编译，用编译得到内核源码作为编译器，内核源码作为库
make

# 得到 hello.ko 



# 现在开始分，该怎么把文件放入stm32mp157中呢？

# u盘
u盘失败，可能是因为这个linux开发版给u盘关了
# 网卡

# 对于单片机
ifconfig eth0 192.168.1.101 up

passwd root

输入密码：123456

vi /etc/ssh/sshd_config
prohibit-password 改成 yes 去掉#
/etc/init.d/S50sshd restart
#对于ubuntu
首先把wifi关掉
然后接上网线，连接以太网，自己打开设置，ipv4模式，手动设置，把地址和掩码设置
ping 192.168.1.101

成功了以后

输入指令
scp ~/xxx.ko root@192.168.1.101:/root/

yes


input your password





#最后，只需要每次启动，都对stm32启动网卡，对于ubuntu直接传输，就可以了

# NFS挂载

# 其余方法过于复杂，没有必要学习

```