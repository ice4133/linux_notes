# simulink无法打开

export QT_QPA_PLATFORM=xcb

原因是因为为了配置ros环境，我直接在.bashrc中export QT_QPA_PLATFORM=wayland,可是要启动simulink必须以xcb进行配置
所以simulink进程被杀死

解决方法：
```bash
vim ~/.bashrc

# 添加以下代码
alias matlab='QT_QPA_PLATFORM=xcb ~/Apps/matlab/bin/matlab'

source ~/.bashrc

```