起因：ubuntu22.04默认python3版本是3.10，而这个sdk的.so文件是针对python3.8编译的，所以需要切换到python3.8环境，或者重新编译这个sdk生成一个适合python3.10的.so文件。
不只这一个点，其余导入的库也要考虑兼容性

去找rc的人
```
souce /opt/ros/humble/setup.bash

python3 --version

# 看下他们的版本
# 还有就是launch中的电机固定版本的python版本，改成3.10
```


还有就是好像就只有python3.8的宇数sdk


好像ubuntu默认的是python2啊



方法：
了解到


sudo apt install software-properties-common -y
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install python3.8 -y


实际上跑的时候，如果你是通过 python3.8 motor_init.py 运行，它确实在跑 3.8；但如果是通过 ros2 run 运行，除非你修改了大量的底层配置，否则它极大概率还是在尝试调用 3.10。