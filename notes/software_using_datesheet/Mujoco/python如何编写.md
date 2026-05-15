```python
import mujoco
import mujoco.viewer
import time
import math

# 1. 加载我们在同一目录下写好的 XML 模型
model = mujoco.MjModel.from_xml_path('single_leg.xml')
data = mujoco.MjData(model)

print("模型加载成功！准备启动可视化窗口...")

# 2. 启动非阻塞式可视化窗口 (这会弹出一个新窗口)
with mujoco.viewer.launch_passive(model, data) as viewer:
    start_time = time.time()

    # 3. 核心控制循环 (只要窗口没关，就一直运行)
    while viewer.is_running():
        step_start = time.time()
        current_time = time.time() - start_time

        # --- 你的控制算法写在这里 ---
        # 我们用一个简单的正弦波函数 (sin) 生成交变力矩
        # 就像你用力推秋千一样，一会儿往前推，一会儿往后拉
        target_torque = 2.0 * math.sin(5.0 * current_time)

        # 把计算好的力矩，赋值给数组里的第 0 个电机 (也就是我们XML里唯一的那个 actuator)
        data.ctrl[0] = target_torque
        # ----------------------------

        # 4. 让物理引擎向前计算一小步 (默认是 0.002秒)
        mujoco.mj_step(model, data)

        # 5. 更新画面显示
        viewer.sync()

        # 保证仿真速度和真实时间一致
        time_until_next_step = model.opt.timestep - (time.time() - step_start)
        if time_until_next_step > 0:
            time.sleep(time_until_next_step)

```