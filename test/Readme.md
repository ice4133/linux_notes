# 1. 首次克隆项目或修改CMake配置后
cmake --preset=Debug         # 配置阶段（较慢）

修改了 CMakeLists.txt

添加/删除源文件
改变编译选项或链接库
修改构建目标等
修改了 CMakePresets.json

改变预设配置参数
修改了工具链 (cmake/ 目录下的文件)

编译器设置、编译标志等
切换了编译配置

从Debug改成Release等

只有改了cmake相关配置，才需要重新配置


# 2. 日常开发中（只修改了.c文件）
cmake --build build/Debug    # 构建阶段（快速，增量编译）


仅仅修改源代码肯定是不需要重新配置的

# 3. 烧录
openocd -f flash.cfg



# 4.环境配置总览
首先拷贝flash.cfg和run.sh和.vscode文件夹进入刚创建的工程

.c_cpp_properties.json
defines中的其实是宏，可以在cmake下的stm32cubemx的cmakelists中找到

