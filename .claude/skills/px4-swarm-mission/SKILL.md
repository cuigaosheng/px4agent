---
name: px4-swarm-mission
version: "1.0.0"
description: 在 PX4 中开发多机协同任务规划（编队/搜索/协同）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
在 PX4 中开发多机协同任务规划（Swarm Mission）：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 源码：`~/px4agent`
- 多机启动脚本：`Tools/simulation/gazebo-classic/sitl_multiple_run.sh`
- ROS2 工作空间：`~/ros2_ws/`

---

## 第一步：确认需求

询问用户：
1. **机群规模**：飞机数量（SITL 建议 ≤ 5 架）
2. **任务类型**：编队飞行 / 区域覆盖搜索 / 领航-跟随
3. **控制接口**：MAVSDK 多实例（推荐）/ ROS2 多命名空间
4. **协调机制**：集中式（地面站统一调度）/ 分布式
5. **运行环境**：SITL 仿真 / 真机
6. **碰撞规避**：是否需要

---

## 第二步：多机 SITL 环境搭建

```bash
cd ~/px4agent

# 方法一：官方多机启动脚本（推荐）
Tools/simulation/gazebo-classic/sitl_multiple_run.sh -n 3 -m iris

# 方法二：手动分实例启动
PX4_SIM_MODEL=iris ./build/px4_sitl_default/bin/px4 \
  -s ROMFS/px4fmu_common/init.d-posix/rcS -i 0 -w /tmp/px4_0
```

### 端口分配规则

| 实例（-i N） | System ID | GCS UDP | Offboard UDP |
|-------------|-----------|---------|--------------|
| 0 | 1 | 14550 | 14540 |
| 1 | 2 | 14551 | 14541 |
| N | N+1 | 14550+N | 14540+N |

---

## 第三步：MAVSDK 多机控制

```cpp
#include <mavsdk/mavsdk.h>
#include <mavsdk/plugins/action/action.h>
#include <mavsdk/plugins/offboard/offboard.h>
#include <mavsdk/plugins/telemetry/telemetry.h>

int main() {
    Mavsdk mavsdk{Mavsdk::Configuration{Mavsdk::ComponentType::GroundStation}};
    const int num_drones = 3;
    for (int i = 0; i < num_drones; i++) {
        mavsdk.add_any_connection("udp://:" + std::to_string(14540 + i));
    }
    // 等待所有飞机连接后创建插件实例
}
```

---

## 第四步：编队飞行实现（领航-跟随）

```cpp
struct FormationOffset { float north, east, down; };
const std::vector<FormationOffset> formation = {
    {0.0f,  0.0f,  0.0f},   // Leader
    {-3.0f, -3.0f, 0.0f},   // 左后方 3m
    {-3.0f,  3.0f, 0.0f},   // 右后方 3m
};

// 编队控制循环（20 Hz）
while (running) {
    auto leader_pos = telemetries[0].position_velocity_ned().position;
    for (size_t i = 1; i < systems.size(); i++) {
        Offboard::PositionNedYaw target{};
        target.north_m = leader_pos.north_m + formation[i].north;
        target.east_m  = leader_pos.east_m  + formation[i].east;
        target.down_m  = leader_pos.down_m  + formation[i].down;
        offboards[i].set_position_ned(target);
    }
    std::this_thread::sleep_for(milliseconds(50));
}
```

---

## 第五步：ROS2 多机命名空间方案

```bash
# 每个 PX4 实例使用不同命名空间
uxrce_dds_client start -t udp -h 127.0.0.1 -p 8888 -n px4_0
uxrce_dds_client start -t udp -h 127.0.0.1 -p 8889 -n px4_1

MicroXRCEAgent udp4 -p 8888 &
MicroXRCEAgent udp4 -p 8889 &
```

话题结构：`/px4_N/fmu/out/<topic>`、`/px4_N/fmu/in/<topic>`

---

## 第六步：碰撞规避

```cpp
const float SAFE_DISTANCE = 5.0f;

bool check_collision_risk(size_t a, size_t b, const auto& positions) {
    auto& pa = positions.at(a);
    auto& pb = positions.at(b);
    float dist = std::sqrt(/* dn^2 + de^2 + dd^2 */);
    return dist < SAFE_DISTANCE;
}
```

---

## 编码规范
- 每架飞机的 Offboard setpoint 必须以 ≥ 20 Hz 独立线程发送
- 飞机间通信数据须校验范围（防止坐标溢出）
- 碰撞规避优先级高于任务目标，检测到风险立即悬停
- System ID 与实例 ID 严格对应，禁止硬编码 System ID
