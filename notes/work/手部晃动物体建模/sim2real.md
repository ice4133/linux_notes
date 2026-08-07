部署到真机上首先想的就是移植


环境移植，代码移植，测试


```bash
echo $CUDA_HOME
echo $TensorRT_ROOT

ldconfig -p | grep onnxruntime
# 必须包含1.16.3和aarch64


uname -m
grep -E '^(NAME|VERSION_ID)=' /etc/os-release
cat /etc/nv_tegra_release
cat /proc/device-tree/model 2>/dev/null | tr -d '\0'
echo


ls -ld /usr/local/cuda*
readlink -f /usr/local/cuda 2>/dev/null || true


command -v nvcc || true
nvcc --version 2>/dev/null || true
/usr/local/cuda-12.6/bin/nvcc --version 2>/dev/null || true
# 必须是12.6





#trtexec 
"$TensorRT_ROOT/bin/trtexec" --version

ldd "$TensorRT_ROOT/bin/trtexec" |
  grep 'not found' || true
#正确结果：
#trtexec 显示 TensorRT 10.7；
#第二条命令没有输出 not found。
```


要求
```text
[OK] aarch64
[OK] Ubuntu 22.04
[OK] L4T R36.x
[OK] CUDA 12.6
[OK] cuda_runtime.h 存在
[OK] libcudart.so 存在
[OK] TensorRT_ROOT 指向 10.7
[OK] TensorRT 库为 ARM aarch64
[OK] trtexec 无缺失库
[OK] ONNX Runtime 1.16.3
[OK] ONNX Runtime 为 ARM aarch64
[OK] ONNX Runtime 头文件存在
[OK] DLA/CUDLA 组件存在
```