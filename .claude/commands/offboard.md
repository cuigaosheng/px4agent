在 PX4 中开发 Offboard 外部控制接口：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 项目：`C:/Users/cuiga/droneyee_px4v1.15.0`
- Offboard 控制模块：`src/modules/commander/`
- MAVLink 接收器：`src/modules/mavlink/mavlink_receiver.cpp`
- uORB topics：`msg/offboard_control_mode.msg`、`msg/trajectory_setpoint.msg`
- MAVSDK 示例：`https://mavsdk.mavlink.io/`

---

## 第一步：确认需求

询问用户：
1. **控制接口**：MAVSDK（推荐）/ ROS2 / 直接 MAVLink
2. **控制模式**：
   - 位置控制（NED 坐标系，m）
   - 速度控制（m/s）
   - 加速度控制（m/s²）
   - 姿态控制（四元数 + 推力）
   - 角速率控制（rad/s + 推力）
3. **运行环境**：SITL 仿真 / 真机
4. **任务描述**（如：自动起飞→悬停→画圆→降落）

---

## 第二步：PX4 侧 Offboard 配置

### 关键参数
```bash
# 允许 Offboard 模式（默认已开启）
param set COM_RCL_EXCEPT 4   # RC 丢失时不退出 Offboard（仿真用）
param set NAV_RCL_ACT 0      # RC 丢失动作：0=忽略（仿真用）
param set NAV_DLL_ACT 0      # 数据链丢失动作：0=忽略（仿真用）
```

### Offboard 模式切换条件
- 必须以 ≥ 2 Hz 持续发送 setpoint，否则自动退出 Offboard
- 切换前飞控必须已解锁（armed）
- 建议先发送 setpoint 再切换模式

---

## 第三步：MAVSDK 接口实现

### 安装 MAVSDK
```bash
# Ubuntu
sudo apt install libmavsdk-dev

# 或从源码编译
git clone https://github.com/mavlink/MAVSDK.git
cd MAVSDK && cmake -Bbuild -DCMAKE_BUILD_TYPE=Release
cmake --build build --target install
```

### 基础框架（C++）
```cpp
#include <mavsdk/mavsdk.h>
#include <mavsdk/plugins/action/action.h>
#include <mavsdk/plugins/offboard/offboard.h>
#include <mavsdk/plugins/telemetry/telemetry.h>
#include <chrono>
#include <thread>

using namespace mavsdk;
using namespace std::chrono;

int main() {
    Mavsdk mavsdk{Mavsdk::Configuration{Mavsdk::ComponentType::GroundStation}};

    // 连接 PX4 SITL（UDP）
    ConnectionResult result = mavsdk.add_any_connection("udp://:14540");
    if (result != ConnectionResult::Success) {
        return 1;
    }

    // 等待飞控连接
    auto system = mavsdk.first_autopilot(3.0);
    if (!system) { return 1; }

    auto action = Action{system.value()};
    auto offboard = Offboard{system.value()};
    auto telemetry = Telemetry{system.value()};

    // 等待 GPS 就绪
    while (!telemetry.health().is_global_position_ok) {
        std::this_thread::sleep_for(1s);
    }

    // 先发送初始 setpoint（必须在切换 Offboard 前）
    offboard.set_velocity_ned({0.0f, 0.0f, 0.0f, 0.0f});

    // 解锁
    action.arm();

    // 切换 Offboard 模式
    Offboard::Result offboard_result = offboard.start();
    if (offboard_result != Offboard::Result::Success) { return 1; }

    // 起飞：向上速度 -1 m/s（NED 坐标系，Z 向下为正）
    offboard.set_velocity_ned({0.0f, 0.0f, -1.0f, 0.0f});
    std::this_thread::sleep_for(3s);

    // 悬停
    offboard.set_velocity_ned({0.0f, 0.0f, 0.0f, 0.0f});
    std::this_thread::sleep_for(2s);

    // 停止 Offboard，切回 Hold 模式
    offboard.stop();
    action.land();

    return 0;
}
```

### CMakeLists.txt
```cmake
cmake_minimum_required(VERSION 3.10)
project(offboard_demo)

find_package(MAVSDK REQUIRED)

add_executable(offboard_demo main.cpp)
target_link_libraries(offboard_demo MAVSDK::mavsdk)
```

---

## 第四步：控制模式实现

### 4a 位置控制（NED 坐标系）
```cpp
// 飞到 North+5m, East+0m, Down-10m（即高度 10m）
Offboard::PositionNedYaw position{};
position.north_m = 5.0f;
position.east_m = 0.0f;
position.down_m = -10.0f;
position.yaw_deg = 0.0f;
offboard.set_position_ned(position);
```

### 4b 速度控制（NED 坐标系）
```cpp
// 向北飞 2 m/s
Offboard::VelocityNedYaw velocity{};
velocity.north_m_s = 2.0f;
velocity.east_m_s = 0.0f;
velocity.down_m_s = 0.0f;
velocity.yaw_deg = 0.0f;
offboard.set_velocity_ned(velocity);
```

### 4c 姿态控制
```cpp
// 设置姿态（四元数）+ 推力
Offboard::Attitude attitude{};
attitude.roll_deg = 0.0f;
attitude.pitch_deg = 5.0f;   // 前倾 5°
attitude.yaw_deg = 0.0f;
attitude.thrust_value = 0.6f; // 0~1
offboard.set_attitude(attitude);
```

### 4d 画圆轨迹示例
```cpp
const float radius = 5.0f;   // 半径 5m
const float altitude = -10.0f; // 高度 10m（NED）
const float speed = 1.0f;    // 线速度 1 m/s
const float omega = speed / radius; // 角速度

for (int i = 0; i < 360; i++) {
    float angle = i * M_PI / 180.0f;
    Offboard::PositionNedYaw pos{};
    pos.north_m = radius * std::cos(angle);
    pos.east_m  = radius * std::sin(angle);
    pos.down_m  = altitude;
    pos.yaw_deg = angle * 180.0f / M_PI + 90.0f; // 朝向切线方向
    offboard.set_position_ned(pos);
    std::this_thread::sleep_for(milliseconds(static_cast<int>(1000.0f / omega / 360.0f * 2 * M_PI)));
}
```

---

## 第五步：SITL 端到端验证

```bash
# 终端 1：启动 PX4 SITL
cd ~/droneyee_px4v1.15.0
make px4_sitl gazebo

# 终端 2：编译并运行 Offboard 程序
mkdir build && cd build
cmake .. && make
./offboard_demo
```

验证检查项：
- PX4 控制台输出 `INFO [commander] Offboard mode`
- Gazebo 中飞机按预期轨迹飞行
- `listener offboard_control_mode` 确认 setpoint 正常接收
- `listener trajectory_setpoint` 确认位置/速度指令正确

---

## 第六步：安全机制

### 必须实现的安全保护
```cpp
// 1. 超时保护：setpoint 发送线程
std::thread setpoint_thread([&]() {
    while (running) {
        offboard.set_velocity_ned(current_setpoint);
        std::this_thread::sleep_for(milliseconds(50)); // 20 Hz
    }
});

// 2. 遥控器接管：监听飞行模式变化
telemetry.subscribe_flight_mode([&](Telemetry::FlightMode mode) {
    if (mode != Telemetry::FlightMode::Offboard) {
        running = false; // 退出 Offboard 控制循环
    }
});

// 3. 地理围栏：位置超限时停止
telemetry.subscribe_position([&](Telemetry::Position pos) {
    if (std::abs(pos.relative_altitude_m) > MAX_ALTITUDE) {
        offboard.stop();
        action.hold();
    }
});
```

---

## 常见问题排查

| 现象 | 原因 | 解决 |
|------|------|------|
| Offboard 模式切换失败 | 未提前发送 setpoint | 先发送 setpoint 再调用 `offboard.start()` |
| 自动退出 Offboard | setpoint 发送频率 < 2 Hz | 确保 ≥ 20 Hz 持续发送 |
| 飞机不响应位置指令 | EKF 未收敛 | 等待 `telemetry.health().is_local_position_ok` |
| 连接超时 | 端口或防火墙问题 | 检查 UDP 14540，WSL 需配置端口转发 |
