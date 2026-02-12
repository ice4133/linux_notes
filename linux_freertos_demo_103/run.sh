#!/bin/bash
# 获取当前脚本所在目录
SCRIPT_DIR=$(dirname "$(realpath "$0")")
# 从当前目录开始，向上查找直到找到 CMakeLists.txt 文件，确定项目根目录
PROJECT_DIR=$SCRIPT_DIR
while [ ! -f "$PROJECT_DIR/CMakeLists.txt" ]; do
PROJECT_DIR=$(dirname "$PROJECT_DIR")
done
# 获取项目根目录名
PROJECT_NAME=$(basename "$PROJECT_DIR")
echo "Project root directory name: $PROJECT_NAME"


# 创建
BUILD_DIR="$PROJECT_DIR/build/Debug"

# 检查是否有命令行参数
REBUILD=false
if [ "$1" == "--rebuild" ] || [ "$1" == "--clean" ]; then
    REBUILD=true
    echo "将重新执行 CMake 配置..."
fi

# 只在构建目录不存在或指定了 --rebuild 参数时，才执行 CMake 配置
if [ ! -d "$BUILD_DIR" ] || [ "$REBUILD" = true ]; then
    echo "执行 CMake 配置..."
    cmake --preset=Debug
else
    echo "构建目录已存在，跳过 CMake 配置。使用 --rebuild 参数强制重新配置。"
fi

# 运行编译
cmake --build build/Debug





# 根据项目名称生成 ELF，BIN 和 HEX 文件路径
ELF_FILE="$BUILD_DIR/${PROJECT_NAME}.elf"
BIN_FILE="$BUILD_DIR/${PROJECT_NAME}.bin"
HEX_FILE="$BUILD_DIR/${PROJECT_NAME}.hex"

# 检查 ELF 文件是否 成功 生成
if [ -f "$ELF_FILE" ]; then
# 将 ELF 文件转换为 BIN 文件和 HEX 文件
arm-none-eabi-objcopy -O binary "$ELF_FILE" "$BIN_FILE"
arm-none-eabi-objcopy -O ihex "$ELF_FILE" "$HEX_FILE"
echo "Conversion to BIN and HEX completed"
else
echo "Error: ELF file not found. Compilation might have failed."
exit 1
fi

if [[ $1 == --flash ]]
then 
    openocd -f "$PROJECT_DIR/flash.cfg"
else
    echo "编译完成，但未执行烧录。使用 --flash 参数来执行烧录。"
fi
# 执行 OpenOCD 进行烧录
