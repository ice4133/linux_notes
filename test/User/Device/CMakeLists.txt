# 自动搜索当前 Src 目录下的所有 .c 文件
file(GLOB_RECURSE SOURCES "Src/*.c")

# 将源文件添加到主工程目标中
# 注意：CMAKE_PROJECT_NAME 是你在根目录定义的项目名
target_sources(${CMAKE_PROJECT_NAME} PRIVATE 
    ${SOURCES}
)

# 将当前 Inc 目录添加到头文件搜索路径
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE 
    Inc
)
