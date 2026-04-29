sudo nano /etc/default/grub

GRUB_CMDLINE_LINUX_DEFAULT="quiet splash isolcpus=15"

// 更新并且重启系统
sudo update-grub
sudo reboot


# 查询cpu个数
lscpu


# 查看主频
grep "cpu MHz" /proc/cpuinfo

grep -i "mhz" /proc/cpuinfo

# 查看cpu实时负载

sudo apt install htop

htop


