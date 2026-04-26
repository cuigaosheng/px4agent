---
name: px4-hil-setup
version: "1.0.0"
description: 在 PX4 中配置硬件在环（HIL）仿真环境。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
在 PX4 中配置硬件在环（HIL）仿真环境：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 源码：`~/px4agent`
- HIL 配置文件：`ROMFS/px4fmu_common/init.d/rcS`
- Gazebo HIL 插件：`Tools/sitl_gazebo/`

---

## HIL 原理说明

```
真实飞控硬件（Pixhawk）
    ↑↓ USB/UART MAVLink
仿真器（Gazebo / AirSim）
    ├── 向飞控发送虚拟传感器数据（IMU/GPS/气压计）
    └── 接收飞控输出的执行器指令，驱动仿真模型

优势：飞控运行真实固件 + 真实调度时序，比 SITL 更接近真机
适用：参数调优验证、控制律验证、电机混控调试、飞前系统集成测试
```

---

## 第一步：确认需求

询问用户：
1. **飞控硬件**：Pixhawk 4 / Pixhawk 6C / Cube Orange / 自定义板
2. **仿真引擎**：Gazebo Classic（推荐）/ jMAVSim（轻量）/ AirSim（高保真视觉）
3. **机型**：多旋翼 iris / 固定翼 plane / 其他
4. **连接方式**：USB（推荐）/ UART / 网络
5. **目标**：控制律验证 / 参数调优 / 系统集成测试

---

## 第二步：飞控硬件配置

### 2a 编译固件
```bash
cd ~/px4agent
make px4_fmu-v5_default         # Pixhawk 4
make px4_fmu-v6c_default        # Pixhawk 6C
make px4_fmu-v5_default upload  # 烧录
```

### 2b 通过 QGC 设置 HIL 参数
```
SYS_HITL = 1        # 启用 HIL 模式（重启后生效）
```

### 2c 配置串口连接（USB 方式）
```bash
ls /dev/ttyUSB* /dev/ttyACM*
sudo usermod -a -G dialout $USER
```

---

## 第三步：启动仿真器

### 方案 A：Gazebo + HIL（推荐）
```bash
cd ~/px4agent
./Tools/simulation/gazebo-classic/sitl_run.sh \
  -s rcS -m iris -n 1 -i 0 -p /dev/ttyACM0
```

### 方案 B：jMAVSim HIL（轻量）
```bash
java -Djava.ext.dirs= -jar Tools/jMAVSim/out/production/jmavsim_run.jar \
  -serial /dev/ttyACM0 -baud 921600
```

### 方案 C：AirSim HIL（高保真视觉）

在 Windows 端 `Documents\AirSim\settings.json` 中配置：
```json
{
  "SettingsVersion": 1.2,
  "SimMode": "Multirotor",
  "Vehicles": {
    "PX4": {
      "VehicleType": "PX4Multirotor",
      "UseSerial": true,
      "SerialPort": "COM3",
      "SerialBaudRate": 921600,
      "LockStep": false
    }
  }
}
```

---

## 第四步：连接 QGroundControl

验证以下状态：
- **传感器**：全部显示绿色（数据来自仿真器）
- **GPS**：LOCK 状态（来自 Gazebo 虚拟 GPS）
- **解锁条件**：飞控认为可以解锁（EKF 收敛）

---

## 第五步：验证 HIL 链路

```bash
param show SYS_HITL            # 应为 1
listener sensor_combined       # 确认 IMU 数据持续更新
listener vehicle_gps_position  # 确认 GPS 数据正常
listener actuator_outputs      # 确认电机指令
mavlink status                 # 确认 HIL_SENSOR、HIL_GPS 接收计数
```

---

## 常见问题排查

| 现象 | 原因 | 解决 |
|------|------|------|
| 飞控连接后仿真器无数据 | SYS_HITL 未设置或未重启 | 设置 `SYS_HITL=1` 后重新上电 |
| 仿真器显示飞机不动 | 串口波特率不匹配 | 确认两端都是 921600 |
| EKF 不收敛 | 仿真 GPS 信号弱 | 降低 `EKF2_REQ_HDOP` |
| 找不到 /dev/ttyACM0 | USB 未挂载到 Linux | `usbipd attach --linux --busid <id>` |

---

## 编码规范（HIL 相关开发）
- HIL 模式下禁止真实传感器读取，只读 `hil_sensor` uORB topic
- 执行器输出通过 `actuator_outputs` 发送，禁止直接 PWM 输出
- HIL 时序依赖 `HIL_SENSOR` 消息的时间戳，禁止使用本地时钟
