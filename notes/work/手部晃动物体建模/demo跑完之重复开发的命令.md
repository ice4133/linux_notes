
# 旧命令，不要看
运行mujocco终端

cd /home/ice/sonic

./.venv_sim/bin/python \
  gear_sonic/scripts/run_payload_sim_loop.py \
  --payload-force-model pendulum \
  --pendulum-load-mode wpc \
  --wpc-random-seed 1234 \
  --run-label official_sonic_wpc_pendulum

cd /home/ice/sonic
进入项目根目录，后面的相对路径都从这里解析。

./.venv_sim/bin/python
使用项目专门运行MuJoCo的Python环境。

gear_sonic/scripts/run_payload_sim_loop.py
启动MuJoCo机器人仿真和载荷施加程序。

--payload-force-model pendulum
使用你从Isaac移植过来的动态钟摆力，不使用原来的固定向下力。

--pendulum-load-mode wpc
使用WPC随机质量模式：每个窗口重新采样质量，包含左右分配、无载概率和单侧载荷概率。

--wpc-random-seed 1234
固定随机种子。官方策略和你的 002450 都使用相同种子，才能得到相同的质量变化，方便公平对比。

--run-label official_sonic_pendulum
给CSV日志命名，用来区分这是官方SONIC的实验结果。





--wpc-max-load-kg                 最大总载荷
--wpc-cap-scale                   载荷上限比例
--wpc-window-no-load-ratio        无载窗口概率
--wpc-single-side-load-ratio      单侧加载概率
--wpc-split-ratio-low/high        左右手质量分配范围
--wpc-uniform-window-s            重新随机质量的窗口长度
--wpc-random-seed                 随机种子
--pendulum-length-m               钟摆长度
--pendulum-damping                阻尼



运行sonic推理命令   


cd /home/ice/sonic

CUSTOM_POLICY_DIR=/home/ice/sonic/gear_sonic_deploy/policy/wpc_step_011000 \
CUSTOM_OBS_CONFIG=/home/ice/sonic/gear_sonic_deploy/policy/wpc_step_011000/observation_config.yaml \
PAYLOAD_MOTION_DATA=reference/payload_hold \
./sonic_launch/heft_wpc/run_payload_ab_controller.sh custom



cd /home/ice/sonic

PAYLOAD_MOTION_DATA=reference/payload_hold \
./sonic_launch/heft_wpc/run_payload_ab_controller.sh sonic


sonic
  → 自动选择 policy/release

custom
  → 需要告诉脚本具体使用哪个自定义目录





# 从pt导出onnx
cd /root/xuxiangling/sonic

SONIC_REPO=/root/xuxiangling/sonic \
SONIC_CONDA_ENV=sonic_z \
CONDA_SH=/root/miniconda3/etc/profile.d/conda.sh \
CUDA_VISIBLE_DEVICES=0 \
HEADLESS=1 \
MOTION_FILE=/mnt/nfs/humanoid/sonic/robot_filtered \
SMPL_MOTION_FILE=/mnt/nfs/humanoid/sonic/smpl_filtered \
EXPECTED_ENCODER_INPUT_DIM=1751 \
SONIC_OBS_CONFIG=/root/xuxiangling/sonic/gear_sonic_deploy/policy/release/observation_config_sonic_release.yaml \
./sonic_launch/heft_wpc/export_new_wpc_onnx.sh \
/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000/model_step_030000.pt \
/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000/deploy_policy_model_step_030000


scp -r \
root@8.140.37.145:/root/xuxiangling/sonic/training_checkpoints/sonic_wpc_train_7gpu_env4096_30000/exported/model_step_030000_{encoder,decoder}.onnx \
~/Downloads/sonic_onnx/



# 新命令
python
  gear_sonic/scripts/run_payload_sim_loop.py \
  --payload-force-model pendulum \
  --pendulum-load-mode wpc \
  --wpc-cap-scale 0.416667 \
  --run-label wuji_wpc_step10000


gear_sonic/scripts/run_payload_sim_loop.py \
  --payload-force-model pendulum \
  --pendulum-load-mode wpc \
  --wpc-cap-scale 0.6 \
  --wpc-random-seed 1234 \
  --run-label walking_wpc_step013450



载荷比例默认值在run_payload_sim_loop.py的112行

这个wpc-cap-scale，要根据实际训练的多少轮来判定



./sonic_launch/heft_wpc/run_payload_ab_controller.sh custom

如果用了新的轮pt，那么就要把run_payload_ab_controller.sh里面的固定路径给改一下，这个修改的是调用哪个onnx





修改动作，只修改 run_payload_ab_controller.sh (line 54)，

MOTION_DATA="reference/example/walking_quip_360_R_002__A428"

修改成深蹲
MOTION_DATA="reference/example/squat_001__A359"



python3 gear_sonic/scripts/monitor_payload_resistance.py \
  --run-label walking_wpc_step013450 \
  --policy-label custom \
  --accept-existing

每次都要修改对应的sonic、custom、heft
--run-label walking_wpc_step013450，这个要对应mujoco的csv


# 载荷率计算
环境步数 = 13450 × 24 = 322800  
训练进度 = 322800 / 720000 = 44.8333%
载荷率 = 44.8333% / 80% = 56.0417%


# 实际遇到的问题和解决

首先是载荷力无法直接加载


动作会直接停止下来


把外力终端显示出来，方便观看


# 自动化测试脚本

cd /home/ice/sonic

./.venv_sim/bin/python \
  gear_sonic/scripts/run_payload_onnx_benchmark.py \
  --policies sonic heft custom \
  --motions \
    walking_wpc_step013450 \
    squat_wpc_step013450 \
    dance_wpc_step013450 \
  --seeds 1234 2345 3456 \
  --evaluation-duration-s 12 \
  --payload-delay-s 1 \
  --controller-settle-s 0.2 \
  --wall-timeout-s 55 \
  --custom-label custom_step020000 \
  --output-dir logs_eval/onnx_payload_benchmark_paired