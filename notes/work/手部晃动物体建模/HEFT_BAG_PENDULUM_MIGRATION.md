# HEFT/WPC 原始干扰力链路与袋子钟摆移植指南

## 1. 文档目标

本文说明两件事：

1. 当前仓库中 HEFT/WPC 载荷干扰力从配置到物理仿真的完整数据链路。
2. 如何把根目录下 `bag_pendulum.py` 的三维袋子钟摆模型移植到
   IsaacLab/HEFT 训练环境，替换原来的载荷力生成公式。

这里采用“最小侵入”方案：

- 保留 WPC 的窗口容量、载荷课程、左右手质量分配和载荷渐变逻辑；
- 只替换“已知每只手承受多少质量之后，如何生成世界系三维力”；
- 保留已有的 IsaacLab 外力写入接口和 privileged observation 接口；
- 不在训练代码中直接 import `bag_pendulum.py`，因为该文件依赖
  MuJoCo 和 NumPy，只适用于单个 MuJoCo 环境。

核心修改文件为：

```text
gear_sonic/envs/manager_env/mdp/payload_state.py
gear_sonic/envs/manager_env/mdp/payload.py
gear_sonic/config/manager_env/events/terms/window_payload.yaml
```

`observations.py` 原则上只读缓存，不需要修改，但必须纳入验证范围。

---

## 2. 原始 HEFT/WPC 干扰力的完整链路

### 2.1 配置组合

wpc.yaml 决定“用哪套实验”；level0_4_wpc.yaml 决定“组合哪些事件”；window_payload.yaml 决定“载荷事件具体怎么配置”；Python 文件决定“这个事件实际怎么计算和施力”

wpc.yaml
│
├── 选择 tracking/level0_4_wpc.yaml
│   │
│   ├── 普通 tracking/level0_4.yaml
│   │
│   └── window_payload.yaml
│       │
│       └── WindowPayloadEvent
│           │
│           └── WindowPayloadState
│
├── 选择 WPC critic 观测配置
│
└── 指定训练专用事件
    ├── push_robot
    ├── compliance_force_push
    └── window_payload



相当于一个配置的总文件，想要修改一些配置，就得来这里，修改具体计算，得去找python文件
配置就相当于，宏文件，是自己根据实际硬件自己定义出来的，固定的，所以可以叫配置


WPC 实验配置：

```text
gear_sonic/config/exp/manager/universal_token/wpc.yaml
```

它完成两件关键事情：

1. 把事件配置切换为 `tracking/level0_4_wpc`；
2. 把 `window_payload` 加入 `train_only_events`。

`tracking/level0_4_wpc.yaml` 进一步组合：

```text
manager_env/events/tracking/level0_4.yaml
manager_env/events/terms/window_payload.yaml
```

因此实际的载荷事件定义来自：

```text
gear_sonic/config/manager_env/events/terms/window_payload.yaml
```

其中最关键的配置是：

```yaml
window_payload:
  func: gear_sonic.envs.manager_env.mdp:WindowPayloadEvent
  mode: "interval"
  interval_range_s: [0.0, 0.0]
```

`interval_range_s: [0.0, 0.0]` 表示该事件每个控制步都执行。当前注释约定控制
频率为 50 Hz，因此 `WindowPayloadEvent.__call__()` 通常每 0.02 秒调用一次。

`train_only_events` 的含义是：默认评估时可以移除该载荷事件，训练时才施加载荷。
评估脚本也可以通过配置覆盖重新启用它。

### 2.2 Event 类实例化

wpc.yaml
    ↓ 选择实验

window_payload.yaml
    ↓ 声明 Event 类和参数

WindowPayloadEvent
    ↓ 实例化 Python 对象

WindowPayloadState
    ↓ 保存和计算载荷状态

IsaacLab EventManager
    ↓ 每个控制步调用

permanent_wrench_composer
    ↓

机器人受到外力









事件实现位于：

```text
gear_sonic/envs/manager_env/mdp/payload.py
```

类名：

```python
WindowPayloadEvent
```



```python
def __init__(self, cfg: EventTermCfg, env: ManagerBasedRLEnv):
    """Read params, resolve bodies, and build the per-env payload state.

    Note:
        The command manager does not exist yet when the event manager
        instantiates class terms (the EventManager is created before
        ``load_managers()``), so everything that needs the motion command
        (``motion_cmd`` and the window-capacity ``lookup``) is bound lazily
        on first ``reset``/``__call__`` via :meth:`_try_bind`.
    """
    super().__init__(cfg, env)
    params = dict(cfg.params)

"""
当这个类被创建的那一刻，调用了构造函数，这个时候已经把windows_payload.yaml作为cfg传递进去了，没有显示的调用
"""

```
构造阶段主要完成：

1. 读取 YAML 参数；
2. 从场景中取得 `robot`；
3. 查找左右手和 pelvis 的 body ID；
4. 保存手掌局部施力点偏置；
5. 创建批量状态机 `WindowPayloadState`。

body 顺序是：

```text
[left_wrist_yaw_link, right_wrist_yaw_link, pelvis]
```

对应的 wrench 张量形状是：

```text
(num_envs, 3 bodies, 3 xyz)
```

`WindowPayloadState` 位于：

```text
gear_sonic/envs/manager_env/mdp/payload_state.py
```

它只处理批量 Torch 数值状态，不直接访问 IsaacLab robot，也不负责写外力。

### 2.3 motion window 容量查询


motion window 就是把一整段动作切成若干时间窗口

每个窗口对应不同载荷，也就是每一帧对应的WindowPayloadState的保存和输出的状态，重量

这两个要结合起来，也就是第1s，1kg；第2s，0.5kg；以此类推
就是一个sync的融合数据







`WindowPayloadEvent` 在 command manager 可用后延迟绑定 motion command，并创建
窗口容量查询器。

有两种模式：

- `label_path` 非空：从离线标签读取不同动作、不同时间窗口的最大载荷；
- `label_path` 为空：使用 uniform fallback，每个时间窗口的容量都等于
  `max_load_kg`。

每个控制步取得：

```python
gids, steps = self._motion_gids_steps()
lookup = self.lookup.lookup(gids, steps)
```

这里：

- `gids`：每个并行环境正在播放的全局 motion ID；
- `steps`：该动作当前进行到第几个仿真控制步；
- `lookup`：当前窗口及下一窗口的容量、边界和合法性等批量信息。

### 2.4 窗口载荷状态机


窗口载荷状态机的作用是：
根据机器人当前处于哪个 motion window，决定当前应该承受多少载荷，并且让载荷平滑地变化，而不是突然跳变。








每个控制步调用：

```python
self.state.update_windows(lookup, steps)
```

状态机有四种模式：

```text
MODE_NO_FORCE  无载荷
MODE_RAMP      载荷渐变
MODE_HOLD      保持载荷
MODE_PREDROP   进入低容量窗口前提前卸载
```

窗口变化时不会瞬间改变载荷，而是在 `transition_duration_s` 内从当前载荷平滑
过渡到目标载荷。若下一窗口容量更低，则可能在当前窗口结束前进入
`MODE_PREDROP`，把载荷提前降低到下一窗口允许的范围。

训练进度还会通过：

```python
self.state.set_progress(
    env.common_step_counter / cap_curriculum_total_env_steps
)
```

控制有效容量比例。也就是说训练初期可以使用较轻载荷，随后逐渐提高到完整容量。

### 2.5 总质量与左右手质量分配

与前文的状态机结合
当前袋子有多重
左手分到多少
右手分到多少





状态机首先得到当前总外部载荷：

```python
current_total_load_kg
```

再用 `body_load_weights` 分配到左右手：

```python
requested = current_total_load_kg.unsqueeze(-1) * body_load_weights
```

最终还会受每只手外部载荷上限约束：

```python
body_load_kg = minimum(
    requested,
    per_hand_total_capacity_kg - hand_self_mass_kg,
)
```

`current_body_load_kg()` 的输出形状为：

```text
(num_envs, 2 hands)
```

这个输出应在钟摆移植后继续保留。它将成为每只袋子的动态质量。

### 2.6 原始手部加速度估计


根据相邻两个控制时刻的手部速度，近似计算当前手部加速度。





`WindowPayloadEvent` 从 IsaacLab robot buffer 取得左右手世界系线速度：

```python
robot.data.body_link_lin_vel_w[:, hand_body_ids]
```

随后调用：

```python
self.state.update_accel(hand_linvel_w)
```

原始实现使用有限差分：

```text
raw_accel = (current_velocity - previous_velocity) / step_dt
```

然后执行：

1. reset 后第一帧加速度置零；
2. 按 `inertial_accel_clip_mps2` 限制异常尖峰；
3. 按 `inertial_accel_tau_s` 做一阶低通滤波；
4. 保存到 `body_accel_w`。

`body_accel_w` 的形状为：

```text
(num_envs, 2 hands, 3 xyz)
```

### 2.7 原始干扰力公式

原始最终力由：

```python
WindowPayloadState.current_body_force_w()
```

生成。对每个环境、每只手：

```text
F = m g d - m s a
```

其中：

- `m`：`current_body_load_kg()` 给出的每手载荷质量；
- `g`：9.81 m/s²；
- `d`：在向下圆锥中随机采样并在一个窗口内保持的单位方向；
- `s`：`inertial_force_scale_range` 采样的惯性力缩放；
- `a`：滤波后的手部世界系加速度。

代码等价于：

```python
body_load_kg = self.current_body_load_kg().unsqueeze(-1)
force_w = body_load_kg * 9.81 * self.force_dirs_w
force_w -= (
    body_load_kg
    * self.current_inertial_force_scale.view(-1, 1, 1)
    * self.body_accel_w
)
```

其输出：

```text
sampled_forces_w.shape == (num_envs, 2, 3)
```

这里的方向是随机圆锥方向，不包含摆长、摆角、摆速或张力约束，因此它不是一个
真实钟摆，只是“重力方向随机化 + 反向惯性力”的扰动近似。

### 2.8 手部与 pelvis 的力分配

手部与 pelvis：决定“力施加到哪些刚体”

current_body_force_w 传给手

pelvis 但是并不是所有力都传给手，可能通过一些传导，传给了身体其他部位







`WindowPayloadEvent.__call__()` 取得 `sampled_forces_w` 后，原实现不会把所有力
直接作用在手上，而是用：

```python
hand_forces_w = sampled_forces_w * hand_fraction
```

剩余部分：

```python
root_forces_by_hand_w = sampled_forces_w - hand_forces_w
```

被合成为 pelvis 上的力和力矩。

因此原始 wrench 是：

```text
左手：hand_fraction × 左手采样力
右手：hand_fraction × 右手采样力
pelvis：两只手剩余力之和
```

这是一种 HEFT 训练扰动设计，不是悬挂袋子的严格机械传力关系。

### 2.9 施力点与力矩

如果这个力正好作用在腕部 link 原点，只会产生平移效果。
但如果力作用在手掌中心，而手掌中心距离腕部原点有偏移：

实际上，肯定是手掌中心，所以这个很有必要

手腕世界位置
+
手腕姿态旋转后的局部手掌偏移
=
手掌世界位置

通过位置变换，求出最后手掌世界位置



手腕 link 原点位置和姿态来自：

```python
body_link_pos_w
body_link_quat_w
```

手掌施力点为：

```text
app_pos_w =
    hand_link_origin_w
    + rotate(hand_link_quaternion_w, palm_offset_local + random_offset_local)
```

由于力作用在偏离 link 原点的位置，需要转换为 link 原点处的等效力矩：

```python
hand_torque_w = cross(
    app_pos_w - hand_pos_w,
    hand_force_w,
)
```

该力矩在袋子钟摆版本中仍然需要保留。

### 2.10 写入 IsaacLab 物理仿真
前面的代码只是计算张量，还没有真正改变机器人运动。
真正把外力交给 IsaacLab 的代码是：

```python

self.robot.permanent_wrench_composer.set_forces_and_torques(
    forces=forces_w,
    torques=torques_w,
    body_ids=self.wrench_body_ids,
    env_ids=None,
    is_global=True,
)
```
作用是：
把 forces_w 和 torques_w 注册为这些刚体当前需要承受的外部 wrench


wrench = force + torque


接下来这个物理步，请把这些力和力矩加入动力学方程







最终将三具刚体的世界系力和力矩写入：

```python
self.robot.permanent_wrench_composer.set_forces_and_torques(
    forces=forces_w,
    torques=torques_w,
    body_ids=self.wrench_body_ids,
    env_ids=None,
    is_global=True,
)
```

`permanent_wrench_composer` 保存该控制步需要施加的外部 wrench，随后由
IsaacLab 的物理写入流程作用到 articulation。

如果手部速度 buffer 暂时不可用，现有代码会把管理的 wrench 清零，避免上一帧
外力永久残留。

### 2.11 privileged observation

critic 的 WPC observation 配置为：

```text
gear_sonic/config/manager_env/observations/terms/payload_hand_forces.yaml
```

它调用：

```python
payload_hand_forces(...)
```

该函数找到当前 `WindowPayloadEvent`，读取：

```python
term.state.current_body_force_w()
```

并使用：

```text
max_load_kg × 9.81
```

归一化为 6 维输入：

```text
[left_Fx, left_Fy, left_Fz, right_Fx, right_Fy, right_Fz]
```

袋子钟摆移植后，`current_body_force_w()` 必须只是读取已缓存的当前力，不能在
这里推进钟摆，否则同一个控制步可能因为 event 和 observation 各调用一次而推进
两次。

### 2.12 原始链路总图

```text
wpc.yaml
  │
  ├─ 启用 window_payload 训练事件
  └─ 启用 payload_hand_forces critic observation
          │
          ▼
window_payload.yaml
  │  配置 body、容量、渐变、随机力参数
  ▼
WindowPayloadEvent.__init__()
  │
  ├─ 找到左右手和 pelvis body ID
  ├─ 解析手掌偏置
  └─ 创建 WindowPayloadState
          │
          ▼ 每个控制步
motion ID + motion step
  │
  ▼
WindowLoadCapacityLookup
  │  当前窗口容量/下一窗口容量
  ▼
WindowPayloadState.update_windows()
  │  NO_FORCE/RAMP/HOLD/PREDROP
  ▼
current_total_load_kg
  │
  ├─ 左右手质量分配
  └─ 每手容量限制
          │
          ▼
current_body_load_kg()  (N, 2)
          │
手部速度 ──► update_accel() ──► body_accel_w (N, 2, 3)
          │
          ▼
current_body_force_w()
  │  F = m g d - m s a
  ▼
sampled_forces_w (N, 2, 3)
  │
  ├─ hand_fraction 部分施加到左右手
  ├─ 剩余部分施加到 pelvis
  └─ 根据施力点计算等效 torque
          │
          ▼
permanent_wrench_composer
  │
  └─ IsaacLab/PhysX articulation

同时：

cached current force
  └─ payload_hand_forces()
       └─ critic privileged observation (N, 6)
```

---

## 3. `bag_pendulum.py` 与 HEFT 接口的差异

根目录 `bag_pendulum.py` 是一个单袋子球面钟摆：

```text
输入：MuJoCo MjData、单个手掌 body、dt
状态：NumPy shape (3,)
输出：单只手的世界系三维力 shape (3,)
写力：mujoco.mj_applyFT()
```

HEFT/IsaacLab 需要：

```text
输入：所有并行环境的左右手状态
状态：Torch shape (num_envs, 2, 3)，通常位于 GPU
输出：所有环境左右手世界系力 shape (num_envs, 2, 3)
写力：permanent_wrench_composer
```

所以不应这样做：

```python
from bag_pendulum import BagPendulum
```

也不应在 GPU 训练循环中把 tensor 转为 NumPy。正确做法是把钟摆方程改写成
批量 Torch 运算，放进 `WindowPayloadState`。

---

## 4. 推荐的移植边界

### 4.1 保留的逻辑

以下逻辑继续保留：

- motion window capacity lookup；
- uniform fallback；
- cap curriculum；
- NO_FORCE/RAMP/HOLD/PREDROP 状态机；
- 总载荷目标和平滑过渡；
- 左右手质量分配；
- 每手最大外部载荷限制；
- 手掌施力点到腕部 link 原点的等效力矩；
- permanent wrench composer 写入；
- 日志指标；
- privileged force observation。

### 4.2 替换的逻辑

以下逻辑由钟摆替换：

- `force_dirs_w` 的随机固定圆锥方向；
- `F = m g d - m s a` 的原始力公式；
- `hand_force_fraction` 导致的 pelvis 剩余力，推荐设为全手部受力、pelvis 为零。

### 4.3 第一版可以暂时保留但不使用的参数

为了降低配置兼容风险，第一版可以继续接受这些参数，只是不参与新力计算：

```yaml
force_cone_half_angle_deg
inertial_force_scale_range
hand_force_fraction_range
```

确认训练配置都迁移完后再删除。

---

## 5. 修改一：`payload_state.py`

### 5.1 构造函数增加参数

在 `WindowPayloadState.__init__()` 增加：

```python
pendulum_length_m,
pendulum_damping,
pendulum_initial_tilt_x_deg,
pendulum_initial_tilt_y_deg,
pendulum_accel_alpha,
pendulum_max_substep_dt_s,
```

保存并验证：

```python
self.pendulum_length_m = float(pendulum_length_m)
self.pendulum_damping = float(pendulum_damping)
self.pendulum_initial_tilt_x_deg = float(pendulum_initial_tilt_x_deg)
self.pendulum_initial_tilt_y_deg = float(pendulum_initial_tilt_y_deg)
self.pendulum_accel_alpha = float(pendulum_accel_alpha)
self.pendulum_max_substep_dt_s = float(pendulum_max_substep_dt_s)

if self.pendulum_length_m <= 0.0:
    raise ValueError("pendulum_length_m must be > 0.")
if self.pendulum_damping < 0.0:
    raise ValueError("pendulum_damping must be >= 0.")
if not 0.0 < self.pendulum_accel_alpha <= 1.0:
    raise ValueError("pendulum_accel_alpha must be in (0, 1].")
if self.pendulum_max_substep_dt_s <= 0.0:
    raise ValueError("pendulum_max_substep_dt_s must be > 0.")
```

### 5.2 增加批量状态 buffer

增加：

```python
self.pendulum_direction_w = torch.zeros(
    (self.num_envs, 2, 3),
    dtype=torch.float32,
    device=self.device,
)
self.pendulum_direction_w[..., 2] = -1.0

self.pendulum_direction_rate_w = torch.zeros_like(
    self.pendulum_direction_w
)

self.current_pendulum_force_w = torch.zeros_like(
    self.pendulum_direction_w
)
```

含义：

- `pendulum_direction_w`：从手掌支点指向袋子的世界系单位方向；
- `pendulum_direction_rate_w`：该单位方向对时间的导数，单位 1/s；
- `current_pendulum_force_w`：缓存的袋子对手掌反作用力。

可以直接复用已有 `body_accel_w` 作为支点加速度。第一版不需要再增加一套加速度
buffer。

### 5.3 reset 钟摆状态

在 `reset(env_ids, ...)` 中，对被 reset 的环境执行：

```python
tilt_x = math.radians(self.pendulum_initial_tilt_x_deg)
tilt_y = math.radians(self.pendulum_initial_tilt_y_deg)

x = math.sin(tilt_x)
y = math.sin(tilt_y)
horizontal_sq = x * x + y * y
if horizontal_sq >= 1.0:
    raise ValueError("Pendulum initial tilt is too large.")

initial_direction = torch.tensor(
    [x, y, -math.sqrt(1.0 - horizontal_sq)],
    dtype=torch.float32,
    device=self.device,
)

self.pendulum_direction_w[env_ids] = initial_direction.view(1, 1, 3)
self.pendulum_direction_rate_w[env_ids] = 0.0
self.current_pendulum_force_w[env_ids] = 0.0
```

训练时推荐让左右手和不同环境具有小幅独立随机初始摆角。否则所有环境的摆相位
完全一致，扰动多样性不足。例如在初始化方向上添加小噪声后重新归一化。

任何无载荷环境虽然可以继续推进无质量钟摆，但更简单的处理是允许方向继续更新、
输出力因质量为零而自然为零。

### 5.4 新增 `update_pendulum()`

建议实现：

```python
def update_pendulum(self) -> None:
    direction = self.pendulum_direction_w
    direction_rate = self.pendulum_direction_rate_w

    gravity_w = torch.zeros_like(direction)
    gravity_w[..., 2] = -self.GRAVITY_MPS2
    effective_accel = gravity_w - self.body_accel_w

    num_substeps = max(
        int(math.ceil(self.step_dt / self.pendulum_max_substep_dt_s)),
        1,
    )
    dt = self.step_dt / num_substeps

    for _ in range(num_substeps):
        projection = (
            direction
            * (direction * effective_accel).sum(dim=-1, keepdim=True)
        )
        tangential_accel = (
            effective_accel - projection
        ) / self.pendulum_length_m

        direction_rate_norm_sq = direction_rate.square().sum(
            dim=-1, keepdim=True
        )

        direction_accel = (
            tangential_accel
            - direction_rate_norm_sq * direction
            - self.pendulum_damping * direction_rate
        )

        direction_rate = direction_rate + direction_accel * dt
        direction = direction + direction_rate * dt
        direction = torch.nn.functional.normalize(
            direction, dim=-1, eps=1.0e-6
        )

        direction_rate = direction_rate - direction * (
            direction * direction_rate
        ).sum(dim=-1, keepdim=True)

    self.pendulum_direction_w.copy_(direction)
    self.pendulum_direction_rate_w.copy_(direction_rate)

    body_load_kg = self.current_body_load_kg().unsqueeze(-1)

    tension = body_load_kg * (
        (direction * effective_accel).sum(dim=-1, keepdim=True)
        + self.pendulum_length_m
        * direction_rate.square().sum(dim=-1, keepdim=True)
    )
    tension.clamp_min_(0.0)

    self.current_pendulum_force_w.copy_(tension * direction)
```

方程含义：

```text
n      = 从手掌指向袋子的单位方向
n_dot  = n 的时间导数
a_p    = 手掌支点加速度
g_eff  = g - a_p

n_ddot =
    [g_eff - n(n·g_eff)] / L
    - |n_dot|² n
    - damping × n_dot

T = m [n·g_eff + L|n_dot|²]
F_hand = max(T, 0) n
```

张力 clamp 到非负值，是因为绳子可以拉但不能推。张力为零表示理论上绳子松弛。
该简化模型不会继续计算松绳后的自由飞行和再次绷紧碰撞。

`pendulum_max_substep_dt_s` 推荐初值为 `0.005`。在 50 Hz 控制周期
`step_dt = 0.02` 时，每个控制步做 4 个钟摆子步，通常比单步显式积分稳定。

### 5.5 `current_body_force_w()` 只返回缓存

改为：

```python
def current_body_force_w(self) -> torch.Tensor:
    return self.current_pendulum_force_w
```

禁止在这个 getter 中调用 `update_pendulum()`。

原因是：

- event 调用它一次来施力；
- observation 还会调用它一次来构造 critic 输入；
- getter 若推进状态，一个控制步会推进两次；
- observation 的读取顺序将意外改变物理结果。

---

## 6. 修改二：`payload.py`

### 6.1 读取并传递新参数

在 `WindowPayloadEvent.__init__()` 创建 `WindowPayloadState` 时增加：

```python
pendulum_length_m=float(params["pendulum_length_m"]),
pendulum_damping=float(params["pendulum_damping"]),
pendulum_initial_tilt_x_deg=float(
    params["pendulum_initial_tilt_x_deg"]
),
pendulum_initial_tilt_y_deg=float(
    params["pendulum_initial_tilt_y_deg"]
),
pendulum_accel_alpha=float(params["pendulum_accel_alpha"]),
pendulum_max_substep_dt_s=float(
    params["pendulum_max_substep_dt_s"]
),
```

同时把相同名字添加到 `WindowPayloadEvent.__call__()` 的形参列表。这里的形参虽然
不会在每次调用时使用，但 IsaacLab EventManager 会根据签名校验 YAML 参数，遗漏
后可能在启动阶段报错。

### 6.2 每个控制步只更新一次钟摆

原流程：

```python
self.state.update_accel(hand_linvel_w)
sampled_forces_w = self.state.current_body_force_w()
```

改为：

```python
self.state.update_accel(hand_linvel_w)
self.state.update_pendulum()
sampled_forces_w = self.state.current_body_force_w()
```

固定顺序必须是：

```text
读取当前手部运动
→ 更新支点加速度
→ 推进一次钟摆
→ 读取缓存力
→ 写入 wrench
```

### 6.3 推荐取消 pelvis 剩余力

真实袋子张力通过提手全部传到手掌。推荐：

```python
hand_forces_w = sampled_forces_w

root_force_w = torch.zeros(
    (self.num_envs, 1, 3),
    dtype=hand_forces_w.dtype,
    device=self.device,
)
root_torque_w = torch.zeros_like(root_force_w)
```

第一版可以继续保留：

```text
wrench_body_ids = [left hand, right hand, pelvis]
```

只是给 pelvis 写零。这样对现有 tensor 拼接和 composer 接口改动最小：

```python
forces_w = torch.cat([hand_forces_w, root_force_w], dim=1)
torques_w = torch.cat([hand_torques_w, root_torque_w], dim=1)
```

如果继续使用 `hand_force_fraction` 并把剩余力施加到 pelvis，代码可以运行，但
物理意义不再是“袋子只挂在手上”。

### 6.4 保留手部等效力矩

以下逻辑应保留：

```python
hand_pos_w = self.robot.data.body_link_pos_w[:, self.hand_body_ids]
hand_quat_w = self.robot.data.body_link_quat_w[:, self.hand_body_ids]

offsets_local = (
    self.palm_offsets_local
    + self.state.force_application_offset_local
)

app_pos_w = hand_pos_w + quat_apply(
    hand_quat_w,
    offsets_local,
)

hand_torques_w = torch.cross(
    app_pos_w - hand_pos_w,
    hand_forces_w,
    dim=-1,
)
```

这相当于 MuJoCo 版本中 `mj_applyFT()` 在手掌点施力的效果。

### 6.5 手掌偏置必须单独确认

`bag_pendulum.py` 中 MuJoCo body 的局部偏置约为：

```text
[0.0415, ±0.003, 0.0]
```

当前 IsaacLab YAML 使用：

```text
[0.18, ∓0.025, 0.0]
```

不能仅根据数值大小直接替换。两个机器人资产的 `wrist_yaw_link` 局部坐标原点和
方向可能不同。应通过 IsaacLab debug visualization 或读取资产几何确认实际手掌
中心。偏置错误会产生错误且可能很大的腕部力矩。

---

## 7. 修改三：`window_payload.yaml`

在 `params` 中增加：

```yaml
pendulum_length_m: 0.55
pendulum_damping: 0.08
pendulum_initial_tilt_x_deg: 8.0
pendulum_initial_tilt_y_deg: 5.0
pendulum_accel_alpha: 0.15
pendulum_max_substep_dt_s: 0.005
```

第一版保留旧参数，以免其他 experiment override 因字段缺失发生兼容问题：

```yaml
force_cone_half_angle_deg: 12.0
inertial_force_scale_range: [0.8, 1.2]
hand_force_fraction_range: [0.2, 1.0]
```

但新钟摆力不再使用它们。

质量继续由：

```yaml
max_load_kg
per_hand_total_capacity_kg
hand_self_mass_kg
split_ratio_range
```

控制，不使用 `bag_pendulum.py` 中固定的 `mass: 2.0`。

---

## 8. 可选的更高保真支点加速度

第一版直接使用 wrist link 原点线加速度：

```python
body_accel_w
```

但真正的钟摆支点位于：

```python
app_pos_w = hand_pos_w + quat_apply(hand_quat_w, palm_offset_local)
```

手腕旋转时，支点还会有切向和向心加速度。更高保真版本应缓存：

```text
previous_pivot_position_w
previous_pivot_velocity_w
pivot_accel_w
pivot_initialized
```

每控制步通过支点位置差分：

```text
pivot_vel = (pivot_pos - previous_pivot_pos) / dt
pivot_acc = (pivot_vel - previous_pivot_vel) / dt
```

再滤波、裁剪后传给钟摆。为此 `update_pendulum()` 需要从 `payload.py` 接受
`app_pos_w`，或者由 `payload.py` 调用独立的 `update_pivot_kinematics()`。

建议先完成腕部原点版本的小规模验证，再做这一步，避免一次改动过大。

---

## 9. 数值稳定和物理注意事项

### 9.1 必须使用子步

控制周期 0.02 秒对快速钟摆和剧烈手部加速度可能偏大。推荐：

```text
pendulum_max_substep_dt_s = 0.005
```

不要把 physics simulation timestep 误当成 event 的调用周期。钟摆 event 当前按
control step 更新，除非明确把更新移入 physics-step callback。

### 9.2 限制加速度异常值

继续保留 `inertial_accel_clip_mps2`，否则 reset、teleport 或 motion 切换可能产生
极大的有限差分加速度，进而产生极端张力。

### 9.3 可增加训练保护上限

物理张力可能因为：

```text
L|n_dot|²
```

显著大于 `mg`。训练初期可增加只用于安全保护的上限：

```python
max_tension = (
    body_load_kg
    * self.GRAVITY_MPS2
    * pendulum_max_tension_scale
)
tension = torch.minimum(tension, max_tension)
```

例如 `pendulum_max_tension_scale: 3.0`。这不是严格物理模型，而是训练稳定性保护；
是否使用应记录在实验配置中。

### 9.4 载荷质量渐变时的解释

WPC 会连续改变袋子的等效质量，但方向和摆速状态保持连续。这相当于袋子质量平滑
变化，不是现实中的瞬时拿起或放下。它保留了原 HEFT curriculum 的平滑性，适合
训练，但应在实验说明中写明。

### 9.5 两只手的物理含义

当前设计是左右手各有一个独立球面钟摆，质量由 WPC 分配。它不是“两只手共同提同
一个刚性袋子”的约束模型。

如果真实任务是双手共同提同一个袋子，需要一个共享袋子位置和两个连接约束，不能
用两个完全独立的钟摆等价替代。

---

## 10. 验证步骤

### 10.1 静态数学验证

设置：

```text
direction = [0, 0, -1]
direction_rate = 0
body_accel = 0
mass = m
```

预期：

```text
force = [0, 0, -m × 9.81]
```

### 10.2 零质量验证

当：

```text
current_body_load_kg == 0
```

必须满足：

```text
current_pendulum_force_w == 0
```

### 10.3 张力方向验证

应始终满足：

```text
force 与 direction 同向
tension >= 0
```

### 10.4 单步推进验证

在一个 control step 中：

```text
update_pendulum() 调用次数 == 1
```

反复调用：

```python
current_body_force_w()
```

不应改变方向、方向速度或力。

### 10.5 reset 验证

部分环境 reset 后：

- 只有对应 `env_ids` 的钟摆状态被重置；
- 其他并行环境状态不变；
- reset 环境的方向合法且范数为 1；
- direction rate 为零；
- 第一帧不会因旧速度产生加速度尖峰。

### 10.6 数值验证

每步检查：

```python
torch.isfinite(self.pendulum_direction_w).all()
torch.isfinite(self.pendulum_direction_rate_w).all()
torch.isfinite(self.current_pendulum_force_w).all()
```

长时间小环境 rollout 不应出现 NaN/Inf。

### 10.7 小规模启动

正式多 GPU 训练前，先使用很少的环境运行：

```text
NUM_ENVS=1、4 或 16
```

确认：

- 配置参数签名校验通过；
- event 能被实例化；
- tensor shape 正确；
- permanent wrench 写入正常；
- 日志中 `wpc/mean_hand_force_n` 有合理数值；
- 开启 render 时机器人受力方向符合预期。

### 10.8 observation 验证

确认：

```text
payload_hand_forces.shape == (num_envs, 6)
```

钟摆动载时归一化 observation 可能超过 1，因为张力可以超过 `mg`。若需要限制，
只 clamp observation，不要 clamp 真实施加力，除非明确使用训练安全上限。

---

## 11. 推荐交付流程

### 11.1 创建实验分支

```bash
git switch -c experiment/bag-pendulum
```

### 11.2 修改后查看范围

```bash
git diff -- \
  gear_sonic/envs/manager_env/mdp/payload_state.py \
  gear_sonic/envs/manager_env/mdp/payload.py \
  gear_sonic/config/manager_env/events/terms/window_payload.yaml
```

确认没有无关文件被修改。

### 11.3 提交

```bash
git add \
  gear_sonic/envs/manager_env/mdp/payload_state.py \
  gear_sonic/envs/manager_env/mdp/payload.py \
  gear_sonic/config/manager_env/events/terms/window_payload.yaml \
  docs/HEFT_BAG_PENDULUM_MIGRATION.md

git commit -m "experiment: replace WPC force model with bag pendulum"
```

根目录 `bag_pendulum.py` 当前可作为参考实现单独保存。如果要纳入 Git，需要显式
`git add bag_pendulum.py`。

### 11.4 交给训练人员的内容

交付信息至少包括：

- 分支名和 commit SHA；
- 新增 YAML 参数及默认值；
- 手掌偏置是否已验证；
- 小规模 smoke test 结果；
- 是否启用了 tension 上限；
- 当前是腕部原点加速度还是手掌偏置点加速度；
- 左右手是两个独立袋子还是共享袋子模型；
- 原始 HEFT force 是否完全禁用；
- 如何回退。

---

## 12. 快速回退

最简单的回退方式是切回原始分支：

```bash
git switch feat/wpc-heavy-payload
```

如果需要在实验分支保留历史并撤销改动：

```bash
git revert <bag-pendulum-commit-sha>
```

不推荐使用：

```bash
git reset --hard
```

因为它可能同时丢弃其他未提交工作。

也可以在配置中增加力模型开关，实现无需切分支的 A/B：

```yaml
payload_force_model: "pendulum"  # "heft" | "pendulum"
```

代码中：

```python
if self.payload_force_model == "pendulum":
    self.state.update_pendulum()
else:
    self.state.update_heft_force()
```

如果需要频繁比较原 HEFT 与钟摆模型，推荐使用该开关；如果只是一次性实验，独立
Git 分支已经足够。

---

## 13. 训练、导出与 MuJoCo 部署的边界

修改上述三个文件只改变 IsaacLab 中训练/评估时的载荷模型。

完整流程是：

```text
修改训练环境
→ 小规模 IsaacLab 可视化/数值验证
→ 多 GPU WPC 微调
→ 得到 .pt checkpoint
→ 评估并选择 checkpoint
→ 单独导出 encoder/decoder ONNX
→ MuJoCo sim2sim
```

训练不会自动直接产生最终 ONNX。训练首先保存：

```text
last.pt
model_step_*.pt
```

再通过：

```bash
CHECKPOINT=/path/to/model_step_xxx.pt \
./sonic_launch/heft_wpc/run_sonic_wpc_export_onnx_local.sh
```

导出 ONNX。

ONNX 只包含神经网络策略，不包含钟摆物理模型。若希望 MuJoCo sim2sim 中也实际
存在袋子扰动力，还必须把 `bag_pendulum.py` 接入 MuJoCo 部署循环，并确保：

- 使用相同的摆长、阻尼和质量定义；
- 使用正确的 MuJoCo 手掌施力点；
- 每个仿真步或控制步推进钟摆；
- 在 `mj_step()` 前正确写入 `qfrc_applied`；
- reset 时同步重置钟摆状态。

否则 MuJoCo 中运行的是“接受过袋子扰动训练的策略”，但 MuJoCo 场景本身没有
实际袋子反作用力。

---

## 14. 最终检查清单

代码交付训练前逐项确认：

- [ ] 只修改预期的三个核心文件和本文档；
- [ ] 新 YAML 参数全部出现在 Event `__call__` 签名中；
- [ ] 所有状态都是 Torch tensor 且位于正确 device；
- [ ] 没有在训练循环中进行 NumPy/CPU 转换；
- [ ] 钟摆状态 shape 为 `(num_envs, 2, 3)`；
- [ ] 每个控制步只调用一次 `update_pendulum()`；
- [ ] `current_body_force_w()` 只读缓存；
- [ ] reset 支持部分 `env_ids`；
- [ ] 零质量输出零力；
- [ ] 静止垂直袋子输出约 `-mg`；
- [ ] 张力非负；
- [ ] 保留施力点产生的腕部等效 torque；
- [ ] pelvis 是否写零已经明确；
- [ ] 手掌局部偏置已经确认；
- [ ] 小规模 rollout 无 NaN/Inf；
- [ ] privileged observation 仍为 `(num_envs, 6)`；
- [ ] 原 HEFT 与钟摆版本的回退方式已记录；
- [ ] 明确 ONNX 不包含袋子物理模型。
