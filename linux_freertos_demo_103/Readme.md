# 注意
本工程基于gcc10,如果你是gcc11,只需修改.ld链接文件中的READONLY
在 STM32F103XX_FLASH.ld:104-148 中把 .ARM.extab, .ARM, .preinit_array, .init_array, .fini_array 五个段的定义从 “.ARM等 (READONLY) :” 改成普通的 “.section :”。这一改动就是去掉 READONLY 关键字，保持段内内容不变。
这样处理是因为当前使用的 GNU Arm Embedded 10.3 链接器不认识 READONLY，否则会在链接阶段报 .ARM.extab 相关的表达式错误。日后如果换成 GCC 11+，可以根据需要再加回该关键字。


# 1.配置环境
## 1.1 查看硬件
+ 判断你所使用的是什么芯片
f103 f407 h723

+ 判断你使用的硬件烧录器
jlink stlink daplink

请记住


## 1.2 配置vscode环境之配置c_cpp_properties.json
+ **ctrl+shift+P** 打开命令面板

+ 请输入**C/C++: Edit Configurations (UI)** ，进入你会看到你打开了C/C++配置

+ 编译器路径，选择对应编译器
这里我的默认配置是
/home/ice/gnu_toolchain/gcc-arm-none-eabi-10.3-2021.10/bin/arm-none-eabi-gcc
不使用g++是因为没有用cpp特性，所以这里选择gcc

+ Intellisense模式
这里我默认linux-gcc-arm
Linux: 指的是你当前运行 VS Code 的操作系统（从路径看你在 Linux 环境下）。
一般有linux、windows、macos

gcc: 指的是你使用的编译器种类。（arm-none-eabi-gcc）
一般有gcc、clang、msvc

arm: 指的是你的目标 CPU 架构（STM32 是 ARM Cortex-M 内核）。
一般有arm、arm64、x64、x86。arm是精简指令集（RISC）、x64是复杂指令集（CISC）

+ 定义，分析文件时 IntelliSense 引擎要使用的预处理器定义的列表
进入cmake/stm32cubemx/Cmakelists.txt中的
```
set(MX_Defines_Syms 
	USE_HAL_DRIVER 
	STM32F103xB
    $<$<CONFIG:Debug>:DEBUG>
)
//复制这两行，到"定义"下面,
	USE_HAL_DRIVER 
	STM32F103xB
```

## 1.3 配置vscode环境之配置launch.json
**简单介绍：工程调试需要的文件，如果你不需要调试，可以不添加**

+ 点击左边菜单栏：“运行和调试”  或者直接“ctrl+shift+D”
相信你已经在左侧看到了**创建一个launch.json文件** 点击**cortex debug**（如果没有这个，下载插件）

再点击**openocd启动**（会有默认jlink启动，可以删去，也可以保留，无影响，这里我删去）
你将会看到以下信息，不是也没有关系，按照后面的改就行
```
{
    // 使用 IntelliSense 了解相关属性。 
    // 悬停以查看现有属性的描述。
    // 欲了解更多信息，请访问: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "cwd": "${workspaceRoot}",
            "executable": "./bin/executable.elf",
            "name": "Debug with OpenOCD",
            "request": "launch",
            "type": "cortex-debug",
            "servertype": "openocd",
            "configFiles": [],
            "searchDir": [],
            "runToEntryPoint": "main",
            "showDevDebugOutput": "none"
        }
    ]
}
```


请按照以下模板进行更改
```
{
    // 使用 IntelliSense 了解相关属性。 
    // 悬停以查看现有属性的描述。
    // 欲了解更多信息，请访问: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "cwd": "${workspaceRoot}",
            "executable": "build/Debug/test.elf",//修改 1
            "name": "Debug with OpenOCD",
            "request": "launch",
            "type": "cortex-debug",
            "servertype": "openocd",
            "gdbPath": "/home/ice/gnu_toolchain/gcc-arm-none-eabi-10.3-2021.10/bin/arm-none-eabi-gdb",//添加 2
            "armToolchainPath": "/home/ice/gnu_toolchain/gcc-arm-none-eabi-10.3-2021.10/bin",//添加 3
            "configFiles": [
                "interface/stlink.cfg",
                "target/stm32f1x.cfg"//添加 4
            ],
            "searchDir": [
                "/usr/share/openocd/scripts"//添加 5
            ],
            "runToEntryPoint": "main",
            "showDevDebugOutput": "none",
            "svdPath": "STM32F103.svd",//添加 6
            "liveWatch": {
                "enabled": true,
                "samplesPerSecond": 4
            } //添加 7

        }
    ]
}
```
---

1. 这个目的是找到调试文件，根据你的调试文件路径进行修改，最后的xxx.elf,请查看根目录下的CMakelists.txt 
找到
```
# Set the project name
set(CMAKE_PROJECT_NAME linux_freertos_demo_103)


//linux_freertos_demo_103就是文件名字，即应该填写linux_freertos_demo_103.elf
```
2. gdb_path 是指你启动调试的软件程序在哪，在终端输入“which arm-none-eabi-gdb",然后填写

3. armtoolchain 指你的交叉编译链在哪里（我不清楚为什么要填写这个，我感觉不用，但最好填写吧）
在终端输入"which arm-none-eabi-gcc",只输入到bin文件，因为到bin文件夹就可以索引到gcc了，可能还要g++，所以不要填死

4. 按照规范填写，这个简单讲述一下，就是gdb和硬件调试器之间的一个中间转译软件工具叫openocd
interface/"你的调试器".cfg
target/"你要烧录进的单片机型号".cfg

5. 在终端输入 "which openocd"，并且加scripts

6. 找到你的单片机对应的svd文件，放入根目录，然后直接填写名称就行

7. 是否实时观测，按照模板填写即可


# 编译与链接
终端依次输入命令
```
cmake --preset=Debug//配置

cmake --build build/Debug//编译与链接

```
或者直接使用./run.sh或 sh run.sh
如果交叉编译器是gcc11以前的，比如我的gcc10,则编译会报错

如果想创建新的文件夹，运行create_dir.sh即可

# 烧录
```
1.openocd -f <接口配置文件> -f <目标芯片配置文件> -c "program <十六进制或二进制文件路径> verify reset exit"

2.如果想用run.sh跑的话，一定要修改flash.cfg文件
```
