# Ubuntu 将 Codex CLI 接入飞书：从零配置完整教程

> 适用场景：在一台全新的 Ubuntu 电脑上，把飞书消息转交给本机的 Codex CLI，让 Codex 在指定项目目录中读取代码、分析问题、执行命令或修改文件，并把结果回复到飞书。
>
> 最后核对：2026-07-27  
> 适用系统：Ubuntu 22.04、Ubuntu 24.04 及相近版本

---

## 目录

- [1. 最终要实现什么](#1-最终要实现什么)
- [2. 整体工作原理](#2-整体工作原理)
- [3. 配置前的重要说明](#3-配置前的重要说明)
- [4. 安装 Ubuntu 基础工具](#4-安装-ubuntu-基础工具)
- [5. 使用 nvm 安装 Node.js](#5-使用-nvm-安装-nodejs)
- [6. 安装并登录 Codex CLI](#6-安装并登录-codex-cli)
- [7. 单独测试 Codex CLI](#7-单独测试-codex-cli)
- [8. 安装飞书 Bridge](#8-安装飞书-bridge)
- [9. 准备 Codex 工作目录](#9-准备-codex-工作目录)
- [10. 首次启动并扫码绑定飞书](#10-首次启动并扫码绑定飞书)
- [11. 在飞书中测试完整链路](#11-在飞书中测试完整链路)
- [12. 切换到真实项目](#12-切换到真实项目)
- [13. 飞书内常用命令](#13-飞书内常用命令)
- [14. 权限与安全设置](#14-权限与安全设置)
- [15. 前台运行与后台运行](#15-前台运行与后台运行)
- [16. 制作一键启动脚本](#16-制作一键启动脚本)
- [17. Clash、VPN 与终端代理](#17-clashvpn-与终端代理)
- [18. 常见故障排查](#18-常见故障排查)
- [19. 配置文件和日志位置](#19-配置文件和日志位置)
- [20. 更新、迁移和彻底卸载](#20-更新迁移和彻底卸载)
- [21. 最短操作清单](#21-最短操作清单)
- [22. 参考资料](#22-参考资料)

---

# 1. 最终要实现什么

配置完成后，消息链路如下：

```text
手机或电脑上的飞书
        │
        │ 发送消息
        ▼
飞书 PersonalAgent 机器人
        │
        │ 飞书消息通道
        ▼
Ubuntu 上运行的 lark-channel-bridge
        │
        │ 调用本机 codex 命令
        ▼
Codex CLI
        │
        │ 读取、分析或修改指定项目
        ▼
Ubuntu 本地项目目录
        │
        └────────── 将结果返回飞书
```

例如，你在飞书中对机器人发送：

```text
分析一下当前项目的目录结构，不要修改任何文件。
```

Bridge 会在 Ubuntu 上调用本机的 Codex CLI。Codex 会进入指定工作目录，读取项目并生成结果，然后 Bridge 把回复发回飞书。

这里接入的是：

```text
飞书 → Codex CLI
```

不是：

```text
飞书 → VS Code 中的 Codex 插件
```

VS Code 可以同时打开这个项目，但 Bridge 真正调用的是终端里的 `codex` 命令。即使没有安装 VS Code Codex 插件，只要 Codex CLI 正常，飞书接入仍然能够工作。

---

# 2. 整体工作原理

整个方案包含四个部分。

## 2.1 飞书 PersonalAgent

它是你最终在飞书中看到并聊天的机器人。

第一次运行 Bridge 时，终端会显示二维码。你用飞书扫码后，可以创建或绑定一个 PersonalAgent 应用。

## 2.2 lark-channel-bridge

`lark-channel-bridge` 是一个第三方开源项目，不是 OpenAI 官方产品，也不是飞书官方的 Codex 功能。

它主要负责：

1. 接收飞书消息；
2. 管理不同聊天对应的会话；
3. 调用本机的 Codex CLI；
4. 把 Codex 的输出返回飞书；
5. 管理工作目录、日志、权限和后台服务。

## 2.3 Codex CLI

`codex` 是 OpenAI 的本地命令行编程 Agent。

它在 Ubuntu 本机运行，因此可以在权限允许的范围内：

- 读取项目代码；
- 搜索文件；
- 分析目录结构；
- 执行终端命令；
- 修改代码；
- 运行编译或测试；
- 查看 Git 状态和差异。

## 2.4 工作目录

工作目录是 Codex 默认处理的项目目录，例如：

```text
/home/xu/IsaacLab
```

更推荐写成：

```text
$HOME/IsaacLab
```

这样不需要硬编码 Ubuntu 用户名。

---

# 3. 配置前的重要说明

## 3.1 本教程按全新 Ubuntu 编写

即使电脑上已经装过部分工具，也可以依次执行检查命令。已经正确安装的部分不需要重复破坏性安装。

## 3.2 推荐使用 nvm 管理 Node.js

Bridge 目前要求：

```text
Node.js >= 20.12.0
```

Ubuntu 软件源中的 Node.js 版本不一定满足要求，因此推荐使用 `nvm`。

使用 `nvm` 的优点：

- Node.js 安装在当前用户目录；
- 不需要使用 `sudo npm install -g`；
- 可以方便切换 Node.js 版本；
- 不会污染 Ubuntu 系统自带的软件包环境。

## 3.3 不要随便把根目录设为工作区

不要把以下目录直接设为 Codex 工作区：

```text
/
```

```text
/home/你的用户名
```

```text
/etc
```

```text
/usr
```

工作区应该是具体项目目录，例如：

```text
/home/xu/projects/robot-control
```

## 3.4 工作目录不等于安全沙箱

`--workspace` 只是指定 Codex 启动时的当前目录，不代表 Codex 一定无法访问目录外的文件。

Codex 实际能访问什么，还取决于 Bridge 和 Codex 的权限模式。因此后面必须认真阅读“权限与安全设置”章节。

---

# 4. 安装 Ubuntu 基础工具

打开终端，执行：

```bash
sudo apt update
sudo apt install -y curl git ca-certificates build-essential
```

这些工具的作用：

| 工具 | 作用 |
|---|---|
| `curl` | 下载安装脚本、测试网络 |
| `git` | 管理项目和创建测试仓库 |
| `ca-certificates` | 提供 HTTPS 证书 |
| `build-essential` | 提供 GCC、G++、make 等基础编译工具 |

查看系统版本：

```bash
cat /etc/os-release
```

查看 CPU 架构：

```bash
uname -m
```

常见结果：

```text
x86_64
```

表示普通 Intel/AMD 64 位电脑。

```text
aarch64
```

表示 ARM 64 位设备。

---

# 5. 使用 nvm 安装 Node.js

## 5.1 安装 nvm

执行：

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash
```

安装脚本通常会自动修改：

```text
~/.bashrc
```

让新终端能够找到 `nvm`。

加载配置：

```bash
source ~/.bashrc
```

检查：

```bash
command -v nvm
```

正常应该输出：

```text
nvm
```

注意：`nvm` 是 Shell 函数，不一定能通过 `which nvm` 正确检查。因此推荐使用：

```bash
command -v nvm
```

## 5.2 如果提示 nvm: command not found

先执行：

```bash
source ~/.bashrc
```

再检查：

```bash
command -v nvm
```

如果仍然没有输出，关闭当前终端，重新打开一个终端，再检查。

还可以查看 `.bashrc` 中是否已经写入 nvm 配置：

```bash
grep -n "NVM_DIR" ~/.bashrc
```

一般会包含类似内容：

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
```

## 5.3 安装 Node.js 22

执行：

```bash
nvm install 22
nvm use 22
nvm alias default 22
```

说明：

```bash
nvm install 22
```

安装 Node.js 22 的最新可用版本。

```bash
nvm use 22
```

让当前终端使用 Node.js 22。

```bash
nvm alias default 22
```

让以后新打开的终端默认使用 Node.js 22。

检查：

```bash
node -v
npm -v
```

只要 Node.js 版本不低于：

```text
v20.12.0
```

就满足 Bridge 的要求。

再检查 Node.js 来自哪里：

```bash
command -v node
```

使用 nvm 时，路径通常类似：

```text
/home/你的用户名/.nvm/versions/node/v22.x.x/bin/node
```

---

# 6. 安装并登录 Codex CLI

## 6.1 安装 Codex CLI

OpenAI 当前为 macOS 和 Linux 提供独立安装脚本：

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

安装完成后，重新加载 Shell：

```bash
source ~/.bashrc
```

检查：

```bash
command -v codex
codex --version
```

`command -v codex` 应该返回一个实际路径。

## 6.2 如果安装后找不到 codex

先关闭当前终端，重新打开，再执行：

```bash
codex --version
```

还可以检查常见安装目录：

```bash
find "$HOME" -maxdepth 4 -type f -name codex 2>/dev/null
```

如果安装程序提示需要向 `PATH` 添加目录，请按照终端提示把对应路径写入 `~/.bashrc`。

## 6.3 登录 Codex

进入一个项目目录后运行：

```bash
codex
```

第一次启动时，按照终端界面选择：

```text
Sign in with ChatGPT
```

然后在浏览器中完成登录。

也可以查看当前认证状态：

```bash
codex login status
```

正常情况下可能显示：

```text
Logged in using ChatGPT
```

## 6.4 登录与网络的关系

Codex CLI 是在本机运行，但需要访问 OpenAI 服务。

因此：

- 本地项目文件不需要上传到飞书才能读取；
- Codex 的模型请求仍然需要联网；
- 如果所在网络无法直接访问相关服务，终端可能需要正确配置代理；
- 浏览器能打开 ChatGPT，不代表终端一定能正常访问，因为浏览器和终端的代理设置可能不同。

---

# 7. 单独测试 Codex CLI

不要一开始就排查飞书。必须先确保 Codex CLI 本身能够正常运行。

创建测试目录：

```bash
mkdir -p "$HOME/projects/codex-feishu-test"
cd "$HOME/projects/codex-feishu-test"
git init
```

创建一个简单文件：

```bash
cat > hello.py <<'PY'
print("Hello from Ubuntu")
PY
```

启动 Codex：

```bash
codex
```

进入 Codex 后发送：

```text
请告诉我当前工作目录，并解释 hello.py 的作用。不要修改文件。
```

如果 Codex 能正常回答，说明以下部分基本正常：

- Codex 已安装；
- Codex 已登录；
- 终端网络正常；
- Codex 能访问当前目录；
- 本地 CLI 可以被 Bridge 调用。

退出 Codex 可以按：

```text
Ctrl + C
```

或使用 Codex 界面中提供的退出方式。

---

# 8. 安装飞书 Bridge

## 8.1 全局安装

执行：

```bash
npm install -g lark-channel-bridge
```

不要写成：

```bash
sudo npm install -g lark-channel-bridge
```

因为本教程使用的是 nvm，当前用户已经有权限写入 npm 的全局安装目录。

## 8.2 检查安装结果

执行：

```bash
command -v lark-channel-bridge
lark-channel-bridge --help
```

正常路径通常类似：

```text
/home/你的用户名/.nvm/versions/node/v22.x.x/bin/lark-channel-bridge
```

查看版本：

```bash
npm list -g --depth=0 | grep lark-channel-bridge
```

## 8.3 npm 下载很慢时

先确认是否是网络或代理问题：

```bash
npm ping
```

查看 npm 当前仓库：

```bash
npm config get registry
```

官方仓库通常是：

```text
https://registry.npmjs.org/
```

临时使用其他 npm 镜像时，应理解它只影响 npm 包下载，不会替代 Codex 访问 OpenAI 的网络。

---

# 9. 准备 Codex 工作目录

## 9.1 查看当前 Ubuntu 用户

执行：

```bash
whoami
echo "$HOME"
```

例如：

```text
xu
/home/xu
```

不要照抄其他电脑上的：

```text
/home/mentor/...
```

新电脑的用户名和目录可能完全不同。

## 9.2 使用测试目录

本教程首次配置使用：

```text
$HOME/projects/codex-feishu-test
```

确认目录存在：

```bash
test -d "$HOME/projects/codex-feishu-test" \
  && echo "目录存在" \
  || echo "目录不存在"
```

## 9.3 查看绝对路径

执行：

```bash
cd "$HOME/projects/codex-feishu-test"
pwd
```

假设输出：

```text
/home/xu/projects/codex-feishu-test
```

这就是 Bridge 可以使用的工作目录。

---

# 10. 首次启动并扫码绑定飞书

## 10.1 推荐的首次启动命令

执行：

```bash
lark-channel-bridge run \
  --profile codex \
  --agent codex \
  --workspace "$HOME/projects/codex-feishu-test"
```

各参数含义如下。

### `run`

```text
在当前终端前台运行 Bridge
```

特点：

- 日志直接显示在当前终端；
- 适合首次配置和排错；
- 按 `Ctrl + C` 就会停止；
- 关闭终端后 Bridge 也会停止。

### `--profile codex`

创建或使用名为：

```text
codex
```

的 Profile。

Profile 会保存：

- 飞书应用信息；
- 使用的 Agent 类型；
- 会话记录；
- 工作目录；
- 日志；
- 权限设置。

### `--agent codex`

明确告诉 Bridge：

```text
后端 Agent 使用 Codex CLI
```

Bridge 也支持其他 Agent，因此第一次配置时建议显式写出 `--agent codex`。

### `--workspace`

指定初始工作目录：

```bash
--workspace "$HOME/projects/codex-feishu-test"
```

## 10.2 扫码流程

第一次运行后，终端会进入扫码向导，大致流程为：

1. 终端显示二维码；
2. 使用手机飞书 App 扫描二维码；
3. 根据页面提示授权；
4. 选择已有 PersonalAgent，或创建新的 PersonalAgent；
5. 如果终端询问 Agent 类型，选择 Codex；
6. 等待终端显示配置成功；
7. Bridge 开始监听飞书消息。

初始化成功后，主要配置会写入：

```text
~/.lark-channel/config.json
```

## 10.3 如果已经有 PersonalAgent App ID

可以执行：

```bash
lark-channel-bridge run \
  --profile codex \
  --agent codex \
  --workspace "$HOME/projects/codex-feishu-test" \
  --app-id cli_xxx
```

终端会继续提示输入 App Secret。

不要把 App Secret 发到群聊、截图、GitHub 仓库或公开文档中。

## 10.4 国际版 Lark

如果使用的不是中国大陆飞书，而是国际版 Lark，可以增加：

```bash
--tenant lark
```

例如：

```bash
lark-channel-bridge run \
  --tenant lark \
  --profile codex \
  --agent codex \
  --workspace "$HOME/projects/codex-feishu-test"
```

---

# 11. 在飞书中测试完整链路

扫码绑定成功并保持 Bridge 终端运行。

## 11.1 找到机器人

在飞书中搜索刚刚创建或绑定的 PersonalAgent 名称，打开私聊。

## 11.2 先查看状态

发送：

```text
/status
```

重点检查：

- Profile 是否为 `codex`；
- Agent 是否为 `codex`；
- 工作目录是否正确；
- Bridge 是否正在运行；
- 会话是否正常。

## 11.3 发送只读测试

发送：

```text
告诉我当前工作目录，并列出当前目录中的文件。不要修改任何文件。
```

如果能收到回复，说明完整链路已经打通：

```text
飞书
  → PersonalAgent
  → lark-channel-bridge
  → Codex CLI
  → 本地项目
  → 飞书回复
```

## 11.4 私聊和群聊的区别

私聊机器人时，通常不需要 `@`。

群聊中默认需要：

```text
@机器人 你的问题
```

例如：

```text
@Codex机器人 分析一下这个项目的构建流程，不要修改代码。
```

---

# 12. 切换到真实项目

假设真实项目位于：

```text
$HOME/IsaacLab
```

先在 Ubuntu 终端确认：

```bash
ls -ld "$HOME/IsaacLab"
```

如果目录存在，在飞书中发送：

```text
/cd /home/你的用户名/IsaacLab
```

注意：飞书中的 `/cd` 最稳妥的是填写完整绝对路径。

例如：

```text
/cd /home/xu/IsaacLab
```

然后发送：

```text
/status
```

确认工作目录已经切换。

再发送：

```text
分析这个项目的目录结构、主要模块和启动入口，不要修改文件。
```

## 12.1 保存常用工作空间

当前目录正确后发送：

```text
/ws save isaaclab
```

以后可以使用：

```text
/ws use isaaclab
```

快速切换回来。

查看所有保存的工作空间：

```text
/ws list
```

删除某个工作空间：

```text
/ws remove isaaclab
```

---

# 13. 飞书内常用命令

| 命令 | 作用 |
|---|---|
| `/status` | 查看 Profile、Agent、目录、会话和运行状态 |
| `/new` | 清空当前会话并新建会话 |
| `/reset` | 与 `/new` 类似，重置当前会话 |
| `/cd <path>` | 切换工作目录并重置会话 |
| `/ws list` | 查看已保存工作空间 |
| `/ws save <name>` | 保存当前工作目录 |
| `/ws use <name>` | 切换到已保存工作空间 |
| `/ws remove <name>` | 删除已保存工作空间 |
| `/resume` | 恢复兼容的历史会话 |
| `/stop` | 停止当前正在执行的任务 |
| `/timeout 10` | 为当前会话设置 10 分钟空闲超时 |
| `/timeout off` | 关闭当前会话空闲探活 |
| `/config` | 调整显示、访问控制等设置 |
| `/reconnect` | 强制重新连接飞书 WebSocket |
| `/doctor` | 执行诊断 |
| `/ps` | 查看本机 Bridge 进程 |
| `/help` | 显示帮助 |

## 13.1 什么时候使用 `/new`

出现以下情况时可以发送：

```text
/new
```

- 之前的对话上下文干扰当前问题；
- 刚刚切换了项目；
- Codex 一直误解当前任务；
- 会话状态异常；
- `/status` 显示的会话不符合预期。

## 13.2 什么时候使用 `/stop`

当 Codex 正在执行不需要的长任务时，发送：

```text
/stop
```

它会尝试停止当前运行。

---

# 14. 权限与安全设置

这是整套配置中最重要的部分之一。

## 14.1 Bridge 的三种主要权限

| Bridge 权限 | Codex 对应模式 | 含义 |
|---|---|---|
| `full` | `danger-full-access` | 权限最大，风险也最大 |
| `workspace` | `workspace-write` | 主要允许在工作区读写 |
| `read-only` | `read-only` | 只读，适合分析和检查 |

Bridge 新建 Profile 时可能默认使用：

```text
full
```

这意味着 Codex 可能在当前 Linux 用户权限范围内执行命令和访问文件，而不只是当前工作区。

## 14.2 推荐策略

刚开始测试时，优先使用：

```text
read-only
```

确认能够正常读取项目后，再根据需要改成：

```text
workspace
```

只有明确理解风险时，才使用：

```text
full
```

## 14.3 通过飞书调整

在机器人私聊中发送：

```text
/config
```

根据交互卡片调整权限、显示方式和访问控制。

不同版本的界面文字可能略有不同，应重点关注：

```text
defaultAccess
maxAccess
```

建议：

```text
defaultAccess = workspace
maxAccess = workspace
```

如果只需要远程阅读和分析：

```text
defaultAccess = read-only
maxAccess = read-only
```

## 14.4 直接修改配置前先备份

配置文件位于：

```text
~/.lark-channel/config.json
```

修改前备份：

```bash
cp "$HOME/.lark-channel/config.json" \
   "$HOME/.lark-channel/config.json.backup"
```

权限字段结构大致类似：

```json
{
  "permissions": {
    "defaultAccess": "workspace",
    "maxAccess": "workspace"
  }
}
```

不要用这段内容覆盖整个 `config.json`，它只是配置中的局部字段。

## 14.5 访问控制

默认情况下，通常只有创建这个应用的人可以使用机器人。

让某个用户能够私聊机器人：

```text
/invite user @某人
```

让某个用户成为管理员：

```text
/invite admin @某人
```

允许当前群中的成员使用：

```text
/invite group
```

不要在不了解影响时随便执行：

```text
/invite all group
```

它可能把机器人所在的多个群都加入允许列表。

## 14.6 不要把敏感目录设为工作区

避免把以下内容所在目录设为工作区：

- SSH 私钥；
- API Key；
- 密码文件；
- 浏览器用户数据；
- 公司机密；
- 云服务凭据；
- 包含大量个人资料的 Home 根目录。

尤其注意：

```text
~/.ssh
~/.aws
~/.config
~/.codex
```

---

# 15. 前台运行与后台运行

## 15.1 前台运行

首次配置和排错使用：

```bash
lark-channel-bridge run \
  --profile codex \
  --agent codex \
  --workspace "$HOME/projects/codex-feishu-test"
```

停止：

```text
Ctrl + C
```

前台模式的优点：

- 错误直接显示；
- 容易确认是否收到消息；
- 容易确认 Codex 是否启动；
- 适合调试网络和权限。

## 15.2 后台运行

确认前台模式已经成功后，先按：

```text
Ctrl + C
```

停止前台进程。

然后启动后台服务：

```bash
lark-channel-bridge start --profile codex
```

查看状态：

```bash
lark-channel-bridge status --profile codex
```

重启：

```bash
lark-channel-bridge restart --profile codex
```

停止：

```bash
lark-channel-bridge stop --profile codex
```

取消注册后台服务：

```bash
lark-channel-bridge unregister --profile codex
```

Linux 上后台模式使用用户级 systemd 服务，服务名称类似：

```text
lark-channel-bridge.bot.codex.service
```

## 15.3 后台模式必须全局安装

后台服务应使用全局安装的 Bridge：

```bash
npm install -g lark-channel-bridge
```

不建议用临时的 `npx` 路径创建后台服务，因为 npm 临时缓存被清理后，后台服务可能找不到程序。

## 15.4 用户退出登录后是否继续运行

用户级 systemd 服务默认行为受系统设置影响。

查看服务：

```bash
systemctl --user status lark-channel-bridge.bot.codex.service
```

如果希望用户退出登录后服务仍可运行，可能需要：

```bash
sudo loginctl enable-linger "$USER"
```

这会改变用户级服务在注销后的运行行为。执行前应理解其影响。

---

# 16. 制作一键启动脚本

创建脚本目录：

```bash
mkdir -p "$HOME/bin"
```

创建脚本：

```bash
nano "$HOME/bin/start-feishu-codex.sh"
```

写入：

```bash
#!/usr/bin/env bash

set -euo pipefail

# 加载 nvm，让脚本能找到 node、npm 和 lark-channel-bridge。
export NVM_DIR="$HOME/.nvm"

if [ -s "$NVM_DIR/nvm.sh" ]; then
    source "$NVM_DIR/nvm.sh"
else
    echo "错误：没有找到 $NVM_DIR/nvm.sh"
    echo "请先安装 nvm。"
    exit 1
fi

# 第一个参数可指定工作目录。
# 未传参数时使用默认测试目录。
WORKSPACE="${1:-$HOME/projects/codex-feishu-test}"

if [ ! -d "$WORKSPACE" ]; then
    echo "错误：工作目录不存在：$WORKSPACE"
    exit 1
fi

if ! command -v node >/dev/null 2>&1; then
    echo "错误：没有找到 node 命令"
    exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
    echo "错误：没有找到 codex 命令"
    exit 1
fi

if ! command -v lark-channel-bridge >/dev/null 2>&1; then
    echo "错误：没有找到 lark-channel-bridge 命令"
    exit 1
fi

echo "Node.js：$(node -v)"
echo "Codex：$(codex --version)"
echo "工作目录：$WORKSPACE"
echo "正在启动飞书 Codex Bridge……"

exec lark-channel-bridge run \
    --profile codex \
    --agent codex \
    --workspace "$WORKSPACE"
```

保存：

```text
Ctrl + O
Enter
Ctrl + X
```

添加执行权限：

```bash
chmod +x "$HOME/bin/start-feishu-codex.sh"
```

启动默认测试项目：

```bash
"$HOME/bin/start-feishu-codex.sh"
```

启动真实项目：

```bash
"$HOME/bin/start-feishu-codex.sh" "$HOME/IsaacLab"
```

停止脚本：

```text
Ctrl + C
```

---

# 17. Clash、VPN 与终端代理

## 17.1 浏览器代理不等于终端代理

即使浏览器能打开 ChatGPT，终端中的：

```bash
codex
npm
curl
git
```

也不一定会自动使用浏览器代理。

先查看终端代理变量：

```bash
env | grep -i proxy
```

可能看到：

```text
HTTP_PROXY=http://127.0.0.1:7897
HTTPS_PROXY=http://127.0.0.1:7897
ALL_PROXY=socks5://127.0.0.1:7897
```

端口必须以你自己的 Clash Verge 配置为准，不要机械照抄 `7897`。

## 17.2 临时给当前终端设置代理

假设 Clash 混合端口为 `7897`：

```bash
export HTTP_PROXY="http://127.0.0.1:7897"
export HTTPS_PROXY="http://127.0.0.1:7897"
export http_proxy="$HTTP_PROXY"
export https_proxy="$HTTPS_PROXY"
```

如果确实需要 SOCKS 代理：

```bash
export ALL_PROXY="socks5://127.0.0.1:7897"
export all_proxy="$ALL_PROXY"
```

注意：具体程序是否优先使用 `ALL_PROXY`，取决于程序使用的网络库。

## 17.3 让飞书域名尝试直连

可以设置：

```bash
export NO_PROXY="localhost,127.0.0.1,::1,.feishu.cn,.larksuite.com"
export no_proxy="$NO_PROXY"
```

但必须理解：

- `NO_PROXY` 是否生效，取决于具体程序和网络库；
- 设置了变量不等于百分之百确认飞书没有走代理；
- Clash 的规则模式、TUN 模式和系统代理也会影响最终路径。

## 17.4 测试飞书直连

执行：

```bash
curl --noproxy '*' \
  -I \
  --connect-timeout 10 \
  https://open.feishu.cn
```

能返回 HTTP 响应头，说明至少当前网络可以直连该地址。

## 17.5 测试当前代理

执行：

```bash
curl -I --connect-timeout 15 https://chatgpt.com
```

查看当前公网出口：

```bash
curl -s https://api.ipify.org
echo
```

测试时不要只依赖 `ping`。很多网站会禁用 ICMP，因此：

```bash
ping github.com
```

失败并不能证明 HTTPS 一定失败。

## 17.6 永久写入 `.bashrc` 前要谨慎

把代理永久写入 `~/.bashrc` 会让以后打开的所有 Bash 终端自动带上代理。

这可能影响：

- `scp`；
- `ssh`；
- `git`；
- `apt`；
- 局域网设备连接；
- 机器人 MiniPC；
- 公司内网服务。

因此更推荐：

- 需要时临时 `export`；
- 或单独写一个代理启用脚本；
- 不需要时执行 `unset`。

关闭当前终端代理：

```bash
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
unset http_proxy https_proxy all_proxy
unset NO_PROXY no_proxy
```

---

# 18. 常见故障排查

排查时按照下面顺序，不要一开始就同时修改很多配置。

---

## 18.1 第一步：检查 Node.js

```bash
node -v
npm -v
command -v node
```

要求 Node.js 不低于：

```text
v20.12.0
```

如果打开新终端后 Node.js 消失：

```bash
source ~/.bashrc
nvm use 22
```

---

## 18.2 第二步：检查 Codex

```bash
command -v codex
codex --version
codex login status
```

然后进入测试目录单独运行：

```bash
cd "$HOME/projects/codex-feishu-test"
codex
```

如果 Codex 自己都不能正常回答，就先不要排查飞书。

---

## 18.3 第三步：检查 Bridge

```bash
command -v lark-channel-bridge
lark-channel-bridge --help
```

查看进程：

```bash
lark-channel-bridge ps
```

或：

```bash
pgrep -af lark-channel-bridge
```

---

## 18.4 第四步：检查工作目录

```bash
ls -ld "$HOME/projects/codex-feishu-test"
```

如果飞书中的会话指向了已经删除或移动的目录，机器人可能不回复。

在飞书发送：

```text
/status
```

然后重新设置目录：

```text
/cd /home/你的用户名/真实项目
```

再发送：

```text
/new
```

---

## 18.5 机器人完全不回复

依次检查：

1. Bridge 终端是否仍然运行；
2. 当前电脑是否休眠；
3. Codex 是否已经登录；
4. `/status` 是否能回复；
5. 当前工作目录是否存在；
6. 飞书机器人是否绑定的是这台新电脑对应的 Profile；
7. 是否有另一个 Bridge 实例占用了同一个 Profile 或应用；
8. 代理是否导致飞书 WebSocket 无法连接。

运行诊断：

```text
/doctor
```

强制重连：

```text
/reconnect
```

---

## 18.6 群聊中不回复

群聊默认通常需要：

```text
@机器人
```

如果群成员没有权限，管理员可在群里发送：

```text
/invite group
```

私聊和群聊权限是两套不同场景，不要因为私聊可用就认为所有群都已开放。

---

## 18.7 能收到消息，但 Codex 一直卡住

先在飞书中发送：

```text
/stop
```

然后：

```text
/new
```

再发送一个简单任务：

```text
只回复当前工作目录，不要执行其他操作。
```

可以设置当前会话空闲超时：

```text
/timeout 10
```

表示长时间没有输出时进行探活和终止处理。

---

## 18.8 `npm install -g` 权限错误

如果出现 `EACCES`，先检查：

```bash
command -v node
command -v npm
npm config get prefix
```

使用 nvm 时，Node.js 应位于：

```text
~/.nvm/versions/node/...
```

不要直接用 `sudo npm install -g` 掩盖问题。

可以重新加载：

```bash
source ~/.bashrc
nvm use 22
```

然后再安装：

```bash
npm install -g lark-channel-bridge
```

---

## 18.9 后台服务启动失败，但前台能运行

检查：

```bash
lark-channel-bridge status --profile codex
```

查看用户级服务：

```bash
systemctl --user status lark-channel-bridge.bot.codex.service
```

查看日志：

```bash
journalctl --user \
  -u lark-channel-bridge.bot.codex.service \
  -n 100 \
  --no-pager
```

常见原因：

- Bridge 不是全局安装；
- systemd 服务记录了已经失效的 Node.js 路径；
- 更新 nvm 的 Node.js 大版本后，全局 npm 包没有重新安装；
- 用户级 systemd 环境中没有正确的路径；
- Profile 已被另一个进程锁定。

可以尝试：

```bash
lark-channel-bridge unregister --profile codex
npm install -g lark-channel-bridge
lark-channel-bridge start --profile codex --agent codex
```

---

## 18.10 换了 Node.js 版本后 Bridge 消失

nvm 的每个 Node.js 版本拥有自己的全局 npm 包目录。

例如你原来在 Node.js 22 中安装了 Bridge，后来切换到 Node.js 24，可能需要重新执行：

```bash
npm install -g lark-channel-bridge
```

查看当前 Node：

```bash
nvm current
```

查看当前全局包：

```bash
npm list -g --depth=0
```

---

# 19. 配置文件和日志位置

Bridge 默认状态目录：

```text
~/.lark-channel
```

常用位置如下：

| 路径 | 内容 |
|---|---|
| `~/.lark-channel/config.json` | 根配置和 Profile 信息 |
| `~/.lark-channel/active-profile` | 当前激活的 Profile |
| `~/.lark-channel/profiles/codex/sessions.json` | 会话状态 |
| `~/.lark-channel/profiles/codex/workspaces.json` | 工作空间记录 |
| `~/.lark-channel/profiles/codex/secrets.enc` | 本地加密的敏感配置 |
| `~/.lark-channel/profiles/codex/media/` | 飞书附件缓存 |
| `~/.lark-channel/profiles/codex/logs/` | 结构化运行日志 |
| `~/.lark-channel/profiles/codex/logs/daemon/` | 后台服务日志 |
| `~/.lark-channel/registry/processes.json` | Bridge 进程注册信息 |

查看日志文件：

```bash
find "$HOME/.lark-channel/profiles/codex/logs" \
  -maxdepth 3 \
  -type f \
  -printf '%TY-%Tm-%Td %TH:%TM %p\n' \
  2>/dev/null \
  | sort
```

查看最近修改的日志：

```bash
find "$HOME/.lark-channel/profiles/codex/logs" \
  -type f \
  -printf '%T@ %p\n' \
  2>/dev/null \
  | sort -nr \
  | head
```

查看某个日志最后 100 行：

```bash
tail -n 100 /实际日志路径
```

实时查看：

```bash
tail -f /实际日志路径
```

---

# 20. 更新、迁移和彻底卸载

## 20.1 更新 Codex CLI

重新执行官方安装脚本：

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

然后检查：

```bash
codex --version
```

## 20.2 更新 Bridge

```bash
npm install -g lark-channel-bridge@latest
```

检查：

```bash
npm list -g --depth=0 | grep lark-channel-bridge
```

更新 Bridge 后，如果使用后台服务，建议：

```bash
lark-channel-bridge restart --profile codex
```

## 20.3 导出 Profile

默认脱敏导出：

```bash
lark-channel-bridge profile export codex \
  --output "$HOME/codex-profile.json" \
  --force
```

默认导出不应包含明文 App Secret。

包含敏感信息的导出命令风险很高：

```bash
lark-channel-bridge profile export codex \
  --include-secrets \
  --yes
```

包含敏感信息的文件不要上传到 GitHub、网盘公开链接或群聊。

## 20.4 在新电脑迁移时的建议

更安全的做法是：

1. 新电脑重新安装 Node.js、Codex 和 Bridge；
2. 新电脑重新登录 Codex；
3. 新电脑重新扫码绑定飞书；
4. 重新设置真实工作目录；
5. 不直接复制旧电脑的全部凭据文件。

如果明确需要迁移 Profile，先理解导出内容是否包含 Secret，并妥善保护文件。

## 20.5 删除某个 Profile

先停止后台服务：

```bash
lark-channel-bridge stop --profile codex 2>/dev/null || true
lark-channel-bridge unregister --profile codex 2>/dev/null || true
```

删除 Profile，但保留归档行为：

```bash
lark-channel-bridge profile remove codex
```

彻底删除：

```bash
lark-channel-bridge profile remove codex --purge --yes
```

## 20.6 卸载 Bridge

```bash
npm uninstall -g lark-channel-bridge
```

## 20.7 删除全部 Bridge 配置

警告：下面命令会删除所有 Profile、会话、应用配置和本地记录。

```bash
rm -rf "$HOME/.lark-channel"
```

执行后，再次使用时需要重新扫码配置。

## 20.8 删除 nvm

只有确定不再需要 nvm 和其中的全部 Node.js 环境时，才执行。

先卸载相关全局包，再根据 nvm 官方卸载说明删除：

```text
~/.nvm
```

同时删除 `~/.bashrc` 中加载 nvm 的配置行。

---

# 21. 最短操作清单

下面是从零配置时最核心的一组命令。

## 21.1 安装基础工具

```bash
sudo apt update
sudo apt install -y curl git ca-certificates build-essential
```

## 21.2 安装 Node.js

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash
source ~/.bashrc

nvm install 22
nvm use 22
nvm alias default 22

node -v
npm -v
```

## 21.3 安装并测试 Codex

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
source ~/.bashrc

codex --version
codex login status

mkdir -p "$HOME/projects/codex-feishu-test"
cd "$HOME/projects/codex-feishu-test"
git init
codex
```

第一次进入 Codex 时使用 ChatGPT 账号登录。

## 21.4 安装 Bridge

```bash
npm install -g lark-channel-bridge

command -v lark-channel-bridge
lark-channel-bridge --help
```

## 21.5 首次扫码启动

```bash
lark-channel-bridge run \
  --profile codex \
  --agent codex \
  --workspace "$HOME/projects/codex-feishu-test"
```

然后：

```text
手机飞书扫码
→ 选择或创建 PersonalAgent
→ 绑定 Codex
→ 在飞书中搜索机器人
→ 私聊发送 /status
→ 发送“列出当前目录文件，不要修改文件”
```

## 21.6 切换真实项目

飞书发送：

```text
/cd /home/你的用户名/真实项目目录
```

然后：

```text
/status
```

## 21.7 正常停止

前台运行时：

```text
Ctrl + C
```

## 21.8 改为后台运行

```bash
lark-channel-bridge start --profile codex
lark-channel-bridge status --profile codex
```

---

# 22. 参考资料

以下资料用于核对安装方式、版本要求和 Bridge 命令。第三方项目更新后，具体界面或参数可能发生变化。

- OpenAI Codex CLI 官方文档  
  <https://developers.openai.com/codex/cli>

- lark-channel-bridge 中文 README  
  <https://github.com/zarazhangrui/lark-coding-agent-bridge/blob/main/README.zh.md>

- lark-channel-bridge 项目主页  
  <https://github.com/zarazhangrui/lark-coding-agent-bridge>

- nvm 官方 README  
  <https://github.com/nvm-sh/nvm/blob/master/README.md>

---

# 附录：推荐的首次测试提示词

在飞书中先使用只读任务：

```text
请告诉我当前工作目录，并列出一级目录中的文件。只读取，不要修改任何文件，也不要执行安装或删除命令。
```

确认正常后再尝试：

```text
分析当前项目的目录结构、主要模块、构建方式和程序入口。只分析，不修改文件。
```

需要修改代码时，建议明确限制范围：

```text
先阅读相关代码并给出修改计划，不要立即修改。等我确认后，再只修改指定文件。
```

执行修改前，建议先在 Ubuntu 项目目录中创建 Git 检查点：

```bash
git status
git add -A
git commit -m "checkpoint before remote codex task"
```

这样出现不符合预期的修改时，更容易查看差异或回退。
