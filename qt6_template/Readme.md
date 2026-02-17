# 简单介绍和直接使用例程
本文档介绍的是如何在linux环境下，使用vscode和cmake配置Qt环境

使用方法：
ctrl + shift + p //打开命令面板

CMake: Delete Cache and Reconfigure //配置kit

按左下角的齿轮 //生成

按左下角的三角形 //运行

# 配置

## 所要下载
默认你已经配置好了linux环境，

+ 下载vscode
```
sudo apt update //更新

sudo apt install code
```

+ 下载cmake等
```
sudo apt update
# 安装基础构建工具（编译器、调试器、CMake）
sudo apt install build-essential gdb cmake

# 安装 Qt 6 核心开发包和工具
# qt6-base-dev 包含核心库，qt6-base-dev-tools 包含 rcc/uic/moc 等工具
sudo apt install qt6-base-dev qt6-base-dev-tools libgl1-mesa-dev

# 如果你未来想做带动画效果的界面（嵌入式常用），建议也安装 QML 相关包
sudo apt install qt6-declarative-dev
```

+ 下载vscode插件
```
C/C++ Extension Pack

CMake Tools

Qt C++ Extension Pack//下一个这个就行，它会把依赖的插件都下好
```


+ 配置文件
```
写一个CMakeLists.txt和一个main.cpp文件，具体自己ai
```


+ 配置kit
```
ctrl + shift + p //打开命令面板

//目的是配置kit，也就是配置你的编译器，可以有多种方法


1.（可选）CMake: Delete Cache and Reconfigure

//如果你是第一次，点击自己的编译器，我是linux x86_64 ，这是直接在linux上开发
//如果你是在嵌入式设备上开发，那么选择交叉编译器
//如果你不是第一次配置，那么会自动配置好


或者你可以使用
2.(可选)scan for kits （扫描kits）
select a kit (挑选一个kit)
//同上面的注释 
```

+ 最终生成
```
f5 或者按左下角的齿轮(生成所选择目标)

ctrl + f5 或者按左下角的三角形(运行)
```

# 从零创建一个工程

默认配置完成

1. 创建一个文件夹
2. 用vscode打开，并且创建一个CMakeLists.txt和一个main.cpp
3. 打开命令面板 CMake: Delete Cache and Reconfigure
4. 生成 + 运行