在 PX4 中配置硬件在环（HIL）仿真环境：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 源码：`C:/Users/cuiga/droneyee_px4v1.15.0`（WSL 内：`~/droneyee_px4v1.15.0`）
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
2. **仿真引擎**：Gazebo Classic（推荐，支持最完整）/ jMAVSim（轻量）/ AirSim（高保真视觉）
3. **机型**：多旋翼 iris / 固定翼 plane / 其他
4. **连接方式**：USB（推荐，调试方便）/ UART / 网络
5. **操作系统**：Windows + WSL2 / 纯 Linux
6. **目标**：控制律验证 / 参数调优 / 系统集成测试

---

## 第二步：飞控硬件配置

### 2a 烧录支持 HIL 的固件

HIL 固件与正常固件相同，通过参数切换：

```bash
# 在 WSL 内编译对应板子的固件
cd ~/droneyee_px4v1.15.0

# 示例：Pixhawk 4
make px4_fmu-v5_default

# 示例：Pixhawk 6C
make px4_fmu-v6c_default

# 烧录（飞控通过 USB 连接到 WSL 内）
make px4_fmu-v5_default upload
```

### 2b 通过 QGroundControl 设置 HIL 参数

连接飞控到 QGC 后，在参数页面设置：

```
SYS_HITL = 1        # 启用 HIL 模式（重启后生效）
```

**重要**：设置后必须重启飞控，HIL 模式才会生效。

重启后飞控会：
- 停止读取真实传感器数据（IMU/气压计/GPS）
- 改由 MAVLink HIL 消息接收仿真传感器数据
- 执行器输出改为通过 MAVLink 发送（不驱动真实电机）

### 2c 配置串口连接（USB 方式）

```bash
# WSL 内查看 USB 设备
ls /dev/ttyUSB* /dev/ttyACM*

# 常见设备路径
# Pixhawk USB: /dev/ttyACM0
# FTDI 串口:   /dev/ttyUSB0

# 授权（避免每次 sudo）
sudo usermod -a -G dialout $USER
# 重新登录后生效
```

---

## 第三步：启动仿真器（Gazebo HIL 模式）

### 方案 A：Gazebo + HIL（推荐）

```bash
# WSL 内，PX4 源码目录
cd ~/droneyee_px4v1.15.0

# 启动 Gazebo HIL 仿真（不启动 SITL，只启动仿真环境）
# Gazebo 会监听 MAVLink 端口，等待真实飞控连接
export PX4_SIM_SPEED_FACTOR=1
gazebo Tools/sitl_gazebo/worlds/iris.world &

# 启动 MAVLink 桥接（Gazebo ↔ 飞控）
python3 Tools/sitl_gazebo/src/gazebo_mavlink_interface.py \
  --serial /dev/ttyACM0 --baud 921600
```

**或者使用 PX4 提供的 HIL 启动脚本**：

```bash
# Gazebo HIL 一键启动（需 Gazebo 和串口权限）
./Tools/simulation/gazebo-classic/sitl_run.sh \
  -s rcS -m iris -n 1 -i 0 -p /dev/ttyACM0
```

### 方案 B：jMAVSim HIL（轻量，无 3D 场景）

```bash
# 启动 jMAVSim，连接真实飞控
cd ~/droneyee_px4v1.15.0
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

- `SerialPort`：Windows 下的 COM 端口（在设备管理器中查看 Pixhawk 对应端口）
- 启动 AirSim 后，飞控通过串口直接连接 AirSim

---

## 第四步：连接 QGroundControl

```
飞控 USB ──► QGC（同一台 Windows 机器）
             ├── 实时查看传感器健康状态
             ├── 参数调整
             └── 飞行模式切换（Stabilized / Position / Mission）
```

QGC 连接飞控后，验证以下状态：
- **传感器**：全部显示绿色（数据来自仿真器）
- **GPS**：LOCK 状态（来自 Gazebo 虚拟 GPS）
- **解锁条件**：飞控认为可以解锁（EKF 收敛）

---

## 第五步：验证 HIL 链路

在 QGC 的 MAVLink Console（或通过串口终端）执行：

```bash
# 确认 HIL 模式已激活
param show SYS_HITL
# 输出应为：SYS_HITL = 1

# 确认仿真传感器数据在更新
listener sensor_combined
# 应看到 IMU 数据持续更新

# 确认 GPS 数据正常（来自仿真器）
listener vehicle_gps_position
# 应看到位置数据更新

# 确认 HIL 执行器输出
listener actuator_outputs
# 飞控解锁后应看到电机指令（发送到仿真，不驱动真实电机）

# 查看 MAVLink 消息统计
mavlink status
# 应看到 HIL_SENSOR、HIL_GPS 等消息的接收计数
```

---

## 第六步：HIL 飞行测试

```bash
# 在 QGC 中或 MAVLink Console：
# 解锁
commander arm

# 切换到 Stabilized 模式，用遥控器控制（仿真）
# 或切换到 Mission 模式执行预设任务

# 起飞
commander takeoff

# 验证飞行响应
listener vehicle_attitude
listener vehicle_local_position
```

**验证指标**：
- 姿态响应与 SITL 一致（因为固件相同）
- EKF 收敛时间 < 10s
- 无传感器超时告警
- 电机指令通过 MAVLink 正常发出（仿真器接收并驱动模型）

---

## 第七步：HIL 与 SITL 差异对比验证

| 验证项 | SITL | HIL |
|--------|------|-----|
| 固件调度时序 | 模拟时钟 | **真实时钟** |
| 传感器噪声 | 仿真注入 | 仿真注入 |
| 参数存储 | 文件系统 | **真实 Flash** |
| 电机输出 | 直接到仿真 | 通过 MAVLink |
| 适用场景 | 算法验证 | **系统集成验证** |

---

## 常见问题排查

| 现象 | 原因 | 解决 |
|------|------|------|
| 飞控连接后仿真器无数据 | SYS_HITL 未设置或未重启 | 设置 `SYS_HITL=1` 后重新上电 |
| 仿真器显示飞机不动 | 串口波特率不匹配 | 确认两端都是 921600 |
| QGC 显示传感器红色 | 仿真器未启动或连接断开 | 先启动仿真器再上电飞控 |
| EKF 不收敛 | 仿真 GPS 信号弱 | 确认 Gazebo GPS 插件正常，或降低 `EKF2_REQ_HDOP` |
| WSL 内找不到 /dev/ttyACM0 | USB 未挂载到 WSL | `usbipd attach --wsl --busid <id>`（需要 usbipd-win） |
| AirSim HIL 无响应 | COM 端口号错误 | 设备管理器确认 Pixhawk COM 端口 |

---

## WSL2 USB 挂载（Windows → WSL2）

```powershell
# Windows PowerShell（管理员）
# 安装 usbipd-win
winget install usbipd

# 列出 USB 设备，找到 Pixhawk
usbipd list

# 挂载到 WSL2（busid 如 2-1）
usbipd bind --busid 2-1
usbipd attach --wsl --busid 2-1
```

```bash
# WSL 内确认
ls /dev/ttyACM*
```

---

## 编码规范（HIL 相关开发）
- HIL 模式下禁止真实传感器读取，只读 `hil_sensor` uORB topic
- 执行器输出通过 `actuator_outputs` 发送，禁止直接 PWM 输出
- HIL 时序依赖 `HIL_SENSOR` 消息的时间戳，禁止使用本地时钟
