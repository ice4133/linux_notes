```python

#!/usr/bin/env python3.8
import rclpy
import time
import threading
from upper_comms_node import UpperCommsNode, UpperData
from decision_control import DecisionControl, ControlCommand
import manual

class AutoObstacleControl:
    """
    自动障碍控制模块
    集成上位机数据和决策控制，实现自动完成障碍赛任务
    """
    def __init__(self):
        # 初始化ROS2节点
        rclpy.init()
        
        # 初始化上位机通信节点
        self.upper_comms_node = UpperCommsNode()
        
        # 初始化决策控制模块
        self.decision_control = DecisionControl()
        
        # 初始化状态
        self.auto_mode = False
        self.current_state = "idle"
        
        # 启动ROS2自旋线程
        self.spin_thread = threading.Thread(target=self.spin_node)
        self.spin_thread.daemon = True
        self.spin_thread.start()
        
        print("Auto obstacle control initialized")
    
    def spin_node(self):
        """
        启动ROS2节点自旋
        """
        rclpy.spin(self.upper_comms_node)
    
    def set_auto_mode(self, enable):
        """
        设置自动模式
        """
        self.auto_mode = enable
        if enable:
            print("Auto mode enabled")
            self.current_state = "auto_active"
        else:
            print("Auto mode disabled")
            self.current_state = "idle"
    
    def run_auto_control(self):
        """
        运行自动控制

            auto_control.run_auto_control()
              ├─ 获取上位机数据
              ├─ 决策控制处理
              └─ 执行电机控制命令        
        """
        if not self.auto_mode:
            return
        
        # 获取最新的上位机数据
        upper_data_dict = self.upper_comms_node.get_latest_data()
        upper_data = UpperData(upper_data_dict)
        
        # 处理数据并生成控制命令
        cmd = self.decision_control.process_upper_data(upper_data)
        
        # 执行控制命令
        self.execute_control_command(cmd)
        
        # 更新状态
        self.current_state = self.decision_control.get_state()
    
    def execute_control_command(self, cmd):
        """
        执行控制命令
        """
        # 根据左右轮速度和模式设置相应的状态
        if cmd.mode == "wheel":
            # 纯轮式模式
            if cmd.left_speed > 0 and cmd.right_speed > 0:
                # 前进
                manual.dog_state = manual.States.TROT_WHEEL
            elif cmd.left_speed < 0 and cmd.right_speed < 0:
                # 后退
                manual.dog_state = manual.States.TROT_BACK
            else:
                # 其他情况保持当前状态
                pass
        elif cmd.mode == "gait":
            # 足式步态模式
            if cmd.left_speed > 0 or cmd.right_speed > 0:
                # 前进或转向
                manual.dog_state = manual.States.TROT
            elif cmd.left_speed < 0 or cmd.right_speed < 0:
                # 后退
                manual.dog_state = manual.States.TROT_BACK
            else:
                # 停止
                manual.dog_state = manual.States.STOP
        
        # 设置轮子速度（使用差速转向）
        # 左前轮和左后轮使用左侧速度
        # 右前轮和右后轮使用右侧速度
        # 注意：右轮速度取负值，因为右轮是反向安装的
        manual.set_target_wheel_speeds(cmd.left_speed, -cmd.right_speed, cmd.left_speed, -cmd.right_speed)
        
        # 更新轮子速度
        manual.update_wheel_speeds(0.1)
    
    def get_state(self):
        """
        获取当前状态
        """
        return self.current_state
    
    def reset(self):
        """
        重置状态
        """
        self.decision_control.reset()
        self.current_state = "idle"
    
    def shutdown(self):
        """
        关闭节点
        """
        self.upper_comms_node.destroy_node()
        rclpy.shutdown()
        print("Auto obstacle control shutdown")

if __name__ == '__main__':
    auto_control = AutoObstacleControl()
    
    try:
        # 启用自动模式
        auto_control.set_auto_mode(True)
        
        # 运行自动控制
        while True:
            auto_control.run_auto_control()
            time.sleep(0.01)
    except KeyboardInterrupt:
        auto_control.shutdown()
        print("Program terminated")

```



# unittree_go_1.py 调用
```python

if __name__ == '__main__':
    # 初始化自动控制模块
    auto_control = None
    if auto_control_available:
        auto_control = AutoObstacleControl() # 实例化对象
        """
    │        └─→ __init__() 方法自动执行
    │            ├─ 初始化ROS2
    │            ├─ 创建通信节点
    │            ├─ 创建决策控制模块
    │            └─ 启动后台自旋线程
        """
        auto_control.set_auto_mode(True) # 启用自动模式
    
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