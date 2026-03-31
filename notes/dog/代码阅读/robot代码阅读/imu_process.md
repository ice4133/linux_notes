最底层
处理imu数据并且发送给电机

狗机器人系统架构
├── 底层驱动
│   └── 硬件IMU传感器 (Livox) 发布原始数据
│       ↓
├── 【 imu_process_node.py 】← 你在这里
│   └── 数据预处理和增强（滤波+姿态解算）
│       ↓
├── 中层应用
│   ├── decision_control.py  (决策控制 - 需要稳定的姿态数据)
│   ├── manual.py  (手动控制)
│   └── auto_obstacle.py  (自动避障)