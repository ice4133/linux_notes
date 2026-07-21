如果跑四轮足的话，会装一个插件，这会导致人形机器人的环境出问题

修改gear_sonic_deploy/scripts/setup_env.sh

gear_sonic_deploy/src/g1/g1_deploy_onnx_ref/cmake/ROS2.cmake

原因是四轮足环境下了几个依赖
混用了libddsc.so.-

编译的时候ros2全局包目录导致dds/features.h，覆盖同名文件