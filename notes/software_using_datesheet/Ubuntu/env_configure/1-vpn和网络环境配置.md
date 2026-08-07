# 下载vpn
我已经把clash的deb和exe都放在了u盘里面，可以直接去下载

然后导入，具体教程查看vpn_configure.md

# 下载google

wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

sudo apt install ./google-chrome-stable_current_amd64.deb


下载完成后，必须打开配置，把vpn代理启动

# 下载github和linux_notes必要仓库

github可以直接在google上面直接安装

配置ssh
```bash
sudo apt update
sudo apt install git openssh-client

ssh-keygen -t ed25519 -C "2640552874@qq.com"
# 然后无脑点击ENTER就可以


cd ~/.ssh
vim id_ed25519.pub
# 复制里面的内容，把它添加到github里面


# 配置ssh网络，让它走代理
sudo apt install netcat-openbsd
cd ~/.ssh
vim config

# 输入
Host github.com
    HostName github.com
    User git
    Port 22
    ProxyCommand nc -X 5 -x 127.0.0.1:7897 %h %p
# 7897是要根据具体的端口号来的，但我的clash是7897

chmod 700 ~/.ssh
chmod 600 ~/.ssh/config

# test
ssh -T git@github.com

# 成功后，会显示如下内容
#Hi ice4133! You've successfully authenticated, but GitHub does not provide shell access.



```

配置http
```bash
vim .bashrc

# 输入，然后source 
PORT=7897

export HTTP_PROXY="http://127.0.0.1:$PORT"
export HTTPS_PROXY="http://127.0.0.1:$PORT"
export http_proxy="http://127.0.0.1:$PORT"
export https_proxy="http://127.0.0.1:$PORT"

export NO_PROXY="localhost,127.0.0.1,::1"
export no_proxy="localhost,127.0.0.1,::1"


```

# 必要app
类似vscode 和 qq 和微信 和 飞书什么的，直接去官网下载