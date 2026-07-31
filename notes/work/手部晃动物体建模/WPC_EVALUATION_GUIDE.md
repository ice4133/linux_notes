# SONIC WPC 抗外力策略评测手册

本文用于评测这样一个任务：

> 宇树人形机器人手掌或手腕受到外力后，策略能否继续保持稳定，并尽量完成原有动作。

文中的训练目录、Conda 环境和数据路径已经按当前项目填写。推荐先直接使用训练产生的 `.pt` checkpoint 在 Isaac Gym/Isaac Sim 环境中评测；确认策略确实学到了抗外力能力后，再导出 ONNX 做 MuJoCo 和部署侧测试。

---

## 1. 先明确：`.pt`、checkpoint、ckpt 和 ONNX 分别是什么

- `checkpoint` 和 `ckpt` 是同一个意思，都是“训练检查点”。
- `.pt` 是 PyTorch 保存的模型文件。它通常不只包含神经网络权重，还可能包含优化器、学习率调度器、训练步数等状态。
- `model_step_005000.pt` 表示训练到某个固定步数时保存的不可变快照，适合中途评测和对比。
- `last.pt` 通常会被后续训练反复覆盖，适合“接着训练”，不适合固定实验结论。
- `last_wpc.pt` 是项目已有的初始/基线 WPC 模型，不等于本次训练最新结果。
- ONNX 是部署格式。它适合交给 MuJoCo 控制器或真机推理程序，但不是判断模型是否训练好的唯一依据。

推荐做法：

1. 用 `model_step_*.pt` 在原训练环境里做定量评测。
2. 对相同 checkpoint 分别做“无外力”和“有外力”评测。
3. 看成功率、动作进度和跟踪误差，并渲染少量视频。
4. 选出表现较好的 `.pt` 后再导出 ONNX。
5. 用 MuJoCo 对官方模型和自己的模型做相同外力下的 A/B 测试。

---

## 2. 当前 WPC 评测究竟测试什么外力

当前项目里的 WPC 载荷主要模拟手部悬挂重物产生的摆锤/拉力，而不是所有方向、所有形式的随机推力。

训练侧的重要含义如下：

- 外力施加在左右手腕相关刚体上。
- 力的效果主要类似重物重力和摆动产生的张力。
- 默认 WPC 最大外部载荷约为 `4.96388 kg`，这是左右手合计的外部载荷预算，不是每只手各 `4.96388 kg`。
- `WPC_PER_HAND_TOTAL_CAPACITY_KG=3.0` 包含手本体质量，不等于每只手都额外挂了 `3 kg`。
- 当前 actor 并不会直接读取一个“手掌外力传感器数值”；载荷信息主要作为 privileged critic observation 使用。部署时 actor 需要从关节位置、速度、姿态等本体感觉中间接恢复稳定。

因此，当前评测可以回答：

> 模型面对训练定义中的悬挂载荷、手部向下拉力和摆动扰动时，是否比基线更稳定？

它不能单独证明：

> 模型面对任意方向的瞬时推掌、水平冲击、持续横向力时都稳定。

如果最终任务是“任意方向推手掌”，后续还需要在训练和评测环境中加入水平力、脉冲力、不同施力点、不同持续时间和随机方向。

---

## 3. 评测前准备：固定 GPU 0、路径和 checkpoint

以下命令在一个新的终端中执行。它们只影响当前终端，不会修改正在使用 GPU 1～7 的训练命令。

```bash
# 进入 SONIC 项目根目录。
cd /root/xuxiangling/sonic

# 项目根目录。评测脚本会从这里查找配置、Python 包和辅助脚本。
export SONIC_REPO=/root/xuxiangling/sonic

# 项目使用的 Conda 环境名称。
export SONIC_CONDA_ENV=sonic_z

# Conda 初始化脚本。评测脚本会 source 它并激活上面的环境。
export CONDA_SH=/root/miniconda3/etc/profile.d/conda.sh

# 只让评测进程看到物理 GPU 0。
# 在评测程序内部，它会显示为 cuda:0，这是正常的。
export CUDA_VISIBLE_DEVICES=0

# 服务器上没有桌面显示器时保持 True，使用无窗口模式。
export HEADLESS=True

# 本次训练保存 checkpoint 的目录。
export SONIC_EVAL_EXPERIMENT_DIR=/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000

# 需要评测的固定训练步数。这里以第 5000 步为例。
export SONIC_EVAL_STEP=003450

# 固定 checkpoint 文件。优先使用 model_step_*.pt，不建议在评测过程中直接引用会变化的 last.pt。
export SONIC_EVAL_CKPT="$SONIC_EVAL_EXPERIMENT_DIR/model_step_${SONIC_EVAL_STEP}.pt"

# 机器人动作数据。
export MOTION_FILE=/mnt/nfs/humanoid/sonic/robot_filtered

# 对应的 SMPL 动作数据。
export SMPL_MOTION_FILE=/mnt/nfs/humanoid/sonic/smpl_filtered
```

如果实际文件是 `model_step_5000.pt` 而不是 `model_step_005000.pt`，需要按真实文件名修改：

```bash
# 用 ls 查看训练目录中 checkpoint 的真实命名。
ls -lh "$SONIC_EVAL_EXPERIMENT_DIR"/model_step_*.pt

# 示例：文件没有前导零时，直接填写完整路径。
export SONIC_EVAL_CKPT="$SONIC_EVAL_EXPERIMENT_DIR/model_step_5000.pt"
```

### 3.1 检查 GPU 0 是否真的空闲

```bash
# 查看物理 GPU 0 的显存、利用率和占用进程。
nvidia-smi -i 0
```

只有在显存占用很低，并确认没有别人的任务使用 GPU 0 时，才启动评测。

如果 GPU 0 显示有进程，可以进一步查看，但不要直接杀掉不属于自己的进程：

```bash
# 查找常见的 Isaac、Python、torchrun 和 accelerate 进程。
ps -ef | grep -E 'isaac|python|torchrun|accelerate' | grep -v grep
```

### 3.2 检查 checkpoint 和配置文件

```bash
# 检查 checkpoint 是否存在；不存在时命令会报错并返回非零状态。
test -f "$SONIC_EVAL_CKPT" && echo "checkpoint 存在: $SONIC_EVAL_CKPT"

# 评测脚本需要 checkpoint 同目录的 config.yaml 来恢复训练配置。
test -f "$SONIC_EVAL_EXPERIMENT_DIR/config.yaml" && echo "config.yaml 存在"

# 检查评测脚本是否存在并可执行。
test -x "$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh" \
  && echo "评测脚本可执行"

# 查看 checkpoint 大小和更新时间，排除空文件或仍在写入的文件。
ls -lh "$SONIC_EVAL_CKPT"
```

如果正在训练，最好选择已经完整写完的历史文件。可以间隔几秒执行两次 `ls -lh`，确认大小和时间没有继续变化。

---
## 4.0.0 初始实验

```bash
# 无外力

cd /root/xuxiangling/sonic

CUDA_VISIBLE_DEVICES=0 \
SONIC_REPO=/root/xuxiangling/sonic \
SONIC_CONDA_ENV=sonic_z \
CONDA_SH=/root/miniconda3/etc/profile.d/conda.sh \
CHECKPOINT=/root/xuxiangling/sonic/sonic_release/last_wpc.pt \
MOTION_FILE=/mnt/nfs/humanoid/sonic/robot_filtered \
SMPL_MOTION_FILE=/mnt/nfs/humanoid/sonic/smpl_filtered \
WPC_EVAL=none \
EVAL_NAME=initial_last_wpc_noload \
EVAL_OUTPUT_DIR=/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000/eval_metrics_initial_last_wpc_noload \
RENDER=false \
HEADLESS=True \
NUM_PROCESSES=1 \
NUM_ENVS=128 \
MAX_UNIQUE_MOTIONS=512 \
./sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh
```


```bash
# 有外力

cd /root/xuxiangling/sonic

CUDA_VISIBLE_DEVICES=0 \
SONIC_REPO=/root/xuxiangling/sonic \
SONIC_CONDA_ENV=sonic_z \
CONDA_SH=/root/miniconda3/etc/profile.d/conda.sh \
CHECKPOINT=/root/xuxiangling/sonic/sonic_release/last_wpc.pt \
MOTION_FILE=/mnt/nfs/humanoid/sonic/robot_filtered \
SMPL_MOTION_FILE=/mnt/nfs/humanoid/sonic/smpl_filtered \
WPC_EVAL=full \
EVAL_NAME=initial_last_wpc_payload \
EVAL_OUTPUT_DIR=/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000/eval_metrics_initial_last_wpc_payload \
RENDER=false \
HEADLESS=True \
NUM_PROCESSES=1 \
NUM_ENVS=128 \
MAX_UNIQUE_MOTIONS=512 \
./sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh

```

## 4. 第一组实验：无外力基线评测

这一步回答：

> 不加 WPC 外载荷时，当前模型能否正常完成动作？

```bash
# CHECKPOINT：要评测的 .pt 文件。
# WPC_EVAL=none：关闭 WPC 外载荷，作为无外力基线。
# EVAL_NAME：输出目录标签，建议包含训练步数和 noload。
# RENDER=false：先只跑定量评测，不生成视频，速度更快。
# NUM_ENVS=128：GPU 0 同时运行 128 个环境；显存不足时可降为 64、32 或 16。
# MAX_UNIQUE_MOTIONS=512：最多抽取 512 个动作；这是评测脚本的默认正式评测规模。
CHECKPOINT="$SONIC_EVAL_CKPT" \
WPC_EVAL=none \
EVAL_NAME="step${SONIC_EVAL_STEP}_noload" \
RENDER=false \
NUM_ENVS=128 \
MAX_UNIQUE_MOTIONS=512 \
"$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh"
```

默认输出目录在 checkpoint 附近，名称类似：

```text
/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000/
└── eval_metrics_step005000_noload_model_step_005000/
    └── metrics_eval.json
```

如果 GPU 0 显存不足，重新执行时只需降低并行环境数：

```bash
# 低显存版本。评测内容不变，只降低并行数量。
CHECKPOINT="$SONIC_EVAL_CKPT" \
WPC_EVAL=none \
EVAL_NAME="step${SONIC_EVAL_STEP}_noload" \
RENDER=false \
NUM_ENVS=32 \
MAX_UNIQUE_MOTIONS=512 \
"$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh"
```

---

## 5. 第二组实验：有外力 WPC 评测

这一步回答：

> 在 WPC 训练定义的手部载荷下，当前模型是否还能保持动作和稳定？

```bash
# WPC_EVAL=full：启用完整 WPC 载荷事件和对应的 privileged critic observation。
# 其他设置与无外力评测保持一致，才能进行公平 A/B 对比。
CHECKPOINT="$SONIC_EVAL_CKPT" \
WPC_EVAL=full \
EVAL_NAME="step${SONIC_EVAL_STEP}_payload" \
RENDER=false \
NUM_ENVS=128 \
MAX_UNIQUE_MOTIONS=512 \
"$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh"
```

默认 WPC 参数已经由项目脚本设置。如需显式写出，完整命令如下：

```bash
# WPC_MAX_LOAD_KG：左右手合计的最大外部载荷预算，单位 kg。
# WPC_PER_HAND_TOTAL_CAPACITY_KG：单手总承载上限，包含手本体质量。
# WPC_HAND_SELF_MASS_KG：左右手自身质量，依次对应左手和右手。
# WPC_UNIFORM_WINDOW_S：载荷随机窗口长度，单位秒。
CHECKPOINT="$SONIC_EVAL_CKPT" \
WPC_EVAL=full \
WPC_MAX_LOAD_KG=4.96388 \
WPC_PER_HAND_TOTAL_CAPACITY_KG=3.0 \
WPC_HAND_SELF_MASS_KG='[0.51806,0.51806]' \
WPC_UNIFORM_WINDOW_S=5.0 \
EVAL_NAME="step${SONIC_EVAL_STEP}_payload" \
RENDER=false \
NUM_ENVS=128 \
MAX_UNIQUE_MOTIONS=512 \
"$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh"
```

注意：

- 不要把 `WPC_MAX_LOAD_KG=4.96388` 理解成每只手各挂 `4.96388 kg`。
- 无外力和有外力评测必须使用同一个 checkpoint、动作数据和动作数量。
- `MAX_UNIQUE_MOTIONS=512` 表示数据集超过 512 个动作时抽取 512 个；数据集不足 512 个时使用全部动作。评测程序会读取同一训练配置中的随机种子，因此同配置的 A/B 运行会选择相同子集。
- 如果只改载荷、不固定其他变量，结果就不能说明差异来自载荷。

---

## 6. 快速冒烟测试：正式评测前先确认程序能跑通

第一次使用 GPU 0 时，建议先用很小的环境数和动作数运行，避免程序配置错误后等待很久。

```bash
# 只运行 8 个并行环境、最多 8 个动作，用于检查启动、checkpoint 加载和指标写出。
CHECKPOINT="$SONIC_EVAL_CKPT" \
WPC_EVAL=full \
EVAL_NAME="step${SONIC_EVAL_STEP}_payload_smoke" \
RENDER=false \
NUM_ENVS=8 \
MAX_UNIQUE_MOTIONS=8 \
"$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh"
```

冒烟测试通过的最低条件：

1. Isaac 环境能正常启动。
2. 日志显示成功加载指定 checkpoint。
3. GPU 0 有利用率且程序没有长期卡在初始化。
4. 最后生成 `metrics_eval.json`。
5. 有外力评测日志里的 WPC 载荷相关数值不是始终为零。

冒烟测试只能证明流程工作，不能用于最终模型结论。

---

## 7. 找到并查看评测结果

### 7.1 查找所有指标文件

```bash
# 在本次训练目录下查找全部 metrics_eval.json，并按路径排序。
find "$SONIC_EVAL_EXPERIMENT_DIR" \
  -type f \
  -name metrics_eval.json \
  -print | sort
```

### 7.2 设置无外力和有外力指标路径

如果实际 checkpoint 文件名不同，请按真实输出目录修改。

```bash
# 无外力评测输出。
export NOLOAD_METRICS="$SONIC_EVAL_EXPERIMENT_DIR/eval_metrics_step${SONIC_EVAL_STEP}_noload_model_step_${SONIC_EVAL_STEP}/metrics_eval.json"

# 有外力评测输出。
export PAYLOAD_METRICS="$SONIC_EVAL_EXPERIMENT_DIR/eval_metrics_step${SONIC_EVAL_STEP}_payload_model_step_${SONIC_EVAL_STEP}/metrics_eval.json"


export INIT_NOLOAD_METRICS="$SONIC_EVAL_EXPERIMENT_DIR/eval_metrics_initial_last_wpc_noload/metrics_eval.json"

export INIT_PAYLOAD_METRICS="$SONIC_EVAL_EXPERIMENT_DIR/eval_metrics_initial_last_wpc_payload/metrics_eval.json"
# 确认两个 JSON 文件都存在。
ls -lh "$NOLOAD_METRICS" "$PAYLOAD_METRICS"
```

### 7.3 打印单个评测的关键指标

```bash
# 这个 Python 片段只读取 JSON，不会修改 checkpoint 或训练状态。
# 把 PAYLOAD_METRICS 改成 NOLOAD_METRICS，即可查看无外力结果。
python3 - "$PAYLOAD_METRICS" <<'PY'
import json
import sys

metrics_path = sys.argv[1]
with open(metrics_path, "r", encoding="utf-8") as file:
    metrics = json.load(file)

keys = [
    "eval/success/success_rate",
    "eval/success/progress_rate",
    "eval/all/mpjpe_g",
    "eval/all/mpjpe_l",
    "eval/all/mpjpe_pa",
    "eval/all/accel_dist",
    "eval/all/vel_dist",
]

print(f"指标文件: {metrics_path}")
for key in keys:
    print(f"{key:35s}: {metrics.get(key, '缺少该字段')}")

details = metrics.get("eval/all_metrics_dict", {})
terminated = details.get("terminated", [])
if terminated:
    failed = sum(bool(value) for value in terminated)
    print(f"terminated motions                  : {failed}/{len(terminated)}")
PY
```

### 7.4 自动比较无外力和有外力结果

```bash
# 读取两个 metrics_eval.json，并打印 payload 相对 noload 的变化量。
# 对 success/progress，正数通常更好；对 MPJPE/速度/加速度误差，负数通常更好。
python3 - "$NOLOAD_METRICS" "$PAYLOAD_METRICS" <<'PY'
import json
import math
import sys

def load(path):
    with open(path, "r", encoding="utf-8") as file:
        return json.load(file)

noload = load(sys.argv[1])
payload = load(sys.argv[2])

keys = [
    "eval/success/success_rate",
    "eval/success/progress_rate",
    "eval/all/mpjpe_g",
    "eval/all/mpjpe_l",
    "eval/all/mpjpe_pa",
    "eval/all/accel_dist",
    "eval/all/vel_dist",
]

print(f"{'metric':35s} {'noload':>12s} {'payload':>12s} {'delta':>12s}")
print("-" * 74)
for key in keys:
    left = noload.get(key)
    right = payload.get(key)
    if isinstance(left, (int, float)) and isinstance(right, (int, float)):
        delta = right - left
        print(f"{key:35s} {left:12.6f} {right:12.6f} {delta:12.6f}")
    else:
        print(f"{key:35s} {str(left):>12s} {str(right):>12s} {'N/A':>12s}")
PY
```

---

## 8. 每个核心指标应该怎样理解

### 8.1 `eval/success/success_rate`

含义：没有提前触发终止的动作比例。

- 越高越好。
- 它是最重要的稳定性指标之一。
- 如果机器人跌倒、严重偏离目标或触发终止条件，动作会被记为失败。

### 8.2 `eval/success/progress_rate`

含义：动作平均执行到了完整时长的多少比例。

- 越接近 `1.0` 越好。
- 它可以区分“刚开始就失败”和“接近结束才失败”。
- 不能只看它而忽略成功率。一个动作可能执行到 `99%` 后终止，此时 progress 很高，但 success 仍然失败。

### 8.3 `eval/all/mpjpe_g`

含义：全局坐标系中的平均关节位置误差，通常以毫米表示。

- 越低越好。
- 对根节点漂移、身体整体偏移比较敏感。

### 8.4 `eval/all/mpjpe_l`

含义：局部或根节点对齐后的关节位置误差。

- 越低越好。
- 更关注身体关节之间的相对姿态是否准确。

### 8.5 `eval/all/mpjpe_pa`

含义：进一步做姿态对齐后的关节位置误差。

- 越低越好。
- 更偏向判断姿势形状是否正确，不应单独拿它判断整体平衡。

### 8.6 `eval/all/accel_dist` 和 `eval/all/vel_dist`

含义：动作加速度和速度与参考动作的差异。

- 越低通常越好。
- 外力下数值大幅上升，可能说明机器人虽然没立即倒下，但出现剧烈抖动、补偿过度或速度失控。

### 8.7 `terminated`

`eval/all_metrics_dict.terminated` 会记录各动作是否触发终止。

- 它有助于定位失败的是哪些动作。
- 不能只看全部动作平均值；平均值可能掩盖某些动作必定失败的问题。

---

## 9. 怎样判断“训练好了”

没有一个对所有任务都通用的单一阈值。正确做法是先确定目标外力、允许的身体位移、允许的姿态误差和持续时间，再进行同条件比较。

至少应同时满足：

1. 无外力成功率没有因为 WPC 训练而明显下降。
2. 有外力成功率比初始 `last_wpc.pt` 更高。
3. 有外力 progress 更接近 `1.0`。
4. 有外力下 MPJPE、速度误差和加速度误差没有显著恶化。
5. 视频中没有靠高频抖动、严重弯腰或异常滑步“勉强不倒”。
6. 在未参与训练的动作集和不同载荷上仍然有效。
7. MuJoCo 中自己的 ONNX 相比官方 ONNX 也有改善。

可以为项目先定义一个“工程验收线”，例如：

- 目标载荷持续 `10 s` 不跌倒。
- 根节点高度下降不超过规定值。
- roll/pitch 不超过规定角度。
- 左右手掌下沉不超过规定距离。
- 相对无外力基线，成功率下降不超过团队允许的百分点。

这些阈值必须由机器人安全要求和任务需要决定，不应该把示例值当成通用标准。

---

## 10. 渲染视频，检查模型是否用“正确方式”保持稳定

定量评测完成后，只渲染少量动作即可。不要一开始就渲染全部动作，否则会很慢并产生大量视频。

### 10.1 无外力视频

```bash
# RENDER=true：开启离屏渲染。
# NUM_ENVS=4：只并行渲染少量环境，降低显存压力。
# MAX_UNIQUE_MOTIONS=4：最多渲染 4 个动作。
CHECKPOINT="$SONIC_EVAL_CKPT" \
WPC_EVAL=none \
EVAL_NAME="step${SONIC_EVAL_STEP}_noload_video" \
RENDER=true \
NUM_ENVS=4 \
MAX_UNIQUE_MOTIONS=4 \
"$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh"
```

### 10.2 有外力视频

```bash
# 只把 WPC_EVAL 改成 full，其余参数和无外力视频保持一致。
CHECKPOINT="$SONIC_EVAL_CKPT" \
WPC_EVAL=full \
EVAL_NAME="step${SONIC_EVAL_STEP}_payload_video" \
RENDER=true \
NUM_ENVS=4 \
MAX_UNIQUE_MOTIONS=4 \
"$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh"
```

### 10.3 查找生成的视频

```bash
# 查找 mp4 文件。
find "$SONIC_EVAL_EXPERIMENT_DIR" \
  -type f \
  -name '*.mp4' \
  -print | sort
```

视频中重点观察：

- 外力开始时身体是否快速失稳。
- 双脚是否持续滑动。
- 膝盖、髋部或腰部是否出现不自然的极端姿态。
- 手臂是否高频抖动。
- 根节点是否持续下沉或侧倾。
- 外力移除后能否恢复，而不是一直保持异常补偿姿势。
- 策略是否牺牲原动作跟踪来换取不跌倒。

---

## 11. 批量评测多个 checkpoint

只评测一个中间 checkpoint 无法判断训练是否持续改善。推荐至少比较：

- 官方/初始 `last_wpc.pt`
- `model_step_001000.pt`
- `model_step_005000.pt`
- `model_step_010000.pt`
- `model_step_020000.pt`
- `model_step_030000.pt`

以下命令会按顺序对存在的 checkpoint 运行无外力和有外力评测；不存在的文件会跳过。

```bash
# 进入项目目录。
cd "$SONIC_REPO"

# 依次遍历多个训练步数。
for step in 001000 005000 010000 020000 030000; do
  # 组成当前步骤对应的 checkpoint 路径。
  ckpt="$SONIC_EVAL_EXPERIMENT_DIR/model_step_${step}.pt"

  # 如果文件不存在，打印提示并进入下一轮。
  if [ ! -f "$ckpt" ]; then
    echo "跳过不存在的 checkpoint: $ckpt"
    continue
  fi

  # 运行无外力评测。
  CHECKPOINT="$ckpt" \
  WPC_EVAL=none \
  EVAL_NAME="step${step}_noload" \
  RENDER=false \
  NUM_ENVS=128 \
  MAX_UNIQUE_MOTIONS=512 \
  "$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh"

  # 运行相同 checkpoint 的有外力评测。
  CHECKPOINT="$ckpt" \
  WPC_EVAL=full \
  EVAL_NAME="step${step}_payload" \
  RENDER=false \
  NUM_ENVS=128 \
  MAX_UNIQUE_MOTIONS=512 \
  "$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh"
done
```

如果 checkpoint 文件名没有补足为六位数字，需要按实际命名修改循环中的路径。

批量实验必须遵循：

- 使用同一套动作。
- 使用同一载荷参数。
- 使用相同的 `NUM_ENVS` 和终止条件。
- 不要把训练集表现当成泛化表现，最好单独准备 held-out 动作集。
- 记录完整 checkpoint 路径、Git 版本、配置文件和随机种子。

---

## 12. 单独评测初始/官方 `last_wpc.pt`

先找到实际文件：

```bash
# 查看项目发布目录中的基线模型。
ls -lh "$SONIC_REPO/sonic_release/last_wpc.pt"
```

对基线做无外力评测：

```bash
CHECKPOINT="$SONIC_REPO/sonic_release/last_wpc.pt" \
WPC_EVAL=none \
EVAL_NAME=official_last_wpc_noload \
RENDER=false \
NUM_ENVS=128 \
MAX_UNIQUE_MOTIONS=512 \
"$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh"
```

对基线做有外力评测：

```bash
CHECKPOINT="$SONIC_REPO/sonic_release/last_wpc.pt" \
WPC_EVAL=full \
EVAL_NAME=official_last_wpc_payload \
RENDER=false \
NUM_ENVS=128 \
MAX_UNIQUE_MOTIONS=512 \
"$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh"
```

如果脚本提示 checkpoint 同目录缺少 `config.yaml`，应使用项目发布模型对应的配置目录或按评测脚本要求补齐匹配的配置；不要拿不同实验的 `config.yaml` 随意搭配模型。

---

## 13. 检查 WPC 外力是否真的生效

训练或评测日志中应能看到 WPC 相关统计。常见字段包括：

- `wpc/mean_load_kg`
- `wpc/max_load_kg`
- `wpc/cap_scale`
- `wpc/mean_hand_force_n`
- 不同载荷模式所占比例

查找日志：

```bash
# 在本次训练日志和 checkpoint 目录中搜索 WPC 统计字段。
grep -R -E \
  'wpc/mean_load_kg|wpc/max_load_kg|wpc/cap_scale|wpc/mean_hand_force_n' \
  /root/xuxiangling/sonic/sonic_launch/logs/sonic_wpc_train_7gpu_env4096_30000 \
  "$SONIC_EVAL_EXPERIMENT_DIR" 2>/dev/null | tail -n 100
```

需要警惕以下情况：

- `mean_load_kg` 和 `mean_hand_force_n` 始终为零。
- 有外力和无外力评测结果完全相同到不合理的程度。
- 配置中 WPC event 存在，但实际没有进入有效载荷窗口。
- 载荷施加到了错误的刚体、方向或坐标系。

如果外力没有真正生效，即使 reward 曲线很好也不能证明策略学会了抗外力。

---



## 14.0.0 导出onnx
cd /root/xuxiangling/sonic
export SONIC_REPO=/root/xuxiangling/sonic
export SONIC_CONDA_ENV=sonic_z
export CONDA_SH=/root/miniconda3/etc/profile.d/conda.sh


export CUDA_VISIBLE_DEVICES=0
export HEADLESS=1

export MOTION_FILE=/mnt/nfs/humanoid/sonic/robot_filtered
export SMPL_MOTION_FILE=/mnt/nfs/humanoid/sonic/smpl_filtered

export SONIC_EXPORT_CKPT=/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000/model_step_002450.pt


export SONIC_EXPORT_DIR=/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000/deploy_policy_model_step_002450


"$SONIC_REPO/sonic_launch/heft_wpc/export_new_wpc_onnx.sh" \
  "$SONIC_EXPORT_CKPT" \
  "$SONIC_EXPORT_DIR"


or

export SONIC_EXPORT_LOG=/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000/export_model_step_002450.log

"$SONIC_REPO/sonic_launch/heft_wpc/export_new_wpc_onnx.sh" \
  "$SONIC_EXPORT_CKPT" \
  "$SONIC_EXPORT_DIR" \
  2>&1 | tee "$SONIC_EXPORT_LOG"



直接运行这个
cd /root/xuxiangling/sonic

export SONIC_REPO=/root/xuxiangling/sonic
export SONIC_CONDA_ENV=sonic_z
export CONDA_SH=/root/miniconda3/etc/profile.d/conda.sh

export MOTION_FILE=/mnt/nfs/humanoid/sonic/robot_filtered
export SMPL_MOTION_FILE=/mnt/nfs/humanoid/sonic/smpl_filtered

export SONIC_EXPORT_CKPT=/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000/model_step_002450.pt

export SONIC_EXPORT_DIR=/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000/deploy_policy_model_step_002450

export SONIC_OBS_CONFIG=/root/xuxiangling/sonic/gear_sonic_deploy/policy/release/observation_config_sonic_release.yaml

RUN_EXPORT=false \
EXPECTED_ENCODER_INPUT_DIM=1751 \
HEADLESS=1 \
CUDA_VISIBLE_DEVICES=0 \
"$SONIC_REPO/sonic_launch/heft_wpc/export_new_wpc_onnx.sh" \
  "$SONIC_EXPORT_CKPT" \
  "$SONIC_EXPORT_DIR"
## 14. 导出选中的 checkpoint 为 ONNX

只有在 `.pt` 原环境评测通过后，才建议导出 ONNX。

### 14.1 创建输出目录并执行导出

```bash
# 选择一个已经通过原环境评测的固定 checkpoint。
export SONIC_EXPORT_CKPT="$SONIC_EVAL_CKPT"

# 为该 checkpoint 单独创建部署模型目录，避免覆盖其他版本。
export SONIC_EXPORT_DIR="$SONIC_EVAL_EXPERIMENT_DIR/deploy_policy_model_step_${SONIC_EVAL_STEP}"

# 调用项目自带的 WPC ONNX 导出脚本。
# 第一个参数是 .pt checkpoint，第二个参数是 ONNX 输出目录。
"$SONIC_REPO/sonic_launch/heft_wpc/export_new_wpc_onnx.sh" \
  "$SONIC_EXPORT_CKPT" \
  "$SONIC_EXPORT_DIR"
```

### 14.2 检查导出产物

```bash
# 查看导出的 encoder、decoder 和 observation 配置。
find "$SONIC_EXPORT_DIR" \
  -maxdepth 1 \
  -type f \
  -printf '%f  %s bytes\n' | sort
```

通常应该至少包含：

```text
model_encoder.onnx
model_decoder.onnx
observation_config.yaml
```

ONNX 导出成功只说明“模型被转换成了部署格式”，不说明它在受力时一定稳定。必须继续做 MuJoCo 或真机前的仿真 A/B 测试。

---

## 15. MuJoCo 中进行官方模型与自训练模型 A/B 测试

MuJoCo 测试建议开两个终端：

- 终端 A：运行策略控制器。
- 终端 B：运行 MuJoCo payload 仿真。

每次只运行一个策略。先测官方策略，停止后再用完全相同参数测自己的策略。

### 15.0 首次运行前检查 MuJoCo 环境和模型文件

```bash
# 进入项目根目录。
cd /root/xuxiangling/sonic

# 指向第 14 节导出的模型目录；如果评测的不是第 5000 步，请修改目录名。
export SONIC_EXPORT_DIR=/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000/deploy_policy_model_step_005000

# 检查 MuJoCo 虚拟环境是否已经安装。
test -f .venv_sim/bin/activate \
  && echo "MuJoCo 环境已存在" \
  || echo "缺少 .venv_sim，需要执行下面的一次性安装命令"

# 检查官方 ONNX 和观测配置是否存在。
ls -lh \
  gear_sonic_deploy/policy/release/model_encoder.onnx \
  gear_sonic_deploy/policy/release/model_decoder.onnx \
  gear_sonic_deploy/policy/release/observation_config.yaml

# 检查自己的 ONNX 和观测配置是否存在。
ls -lh \
  "$SONIC_EXPORT_DIR/model_encoder.onnx" \
  "$SONIC_EXPORT_DIR/model_decoder.onnx" \
  "$SONIC_EXPORT_DIR/observation_config.yaml"
```

如果 `.venv_sim` 不存在，只在宿主机上执行一次：

```bash
# 该安装脚本会创建 .venv_sim，并安装 MuJoCo、Pinocchio 和 Unitree SDK 等依赖。
# 注意：脚本会重新创建已有的 .venv_sim；如果其中有自行安装的依赖，应先记录或备份。
cd /root/xuxiangling/sonic
bash install_scripts/install_mujoco_sim.sh
```

如果官方 `model_encoder.onnx` 或 `model_decoder.onnx` 不存在，`run_payload_ab_controller.sh sonic` 会明确报出缺少的文件。此时要先补齐项目官方 release 模型，不能用自己的 ONNX 冒充官方基线。

### 15.1 终端 A：启动官方策略控制器

```bash
# 进入项目目录。
cd /root/xuxiangling/sonic

# 指定用于 payload 测试的参考动作。
export PAYLOAD_MOTION_DATA=reference/payload_hold

# 使用 ZMQ 与 MuJoCo 仿真交换控制数据。
export OUTPUT_TYPE=zmq

# sonic 表示使用项目自带的官方策略。
./sonic_launch/heft_wpc/run_payload_ab_controller.sh sonic
```

控制器启动后，根据终端提示完成准备，并在需要时按 `]` 启动策略输出。

### 15.2 终端 B：启动官方策略对应的 MuJoCo 载荷测试

```bash
# 进入项目目录。
cd /root/xuxiangling/sonic

# 激活 MuJoCo 仿真专用虚拟环境。
source .venv_sim/bin/activate

# payload-kg-per-hand=2.0：每只手施加相当于 2 kg 重物的载荷。
# payload-delay-s=3.0：触发后等待 3 秒再开始加载。
# payload-ramp-s=2.0：用 2 秒从零平滑增加到目标载荷，避免瞬间冲击。
# log-hz=20：每秒保存 20 行状态数据。
# log-dir：保存 CSV 指标的目录。
# run-label：本次实验标签，方便与自训练模型区分。
python gear_sonic/scripts/run_payload_sim_loop.py \
  --payload-kg-per-hand 2.0 \
  --payload-delay-s 3.0 \
  --payload-ramp-s 2.0 \
  --log-hz 20 \
  --log-dir /root/xuxiangling/sonic/mujoco_payload_metrics \
  --run-label official_sonic_2kg
```

MuJoCo 窗口准备好后，按项目脚本约定的 `9` 键触发载荷。先运行固定时长，例如 `20 s`，再停止并保存结果。

### 15.3 终端 A：启动自己的 ONNX 控制器

先停止官方策略控制器，然后执行：

```bash
# 进入项目目录。
cd /root/xuxiangling/sonic

# 指向第 14 节导出的自训练 ONNX 目录。
export CUSTOM_POLICY_DIR=/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000/deploy_policy_model_step_005000

# 显式指定与这次 ONNX 导出配套的观测配置。
export CUSTOM_OBS_CONFIG="$CUSTOM_POLICY_DIR/observation_config.yaml"

# 使用与官方策略相同的参考动作。
export PAYLOAD_MOTION_DATA=reference/payload_hold

# 使用相同通信方式。
export OUTPUT_TYPE=zmq

# custom 表示加载 CUSTOM_POLICY_DIR 中的模型。
./sonic_launch/heft_wpc/run_payload_ab_controller.sh custom
```

同样根据提示准备控制器，并按 `]` 启动策略输出。`payload_hold` 是静态参考姿态，因此通常不必再按 `T`；完成测试后可在控制器终端按 `O` 停止。

### 15.4 终端 B：用完全相同参数测试自己的策略

停止上一轮 MuJoCo 后重新启动：

```bash
cd /root/xuxiangling/sonic
source .venv_sim/bin/activate

# 除 run-label 外，载荷、延迟、ramp 和运行时长必须与官方策略完全相同。
python gear_sonic/scripts/run_payload_sim_loop.py \
  --payload-kg-per-hand 2.0 \
  --payload-delay-s 3.0 \
  --payload-ramp-s 2.0 \
  --log-hz 20 \
  --log-dir /root/xuxiangling/sonic/mujoco_payload_metrics \
  --run-label custom_step005000_2kg
```

仍然在相同准备阶段按 `9`，并运行相同持续时间。

### 15.5 查找 MuJoCo CSV 结果

```bash
# 列出生成的 CSV 指标文件。
find /root/xuxiangling/sonic/mujoco_payload_metrics \
  -type f \
  -name '*.csv' \
  -print | sort
```

CSV 中重点比较：

- 根节点 `x/y/z` 位移。
- root roll、pitch、yaw。
- 左右手腕/手掌位置。
- 载荷开始后的手掌下沉量。
- 是否跌倒或触发异常。
- 从载荷开始到恢复稳定所需时间。
- 稳态是否持续振荡。

---

## 16. MuJoCo 载荷阶梯测试

不要只测单一载荷。推荐每只手依次测试：

```text
0.0 kg
0.5 kg
1.0 kg
1.5 kg
2.0 kg
2.5 kg
```

零载荷命令示例：

```bash
cd /root/xuxiangling/sonic
source .venv_sim/bin/activate

python gear_sonic/scripts/run_payload_sim_loop.py \
  --payload-kg-per-hand 0.0 \
  --payload-delay-s 3.0 \
  --payload-ramp-s 2.0 \
  --log-hz 20 \
  --log-dir /root/xuxiangling/sonic/mujoco_payload_metrics \
  --run-label custom_step005000_0kg
```

每只手 `2.5 kg` 的命令示例：

```bash
cd /root/xuxiangling/sonic
source .venv_sim/bin/activate

python gear_sonic/scripts/run_payload_sim_loop.py \
  --payload-kg-per-hand 2.5 \
  --payload-delay-s 3.0 \
  --payload-ramp-s 2.0 \
  --log-hz 20 \
  --log-dir /root/xuxiangling/sonic/mujoco_payload_metrics \
  --run-label custom_step005000_2p5kg
```

注意单位差异：

- Isaac WPC 的 `WPC_MAX_LOAD_KG` 是左右手合计外部载荷预算。
- MuJoCo 的 `--payload-kg-per-hand` 是每只手的载荷。
- `--payload-kg-per-hand 2.0` 表示两只手合计约 `4.0 kg` 的重力等效载荷。

两种仿真器的施力点、接触、关节动力学和控制延迟也可能不同，因此数值不能只按公斤数直接等价。

---

## 17. 如何判断问题出在训练、模型设计、ONNX 还是仿真迁移

### 情况 A：Isaac `.pt` 有外力评测明显改善，MuJoCo ONNX 没改善

优先检查：

- ONNX 是否从正确 checkpoint 导出。
- `observation_config.yaml` 是否和 ONNX 配套。
- encoder 和 decoder 是否来自同一次导出。
- 关节顺序、观测顺序和动作缩放是否一致。
- MuJoCo 与训练环境的施力位置是否一致。
- 控制频率、PD 参数、动作延迟和机器人质量是否一致。

这通常更像导出或 sim-to-sim 问题，不应立即断定训练失败。

### 情况 B：Isaac `.pt` 和 MuJoCo ONNX 都没有改善

优先检查：

- WPC 外力是否真的施加。
- reward 是否鼓励稳定而不是只鼓励动作跟踪。
- curriculum 是否很久都停留在太小载荷。
- 外力方向、施力点和最终任务是否匹配。
- actor 的本体观测是否足以感知受力后的状态变化。
- 模型容量、训练步数或数据覆盖是否不足。

### 情况 C：有外力能力提高，但无外力表现明显下降

可能是：

- 对 WPC 载荷过拟合。
- 载荷样本比例过高。
- 原动作跟踪 reward 权重不足。
- 训练过程中发生灾难性遗忘。

需要在无载荷、小载荷和大载荷之间重新平衡 curriculum 与 reward。

### 情况 D：训练动作很好，未见动作很差

这是泛化不足或过拟合。应该建立独立 held-out 动作集，评测时不要与训练动作混用。

### 情况 E：progress 很高，但 success 很低

说明很多动作接近结束时仍然触发了终止。不能因为 progress 接近 `1.0` 就认定已经训练好。

---

## 18. 当前模型设计需要特别核对的地方

### 18.1 施力点是否匹配真实任务

训练侧手掌/手腕外力可能使用类似以下局部偏移：

```text
左侧约为 [0.18, -0.025, 0]
右侧约为 [0.18,  0.025, 0]
```

MuJoCo payload 测试的默认前向偏移可能是 `0.12 m`。施力点不同会改变对手腕、手臂和身体的力矩。

如果目标是“真实手掌中心受到外力”，应确认：

- 机器人模型里的左右手掌坐标系。
- 力究竟施加在 wrist link 还是 palm link。
- 偏移方向是在局部坐标系还是世界坐标系。
- Isaac、MuJoCo 和真机使用的是同一个物理位置。

### 18.2 当前载荷是否覆盖真实外力形式

至少分别考虑：

- 持续向下拉力。
- 水平向前/向后推力。
- 左右方向推力。
- 短时脉冲冲击。
- 缓慢增加的持续力。
- 单手受力和双手受力。
- 两只手大小不对称的力。
- 不同施力点和力矩。

如果训练只包含悬挂载荷，那么对水平推力不稳定不一定是网络结构错误，也可能只是训练分布没有覆盖目标任务。

### 18.3 critic 能看到外力、actor 看不到外力是否合理

这是常见的 asymmetric actor-critic 设计：

- 训练时 critic 使用外力等 privileged information，帮助估计价值。
- 部署时 actor 只使用真机可获得的本体观测。

这种设计本身没有问题，但 actor 必须能从姿态、关节误差、速度和角速度中及时感受到受力结果。如果补偿过慢，才需要考虑增加可部署的力/力矩传感器观测，或加入更丰富的历史观测。

---

## 19. GPU 0 常见故障排查

### 19.1 显存不足

现象通常包含 `CUDA out of memory`。

处理：

```bash
# 把评测并行环境数降到 32。
export NUM_ENVS=32
```

然后重新执行评测命令，或直接在命令中写 `NUM_ENVS=32`。

### 19.2 Isaac 长时间卡在启动

先检查：

```bash
# 查看 GPU 0 是否有显存变化和利用率。
nvidia-smi -i 0

# 查看当前用户相关的仿真和 Python 进程。
ps -ef | grep -E 'isaac|python|torchrun|accelerate' | grep -v grep
```

如果 GPU 0 没有可见进程但 Isaac 仍反复卡死，可能是该卡的驱动上下文或 Isaac 初始化异常。此时应让管理员检查 GPU reset 或重启，不要随意终止其他人的任务。

### 19.3 评测意外尝试多卡 NCCL

本手册里的评测应是单 GPU，不需要 7/8 卡 NCCL。确认：

```bash
# 应只输出 0。
echo "$CUDA_VISIBLE_DEVICES"

# 应输出 1，表示当前进程只能看到一张 CUDA 卡。
python3 -c 'import torch; print(torch.cuda.device_count())'
```

如果第二条命令报 `No module named torch`，先激活训练环境：

```bash
source /root/miniconda3/etc/profile.d/conda.sh
conda activate sonic_z
python3 -c 'import torch; print(torch.cuda.device_count())'
```

---

## 20. 推荐的最终实验表

对每个模型填写同一张表：

| 模型 | 场景 | 载荷 | success rate | progress rate | MPJPE-G | root 最大倾角 | 手掌最大下沉 | 是否跌倒 |
|---|---|---:|---:|---:|---:|---:|---:|---|
| 官方 `last_wpc.pt` | Isaac | 无外力 |  |  |  |  |  |  |
| 官方 `last_wpc.pt` | Isaac | WPC full |  |  |  |  |  |  |
| `model_step_005000.pt` | Isaac | 无外力 |  |  |  |  |  |  |
| `model_step_005000.pt` | Isaac | WPC full |  |  |  |  |  |  |
| 官方 ONNX | MuJoCo | 每手 2.0 kg |  |  |  |  |  |  |
| 自训练 ONNX | MuJoCo | 每手 2.0 kg |  |  |  |  |  |  |

同一个结论至少重复多个随机种子或多次试验，报告均值和最差情况。机器人稳定任务只看平均值不够，因为一次严重跌倒也可能具有安全风险。

---

## 21. 最短但完整的执行顺序

如果只想快速按正确流程执行，顺序如下：

```bash
# 第 1 步：进入项目并设置公共变量。
cd /root/xuxiangling/sonic
export SONIC_REPO=/root/xuxiangling/sonic
export SONIC_CONDA_ENV=sonic_z
export CONDA_SH=/root/miniconda3/etc/profile.d/conda.sh
export CUDA_VISIBLE_DEVICES=0
export HEADLESS=True
export MOTION_FILE=/mnt/nfs/humanoid/sonic/robot_filtered
export SMPL_MOTION_FILE=/mnt/nfs/humanoid/sonic/smpl_filtered
export SONIC_EVAL_EXPERIMENT_DIR=/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000
export SONIC_EVAL_STEP=005000
export SONIC_EVAL_CKPT="$SONIC_EVAL_EXPERIMENT_DIR/model_step_${SONIC_EVAL_STEP}.pt"

# 第 2 步：确认 GPU、checkpoint 和配置。
nvidia-smi -i 0
ls -lh "$SONIC_EVAL_CKPT" "$SONIC_EVAL_EXPERIMENT_DIR/config.yaml"

# 第 3 步：无外力定量评测。
CHECKPOINT="$SONIC_EVAL_CKPT" \
WPC_EVAL=none \
EVAL_NAME="step${SONIC_EVAL_STEP}_noload" \
RENDER=false \
NUM_ENVS=128 \
MAX_UNIQUE_MOTIONS=512 \
"$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh"

# 第 4 步：有外力定量评测。
CHECKPOINT="$SONIC_EVAL_CKPT" \
WPC_EVAL=full \
EVAL_NAME="step${SONIC_EVAL_STEP}_payload" \
RENDER=false \
NUM_ENVS=128 \
MAX_UNIQUE_MOTIONS=512 \
"$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh"

# 第 5 步：查找两个评测生成的 JSON。
find "$SONIC_EVAL_EXPERIMENT_DIR" \
  -type f \
  -name metrics_eval.json \
  -print | sort

# 第 6 步：有外力视频检查。
CHECKPOINT="$SONIC_EVAL_CKPT" \
WPC_EVAL=full \
EVAL_NAME="step${SONIC_EVAL_STEP}_payload_video" \
RENDER=true \
NUM_ENVS=4 \
MAX_UNIQUE_MOTIONS=4 \
"$SONIC_REPO/sonic_launch/heft_wpc/run_sonic_wpc_eval_local.sh"

# 第 7 步：导出通过评测的 checkpoint。
export SONIC_EXPORT_DIR="$SONIC_EVAL_EXPERIMENT_DIR/deploy_policy_model_step_${SONIC_EVAL_STEP}"
"$SONIC_REPO/sonic_launch/heft_wpc/export_new_wpc_onnx.sh" \
  "$SONIC_EVAL_CKPT" \
  "$SONIC_EXPORT_DIR"
```

最后再按第 15～16 节使用同样的参考动作、载荷和运行时间，对官方 ONNX 与自己的 ONNX 做 MuJoCo A/B 测试。

---

## 22. 最终结论应该怎样写

一个可靠的结论不应该只写“模型能运行”或“ONNX 导出成功”，而应该写成：

> 在固定验证动作集上，`model_step_xxxxxx.pt` 在无外力条件下的成功率和跟踪误差相对基线没有明显退化；在指定 WPC 总载荷下，成功率、动作进度和根节点稳定性优于初始模型。该改进在 MuJoCo 中使用相同动作、每手相同载荷、相同加载时间进行 A/B 测试后仍然存在。因此可以初步认为模型学到了目标载荷范围内的抗扰能力。对水平推力、瞬时冲击和真机表现仍需单独验证。

只有这类同时包含 checkpoint、动作集、载荷、指标、基线、仿真器和限制条件的结论，才足以判断建模和训练是否有效。
