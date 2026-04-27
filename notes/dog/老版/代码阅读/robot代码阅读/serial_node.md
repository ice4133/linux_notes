```python

#!/usr/bin/env python3
import struct
import time
import rclpy
import threading
import sys
import os
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy
from std_msgs.msg import Float32MultiArray
from unitree_legged_msgs.msg import MotorState

try:
    import serial
    from serial import Serial, SerialException
except ImportError:
    print("请安装 pyserial 库: sudo apt install python3-serial 或 pip3 install pyserial")
    exit(1)

last_print_time = time.time()
print_interval = 0.01 

# 检查Ubuntu版本兼容性
def check_system_compatibility():
    """检查系统兼容性"""
    try:
        with open('/etc/os-release', 'r') as f:
            os_release = f.read()
            if '22.04' not in os_release:
                print("警告: 该脚本优化用于Ubuntu 22.04，当前系统版本可能不兼容")
        return True
    except Exception as e:
        print(f"系统兼容性检查失败: {e}")
        return True

class SerialCommunicationNode(Node):
    def __init__(self):
        super().__init__("unitree_serial_communication")
        
        # 串口相关变量
        self.serial_port = None
        self.is_connected = False
        self.receive_thread = None
        self.receive_callback = None
        self.receive_buffer = b''
        self._thread_exit_flag = False
        
        # 电机数据存储
        self.motor_states = [[0.0] * 5 for _ in range(16)]  # 16个电机，每个5个状态参数
        self.motor_commands = [None] * 16  # 存储16个电机的命令
        self.motor_last_full_cmd = [None] * 16  # 记录每个电机最后接收的完整命令
        
        # 调试计数器
        self.callback_counter = 0
        self.last_debug_time = time.time()
        self.last_print_time = time.time()
        
        # ROS2 QoS配置（适配实时控制场景）
        self.qos_profile = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            history=HistoryPolicy.KEEP_LAST,
            depth=10
        )
        
        # 声明参数
        self.declare_parameter("port", "/dev/ttyUSB0")
        self.declare_parameter("baudrate", 921600)
        self.declare_parameter("serial_timeout", 1.0)
        
        # 获取参数
        self.port = self.get_parameter("port").value
        self.baudrate = self.get_parameter("baudrate").value
        self.serial_timeout = self.get_parameter("serial_timeout").value
        
        # 初始化ROS2发布器和订阅器
        self._init_ros2_publishers_subscribers()
        
        # 连接串口
        self.get_logger().info(f"尝试连接串口: {self.port}, 波特率: {self.baudrate}")
        if self.connect():
            self.get_logger().info("串口通信节点已启动，等待ROS2电机命令...")
        else:
            self.get_logger().error("串口连接失败，节点启动失败")
            sys.exit(1)
    
    def _init_ros2_publishers_subscribers(self):
        """初始化ROS2发布器和订阅器"""
        motor_names = [
            "FR_hip_joint", "FR_thigh_joint", "FR_calf_joint",
            "FL_hip_joint", "FL_thigh_joint", "FL_calf_joint",  
            "RR_hip_joint", "RR_thigh_joint", "RR_calf_joint", 
            "RL_hip_joint", "RL_thigh_joint", "RL_calf_joint",
            "joint_12","joint_13","joint_14","joint_15"
        ]
        
        self.get_logger().info("开始初始化ROS2发布器和订阅器...")
        
        # 初始化电机状态发布器（每个电机一个话题）
        self.motor_state_pubs = [None] * 16
        
        for i, motor_name in enumerate(motor_names):
            # 电机状态发布器
            state_topic = f"/motor_state/{motor_name}"
            self.motor_state_pubs[i] = self.create_publisher(
                MotorState, state_topic, self.qos_profile
            )
            
            # 电机命令订阅器
            cmd_topic = f"/real_robot/motor_cmd_{motor_name}"
            self.create_subscription(
                Float32MultiArray,
                cmd_topic,
                lambda msg, idx=i: self.motor_cmd_callback(msg, idx),

                # lambda [参数列表]: [函数体]
                # lambda 的参数列表中的第一个参数默认就是订阅获得的消息，后面可以添加其他参数，这些参数在lambda函数被调用时会被传入
                self.qos_profile
            )
            # lambda [参数列表]: [函数体]
            self.get_logger().info(f"订阅话题: {cmd_topic}")
        
        # 电机状态数组发布器（汇总所有电机状态）
        self.motor_state_array_pub = self.create_publisher(
            Float32MultiArray, "/motor_states", QoSProfile(depth=20)
        )
        
        # 调试信息定时器（1Hz）
        self.debug_timer = self.create_timer(1.0, self.publish_debug_info)
        
        self.get_logger().info("ROS2发布器和订阅器初始化完成")
    
    def connect(self):
        """连接串口"""
        # 检查串口权限
        self._check_serial_permissions()
        
        try:
            self.serial_port = Serial(
                port=self.port,
                baudrate=self.baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=self.serial_timeout,
                write_timeout=0.5
            )
            self.is_connected = True
            self._thread_exit_flag = False
            
            # 清空缓冲区
            self.serial_port.reset_input_buffer()
            self.serial_port.reset_output_buffer()
            
            # 启动接收线程
            self.receive_thread = threading.Thread(target=self._receive_data)
            self.receive_thread.daemon = True
            self.receive_thread.start()
            
            self.get_logger().info(f"已连接到串口: {self.port}")
            return True
            
        except SerialException as e:
            self.get_logger().error(f"连接串口失败: {e}")
            self.get_logger().error("可能的解决方法:")
            self.get_logger().error(f"1. 检查串口是否存在: ls {self.port}")
            self.get_logger().error(f"2. 添加串口权限: sudo chmod 666 {self.port}")
            self.get_logger().error("3. 将用户添加到dialout组: sudo usermod -aG dialout $USER (需要注销重新登录)")
            self.get_logger().error(f"4. 检查是否有其他程序占用串口: lsof | grep {self.port}")
            return False
    
    def _check_serial_permissions(self):
        """检查串口权限"""
        try:
            if os.path.exists(self.port):
                if not os.access(self.port, os.R_OK | os.W_OK):
                    self.get_logger().warn(f"串口 {self.port} 没有读写权限")
                    self.get_logger().warn("尝试自动添加权限...")
                    try:
                        os.system(f"sudo chmod 666 {self.port}")
                        #time.sleep(0.1)
                        if os.access(self.port, os.R_OK | os.W_OK):
                            self.get_logger().info(f"成功添加 {self.port} 读写权限")
                        else:
                            self.get_logger().error(f"添加权限失败，请手动执行: sudo chmod 666 {self.port}")
                    except Exception as e:
                        self.get_logger().error(f"添加权限时出错: {e}")
            else:
                self.get_logger().warn(f"串口设备 {self.port} 不存在")
        except Exception as e:
            self.get_logger().warn(f"检查串口权限失败: {e}")
    
    def publish_debug_info(self):
        """定期发布调试信息（ROS2定时器回调）"""
        if not self.is_connected:
            return
    
    def _print_motor_commands_summary(self):
        """每2秒打印一次电机命令汇总"""
        current_time = time.time()
        if current_time - self.last_print_time >= 2.0:
            self.last_print_time = current_time
            
            self.get_logger().info("=== 电机命令数据汇总 (每2秒更新) ===")
            for i in range(16):
                if self.motor_commands[i] is not None:
                    cmd = self.motor_commands[i]
                    self.get_logger().info(
                        f"电机{i}: q: {cmd['q']:.3f}, dq: {cmd['dq']:.3f}, "
                        f"tau: {cmd['tau']:.3f}, mode: {cmd['mode']}"
                    )
                else:
                    self.get_logger().info(f"电机{i}: 无数据")
            self.get_logger().info("=====================================")
    
    def motor_cmd_callback(self, msg: Float32MultiArray, motor_id: int):
        """电机命令回调函数"""
        self.callback_counter += 1
        
        # 定期打印汇总信息
        self._print_motor_commands_summary()
        
        current_time = time.time()
        if current_time - self.last_debug_time > 2.0:
            self.get_logger().info(
                f"[DEBUG] 收到电机 {motor_id} 的命令，数据长度: {len(msg.data)}"
            )
            self.get_logger().info(
                f"[RAW DATA] 电机 {motor_id} 原始数据: {[round(x, 3) for x in msg.data]}"
            )
            self.last_debug_time = current_time
        
        if len(msg.data) >= 6:
            cmd = {
                'mode': int(msg.data[0]),
                'tau': msg.data[1],
                'q': msg.data[2],
                'dq': msg.data[3],
                'kp': msg.data[4],
                'kd': msg.data[5]
            }
            self.motor_commands[motor_id] = cmd
            self.motor_last_full_cmd[motor_id] = cmd
            
            if current_time - self.last_debug_time > 2.0:
                self.get_logger().info(
                    f"[PROCESSED] 电机 {motor_id} 命令: mode={cmd['mode']}, "
                    f"q={cmd['q']:.3f}, dq={cmd['dq']:.3f}, tau={cmd['tau']:.3f}"
                )
            
            # 立即发送命令
            self._send_motor_command(motor_id, cmd)
            # time.sleep(0.005)
        else:
            self.get_logger().warn(
                f"电机 {motor_id} 命令数据长度不足: {len(msg.data)}，期望6个参数"
            )
    
    def _send_motor_command(self, motor_id: int, cmd: dict):
        """发送单个电机命令"""
        if not self.is_connected or not self.serial_port:
            self.get_logger().error("串口未连接，无法发送命令")
            return
        
        # 解析命令参数
        mode_val = int(cmd['mode'])
        q_val = cmd['q']
        dq_val = cmd['dq']
        kp_val = cmd['kp']
        kd_val = cmd['kd']
        tau_val = cmd['tau']
        
        # 构建模式字节
        id_val = (mode_val >> 4) & 0x0F
        status_val = (mode_val >> 1) & 0x07
        none_val = mode_val & 0x01
        print(f"电机 {motor_id} - id,state,none {id_val} {status_val} {none_val}")
        
        # 发送命令数据包
        success = self.send_control_packet(
            id_val, status_val, none_val,
            tau_val, q_val, dq_val,
            kp_val, kd_val
        )
        #time.sleep(0.01)
        if success:
            self.get_logger().info(
                f"发送电机 {motor_id} 命令: 位置={q_val:.3f}, 速度={dq_val:.3f}, 力矩={tau_val:.3f},KP={kp_val},kd={kd_val}"
            )
        else:
            self.get_logger().error(f"发送电机 {motor_id} 命令失败")
    
    def _send_motor_stop_cmd_serial(self, motor_id: int):
        """通过串口发送单个电机停止命令（无ROS2依赖）"""
        # 跳过未接收过命令的电机
        last_cmd = self.motor_last_full_cmd[motor_id]
        if last_cmd is None:
            print(f"[停止命令] 电机 {motor_id} 未接收过命令，跳过")
            return
        
        # 构建停止命令（mode保留，其余参数置0）
        stop_cmd = {
            'mode': last_cmd['mode'],
            'tau': 0.0,
            'q': 0.0,
            'dq': 0.0,
            'kp': 0.0,
            'kd': 0.0
        }
        
        # 直接调用串口发送逻辑，不使用ROS2日志
        mode_val = int(stop_cmd['mode'])
        id_val = (mode_val >> 4) & 0x0F
        status_val = (mode_val >> 1) & 0x07
        none_val = mode_val & 0x01
        
        # 发送停止数据包
        success = self.send_control_packet(
            id_val, status_val, none_val,
            stop_cmd['tau'], stop_cmd['q'], stop_cmd['dq'],
            stop_cmd['kp'], stop_cmd['kd']
        )
        
        if success:
            print(f"[停止命令] 电机 {motor_id} 发送完成: mode={stop_cmd['mode']}, 停止命令:{stop_cmd}")
        else:
            print(f"[停止命令] 电机 {motor_id} 发送失败")
    
    def send_all_motors_stop_cmd(self):
        """发送所有电机停止命令（纯串口+原生print，无ROS2依赖）"""
        print("\n=== 开始发送所有电机停止命令（串口直接发送）===")
        
        # 统计已接收命令的电机数量
        valid_motor_count = sum(1 for cmd in self.motor_last_full_cmd if cmd is not None)
        print(f"共有 {valid_motor_count}/16 个电机接收过命令，将发送停止包")
        
        # 遍历所有电机，逐一发送停止命令
        for motor_id in range(16):
            if self.motor_last_full_cmd[motor_id] is not None:
                # 连续发送3次，确保电机收到
                for _ in range(3):
                    self._send_motor_stop_cmd_serial(motor_id)
                    time.sleep(0.01)
                #time.sleep(0.005)
        
        print("=== 所有电机停止命令发送完成 ===\n")
    
    def create_control_packet(self, id_val: int, status_val: int, none_val: int,
                             control_t: float, control_pos: float, control_speed: float,
                             control_kp: float, control_kw: float) -> bytes:
        """构建控制数据包"""
        mode_byte = (none_val << 7) | (status_val << 4) | (id_val & 0x0F)
        #print(f"mode_byte {mode_byte}")
        packet = (
            b'\xFF\xAA' +                           # 包头
            bytes([mode_byte]) +                    # 模式字节
            struct.pack('<f', control_t) +          # 力矩
            struct.pack('<f', control_pos) +        # 位置
            struct.pack('<f', control_speed) +      # 速度 
            struct.pack('<f', control_kp) +         # 刚度Kp
            struct.pack('<f', control_kw) +         # 阻尼Kd
            b'\xBB\xCC'                             # 包尾
        )
        return packet
    
    def send_control_packet(self, id_val: int, status_val: int, none_val: int,
                           control_t: float, control_pos: float, control_speed: float,
                           control_kp: float, control_kw: float) -> bool:
        """发送控制数据包"""
        try:
            if not self.serial_port or not self.serial_port.is_open:
                print("[串口错误] 串口未打开，无法发送数据")
                return False
            
            packet = self.create_control_packet(
                id_val, status_val, none_val,
                control_t, control_pos, control_speed,
                control_kp, control_kw
            )
            
            
            self.bytes_written = self.serial_port.write(packet)
            self.serial_port.flush()
           
            return self.bytes_written == len(packet)
            
        except SerialException as e:
            print(f"[串口错误] 发送数据失败: {e}")
            self._reconnect_serial()
            return False
        except Exception as e:
            print(f"[串口错误] 发送数据异常: {e}")
            return False
    
    def _reconnect_serial(self):
        """串口断线重连"""
        print("[串口重连] 尝试重新连接串口...")
        try:
            if self.serial_port and self.serial_port.is_open:
                self.serial_port.close()
            
            time.sleep(1.0)
            self.serial_port.open()
            self.serial_port.reset_input_buffer()
            self.serial_port.reset_output_buffer()
            print("[串口重连] 串口重新连接成功")
            return True
        except Exception as e:
            print(f"[串口重连] 失败: {e}")
            return False
    
    def _receive_data(self):
        """串口接收线程"""
        self.get_logger().info("串口接收线程已启动")
        
        # while self.is_connected and not self._thread_exit_flag and rclpy.ok():
        #     try:
        #         if not self.serial_port or not self.serial_port.is_open:
        #             self.get_logger().warn("串口未打开，等待重连...")
        #             time.sleep(1.0)
        #             continue
                
        #         if self.serial_port.in_waiting > 0:
        #             data = self.serial_port.read(self.serial_port.in_waiting)
        #             self.receive_buffer += data
        #             self.get_logger().debug(
        #                 f"接收 {len(data)} 字节，缓冲区总长度: {len(self.receive_buffer)}"
        #             )
                    
        #             while len(self.receive_buffer) >= 17:
        #                 start_idx = self.receive_buffer.find(b'\xFF\xAA')
        #                 if start_idx == -1:
        #                     self.get_logger().debug("未找到包头，清空缓冲区")
        #                     self.receive_buffer = b''
        #                     break
                        
        #                 if start_idx > 0:
        #                     self.get_logger().debug(f"移除包头前 {start_idx} 字节无效数据")
        #                     self.receive_buffer = self.receive_buffer[start_idx:]
                        
        #                 if len(self.receive_buffer) >= 17:
        #                     packet = self.receive_buffer[:17]
                            
        #                     if packet[15:17] == b'\xBB\xCC':
        #                         self._process_received_packet(packet)
        #                         self.receive_buffer = self.receive_buffer[17:]
        #                     else:
        #                         self.get_logger().debug("包尾不匹配，丢弃第一个字节")
        #                         self.receive_buffer = self.receive_buffer[1:]
        #                 else:
        #                     break
        #         else:
        #             time.sleep(0.001)
            
            # except SerialException as e:
            #     self.get_logger().error(f"串口接收错误: {e}")
            #     self._reconnect_serial()
            #     time.sleep(0.1)
            # except Exception as e:
            #     self.get_logger().error(f"接收线程异常: {e}")
            #     time.sleep(0.1)
    
    # def _process_received_packet(self, packet: bytes):
    #     """处理接收到的电机状态数据包"""
    #     try:
    #         mode_byte = packet[2]
    #         motor_id = mode_byte & 0x0F
    #         status = (mode_byte >> 4) & 0x07
    #         reserve = (mode_byte >> 7) & 0x01
            
    #         torque = struct.unpack('<f', packet[3:7])[0]
    #         position = struct.unpack('<f', packet[7:11])[0]
    #         speed = struct.unpack('<f', packet[11:15])[0]
            
    #         self.get_logger().info(
    #             f"接收电机 {motor_id} 状态: 位置={position:.3f} rad, "
    #             f"速度={speed:.3f} rad/s, 力矩={torque:.3f} N·m"
    #         )
            
    #         if 0 <= motor_id < 16:
    #             self.motor_states[motor_id][0] = position
    #             self.motor_states[motor_id][1] = speed
    #             self.motor_states[motor_id][2] = 0.0
    #             self.motor_states[motor_id][3] = torque
    #             self.motor_states[motor_id][4] = mode_byte
            
    #         self._publish_motor_state_array()
    #         self._publish_single_motor_state(motor_id, mode_byte, position, speed, torque)
            
    #         if self.receive_callback:
    #             parsed_data = {
    #                 'id': motor_id, 'status': status, 'reserve': reserve,
    #                 'position': position, 'speed': speed, 'torque': torque
    #             }
    #             self.receive_callback(packet, parsed_data)
                
        # except struct.error as e:
        #     self.get_logger().error(f"解析数据包失败: {e}")
        # except Exception as e:
        #     self.get_logger().error(f"处理数据包异常: {e}")
    
    def _publish_motor_state_array(self):
        """发布所有电机状态的数组消息"""
        msg = Float32MultiArray()
        msg.data = []
        for state in self.motor_states:
            msg.data.extend(state)
        self.motor_state_array_pub.publish(msg)
    
    def _publish_single_motor_state(self, motor_id: int, mode: int,
                                   position: float, speed: float, torque: float):
        """发布单个电机的MotorState消息"""
        if 0 <= motor_id < 16 and self.motor_state_pubs[motor_id] is not None:
            msg = MotorState()
            msg.mode = mode
            msg.q = position
            msg.dq = speed
            msg.tau_est = torque
            msg.q_raw = 0.0
            msg.dq_raw = 0.0
            msg.ddq_raw = 0.0
            msg.temperature = 0
            msg.reserve = [0, 0]
            
            self.motor_state_pubs[motor_id].publish(msg)
    
    def set_receive_callback(self, callback):
        """设置自定义接收回调函数"""
        self.receive_callback = callback
    
    def disconnect(self):
        """断开串口连接（无ROS2日志）"""
        print("正在断开串口连接...")
        
        # 发送停止命令
        self.send_all_motors_stop_cmd()
        
        # 关闭串口
        self.is_connected = False
        self._thread_exit_flag = True
        
        if self.receive_thread and self.receive_thread.is_alive():
            self.receive_thread.join(timeout=2.0)
        
        if self.serial_port and self.serial_port.is_open:
            self.serial_port.close()
        
        print("串口已断开连接")

# 自定义接收回调示例
def custom_receive_callback(raw_packet: bytes, parsed_data: dict):
    """自定义数据包接收回调函数"""
    node = rclpy.get_default_context().get_node("unitree_serial_communication")
    if node:
        node.get_logger().info("=== 自定义回调收到数据 ===")
        node.get_logger().info(f"电机ID: {parsed_data['id']}, 状态: {parsed_data['status']}")
        node.get_logger().info(
            f"位置: {parsed_data['position']:.3f} rad, "
            f"速度: {parsed_data['speed']:.3f} rad/s, "
            f"力矩: {parsed_data['torque']:.3f} N·m"
        )
        node.get_logger().info("=========================")

def main(args=None):
    # 检查系统兼容性
    check_system_compatibility()
    
    # 初始化ROS2
    rclpy.init(args=args)
    context = rclpy.get_default_context()
    node = None
    
    try:
        # 创建节点
        node = SerialCommunicationNode()
        node.set_receive_callback(custom_receive_callback)
        # 这个传参之后，都没有实际调用啊
        # 那数据从哪个回调函数进行传参呢
        
        # 运行节点
        rclpy.spin(node)
    except KeyboardInterrupt:
        print("\n程序被用户中断（Ctrl+C）")
        # 发送停止命令（无ROS2依赖）
        if node:
            node.send_all_motors_stop_cmd()
    except Exception as e:
        print(f"程序异常终止: {e}")
        if node:
            node.send_all_motors_stop_cmd()
    finally:
        # 安全清理资源，避免重复shutdown
        if node:
            node.disconnect()
            node.destroy_node()
        # 检查上下文状态，避免重复shutdown
        if context.ok():
            rclpy.shutdown()
        print("程序已正常退出")

if __name__ == "__main__":
    main()
```



回调函数的启用：
好比单片机中，会有引脚因为上升沿而触发

在ros2中
self.receive_thread = threading.Thread(target=self._receive_data)
启动了线程
假设串口接收到了数据，线程就会调用_receive_data函数
当然触发这个中断还是有条件的
比如连续17个字节，并且前两个字节是0xFF 0xAA，后两个字节是0xBB 0xCC
满足条件了，就会调用_process_received_packet函数
也就是回调函数

这个触发的底层逻辑虽然不如单片机中的中断机制那样直接和硬件相关，但在软件层面上实现了类似的事件驱动机制


物理层：串口有数据到来（线程在监听）   引脚有上升沿
接收层:
解析层：
回调层：调用回调函数
用户层：用户定义的回调函数被调用，处理数据




线程在后台运行
thread = threading.Thread(target=self._receive_data)
thread.start()

主程序可以继续做其他事
rclpy.spin()  # ← 同时执行！


线程在监听，


create_control_packet()  [打包数据]
serial_port.write()      [发送数据]
serial_port.flush()      [确认发出]
self.serial_port.flush()
应用层发送数据的最后一步