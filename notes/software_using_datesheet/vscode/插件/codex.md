必须给codex配置代理

```bash
vim .bashrc



PORT=7897

export HTTP_PROXY="http://127.0.0.1:$PORT"
export HTTPS_PROXY="http://127.0.0.1:$PORT"
export http_proxy="http://127.0.0.1:$PORT"
export https_proxy="http://127.0.0.1:$PORT"

export NO_PROXY="localhost,127.0.0.1,::1"
export no_proxy="localhost,127.0.0.1,::1"


source .bashrc
```