winget install --interactive --exact dorssel.usbipd-win


usbipd list


usbipd bind --busid 2-3

//从这之后，普通管理员权限的powershell就可以使用usbipd attach --wsl --busid 2-3了

usbipd attach --wsl --busid 2-3


这里的2-3是usbipd list中显示的busid，注意每次重启后都需要重新绑定和连接