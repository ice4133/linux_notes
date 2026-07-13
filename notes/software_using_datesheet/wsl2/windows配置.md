# 第一步 windows配置vpn


# 第二步 下载wsl2 本体
打开powershell 管理员

```
# 输入

wsl --install --no-distribution --web-download

```

下载完成后重启
```
# 更新
wsl --update

# 设置默认版本为2 
wsl --set-default-version 2

# 查看可用的Linux发行版
wsl --list --online

```
# 第三步 安装Linux发行版
```
# 以下命令行就不要修改了，都默认下到D盘
# 创建文件夹
New-Item -ItemType Directory -Force D:\WSL\Ubuntu-22.04

# 下载linux发行版
wsl --install -d Ubuntu-22.04 --location D:\WSL\Ubuntu-22.04
```

# 第四步 linux获取windows的vpn


## 修改防火墙规则
```
# 具体命令肯定不同，具体细节可以ai修改


# 打开powershell 管理员 修改防火墙，让wsl2可以访问经过防火墙windows的vpn

New-NetFirewallRule -DisplayName "Clash Verge for WSL2" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 7897 -RemoteAddress 172.16.0.0/12


# 进入wsl
wsl ~

# 获取ip地址
WIN_HOST=$(ip route | awk '/default/ {print $3; exit}')

echo $WIN_HOST

curl -I --connect-timeout 5 -x http://$WIN_HOST:7897 https://www.google.com

# 如果返回200就说明可以访问了


```


## 永久生效

vim .bashrc

```
WIN_HOST=$(ip route | awk '/default/ {print $3; exit}')
export http_proxy="http://$WIN_HOST:7897"
export https_proxy="http://$WIN_HOST:7897"
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"

```
source .bashrc