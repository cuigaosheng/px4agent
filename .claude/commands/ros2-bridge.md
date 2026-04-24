在 PX4 中配置 ROS2 与飞控的通信桥接：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 项目：`C:/Users/cuiga/droneyee_px4v1.15.0`
- ROS2 工作空间：`C:/Users/cuiga/px4agent/ros2/`
- px4_msgs：`~/ros2_ws/src/px4_msgs/`
- px4_ros_com：`~/ros2_ws/src/px4_ros_com/`
- uXRCE-DDS 配置：`src/modules/uxrce_dds_client/`

---

## 第一步：确认需求

询问用户：
1. **ROS2 版本**：Humble（推荐，LTS）/ Foxy / Galactic
2. **通信方式**：
   - uXRCE-DDS（PX4 v1.14+ 推荐，直接 uORB ↔ ROS2 topic）
   - MAVROS（MAVLink 桥接，兼容旧版本）
3. **需要订阅的 PX4 数据**（如：姿态、位置、传感器）
4. **需要发布到 PX4 的指令**（如：Offboard setpoint、参数设置）
5. **运行环境**：WSL2 / 原生 Linux / Docker

---

## 第二步：安装 ROS2 环境

```bash
# Ubuntu 22.04 安装 ROS2 Humble
sudo apt update && sudo apt install locales
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

sudo apt install software-properties-common
sudo add-apt-repository universe
sudo apt update && sudo apt install curl -y
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
  -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
  http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
  | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

sudo apt update && sudo apt install ros-humble-desktop python3-colcon-common-extensions
```

---

## 第三步：方案 A — uXRCE-DDS 桥接（推荐，PX4 v1.14+）

### 3a 安装 Micro-XRCE-DDS Agent
```bash
pip install --user -U empy==3.3.4 pyros-genmsg setuptools
sudo snap install micro-xrce-dds-agent --edge

# 或从源码编译
git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git
cd Micro-XRCE-DDS-Agent && mkdir build && cd build
cmake .. && make && sudo make install
```

### 3b 配置 PX4 uXRCE-DDS Client
```bash
# 在 PX4 控制台启用 uXRCE-DDS client
uxrce_dds_client start -t udp -h 127.0.0.1 -p 8888

# 或在 ROMFS 启动脚本中永久启用
# 编辑 ROMFS/px4fmu_common/init.d-posix/rcS
# 添加：uxrce_dds_client start -t udp -h 127.0.0.1 -p 8888
```

### 3c 配置发布/订阅的 topic
编辑 `src/modules/uxrce_dds_client/dds_topics.yaml`：
```yaml
publications:
  - topic: /fmu/out/vehicle_attitude
    type: px4_msgs::msg::VehicleAttitude
  - topic: /fmu/out/vehicle_local_position
    type: px4_msgs::msg::VehicleLocalPosition
  - topic: /fmu/out/sensor_combined
    type: px4_msgs::msg::SensorCombined
  - topic: /fmu/out/battery_status
    type: px4_msgs::msg::BatteryStatus

subscriptions:
  - topic: /fmu/in/offboard_control_mode
    type: px4_msgs::msg::OffboardControlMode
  - topic: /fmu/in/trajectory_setpoint
    type: px4_msgs::msg::TrajectorySetpoint
  - topic: /fmu/in/vehicle_command
    type: px4_msgs::msg::VehicleCommand
```

### 3d 创建 ROS2 工作空间
```bash
mkdir -p ~/ros2_ws/src && cd ~/ros2_ws/src

# 克隆 px4_msgs（版本必须与 PX4 固件匹配）
git clone https://github.com/PX4/px4_msgs.git
git clone https://github.com/PX4/px4_ros_com.git

cd ~/ros2_ws
source /opt/ros/humble/setup.bash
colcon build --symlink-install
source install/setup.bash
```

---

## 第四步：方案 B — MAVROS 桥接（兼容方案）

```bash
# 安装 MAVROS
sudo apt install ros-humble-mavros ros-humble-mavros-extras
sudo /opt/ros/humble/lib/mavros/install_geographiclib_datasets.sh

# 启动 MAVROS（连接 PX4 SITL）
ros2 launch mavros px4.launch fcu_url:="udp://:14540@127.0.0.1:14557"
```

常用 MAVROS topic：
```bash
# 订阅飞控数据
ros2 topic echo /mavros/imu/data
ros2 topic echo /mavros/local_position/pose
ros2 topic echo /mavros/state

# 发布控制指令
ros2 topic pub /mavros/setpoint_position/local geometry_msgs/PoseStamped ...
```

---

## 第五步：编写 ROS2 节点（uXRCE-DDS 方案）

### 订阅 PX4 姿态数据
```cpp
#include <rclcpp/rclcpp.hpp>
#include <px4_msgs/msg/vehicle_attitude.hpp>
#include <px4_msgs/msg/vehicle_local_position.hpp>

class PX4Subscriber : public rclcpp::Node {
public:
    PX4Subscriber() : Node("px4_subscriber") {
        // 订阅姿态
        attitude_sub_ = create_subscription<px4_msgs::msg::VehicleAttitude>(
            "/fmu/out/vehicle_attitude", rclcpp::QoS(10).best_effort(),
            [this](const px4_msgs::msg::VehicleAttitude::SharedPtr msg) {
                RCLCPP_INFO(get_logger(), "Roll: %.2f, Pitch: %.2f, Yaw: %.2f",
                    msg->q[0], msg->q[1], msg->q[2]);
            });

        // 订阅本地位置
        position_sub_ = create_subscription<px4_msgs::msg::VehicleLocalPosition>(
            "/fmu/out/vehicle_local_position", rclcpp::QoS(10).best_effort(),
            [this](const px4_msgs::msg::VehicleLocalPosition::SharedPtr msg) {
                RCLCPP_INFO(get_logger(), "x: %.2f, y: %.2f, z: %.2f",
                    msg->x, msg->y, msg->z);
            });
    }

private:
    rclcpp::Subscription<px4_msgs::msg::VehicleAttitude>::SharedPtr attitude_sub_;
    rclcpp::Subscription<px4_msgs::msg::VehicleLocalPosition>::SharedPtr position_sub_;
};

int main(int argc, char* argv[]) {
    rclcpp::init(argc, argv);
    rclcpp::spin(std::make_shared<PX4Subscriber>());
    rclcpp::shutdown();
    return 0;
}
```

### QoS 配置（重要）
PX4 uXRCE-DDS 使用 Best Effort QoS，ROS2 订阅者必须匹配：
```cpp
auto qos = rclcpp::QoS(rclcpp::KeepLast(10)).best_effort().durability_volatile();
```

---

## 第六步：SITL 端到端验证

```bash
# 终端 1：启动 PX4 SITL
cd ~/droneyee_px4v1.15.0
make px4_sitl gazebo

# 终端 2：启动 uXRCE-DDS Agent
MicroXRCEAgent udp4 -p 8888

# 终端 3：source 并验证 topic
source ~/ros2_ws/install/setup.bash
ros2 topic list | grep fmu
ros2 topic echo /fmu/out/vehicle_attitude --no-arr
ros2 topic hz /fmu/out/vehicle_local_position
```

验证检查项：
- `ros2 topic list` 能看到 `/fmu/out/*` 和 `/fmu/in/*`
- 姿态数据以 ≥ 50 Hz 更新
- 发布 setpoint 后飞控能响应

---

## 第七步：自定义 uORB ↔ ROS2 topic 桥接

如需桥接自定义 uORB topic（配合 `/px4-module` 或 `/sensor-driver` 开发的模块）：

1. 在 `px4_msgs` 中添加对应消息定义（`.msg` 文件）
2. 在 `dds_topics.yaml` 中注册 publication/subscription
3. 重新编译 PX4 固件和 ROS2 工作空间

```bash
# 重新编译
cd ~/droneyee_px4v1.15.0
make px4_sitl_default

cd ~/ros2_ws
colcon build --packages-select px4_msgs
source install/setup.bash
```

---

## 常见问题排查

| 现象 | 原因 | 解决 |
|------|------|------|
| `ros2 topic list` 无 `/fmu` topic | Agent 未连接 | 确认 `uxrce_dds_client` 已启动，Agent 端口匹配 |
| 数据接收但频率低 | QoS 不匹配 | 订阅者改用 `best_effort()` |
| WSL2 中 Agent 无法连接 | 网络隔离 | 用 `ip route` 查宿主机 IP，或用 serial 模式 |
| px4_msgs 编译报错 | 版本不匹配 | 切换到与 PX4 固件版本对应的 px4_msgs tag |
| MAVROS 连接超时 | FCU URL 错误 | 检查 UDP 端口，SITL 默认 14540 |
