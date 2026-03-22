sudo apt remove --purge brltty

重启ubuntu


观察是否有 /dev/ttyUSB0 设备

# 如何查看ch340信息

sudo minicom -D /dev/ttyUSB0 -b 115200