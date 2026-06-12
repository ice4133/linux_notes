1. 生成新的 Token (PAT)
登录 GitHub 网页端，点击右上角的个人头像，在下拉菜单中选择 Settings (设置)。

滚动左侧导航栏到最底部，点击 Developer settings (开发者设置)。

在左侧菜单中展开 Personal access tokens，推荐选择 Tokens (classic) （经典令牌，配置最简单直接）。

点击右上角的 Generate new token，选择 Generate new token (classic)。

填写配置信息：

Note (备注)：随便写，比如填个标识方便你记住在哪台电脑上用（例如 "Ubuntu Dev Token"）。

Expiration (过期时间)：你可以继续选择 90 days（3个月），或者为了方便选择更长的时间（比如 1 年）。也有 "No expiration"（永不过期）的选项，但出于安全考虑官方不推荐。

Select scopes (权限范围)：这是最关键的一步。为了能正常拉取 (clone) 和推送 (push) 你的代码仓库，必须勾选 repo 这一项主菜单（它会自动勾选下面相关的全套仓库权限）。

滚动到页面最底部，点击绿色的 Generate token 按钮。