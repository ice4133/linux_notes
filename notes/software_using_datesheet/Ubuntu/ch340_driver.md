sudo apt remove --purge brltty

重启ubuntu


观察是否有 /dev/ttyUSB0 设备

# 如何查看ch340信息

sudo minicom -D /dev/ttyUSB0 -b 115200


# 用自己的电脑如何查看打印数据

没有usb的情况下，根本没有ttyUSB0

这个时候就需要下载虚拟串口了

```bash
sudo apt intall socat

socat -d -d PTY,link=/tmp/ttyV0,raw,echo=0 PTY,link=/tmp/ttyV1,raw,echo=0

# 这条命令会创建两个虚拟设备：/tmp/ttyV0 和 /tmp/ttyV1


# 然后再输入这个命令就可以查看了
minicom -D /dev/ttyUSB0 -b 115200
```