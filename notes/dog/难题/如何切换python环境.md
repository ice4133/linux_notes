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