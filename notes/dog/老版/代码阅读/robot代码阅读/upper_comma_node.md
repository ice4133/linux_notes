# 工作流程
上位机发送 JSON 数据
    ↓
订阅 'upper_data' topic
    ↓
回调函数解析 JSON
    ↓
更新 latest_data 字典
    ↓
其他节点通过 get_latest_data() 获取数据


比如unitree_go_1.py中的auto_control.run_auto_control()函数会调用upper_comms_node.get_latest_data()来获取上位机数据，并根据这些数据进行决策控制和电机命令执行


# 函数功能
|功能|	说明|
|---|---|
|订阅数据	|监听 upper_data topic，接收来自上位机的 JSON 格式消息|
|数据解析	|将 JSON 字符串转换为结构化数据|
|数据存储	|维护 latest_data 字典，始终保存最新接收的数据|
|数据提供	|通过 get_latest_data() 方法供其他节点使用|
|错误处理	|捕获 JSON 解析异常并记录日志|


# 在整个工程中的角色
上位机（视觉/路径规划系统）
         ↓
    UpperCommsNode
         ↓
下层控制节点（motor_init、unittree_go_1 等）


🔌 通信接口：建立上位机与机器人控制系统的数据通道
📊 实时数据采集：接收视觉识别、距离检测、二维码扫描结果
🎯 决策支持：为障碍避免、自主导航提供上位机的环境感知数据
🔄 数据转接：将上位机的高层决策转换成下层控制能理解的格式