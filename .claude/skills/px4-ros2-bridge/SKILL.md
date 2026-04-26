---
name: px4-ros2-bridge
version: "1.0.0"
description: 在 PX4 中配置 ROS2 与飞控的通信桥接（uXRCE-DDS）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
在 PX4 中配置 ROS2 与飞控的通信桥接：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 项目：`~/px4agent`
- ROS2 工作空间：`~/ros2_ws/`
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
5. **运行环境**：Linux / Docker

---

## 第二步：安装 ROS2 环境

```bash
sudo apt update && sudo apt install ros-humble-desktop python3-colcon-common-extensions
```

---

## 第三步：方案 A — uXRCE-DDS 桥接（推荐，PX4 v1.14+）

### 3a 安装 Micro-XRCE-DDS Agent
```bash
sudo snap install micro-xrce-dds-agent --edge
```

### 3b 配置 PX4 uXRCE-DDS Client
```bash
uxrce_dds_client start -t udp -h 127.0.0.1 -p 8888
```

### 3c 配置发布/订阅的 topic
编辑 `src/modules/uxrce_dds_client/dds_topics.yaml`：
```yaml
publications:
  - topic: /fmu/out/vehicle_attitude
    type: px4_msgs::msg::VehicleAttitude
  - topic: /fmu/out/vehicle_local_position
    type: px4_msgs::msg::VehicleLocalPosition

subscriptions:
  - topic: /fmu/in/offboard_control_mode
    type: px4_msgs::msg::OffboardControlMode
  - topic: /fmu/in/trajectory_setpoint
    type: px4_msgs::msg::TrajectorySetpoint
```

### 3d 创建 ROS2 工作空间
```bash
mkdir -p ~/ros2_ws/src && cd ~/ros2_ws/src
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
sudo apt install ros-humble-mavros ros-humble-mavros-extras
sudo /opt/ros/humble/lib/mavros/install_geographiclib_datasets.sh
ros2 launch mavros px4.launch fcu_url:="udp://:14540@127.0.0.1:14557"
```

---

## 第五步：编写 ROS2 节点（uXRCE-DDS 方案）

```cpp
#include <rclcpp/rclcpp.hpp>
#include <px4_msgs/msg/vehicle_attitude.hpp>

class PX4Subscriber : public rclcpp::Node {
public:
    PX4Subscriber() : Node("px4_subscriber") {
        attitude_sub_ = create_subscription<px4_msgs::msg::VehicleAttitude>(
            "/fmu/out/vehicle_attitude", rclcpp::QoS(10).best_effort(),
            [this](const px4_msgs::msg::VehicleAttitude::SharedPtr msg) {
                RCLCPP_INFO(get_logger(), "Roll: %.2f", msg->q[0]);
            });
    }
private:
    rclcpp::Subscription<px4_msgs::msg::VehicleAttitude>::SharedPtr attitude_sub_;
};
```

**QoS 配置（重要）**：PX4 uXRCE-DDS 使用 Best Effort QoS：
```cpp
auto qos = rclcpp::QoS(rclcpp::KeepLast(10)).best_effort().durability_volatile();
```

---

## 第六步：SITL 端到端验证

```bash
# 终端 1：启动 PX4 SITL
cd ~/px4agent && make px4_sitl gazebo

# 终端 2：启动 uXRCE-DDS Agent
MicroXRCEAgent udp4 -p 8888

# 终端 3：验证 topic
source ~/ros2_ws/install/setup.bash
ros2 topic list | grep fmu
ros2 topic echo /fmu/out/vehicle_attitude --no-arr
ros2 topic hz /fmu/out/vehicle_local_position
```

---

## 常见问题排查

| 现象 | 原因 | 解决 |
|------|------|------|
| `ros2 topic list` 无 `/fmu` topic | Agent 未连接 | 确认 `uxrce_dds_client` 已启动，Agent 端口匹配 |
| 数据接收但频率低 | QoS 不匹配 | 订阅者改用 `best_effort()` |
| px4_msgs 编译报错 | 版本不匹配 | 切换到与 PX4 固件版本对应的 px4_msgs tag |
