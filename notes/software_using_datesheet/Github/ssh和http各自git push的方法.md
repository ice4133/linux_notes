对于自己的账号，克隆到本地，在本地git push
有两条路径可走

# http（麻烦）

## 介绍
需要username和password
需要知晓的是username就是ice4133,对于这个需要记住

password，截至目前2026年，对于有密码严格要求性的，现在都是token而并非单纯密码了
就比如onenet进行登录产品，必须要用你的一些product id和device id 等生成一个一段时间成立的token，这个我们一般认为是临时密码，优点是不容易被盗窃

言归正传，也就是说，想要通过http登录github，必须要有所谓的token，也就是它显示的password，这个区别于登录密码，我认为应该把登录密码等同于onenet中的product id等

## 具体如何git push

生成并使用个人访问令牌 (PAT) —— 最快
你可以把这个令牌理解为专门给 Git 命令行使用的“临时密码”。

生成令牌：

1. 登录 GitHub 网页版，点击右上角头像 -> Settings。

2. 左侧菜单拉到最下面，点击 Developer settings。

3. 选择 Personal access tokens -> Tokens (classic)。

4. 点击 Generate new token (classic)。

额外 ：在手机端打开authentication，输入6个数字，这个是2fa（二次认证）

5. 在 Note 随便填个名字（比如 linux-pc），Expiration 建议选 90 天或更久。

6. 勾选权限： 至少勾选 repo（全选）和 workflow。

7. 点击最下方的 Generate token。

重要： 复制生成的那个以 ghp_ 开头的长字符串，关掉网页就再也看不到了。

# ssh (简单)

只需要clone下来，就可以了

但是有一个非常致命的问题，校园网的流量好像不可以让它git push