#!/bin/bash

# 定义要创建的模块名称（使用 POSIX 兼容的空格分隔列表，避免在 /bin/sh 下报错）
MODULES="Device Driver Interaction"

# 1. 创建 User 目录
if [ ! -d "User" ]; then
    mkdir User
    echo "Created Directory: User"
else
    echo "Directory User already exists."
fi

# 2. 创建 User/CMakeLists.txt (中间层)
# 这个文件负责包含下级子目录
cat > User/CMakeLists.txt << EOF
# User 层级 CMakeLists - 负责分发子模块
add_subdirectory(Device)
add_subdirectory(Driver)
add_subdirectory(Interaction)
EOF
echo "Created: User/CMakeLists.txt"

# 3. 循环创建子模块 (Device, Driver, Interaction)
for mod in $MODULES; do
    # 创建目录结构
    mkdir -p "User/$mod/Inc"
    mkdir -p "User/$mod/Src"
    
    # 创建空的占位文件（可选，防止Git忽略空文件夹）
    touch "User/$mod/Src/.gitkeep"
    touch "User/$mod/Inc/.gitkeep"

    # 4. 创建子模块的 CMakeLists.txt
    # 注意：这里使用 'EOF' 防止 shell 解析 CMake 的变量
    cat > "User/$mod/CMakeLists.txt" << 'EOF'
# 自动搜索当前 Src 目录下的所有 .c 文件
file(GLOB_RECURSE SOURCES "Src/*.c")

# 将源文件添加到主工程目标中
# 注意：CMAKE_PROJECT_NAME 是你在根目录定义的项目名
target_sources(${CMAKE_PROJECT_NAME} PRIVATE 
    ${SOURCES}
)

# 将当前 Inc 目录添加到头文件搜索路径
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE 
    Inc
)
EOF

    echo "Created Module: User/$mod (Inc, Src, CMakeLists.txt)"
done

echo "------------------------------------------------"
echo "✅ 目录结构创建完成！"
echo "⚠️  请记得修改根目录的 CMakeLists.txt，取消注释: add_subdirectory(User)"




# 只需要修改User和MODULES变量即可，其他部分会自动生成对应的目录和CMakeLists.txt文件。
# 根目录的CMakeLists.txt需要手动修改，add_subdirectory(User)以包含User层级的模块。
# .vscode

