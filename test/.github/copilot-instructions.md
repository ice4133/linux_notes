# Copilot 指令 — `test` 仓库（STM32）

下面为 AI 编码助手在此仓库中立即可用、可执行的要点。目标是让模型快速理解工程结构、常用工作流、命名约定与关键文件位置。

## 项目概览（大局）
- **类型**：STM32CubeMX 生成的 STM32F1 HAL C 项目，使用 CMake 构建（工具链为 arm-none-eabi）。
- **代码生成与手写代码分离**：自动生成的代码位于 `Core/` 和 `Drivers/` 下，用户修改应遵循 `/* USER CODE BEGIN */` / `/* USER CODE END */` 标记。
- **构建产物**：可执行文件为 `build/Debug/<project>.elf`（project 名在 `CMakeLists.txt` 中定义为 `test`）。

## 主要目录与文件（必须知道的位置）
- 构建与预设：`CMakePresets.json`, `CMakeLists.txt`, `cmake/stm32cubemx/`
- 运行脚本：`run.sh`（自动化 cmake 构建、objcopy、以及用 `openocd` 烧录）
- 烧录配置：`flash.cfg`（使用 ST-Link，执行 `program build/Debug/test.elf verify reset exit`）
- 应用入口与外设：`Core/Src/main.c`, `Core/Inc/*`（HAL 配置和外设 init）
- HAL 驱动：`Drivers/STM32F1xx_HAL_Driver/`（库实现）

## 构建 / 调试 / 烧录 工作流（明确命令）
- 首次或修改 CMake 相关文件后（慢）：
  - `cmake --preset=Debug`
- 日常仅改 .c 文件时（快速增量编译）：
  - `cmake --build build/Debug`
- 生成二进制并烧录：仓库提供 `run.sh`，等价步骤：
  - `cmake --build build/Debug`
  - `arm-none-eabi-objcopy -O binary build/Debug/test.elf build/Debug/test.bin`
  - `arm-none-eabi-objcopy -O ihex build/Debug/test.elf build/Debug/test.hex`
  - `openocd -f flash.cfg`
- 注意：只有当修改了 `CMakeLists.txt`、`CMakePresets.json` 或 `cmake/` 下的工具链文件时，才需要重新运行 `cmake --preset=Debug`。

## 代码与惯例（项目特有）
- 使用 STM32CubeMX 标准的 `USER CODE BEGIN/END` 区块保护手工修改，勿在生成代码段外大量修改以免被工具覆盖。
- 编译选项、宏定义与 include 路径多数通过 `cmake/stm32cubemx` 子目录生成的 CMake 文件管理，修改时应优先编辑生成脚本或重新配置 CubeMX。
- 可执行目标名称由 `CMakeLists.txt` 中 `set(CMAKE_PROJECT_NAME test)` 决定；因此脚本和 `flash.cfg` 中硬编码了 `test.elf`，若更名需同步修改 `run.sh` 与 `flash.cfg`。

## 常见编辑点与示例
- 修改主循环或外设：编辑 `Core/Src/main.c`（在 `USER CODE` 区块内改动）。
- 添加/移除源文件：修改 `cmake/stm32cubemx` 生成的目标源列表或通过 STM32CubeMX 再生成。
- 调试/断点：通过 OpenOCD + GDB（使用 `build/Debug/test.elf`）或 VSCode `.vscode/` 配置（仓库中可能包含）。

## 外部依赖与工具链
- 需要 `arm-none-eabi-*` 工具链（gcc, objcopy 等）以及 `openocd`。
- `flash.cfg` 依赖 OpenOCD 的 `interface/stlink.cfg` 和 `target/stm32f1x.cfg`（OpenOCD 自带或通过包管理安装）。

## 编辑与提交注意事项
- 保持对生成代码的最小改动；更改 HAL/库实现优先在 `Drivers/` 或 `Core/` 的 `USER CODE` 区块内。
- 更改构建目标名后记得同步更新 `run.sh`、`flash.cfg` 和任何脚本中对 `build/Debug/<name>.elf` 的引用。

## 例子片段（可直接使用）
- 构建（完整一轮）：
  - `cmake --preset=Debug && cmake --build build/Debug`
- 一键脚本：仓库根的 `run.sh` 已封装常见流程（支持 `--rebuild` 参数以强制重新配置）。

---
如果你希望我把这些内容合并或精简为英文版本，或者在文件中加入 CI（GitHub Actions）示例，请告诉我想要的格式或添加哪些自动化步骤。
