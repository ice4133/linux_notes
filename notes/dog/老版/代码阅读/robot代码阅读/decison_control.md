这个文件是 决策控制模块，是机器人系统中的中间控制层，担当着"大脑"的角色—— 将高层感知结果转化为低层电机控制命令。


1. 数据处理与决策
接收来自上位机（Upper Computer）的 UpperData 对象，包含：

IMU 传感器数据（姿态信息）
目标标签分类
距离和偏移量
二维码检测与内容
根据这些数据做出决策，生成 ControlCommand 对象

上位机感知系统 (upper_comms_node)
        ↓
   决策层 (decision_control.py) ← 你在这里
        ↓
执行层 (motor_init, serial_node)
        ↓
      硬件执行