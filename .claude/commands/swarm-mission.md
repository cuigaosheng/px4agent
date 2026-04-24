在 PX4 中开发多机协同任务规划（Swarm Mission）：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 源码：`C:/Users/cuiga/droneyee_px4v1.15.0`（WSL 内：`~/droneyee_px4v1.15.0`）
- 多机启动脚本：`Tools/simulation/gazebo-classic/sitl_multiple_run.sh`
- ROS2 工作空间：`~/ros2_ws/`
- MAVSDK 文档：https://mavsdk.mavlink.io/

---

## 第一步：确认需求

询问用户：
1. **机群规模**：飞机数量（SITL 建议 ≤ 5 架，真机无限制）
2. **任务类型**：
   - 编队飞行（固定队形跟随）
   - 区域覆盖搜索（分区并行搜索）
   - 协同载荷（分工投送/采集）
   - 领航-跟随（1 leader + N followers）
3. **控制接口**：
   - MAVSDK 多实例（推荐，C++，独立连接每架飞机）
   - ROS2 多命名空间（推荐，算法复杂时优选）
   - QGC 多机任务（简单任务，无编程需要）
4. **协调机制**：
   - 集中式（地面站统一调度）
   - 分布式（飞机间 MAVLink 通信协商）
5. **运行环境**：SITL 仿真 / 真机
6. **碰撞规避**：是否需要（SITL 验证阶段可先关闭）

---

## 第二步：多机 SITL 环境搭建

### 2a 启动多机 Gazebo SITL

```bash
# WSL 内，PX4 源码目录
cd ~/droneyee_px4v1.15.0

# 方法一：官方多机启动脚本（推荐）
# 启动 N 架 iris，自动分配端口
Tools/simulation/gazebo-classic/sitl_multiple_run.sh -n 3 -m iris

# 方法二：手动分实例启动（更灵活）
# 终端 1：实例 0（System ID=1）
PX4_SIM_MODEL=iris ./build/px4_sitl_default/bin/px4 \
  -s ROMFS/px4fmu_common/init.d-posix/rcS -i 0 -w /tmp/px4_0

# 终端 2：实例 1（System ID=2）
PX4_SIM_MODEL=iris ./build/px4_sitl_default/bin/px4 \
  -s ROMFS/px4fmu_common/init.d-posix/rcS -i 1 -w /tmp/px4_1

# 终端 3：实例 2（System ID=3）
PX4_SIM_MODEL=iris ./build/px4_sitl_default/bin/px4 \
  -s ROMFS/px4fmu_common/init.d-posix/rcS -i 2 -w /tmp/px4_2
```

### 2b 端口分配规则

| 实例（-i N） | System ID | GCS UDP | Offboard UDP | MAV_SYS_ID |
|-------------|-----------|---------|--------------|------------|
| 0 | 1 | 14550 | 14540 | 1 |
| 1 | 2 | 14551 | 14541 | 2 |
| 2 | 3 | 14552 | 14542 | 3 |
| N | N+1 | 14550+N | 14540+N | N+1 |

### 2c 验证多机启动

```bash
# 每个实例的 PX4 控制台执行
commander status    # 确认 System ID 正确
listener vehicle_local_position  # 确认各机有不同初始位置
```

---

## 第三步：MAVSDK 多机控制

### 3a 连接多架飞机

```cpp
#include <mavsdk/mavsdk.h>
#include <mavsdk/plugins/action/action.h>
#include <mavsdk/plugins/offboard/offboard.h>
#include <mavsdk/plugins/telemetry/telemetry.h>
#include <vector>
#include <thread>
#include <chrono>

using namespace mavsdk;
using namespace std::chrono;

int main() {
    Mavsdk mavsdk{Mavsdk::Configuration{Mavsdk::ComponentType::GroundStation}};

    // 连接所有飞机（每架监听不同 UDP 端口）
    const int num_drones = 3;
    for (int i = 0; i < num_drones; i++) {
        std::string conn = "udp://:" + std::to_string(14540 + i);
        auto result = mavsdk.add_any_connection(conn);
        if (result != ConnectionResult::Success) {
            return 1;
        }
    }

    // 等待所有飞机连接
    std::vector<std::shared_ptr<System>> systems;
    while (systems.size() < static_cast<size_t>(num_drones)) {
        std::this_thread::sleep_for(500ms);
        systems = mavsdk.systems();
    }

    // 为每架飞机创建插件实例
    std::vector<Action> actions;
    std::vector<Offboard> offboards;
    std::vector<Telemetry> telemetries;

    for (auto& system : systems) {
        actions.emplace_back(system);
        offboards.emplace_back(system);
        telemetries.emplace_back(system);
    }

    // 等待所有飞机 EKF 就绪
    for (size_t i = 0; i < systems.size(); i++) {
        while (!telemetries[i].health().is_local_position_ok) {
            std::this_thread::sleep_for(500ms);
        }
    }

    return 0;
}
```

### 3b 并行解锁与起飞

```cpp
// 同时解锁所有飞机
std::vector<std::thread> threads;
for (size_t i = 0; i < systems.size(); i++) {
    threads.emplace_back([&actions, i]() {
        actions[i].arm();
        std::this_thread::sleep_for(1s);
        actions[i].takeoff();
    });
}
for (auto& t : threads) t.join();

// 等待所有飞机到达目标高度
std::this_thread::sleep_for(5s);
```

---

## 第四步：编队飞行实现

### 4a 领航-跟随编队（Leader-Follower）

```cpp
// 编队偏移定义（相对 Leader 的 NED 偏移，单位 m）
struct FormationOffset {
    float north;
    float east;
    float down;
};

const std::vector<FormationOffset> formation = {
    {0.0f,  0.0f,  0.0f},   // Drone 0：Leader
    {-3.0f, -3.0f, 0.0f},   // Drone 1：左后方 3m
    {-3.0f,  3.0f, 0.0f},   // Drone 2：右后方 3m
};

// 编队控制循环（20 Hz）
while (running) {
    // 获取 Leader 当前位置
    auto leader_pos = telemetries[0].position_velocity_ned().position;

    // 其他飞机跟随 Leader
    for (size_t i = 1; i < systems.size(); i++) {
        Offboard::PositionNedYaw target{};
        target.north_m = leader_pos.north_m + formation[i].north;
        target.east_m  = leader_pos.east_m  + formation[i].east;
        target.down_m  = leader_pos.down_m  + formation[i].down;
        target.yaw_deg = telemetries[0].attitude_euler().yaw_deg; // 同向
        offboards[i].set_position_ned(target);
    }

    std::this_thread::sleep_for(milliseconds(50)); // 20 Hz
}
```

### 4b 固定编队队形定义

```cpp
// 常用编队队形（相对 Leader，单位 m）

// V 形编队（5 架）
const std::vector<FormationOffset> V_FORMATION = {
    { 0.0f,  0.0f, 0.0f},  // Leader
    {-3.0f, -3.0f, 0.0f},  // 左翼 1
    {-6.0f, -6.0f, 0.0f},  // 左翼 2
    {-3.0f,  3.0f, 0.0f},  // 右翼 1
    {-6.0f,  6.0f, 0.0f},  // 右翼 2
};

// 菱形编队（4 架）
const std::vector<FormationOffset> DIAMOND_FORMATION = {
    { 0.0f,  0.0f, 0.0f},  // 前
    {-3.0f, -3.0f, 0.0f},  // 左
    {-3.0f,  3.0f, 0.0f},  // 右
    {-6.0f,  0.0f, 0.0f},  // 后
};

// 纵队（列队，适合穿越窄道）
const std::vector<FormationOffset> COLUMN_FORMATION = {
    { 0.0f, 0.0f, 0.0f},   // 1 号
    {-5.0f, 0.0f, 0.0f},   // 2 号
    {-10.0f, 0.0f, 0.0f},  // 3 号
};
```

---

## 第五步：ROS2 多机命名空间方案

适用于需要复杂算法（路径规划、SLAM、感知）的场景。

### 5a 多机命名空间配置（uXRCE-DDS）

每个 PX4 实例使用不同 DDS 域 ID（实例 N 对应域 ID N）：

```bash
# PX4 实例 0（DDS 域 0，命名空间 /px4_0）
uxrce_dds_client start -t udp -h 127.0.0.1 -p 8888 -n px4_0

# PX4 实例 1（DDS 域 1，命名空间 /px4_1）
uxrce_dds_client start -t udp -h 127.0.0.1 -p 8889 -n px4_1

# PX4 实例 2（DDS 域 2，命名空间 /px4_2）
uxrce_dds_client start -t udp -h 127.0.0.1 -p 8890 -n px4_2
```

```bash
# 启动多个 Agent（每个监听不同端口）
MicroXRCEAgent udp4 -p 8888 &
MicroXRCEAgent udp4 -p 8889 &
MicroXRCEAgent udp4 -p 8890 &
```

### 5b 多机 ROS2 话题结构

```bash
# 验证多机话题
ros2 topic list | grep fmu
# 输出示例：
# /px4_0/fmu/out/vehicle_attitude
# /px4_0/fmu/out/vehicle_local_position
# /px4_1/fmu/out/vehicle_attitude
# /px4_1/fmu/out/vehicle_local_position
# /px4_2/fmu/out/vehicle_attitude
# /px4_2/fmu/out/vehicle_local_position
```

### 5c 多机协调节点（C++）

```cpp
#include <rclcpp/rclcpp.hpp>
#include <px4_msgs/msg/vehicle_local_position.hpp>
#include <px4_msgs/msg/trajectory_setpoint.hpp>
#include <px4_msgs/msg/offboard_control_mode.hpp>

class SwarmCoordinator : public rclcpp::Node {
public:
    SwarmCoordinator(int num_drones) : Node("swarm_coordinator") {
        auto qos = rclcpp::QoS(10).best_effort();

        for (int i = 0; i < num_drones; i++) {
            std::string ns = "/px4_" + std::to_string(i);

            // 订阅每架飞机的位置
            pos_subs_.push_back(
                create_subscription<px4_msgs::msg::VehicleLocalPosition>(
                    ns + "/fmu/out/vehicle_local_position", qos,
                    [this, i](const px4_msgs::msg::VehicleLocalPosition::SharedPtr msg) {
                        positions_[i] = *msg;
                    }
                )
            );

            // 发布 Offboard 控制模式
            mode_pubs_.push_back(
                create_publisher<px4_msgs::msg::OffboardControlMode>(
                    ns + "/fmu/in/offboard_control_mode", qos
                )
            );

            // 发布轨迹 setpoint
            setpoint_pubs_.push_back(
                create_publisher<px4_msgs::msg::TrajectorySetpoint>(
                    ns + "/fmu/in/trajectory_setpoint", qos
                )
            );
        }

        // 20 Hz 控制循环
        timer_ = create_wall_timer(
            std::chrono::milliseconds(50),
            std::bind(&SwarmCoordinator::control_loop, this)
        );
    }

private:
    void control_loop() {
        for (size_t i = 0; i < mode_pubs_.size(); i++) {
            // 发布 Offboard 控制模式
            px4_msgs::msg::OffboardControlMode mode{};
            mode.position = true;
            mode.timestamp = get_clock()->now().nanoseconds() / 1000;
            mode_pubs_[i]->publish(mode);

            // 计算编队 setpoint
            auto sp = compute_formation_setpoint(i);
            sp.timestamp = get_clock()->now().nanoseconds() / 1000;
            setpoint_pubs_[i]->publish(sp);
        }
    }

    px4_msgs::msg::TrajectorySetpoint compute_formation_setpoint(size_t drone_id) {
        px4_msgs::msg::TrajectorySetpoint sp{};
        // 示例：V 形编队
        const float offsets_north[] = {0.0f, -3.0f, -3.0f};
        const float offsets_east[]  = {0.0f, -3.0f,  3.0f};

        if (drone_id < 3) {
            sp.position[0] = mission_north_ + offsets_north[drone_id];
            sp.position[1] = mission_east_  + offsets_east[drone_id];
            sp.position[2] = -10.0f;  // 高度 10m（NED，Z 向下）
        }
        sp.yaw = 0.0f;
        return sp;
    }

    std::vector<rclcpp::Subscription<px4_msgs::msg::VehicleLocalPosition>::SharedPtr> pos_subs_;
    std::vector<rclcpp::Publisher<px4_msgs::msg::OffboardControlMode>::SharedPtr> mode_pubs_;
    std::vector<rclcpp::Publisher<px4_msgs::msg::TrajectorySetpoint>::SharedPtr> setpoint_pubs_;
    std::map<int, px4_msgs::msg::VehicleLocalPosition> positions_;
    rclcpp::TimerBase::SharedPtr timer_;
    float mission_north_{0.0f};
    float mission_east_{0.0f};
};

int main(int argc, char* argv[]) {
    rclcpp::init(argc, argv);
    rclcpp::spin(std::make_shared<SwarmCoordinator>(3));
    rclcpp::shutdown();
    return 0;
}
```

---

## 第六步：区域覆盖搜索任务

### 6a 区域分割（集中式调度）

```cpp
// 将目标区域按飞机数量分割为子区域
struct SearchArea {
    float north_min, north_max;
    float east_min, east_max;
};

std::vector<SearchArea> split_area(SearchArea total, int num_drones) {
    std::vector<SearchArea> sub_areas;
    float strip_width = (total.east_max - total.east_min) / num_drones;

    for (int i = 0; i < num_drones; i++) {
        SearchArea sub;
        sub.north_min = total.north_min;
        sub.north_max = total.north_max;
        sub.east_min  = total.east_min + i * strip_width;
        sub.east_max  = total.east_min + (i + 1) * strip_width;
        sub_areas.push_back(sub);
    }
    return sub_areas;
}

// 生成弓字形（Lawn-mower）扫描航点
std::vector<std::pair<float, float>> generate_lawnmower(
    const SearchArea& area, float line_spacing) {

    std::vector<std::pair<float, float>> waypoints;
    bool left_to_right = true;

    for (float n = area.north_min; n <= area.north_max; n += line_spacing) {
        if (left_to_right) {
            waypoints.push_back({n, area.east_min});
            waypoints.push_back({n, area.east_max});
        } else {
            waypoints.push_back({n, area.east_max});
            waypoints.push_back({n, area.east_min});
        }
        left_to_right = !left_to_right;
    }
    return waypoints;
}
```

---

## 第七步：碰撞规避

### 7a 简单距离保持（软约束）

```cpp
// 检查两架飞机间距离，小于安全距离时停止接近
const float SAFE_DISTANCE = 5.0f;  // 安全距离 5m

bool check_collision_risk(size_t drone_a, size_t drone_b,
                           const std::map<int, px4_msgs::msg::VehicleLocalPosition>& positions) {
    auto& pa = positions.at(drone_a);
    auto& pb = positions.at(drone_b);

    float dn = pa.x - pb.x;
    float de = pa.y - pb.y;
    float dd = pa.z - pb.z;
    float dist = std::sqrt(dn*dn + de*de + dd*dd);

    return dist < SAFE_DISTANCE;
}

// 碰撞规避动作：悬停等待
if (check_collision_risk(i, j, positions_)) {
    // 发送悬停 setpoint（当前位置）
    sp.position[0] = positions_[i].x;
    sp.position[1] = positions_[i].y;
    sp.position[2] = positions_[i].z;
}
```

### 7b 利用 PX4 内置规避（真机推荐）

```bash
# 启用 PX4 防碰撞参数（需要 ADS-B 或 companion computer 提供位置）
param set CP_DIST 5.0        # 碰撞预防距离 5m
param set CP_GO_NO_DATA 0    # 无数据时不禁止飞行（SITL）
```

---

## 第八步：SITL 端到端验证

```bash
# 终端 1：启动多机 Gazebo SITL
cd ~/droneyee_px4v1.15.0
Tools/simulation/gazebo-classic/sitl_multiple_run.sh -n 3 -m iris

# 终端 2：启动多个 uXRCE-DDS Agent（若用 ROS2 方案）
MicroXRCEAgent udp4 -p 8888 &
MicroXRCEAgent udp4 -p 8889 &
MicroXRCEAgent udp4 -p 8890 &

# 终端 3：运行编队控制程序
# MAVSDK 方案：
./swarm_mission

# ROS2 方案：
source ~/ros2_ws/install/setup.bash
ros2 run swarm_pkg swarm_coordinator
```

验证检查项：
- 每架飞机的 PX4 实例 System ID 不同（1 / 2 / 3）
- Gazebo 中 3 架飞机出现并间距正确
- MAVSDK 或 ROS2 程序能连接所有飞机
- 编队飞行时各机间距保持稳定
- `ros2 topic hz /px4_0/fmu/out/vehicle_local_position` 频率 ≥ 10 Hz

---

## 常见问题排查

| 现象 | 原因 | 解决 |
|------|------|------|
| 多机 Gazebo 启动后只有 1 架 | 端口冲突 | 确认 14540+N 端口未被占用 |
| MAVSDK 连接混淆飞机 | System ID 未区分 | 通过 `telemetry.get_info()` 确认 System ID |
| ROS2 话题无数据 | uXRCE-DDS 端口不匹配 | 确认 PX4 实例和 Agent 端口一一对应 |
| 编队散开 | setpoint 发送频率不足 | 确保 ≥ 20 Hz，用独立线程发送 |
| 碰撞规避触发过频繁 | 安全距离设置过大 | 适当减小 `SAFE_DISTANCE` |
| 飞机起飞后不跟随 Leader | Leader 位置获取失败 | 检查 telemetry 订阅是否成功 |

---

## 编码规范
- 每架飞机的 Offboard setpoint 必须以 ≥ 20 Hz 独立线程发送
- 飞机间通信数据须校验范围（防止坐标溢出）
- 碰撞规避优先级高于任务目标，检测到风险立即悬停
- 多机任务中每架飞机应有独立的超时保护和降落逻辑
- System ID 与实例 ID 严格对应，禁止硬编码 System ID
