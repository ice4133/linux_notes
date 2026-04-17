对于vscode中，如果直接编写linux驱动代码的话，它是一定会报错的

因为没有头文件让它索引，于是就必须自己在vscode中配置一下头文件路径

我自己只填写/home/ice/linux/origin_code/linux/linux-5.4.31/include/**       （原本都是还是～代替/home/ice/，但是好像不会解析这个符号）

但是linux内核源码不是普通的c语言代码，头文件分布在多个及其深的目录中，仅靠一个include/**是不够的，因为有些关键头文件是动态生成的，必须要把生成的头文件路径也添加到vscode中，否则就会报错

所以
          "includePath": [
                "${workspaceFolder}/**",
                "/home/ice/linux_boot_code/origin_code/linux/linux-5.4.31/include",
                "/home/ice/linux_boot_code/origin_code/linux/linux-5.4.31/arch/arm/include",
                "/home/ice/linux_boot_code/origin_code/linux/linux-5.4.31/arch/arm/include/generated",
                "/home/ice/linux_boot_code/origin_code/linux/linux-5.4.31/include/linux"
            ],
如果这里还有报错，那么继续添加就行
应该这么写


如果代码没有证明自己是内核源码，很多定义不会开启
于是
"defines": [
    "__KERNEL__",
    "MODULE"
],
//在内核源码中，很多函数和宏被包裹在 #ifdef __KERNEL__ 或 #ifdef MODULE 块中。如果你不定义这两个宏，IntelliSense 就会跳过这些代码块，导致“找不到定义”。

添加一下这个

