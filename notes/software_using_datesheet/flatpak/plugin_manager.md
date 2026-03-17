# 如何配置好插件管理器
因为不能使用原生的插件管理器

于是选择使用flatpak


先删除之前的

sudo apt purge gnome-shell-extension-manager
sudo apt autoremove


下载flatpak
确保有 flatpak 环境
sudo apt install flatpak

添加 flathub 仓库
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

安装管理器
flatpak install flathub com.mattjakeman.ExtensionManager