# 交叉编译器
但在嵌入式开发中，你的代码是在 PC (Host) 上编写的，但程序最终要运行在 STM32 或 ESP32 (Target) 芯片上。由于 PC 和单片机的指令集完全不同，你需要一个能“跨越架构”产生代码的工具。

于是

定义： 在 A 架构上运行，却能生成可在 B 架构上执行的二进制文件的编译器，就叫交叉编译器。

一般我们认为是交叉编译器的有：
arm-none-eabi-gcc :开源界的标准ARM交叉编译器
armclang：arm官方提供的，基于llvm的交叉；编译器
xtensa-esp32-elf-gcc： 专门用于 ESP32 的交叉编译器

# 理解
stm32cubemx：生成初始化代码+启动文件+链接脚本

vscode ：只是编译器 + 界面

CMake ：构建调度器，它只负责找到编译器，传参数，调用编译器去编译、找到链接文件，链接文件，最后模块化生成一个build文件夹，最终的烧录文件放在里面
这里面有个门道，就是Cmake调用编译器，编译器自动会识别链接脚本，只不过对于不同的编译器，它们识别的链接脚本的形式会不一样
gcc： ld .ld
armclang：armlink .sct
iccarm：ilinkarm



编译器 ： 编译

所以无论是arm-none-eabi-gcc还是armclang，都可以使用