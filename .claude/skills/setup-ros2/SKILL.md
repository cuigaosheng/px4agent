---
name: setup-ros2
version: "1.0.0"
description: 安装 ROS2 Humble + px4_msgs + Micro-XRCE-DDS-Agent，并验证 PX4 uXRCE-DDS 桥接。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
安装 ROS2 Humble 并配置 PX4 uXRCE-DDS 桥接：$ARGUMENTS

以下所有命令均在 **WSL/Linux 终端**中执行。

---

## 第一步：检测 ROS2 安装状态

```bash
# [WSL/Linux] 检测 ROS2 Humble
echo "--- ROS2 ---"
source /opt/ros/humble/setup.bash 2>/dev/null && ros2 --version || echo "ROS2 Humble 未安装"

echo "--- px4_msgs ---"
ls ~/ros2_ws/src/px4_msgs 2>/dev/null && echo "px4_msgs 已存在" || echo "px4_msgs 未克隆"
ls ~/ros2_ws/install/px4_msgs 2>/dev/null && echo "px4_msgs 已编译" || echo "px4_msgs 未编译"

echo "--- Micro XRCE-DDS Agent ---"
which MicroXRCEAgent 2>/dev/null && MicroXRCEAgent --version 2>/dev/null | head -1 || echo "MicroXRCEAgent 未安装"
```

**判断逻辑**：
- ROS2 + px4_msgs 已编译 + MicroXRCEAgent 已安装 → **报告跳过，退出**
- 部分安装 → 跳到对应步骤补全
- 完全未安装 → 从第二步开始

---

## 第二步：添加 ROS2 apt 源

```bash
# [WSL/Linux] 添加 ROS2 官方 apt 源
sudo apt update && sudo apt install -y curl gnupg lsb-release

# 添加 ROS2 GPG 密钥
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

# 添加 ROS2 Humble 源
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

sudo apt update
```

**网络慢时替代**（国内镜像，以中科大为例）：

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
https://mirrors.ustc.edu.cn/ros2/ubuntu $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
```

---

## 第三步：安装 ROS2 Humble Desktop

```bash
# [WSL/Linux] 安装 ROS2 Humble 桌面版（含 rclcpp、rclpy、工具）
sudo apt install -y ros-humble-desktop python3-colcon-common-extensions python3-rosdep

# 初始化 rosdep（若从未初始化过）
sudo rosdep init 2>/dev/null || echo "rosdep 已初始化"
rosdep update

# 将 ROS2 source 加入 ~/.bashrc
echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
source ~/.bashrc
```

---

## 第四步：创建 ROS2 工作区并克隆 px4_msgs

```bash
# [WSL/Linux] 创建工作区
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws/src

# 克隆 px4_msgs（版本必须与 PX4 固件版本对应，v1.15.0 用 main 或对应 tag）
git clone https://github.com/PX4/px4_msgs.git --branch release/1.15 --depth 1

# 返回工作区根目录编译
cd ~/ros2_ws
source /opt/ros/humble/setup.bash
colcon build --packages-select px4_msgs
```

**注意**：`px4_msgs` 版本必须与 PX4 固件版本严格匹配，否则话题格式不兼容会导致通信失败。

---

## 第五步：编译安装 Micro-XRCE-DDS-Agent

```bash
# [WSL/Linux] 克隆 Micro-XRCE-DDS-Agent 源码
cd ~
git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git --depth 1
cd Micro-XRCE-DDS-Agent

# 安装编译依赖
sudo apt install -y cmake g++ libssl-dev

# 编译安装
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
sudo make install

# 验证安装
which MicroXRCEAgent && MicroXRCEAgent --version
```

**替代方案**（snap 安装，更简单但版本较旧）：

```bash
# 若编译失败，使用 snap 安装
sudo snap install micro-xrce-dds-agent --edge
# snap 安装后命令为 micro-xrce-dds-agent（而非 MicroXRCEAgent）
```

---

## 第六步：配置 bashrc

```bash
# [WSL/Linux] 将完整 ROS2 + 工作区环境加入 ~/.bashrc
cat >> ~/.bashrc << 'EOF'

# ROS2 Humble + PX4 工作区
source /opt/ros/humble/setup.bash
source ~/ros2_ws/install/setup.bash 2>/dev/null || true

# uXRCE-DDS 连接参数（PX4 SITL 默认端口）
export PX4_UXRCE_DDS_PORT=8888
EOF

source ~/.bashrc
```

---

## 第七步：验证

**验证步骤**：

1. 启动 PX4 SITL（终端 1）：

```bash
# [WSL/Linux] 终端 1：启动 SITL
cd ~/PX4-Autopilot
make px4_sitl none_iris
```

2. 在 PX4 控制台启动 uXRCE-DDS 客户端：

```bash
# [PX4 控制台] 启动 DDS 客户端
uxrce_dds_client start -t udp -h 127.0.0.1 -p 8888
```

3. 启动 Micro-XRCE-DDS-Agent（终端 2）：

```bash
# [WSL/Linux] 终端 2：启动 DDS Agent
MicroXRCEAgent udp4 -p 8888
```

4. 检查 ROS2 话题（终端 3）：

```bash
# [WSL/Linux] 终端 3：查看话题列表
source ~/.bashrc
ros2 topic list
```

**成功标志**：`ros2 topic list` 输出中出现：

```
/px4_0/fmu/out/vehicle_attitude
/px4_0/fmu/out/vehicle_local_position
/px4_0/fmu/out/vehicle_status
/px4_0/fmu/in/vehicle_command
...
```

---

## 常见报错

| 现象 | 原因 | 解决 |
|------|------|------|
| `ros2: command not found` | bashrc 未生效 | `source /opt/ros/humble/setup.bash` |
| `colcon build` 失败 | px4_msgs 版本不匹配 | 确认 `--branch release/1.15` |
| `ros2 topic list` 为空 | DDS Agent 未启动 | 先启动 MicroXRCEAgent |
| Agent 连接失败 | PX4 端未启动 uxrce_dds_client | 在 PX4 控制台执行 `uxrce_dds_client start -t udp -h 127.0.0.1 -p 8888` |
| `MicroXRCEAgent: command not found` | 安装路径问题 | `sudo ldconfig` 后重新 source bashrc |
| px4_msgs 编译报 ROS2 版本错误 | ROS2 版本不是 Humble | `ros2 --version` 确认为 `rclpy 3.x.x` |
