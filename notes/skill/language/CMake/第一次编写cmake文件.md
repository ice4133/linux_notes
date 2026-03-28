首先要求添加的三个指令

```cmake
cmake_minimum_required(VERSION 3.15) # 指定cmake的最低版本要求

project(hello_cmake) # 项目名称，可以任意修改

add_executable(hello_cmake main.cpp)# 添加可执行文件，参数分别是生成的可执行文件名称和源文件列表

```

然后 cmake ..

紧接着 make

最后 ./hello_cmake 就可以运行了


set的语法就是给变量赋值 跟int a = 10;类似
只不过有些有默认的宏，有些需要自己定义

set(SRC_Lists main.cpp hello.cpp) # 定义一个变量，包含所有的源文件

add_executable(hello_cmake ${SRC_Lists}) # 使用变量来指定源文件列表
用$来取出变量的值，是因为SRC——Lists是一个string类型的变量，用${}来取出变量

指定c++标准

```cmake
set(CMAKE_CXX_STANDARD 11) # 设置C++标准为C++11
set(CMAKE_CXX_STANDARD_REQUIRED True) # 强制要求使用指定的C++标准
```

指定可执行程序的输出目录

```cmake
set(EXECUTABLE_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/bin) # 设置可执行文件的输出目录为项目根目录下的bin文件夹
```


搜索文件
解决的问题是当项目里有多个源文件的时候，手动添加太麻烦

于是

```cmake
aux_source_directory(src SRC_Lists) # 搜索src目录下的所有源文件，并将它们添加到SRC_Lists变量中


file(GLOB SRC_Lists src/*.cpp) # 使用GLOB命令搜索src目录下的所有.cpp文件，并将它们添加到SRC_Lists变量中

# GLOB的意思是当前路径下搜索
#GLOB_RECURSE的意思是递归搜索当前路径下的所有子目录
```


此时我们把代码结构优化一下

```
CMakeLists.txt
src/
include/
build/
``` 

此时我们进行编译，会发现找不到头文件
因为默认情况下，编译器只会在当前目录下搜索头文件，而不会去include目录下搜索，也不会去其它目录下搜索，所以我们需要告诉编译器去哪里搜索头文件

```cmake
include_directories(include) # 告诉编译器去include目录下搜索头文件，最好写成绝对路径
```

