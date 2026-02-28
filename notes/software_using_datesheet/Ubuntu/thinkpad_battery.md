# 虚电问题
我发现如果一直给thinkpad充电，它会有大量虚电进行自我保护，无法开机，必须强制重启

# 解决思路（此为解决方法之一）
因为查到的结果是，我的thinkpad电池容量只有90%了，而充电却不充电到100,不会停止，那么多出来的10,导致电池压力很大，最后进入电池保护

那么只需要软件设置中，进行设置，如果高于90,那就不充电，低于85,那就充电

# 具体解决流程

+ 下载软件
```
sudo apt update
sudo apt install tlp tlp-rdw
```

+ 软件修改
```
sudo nano /etc/tlp.conf
//找到 START_CHARGE_THRESH_BAT0 和 STOP_CHARGE_THRESH_BAT0
//去掉前面的 # 注释符号，修改为 85 和 90
//按 Ctrl+O 保存，Ctrl+X 退出
```


+ 设置生效
```
sudo systemctl enable tlp.service
sudo tlp start
```

+ 设置查询
```
sudo tlp-stat -b
```
