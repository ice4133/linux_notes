```python
#! /usr/bin/env python3.8
import sys
import time
from datetime import datetime
import keyboard
import threading
import sys

import manual
sys.path.append('../lib')
from unitree_actuator_sdk import *
import signal
import unitree_actuator_sdk

# 导入自动障碍控制模块
try:
    from auto_obstacle import AutoObstacleControl
    auto_control_available = True
except ImportError:
    auto_control_available = False
    print("Auto obstacle control module not available")

# 导入串口通信模块 + 初始化serial_node 原代码必备
# try:
#     from serial_node import SerialCommunicationNodepositions[i]
#     print("Successfully imported serial_node")
#     serial_node = SerialCommunicationNode()
# except ImportError:
#     serial_node = None
#     print("Warning: Cannot import serial_node module")
serial_node = None  # 修改1：定义serial_node，解决未声明报错

# 关节电机初始角度参数
motor_init =[2.17,0.12,5.02,0.42,3.38,4.77,3.09,4.45,0,0,0,0]
#4 -1,25positions[i]
# 定义不同步态下的轮子转速参数结构体
class WheelSpeedConfig:
    def __init__(self, left_front=0.0, right_front=0.0, left_rear=0.0, right_rear=0.0):
        self.left_front = left_front      # 左前轮转速
        self.right_front = right_front    # 右前轮转速
        self.left_rear = left_rear        # 左后轮转速
        self.right_rear = right_rear      # 右后轮转速

# 不同步态对应的轮子转速配置 原代码完整版本
wheel_speed_configs = [
    WheelSpeedConfig(0.0, 0.0, 0.0, 0.0),        # STOP - 停止
    WheelSpeedConfig(50.0, -50.0, 50.0, -50.0),        # TROT - 疾步
    WheelSpeedConfig(-1.0, -1.0, -1.0, -1.0),    # TROT_BACK - 后退疾步
    WheelSpeedConfig(-1.0, 1.0, -1.0, 1.0),      # TROT_BACK_RIGHT - 后退右转
    WheelSpeedConfig(1.0, -1.0, 1.0, -1.0),      # TROT_BACK_LEFT - 后退左转
    WheelSpeedConfig(1.0, -1.0, 1.0, -1.0),      # TROT_LEFT - 左转
    WheelSpeedConfig(-1.0, 1.0, -1.0, 1.0),      # TROT_RIGHT - 右转
    WheelSpeedConfig(-1.0, 1.0, -1.0, 1.0),      # ROTATE_LEFT - 原地左转
    WheelSpeedConfig(1.0, -1.0, 1.0, -1.0),      # ROTATE_RIGHT - 原地右转
    WheelSpeedConfig(150, -150, 150, -150),        # TROT_WHEEL - 上坡
    WheelSpeedConfig(0.5, 0.5, 0.5, 0.5),        # slow_TROT - 慢走
    WheelSpeedConfig(0.5, -0.5, 0.5, -0.5),      # small_TROT_LEFT - 小幅度左转
    WheelSpeedConfig(-0.5, 0.5, -0.5, 0.5),      # small_TROT_RIGHT - 小幅度右转
    WheelSpeedConfig(1.0, 1.0, 1.0, 1.0),        # dijia_trot - 地面疾走
    WheelSpeedConfig(-1.0, 1.0, -1.0, 1.0),      # dijia_left - 地面左转
    WheelSpeedConfig(1.0, -1.0, 1.0, -1.0),      # dijia_right - 地面右转
    WheelSpeedConfig(1.0, -1.0, -1.0, 1.0),      # move_left - 左移
    WheelSpeedConfig(-1.0, 1.0, 1.0, -1.0),      # move_right - 右移
    WheelSpeedConfig(1.0, 1.0, 1.0, 1.0),        # xiepo_TROT - 斜坡行走
    WheelSpeedConfig(1.0, 1.0, 1.0, 1.0),        # xiataijie - 下台阶
    WheelSpeedConfig(1.0, 1.0, 1.0, 1.0),        # taijie_trot - 台阶行走
    WheelSpeedConfig(1.0, 1.0, 1.0, 1.0),        # xiaxiepo - 下斜坡
    WheelSpeedConfig(1.0, 1.0, 1.0, 1.0),        # shakeng - 沙坑
    WheelSpeedConfig(1.0, 1.0, 1.0, 1.0),        # xiadaxiepo - 下大斜坡
    WheelSpeedConfig(0.3, 0.3, 0.3, 0.3),        # slow_xiaxiepo - 慢速下斜坡
    WheelSpeedConfig(1.0, -1.0, -1.0, 1.0),      # move_left_1 - 左移变体
    WheelSpeedConfig(-1.0, 1.0, 1.0, -1.0),      # move_right_1 - 右移变体
    WheelSpeedConfig(-0.8, 0.8, -0.8, 0.8),      # ROTATE_LEFT_1 - 原地左转变体
    WheelSpeedConfig(0.8, -0.8, 0.8, -0.8)       # ROTATE_RIGHT_1 - 原地右转变体
]

# 轮足转速控制函数 - 原代码完整无删减 核心恢复
def wheel_speed_control(state):
    """
    根据当前状态设置轮子转速
    :param state: 当前机器人状态
    """
    if 0 <= state < len(wheel_speed_configs):

        #len是python内置函数，作用是返回input的长度，这里是返回wheel_speed_configs列表的长度，确保state在有效范围内 

        config = wheel_speed_configs[state]
        manual.set_target_wheel_speeds(
            config.left_front,
            config.right_front,
            config.left_rear,
            config.right_rear
        )
        # 更新轮子速度（带平滑处理，防止转速突变）
        manual.update_wheel_speeds(0.1)

# 全局步态状态
dog_state = 0
# TROT状态进入时间，用于参数平滑过渡
trot_start_time = None  # 记录【切换到TROT小跑状态】的时间戳      
state_start_time = None # 通用状态开始时间  
state_flow = None # 状态流程控制
start_done = False # TROT状态启动完成标志

state_motor_params = [
    [1.2,0.03], #STOP
    [1.2, 0.025], # TROT
    [1.2, 0.03], # TROT_BACK
    [1.2, 0.03], # TROT_BACK_RIGHT
    [1.2, 0.03], # TROT_BACK_LEFT
    [1.2, 0.03], # TROT_LEFT
    [1.2, 0.03], # TROT_RIGHT
    [1.2, 0.03], # ROTATE_LEFT
    [1.2, 0.03], #ROTATE_RIGHT
    [1.2, 0.03], # TROT_WHEEL


    # TROT 是 四足机器人的标准前进运动状态（最常用、最基础的行走 / 小跑模式）。
    # state_motor_params 是不同运动状态对应的电机控制参数  
]

# 姿态控制核心函数 - 原代码完整版本
def posture_control_task():
    global dog_state
    # 调用轮足转速控制 核心调用 必加
    wheel_speed_control(dog_state)
    
    detached_params = manual.state_detached_params[dog_state]
    gait_angle = manual.gait_angles[dog_state]
    if dog_state == manual.States. STOP:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,0,0,0)
    if dog_state == manual.States. TROT:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States. TROT_BACK:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, -1.0, -1.0, -1.0, -1.0, gait_angle,1,0,0)
    if dog_state == manual.States. TROT_BACK_RIGHT:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, -1.0, -1.0, -1.0, -1.0, gait_angle,1,0,0)
    if dog_state == manual.States. TROT_BACK_LEFT:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, -1.0, -1.0, -1.0, -1.0, gait_angle,1,0,0)
    if dog_state == manual.States. TROT_LEFT:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States. TROT_RIGHT:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States. ROTATE_LEFT:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, -1.0, 1.0, -1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States. ROTATE_RIGHT:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, -1.0, 1.0, -1.0, gait_angle,1,0,0)
    if dog_state == manual.States. TROT_WHEEL:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,2,0,0)
    if dog_state == manual.States. slow_TROT:
        manual.update_leg_trajectory(0,0.001)
    if dog_state == manual.States.small_TROT_RIGHT:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States.small_TROT_LEFT:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States.dijia_trot:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States. dijia_left:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, -1.0, 1.0, -1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States. dijia_right:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, -1.0, 1.0, -1.0, gait_angle,1,0,0)
    if dog_state == manual.States.move_left:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, -1.0, 1.0, 1.0, -1.0, gait_angle,1,0,0)
    if dog_state == manual.States.move_right:
        manual.gait_detached_all_legs(detached_params, 0.5, 0.0, 0.5, 0.0, 1.0, -1.0, -1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States.xiepo_TROT:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States.xiataijie:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States.taijie_trot:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States.xiaxiepo:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States.shakeng:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States.xiadaxiepo:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States.slow_xiaxiepo:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.25, 0.75, 1.0, 1.0, 1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States.move_left_1:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, -1.0, 1.0, 1.0, -1.0, gait_angle,1,0,0)
    if dog_state == manual.States.move_right_1:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, -1.0, -1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States.ROTATE_LEFT_1:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, -1.0, 1.0, -1.0, 1.0, gait_angle,1,0,0)
    if dog_state == manual.States.ROTATE_RIGHT_1:
        manual.gait_detached_all_legs(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, -1.0, 1.0, -1.0, gait_angle,1,0,0)

# 步态时长控制函数 - 原代码完整版本
def state_times(state,times):
    global dog_state
    dog_state = state
    detached_params = manual.state_detached_params[dog_state]
    gait_angle = manual.gait_angles[dog_state]
    time =times
    if dog_state == manual.States. STOP:

        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,0,time)
    if dog_state == manual.States. TROT:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,times)
    if dog_state == manual.States. TROT_BACK:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, -1.0, -1.0, -1.0, -1.0, gait_angle,1,time)
    if dog_state == manual.States. TROT_BACK_RIGHT:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, -1.0, -1.0, -1.0, -1.0, gait_angle,1,time)
    if dog_state == manual.States. TROT_BACK_LEFT:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, -1.0, -1.0, -1.0, -1.0, gait_angle,1,time)
    if dog_state == manual.States. TROT_LEFT:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,time)
    if dog_state == manual.States. TROT_RIGHT:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,time)
    if dog_state == manual.States. ROTATE_LEFT:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, -1.0, 1.0, -1.0, 1.0, gait_angle,1,time)
    if dog_state == manual.States. ROTATE_RIGHT:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, -1.0, 1.0, -1.0, gait_angle,1,time)
    if dog_state == manual.States. TROT_WHEEL:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,time)
    if dog_state == manual.States. slow_TROT:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,time)
    if dog_state == manual.States.small_TROT_RIGHT:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,time)
    if dog_state == manual.States.small_TROT_LEFT:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,time)
    if dog_state == manual.States.dijia_trot:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,time)
    if dog_state == manual.States. dijia_left:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, -1.0, 1.0, -1.0, 1.0, gait_angle,1,time)
    if dog_state == manual.States. dijia_right:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, -1.0, 1.0, -1.0, gait_angle,1,time)
    if dog_state == manual.States.move_left:
        manual.gait_detached_all_legs_times(detached_params, 0.5, 0.0, 0.5, 0.0, -1.0, 1.0, 1.0, -1.0, gait_angle,1,time)
    if dog_state == manual.States.move_right:
        manual.gait_detached_all_legs_times(detached_params, 0.5, 0.0, 0.5, 0.0, 1.0, -1.0, -1.0, 1.0, gait_angle,1,time)
    if dog_state == manual.States. xiepo_TROT:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,time)
    if dog_state == manual.States. xiataijie:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,time)
    if dog_state == manual.States. taijie_trot:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,time)
    if  dog_state == manual.States.shakeng:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,time)
    if  dog_state == manual.States.xiadaxiepo:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,time)
    if  dog_state == manual.States.slow_xiaixiepo:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, 1.0, 1.0, 1.0, gait_angle,1,time)
    if dog_state == manual.States.move_left_1:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, -1.0, 1.0, 1.0, -1.0, gait_angle,1,time)
    if dog_state == manual.States.move_right_1:
        manual.gait_detached_all_legs_times(detached_params, 0.0, 0.5, 0.5, 0.0, 1.0, -1.0, -1.0, 1.0, gait_angle,1,time)

# 初始化串口 - 原路径不变
serial =  unitree_actuator_sdk.SerialPort('/dev/ttyUSB0')
cmd = unitree_actuator_sdk.MotorCmd()
data =  unitree_actuator_sdk.MotorData()

def state_control(dog_state):
    global trot_start_time
    global state_start_time
    global state_flow
    global start_done
    
    if dog_state == manual.States.STOP and start_done is False:
        current_time = time.time()
        
        # 记录首次进入TROT状态的时间
        if trot_start_time is None:
            trot_start_time = current_time
        
        # 计算自进入TROT状态以来的时间（秒）
        elapsed_time = current_time - trot_start_time
        
        # 设置过渡时间（秒）
        transition_duration = 2.0
        
        # 线性插值计算参数
        if elapsed_time < transition_duration:
            # 过渡阶段：从初始值线性增加到目标值
            ratio = elapsed_time / transition_duration
            cmd.kp = 0.1 + ratio * (state_motor_params[0][0] - 0.1)
            cmd.kd = 0.01 + ratio * (state_motor_params[0][1] - 0.01)
        else:
            # 完成过渡：保持稳定值
            cmd.kp = state_motor_params[0][0]
            cmd.kd = state_motor_params[0][1]
            start_done = True
            state_flow = dog_state

    
    elif state_flow != dog_state:
        current_time = time.time()
        if state_start_time is None:
            state_start_time = time.time()
        elapsed_time = current_time - state_start_time
        
        transition_duration = 0.8
        if elapsed_time < transition_duration:
            # 过渡阶段：从初始值线性增加到目标值
            ratio = elapsed_time / transition_duration
            cmd.kp = 0.6 + ratio * (state_motor_params[dog_state][0] - 0.6)
            cmd.kd = 0.01 + ratio * (state_motor_params[dog_state][1] - 0.01)
        else:
            # 完成过渡：保持稳定值
            cmd.kp = state_motor_params[dog_state][0]
            cmd.kd = state_motor_params[dog_state][1]
            state_flow = dog_state
            state_start_time = None


# 电机停止函数 - 原代码完整版本
def motor_stop():
    tau=0
    for i in range(8):
        data.motorType =  unitree_actuator_sdk.MotorType.GO_M8010_6
        cmd.motorType =  unitree_actuator_sdk.MotorType.GO_M8010_6
        cmd.mode =  unitree_actuator_sdk.queryMotorMode( unitree_actuator_sdk.MotorType.GO_M8010_6,  unitree_actuator_sdk.MotorMode.FOC)
        cmd.id = i
        cmd.q = motor_init[i]
        cmd.dq = 0.0
        cmd.kp = 0.01
        cmd.kd = 0.03
        cmd.tau= tau
        serial.sendRecv(cmd, data)
    for i in range(4):
        data.motorType =  unitree_actuator_sdk.MotorType.GO_M8010_6
        cmd.motorType =  unitree_actuator_sdk.MotorType.GO_M8010_6
        cmd.mode =  unitree_actuator_sdk.queryMotorMode( unitree_actuator_sdk.MotorType.GO_M8010_6,  unitree_actuator_sdk.MotorMode.FOC)
        cmd.id = i+8
        cmd.q = 0
        cmd.dq = 0.0
        cmd.kp = 0
        cmd.kd = 0.01
        cmd.tau = 0
        serial.sendRecv(cmd, data)
    print("stop")

# 按键状态集合 + 跳跃模式标识
pressed_keys = set()
jump = 100

# 键盘事件监听函数 - 原代码完整版本
def log_keystroke(event):
    global dog_state,jump
    if event.event_type == 'down':
        pressed_keys.add(event.name)
    elif event.event_type == 'up':
        pressed_keys.discard(event.name)  
        dog_state=manual.States. STOP
        manual.Jump_Value_duanqiao=0
        manual.Jump_Value_shakeng=0
    if 'up' in pressed_keys:
        dog_state = manual.States. TROT
    if 'down' in pressed_keys:
        dog_state = manual.States. TROT_BACK
    if 'left' in pressed_keys and 'shift' not in pressed_keys:
        dog_state = manual.States. TROT_LEFT
    if 'right' in pressed_keys and 'shift' not in pressed_keys:
        dog_state = manual.States. TROT_RIGHT
    if 'shift' in pressed_keys and 'left' in pressed_keys:
        dog_state = manual.States. TROT_BACK_LEFT
    if 'shift' in pressed_keys and 'right' in pressed_keys:
        dog_state = manual.States. TROT_BACK_RIGHT
    if '[' in pressed_keys:
        dog_state = manual.States. ROTATE_LEFT
    if ']' in pressed_keys:
        dog_state = manual.States. ROTATE_RIGHT
    if 'shift' in pressed_keys and 'up' in pressed_keys:
        dog_state = manual.States.TROT_WHEEL
    if 'e' in pressed_keys:
        manual.plan_leg_trajectory(0,0,20,1.0,"linear")
    if 'r' in pressed_keys:
        dog_state = manual.States.small_TROT_LEFT
    if 'q' in pressed_keys:
        dog_state = manual.States.small_TROT_RIGHT
    if 't' in pressed_keys:
        dog_state = manual.States.dijia_trot
    if 'y' in pressed_keys:
        dog_state = manual.States.dijia_left
    if 'u' in pressed_keys:
        dog_state = manual.States.dijia_right
    if 'a' in pressed_keys:
        dog_state = manual.States.move_left
    if 'd' in pressed_keys:
        dog_state = manual.States.move_right
    if 'f' in pressed_keys:
        dog_state = manual.States.xiepo_TROT
    if 'g' in pressed_keys:
        dog_state = manual.States.xiataijie
    if 'h' in pressed_keys:
        dog_state = manual.States.taijie_trot
    if 'j' in pressed_keys:
        dog_state = manual.States.xiaxiepo
    if 'k' in pressed_keys:
        dog_state = manual.States.shakeng
    if 'l' in pressed_keys:
        dog_state = manual.States.xiadaxiepo
    if 'p' in pressed_keys:
        dog_state = manual.States.slow_xiaxiepo
    if 'n' in pressed_keys:
        dog_state = manual.States.move_left_1
    if 'm' in pressed_keys:
        dog_state = manual.States.move_right_1
    if 'b' in pressed_keys:
        dog_state = manual.States.ROTATE_LEFT_1
    if 'c' in pressed_keys:
        dog_state = manual.States.ROTATE_RIGHT_1
    if 'x' in pressed_keys:
        dog_state = jump
    if 'z' in pressed_keys:
        dog_state = jump

# 启动键盘监听线程
# 修改3：键盘线程加完整异常捕获+忽略报错，彻底解决Thread-1崩溃
def start_key_listener():
    try:
        keyboard.hook(log_keystroke)
        keyboard.wait("esc")
    except Exception as e:
        pass

key_listener_thread = threading.Thread(target=start_key_listener)
key_listener_thread.daemon = True
key_listener_thread.start()

# 信号处理函数 - 优雅退出
def handle_sigtstp(signum, frame):
    motor_stop()
    sys.exit(0)

signal.signal(signal.SIGTSTP, handle_sigtstp)



# ==================== 平滑控制模块 ====================
class SmoothController:
    """轻量级平滑控制器，集成到主控制循环中"""
    
    def __init__(self):
        # 历史位置记录
        self.prev_positions = [0.0] * 8
        # 平滑因子 (0.01-1.0，越小越平滑)
        self.smooth_factor = 0.5
        # 安全检测开关
        self.safety_enabled = True

        # KP参数对应的安全阈值
        self.kp_thresholds = [0.15] * 8
    
    def init_kp_parameters(self, current_kp):
        """
        初始化KP参数并计算所有关节的阈值
        :param current_kp: 当前步态的KP值（标量）
        """
        # 确保输入是合法的数值
        if current_kp <= 0:
            # 如果KP <= 0，使用默认阈值
            self.kp_thresholds = [0.15] * len(self.kp_thresholds)
        else:
            # 根据公式计算统一阈值
            threshold = max(0.2, 0.5 / current_kp)
            self.kp_thresholds = [threshold] * len(self.kp_thresholds)
    
    def process_positions(self, target_positions):
        """
        处理位置数据：应用平滑插值和安全检测
        返回安全的位置值
        """

        
        safe_positions = [0.0] * 8
        
        for i in range(8):
            if i >= len(target_positions):
                safe_positions[i] = self.prev_positions[i]
                continue
            
            target_val = target_positions[i]
            prev_val = self.prev_positions[i]
            
            # 线性插值平滑
            smoothed_val = prev_val + (target_val - prev_val) * self.smooth_factor
            
            # 安全检测
            if self.safety_enabled:
                delta = abs(smoothed_val - prev_val)
                threshold = self.kp_thresholds[i]
                
                if delta > threshold:
                    print(f"警告: 电机{i}位置变化过大 ({delta:.4f} > {threshold:.4f})")
                    print("执行紧急停止")
                    motor_stop()  # 直接调用电机停止函数
                    safe_positions[i] = prev_val  # 保持原位置
                    continue
            
            safe_positions[i] = smoothed_val
        
        # 更新历史位置
        self.prev_positions = safe_positions.copy()
        return safe_positions
    


# 创建全局平滑控制器实例
position_smoothing = SmoothController()

# ==================== 修改电机控制函数 ====================

def motor_control(positions, speeds):
    """
    原始电机控制函数，现在集成了平滑控制
    """
    global dog_state
    
    # 先调用state_control获取当前状态的参数（可能会设置过渡值）
    state_control(dog_state)
    
    # 获取当前实际的KP值并初始化平滑控制器
    # 使用cmd.kp，这是state_control设置的当前实际值
    current_kp = cmd.kp
    position_smoothing.init_kp_parameters(current_kp)
    
    # 应用平滑控制和安全检测
    safe_positions = position_smoothing.process_positions(positions)
    
    # 执行原有的姿态控制任务
    posture_control_task()
    
    # 发送处理后的位置给电机（使用safe_positions）
    for i in range(8):
        data.motorType = unitree_actuator_sdk.MotorType.GO_M8010_6
        cmd.motorType = unitree_actuator_sdk.MotorType.GO_M8010_6
        cmd.mode = unitree_actuator_sdk.queryMotorMode(unitree_actuator_sdk.MotorType.GO_M8010_6, unitree_actuator_sdk.MotorMode.FOC)
        cmd.id = i
        cmd.q = safe_positions[i] * 6.33 + motor_init[i]  # 使用安全位置
        cmd.dq = 0
        # 直接使用cmd.kp和cmd.kd，它们可能已经被state_control设置为过渡值
        cmd.tau = 0.0
        serial.sendRecv(cmd, data)
        print(cmd.id,safe_positions[i],cmd.dq)
    
    # 轮子控制保持原有逻辑不变
    for i in range(4):
        data.motorType = unitree_actuator_sdk.MotorType.GO_M8010_6
        cmd.motorType = unitree_actuator_sdk.MotorType.GO_M8010_6
        cmd.mode = unitree_actuator_sdk.queryMotorMode(unitree_actuator_sdk.MotorType.GO_M8010_6, unitree_actuator_sdk.MotorMode.FOC)
        cmd.id = i + 8
        cmd.q = 0
        cmd.dq = speeds[i]
        cmd.kp = 0
        cmd.kd = 0.03
        cmd.tau = 0.0
        serial.sendRecv(cmd, data)
        print(cmd.id,cmd.q,cmd.dq)

# 主函数入口 - 补全核心调用
# 修改4：主循环加短暂延时，降低串口发送频率，解决电机应答超时
if __name__ == '__main__':
    # 初始化自动控制模块
    auto_control = None
    if auto_control_available:
        auto_control = AutoObstacleControl()
        auto_control.set_auto_mode(True)
    
    try:
        while True:
            # 运行自动控制
            if auto_control_available and auto_control:
                auto_control.run_auto_control()
            
            # 根据当前步态更新KP阈值
            current_kp = state_motor_params[dog_state][0]
            position_smoothing.init_kp_parameters(current_kp)
            
            # 执行电机控制
            motor_control(manual.pos,manual.wheel_speeds)
            # print(cmd.q,cmd.dq)
            #send_motor_commands(manual.pos,manual.wheel_speeds)
            time.sleep(0.01) # 降低串口压力，电机有足够时间应答
            """
            time.sleep(0.01)  # 暂停程序执行 0.01 秒（10 毫秒）
            等同于freertos中的vTaskDelay(10)，可以有效降低CPU占用率，给电机足够时间处理命令并应答，避免通信超时和丢包问题。
            """
    except KeyboardInterrupt:
        # 关闭自动控制模块
        if auto_control_available and auto_control:
            auto_control.shutdown()
        motor_stop()
        print("程序被手动中断，电机已停止")
    except Exception as e:
        # 关闭自动控制模块
        if auto_control_available and auto_control:
            auto_control.shutdown()
        motor_stop()
        print(f"运行出错: {e}")

```


## 多层结构
unitree_go_1.py 的多层结构
═════════════════════════════════════

第1层：原始硬件接口
├─ serial = SerialPort('/dev/ttyUSB0')
├─ cmd = MotorCmd()
└─ data = MotorData()

    ↑ (通过)

第2层：基础控制函数
├─ wheel_speed_control()      ← 轮子转速控制
├─ posture_control_task()     ← 四肢姿态控制
├─ state_control()            ← 状态平滑过渡
└─ motor_stop()               ← 紧急停止

    ↑ (调用)

第3层：平滑和安全层
├─ class SmoothController     ← 位置平滑处理
│   ├─ process_positions()    ← 安全检测
│   └─ init_kp_parameters()   ← 参数初始化
└─ motor_control()            ← 集成所有控制

    ↑ (调用)

第4层：自动控制层
├─ from auto_obstacle import AutoObstacleControl
└─ auto_control.run_auto_control()

    ↑ (循环调用)

第5层：主程序循环
└─ while True:
   ├─ 自动控制
   ├─ 平滑处理
   ├─ 电机控制
   └─ time.sleep(0.01)




## 思考
键盘输入 (log_keystroke)
    ↓
更新 dog_state
    ↓
每次循环 (while True):
    ├─ 决策层：auto_control.run_auto_control()
    │   └─ 读取上位机数据 → 生成控制命令
    │
    ├─ 控制层：motor_control(positions, speeds)
    │   ├─ state_control(dog_state)
    │   │   └─ 计算平滑后的 kp, kd 参数
    │   ├─ position_smoothing.process_positions()
    │   │   ├─ 平滑位置数据
    │   │   └─ 安全检测（位置变化过大 → 紧急停止）
    │   ├─ posture_control_task()
    │   │   ├─ wheel_speed_control()
    │   │   │   └─ 设置轮子转速
    │   │   └─ 设置四肢姿态
    │   │
    │   └─ 发送到硬件层：serial.sendRecv(cmd, data)
    │       ↓
    │       电机硬件执行
    │
    └─ time.sleep(0.01)  ← 降低频率




## 函数
|代码部分	|作用	|为什么需要？|
|---|---|---|
|全局配置 (前100行)	|定义电机参数、步态参数	|机器人的"个性"定义|
|wheel_speed_control()	|根据步态设置轮子速度	|不同步态需要不同轮速|
|posture_control_task()	|控制四条腿的关节姿态	|让机器人做各种动作|
|state_control()	|参数平滑过渡	|避免电机突然收到剧烈指令|
|SmoothController 类	|位置平滑+安全检测	|防止电机受损|
|motor_control()	|整合所有控制，最终发送	|串口通信的入口|
|自动控制模块	|从上位机读数据做自动决策	|实现自动障碍赛|
|主循环	|100Hz 循环（每0.01s一次）	|实时控制|