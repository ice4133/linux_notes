```python


#!/usr/bin/env python3.8
import sys
import time
from datetime import datetime

# 关键：删除手动sys.path.append，依赖Colcon配置
# sys.path.append('../lib')  # 注释/删除这行

# 现在可直接导入（Colcon已配置好路径）
from unitree_actuator_sdk import *
from Robot_go import * # 这一行直接删去，不需要

motor_init = [0]*12
count = 0

# 初始化串口（注意：/dev/motor需确认存在，或改为/dev/ttyUSB0）
serial = SerialPort('/dev/ttyUSB0')
cmd = MotorCmd()
data = MotorData()

def motor_control():
    global count
    count += 0.1  # 每次增加0.01，控制角度变化速度
    for i in range(12):
        data.motorType = MotorType.GO_M8010_6
        cmd.motorType = MotorType.GO_M8010_6
        cmd.mode = queryMotorMode(MotorType.GO_M8010_6, MotorMode.FOC)
        cmd.id = i  # 电机ID 0-5
        cmd.q = count * 6.33  # 期望角度（带减速比）
        cmd.dq = 0.0  # 期望角速度
        cmd.kp = 1.0  # 比例系数（小值更温和）
        cmd.kd = 0.03  # 阻尼系数
        cmd.tau = 0.0  # 前馈力矩
        serial.sendRecv(cmd, data)
        motor_init[i] = round(data.q, 4)

if __name__ == "__main__":
    try:
        while True:
            motor_control()
            print("motor_init =", motor_init)
            time.sleep(0.01)  # 增加小延迟，避免打印刷屏
    except KeyboardInterrupt:
        print("\n程序被用户中断")
        # 可选：发送停止命令
        for i in range(12):
            cmd.mode = queryMotorMode(MotorType.GO_M8010_6, MotorMode.FOC)
            cmd.id = i
            cmd.q = motor_init[i]  # 回到当前位置
            cmd.dq = 0.0
            cmd.kp = 0.0
            cmd.kd = 0.0
            cmd.tau = 0.0
            serial.sendRecv(cmd, data)
motor_init.py


# 这段代码属于安全退出机制（Emergency Shutdown/Safe Exit
# 这段代码包裹在 except KeyboardInterrupt: 下。这意味着在 Ubuntu 终端里运行程序时，只要你按下 Ctrl+C，程序不会立即崩溃退出，而是先跳到这一段代码执行完，再彻底关闭。
```