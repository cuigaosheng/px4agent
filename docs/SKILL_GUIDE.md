# Skill 选择指南

> 48 个 Skill 的完整分类、用途和选择决策树

---

## 快速决策树

```
你的需求是什么？

├─ 🚀 我想快速启动开发环境
│  └─ /setup-all              ← 一键安装 PX4 完整环境
│
├─ 📡 我想开发传感器驱动
│  ├─ 有现成的芯片库吗？
│  │  ├─ 是 → /px4-imu-gen、/px4-mag-gen、/px4-gnss-gen 等
│  │  └─ 否 → /px4-sensor-codegen（通用生成器）
│  └─ 需要完整工作流？
│     └─ 是 → /px4-e2e-sensor（端到端开发）
│
├─ 🚁 我想开发避障系统
│  └─ /px4-e2e-avoidance      ← 完整避障链路（传感器+算法+仿真+验证）
│
├─ 🎮 我想开发控制律
│  └─ /px4-e2e-control        ← 完整控制链路（内环+外环+仿真+ROS2）
│
├─ 🐝 我想做多机协同
│  └─ /px4-e2e-swarm          ← 完整多机链路（多实例+协同+通信）
│
├─ 🔧 我想调参或诊断
│  ├─ 有飞行日志吗？
│  │  ├─ 是 → /px4-diagnose（自动诊断+调参建议）
│  │  └─ 否 → /px4-param-tune（手动调参）
│  └─ 需要分析日志？
│     └─ 是 → /px4-log-analyze（日志分析）
│
├─ 🌐 我想集成 ROS2
│  └─ /px4-ros2-bridge        ← uXRCE-DDS 桥接配置
│
└─ 📊 我想在 QGC 显示数据
   └─ /qgc-display            ← 自定义 MAVLink 数据图表
```

---

## Layer 3：场景技能（4 个）

端到端场景编排，涵盖 PX4 开发的完整工作流。

### px4-e2e-sensor - 传感器端到端开发

**用途**：从驱动开发到 QGC 显示的完整传感器开发链路

**适用场景**：
- 添加新传感器（IMU、磁力计、气压计、测距仪等）
- 需要完整的驱动 → uORB → MAVLink → QGC 链路
- 需要仿真验证

**触发命令**：
```
/px4-e2e-sensor <传感器名> <总线类型>

示例：
/px4-e2e-sensor ICM42688 SPI
/px4-e2e-sensor MS5611 I2C
/px4-e2e-sensor SF45 UART
```

**输出**：
- 完整驱动代码（驱动 + uORB + MAVLink）
- 仿真配置（Gazebo 或 AirSim）
- QGC 显示配置
- 单元测试框架

---

### px4-e2e-avoidance - 避障全链路开发

**用途**：从传感器到避障算法的完整避障系统开发

**适用场景**：
- 开发避障系统（毫米波雷达、激光雷达等）
- 需要传感器 + 算法 + 仿真 + 安全验证
- 需要与 QGC 集成

**触发命令**：
```
/px4-e2e-avoidance <传感器> <总线> <扫描类型> <仿真器> <算法>

示例：
/px4-e2e-avoidance 毫米波雷达 DroneCAN 单点测距 AirSim ROS2方案
/px4-e2e-avoidance SF45 UART 360°扫描 Gazebo internal
```

**输出**：
- 传感器驱动
- 避障算法模块
- 仿真环境配置
- 故障保护配置
- QGC 显示

---

### px4-e2e-control - 控制律全链路开发

**用途**：从控制律设计到仿真验证的完整控制开发

**适用场景**：
- 开发自定义飞行控制律（PID、MPC、自适应等）
- 需要内环/外环设计
- 需要 SITL 仿真验证
- 需要 ROS2 接口

**触发命令**：
```
/px4-e2e-control <控制律类型>

示例：
/px4-e2e-control PID
/px4-e2e-control MPC
/px4-e2e-control 自适应
```

**输出**：
- 控制律实现代码
- 参数定义
- SITL 仿真测试
- ROS2 接口
- 调参指南

---

### px4-e2e-swarm - 多机协同全链路开发

**用途**：从多机仿真到协同任务的完整多机开发

**适用场景**：
- 开发多机协同系统
- 需要多实例 SITL 仿真
- 需要协同通信和任务规划
- 需要安全验证

**触发命令**：
```
/px4-e2e-swarm <机型> <任务>

示例：
/px4-e2e-swarm 四旋翼 编队飞行
/px4-e2e-swarm 固定翼 搜索任务
```

**输出**：
- 多实例 SITL 配置
- 协同通信模块
- 任务规划代码
- 安全验证框架

---

## Layer 2：组件技能（25 个）

细粒度的开发工具，可独立使用或组合使用。

### 代码生成器（9 个）

一键生成完整驱动框架。

#### px4-imu-gen - IMU 驱动代码生成器

**支持芯片**：MPU6050、MPU9250、ICM20689、ICM42688、BMI088、BMI160、LSM6DSL、LSM6DSO、MPU6000

**触发命令**：
```
/px4-imu-gen <芯片型号> <总线类型>

示例：
/px4-imu-gen ICM42688 SPI
/px4-imu-gen MPU6050 I2C
```

**输出**：驱动 + uORB + MAVLink + 参数 + CMakeLists + 单元测试

---

#### px4-mag-gen - 磁力计驱动代码生成器

**支持芯片**：HMC5883L、IST8310、QMC5883L、LIS3MDL、BMM150、AK8963、AK09916、RM3100

**触发命令**：
```
/px4-mag-gen <芯片型号> <总线类型>
```

---

#### px4-rangefinder-gen - 测距仪驱动代码生成器

**支持芯片**：VL53L0X、VL53L1X、SF45、TF-Luna、TF-Mini、HC-SR04、MB1242、PX4FLOW

**触发命令**：
```
/px4-rangefinder-gen <芯片型号> <总线类型>
```

---

#### px4-gnss-gen - GNSS 接收机驱动代码生成器

**支持芯片**：u-blox NEO-M8N、M9N、ZED-F9P、F9R、Septentrio mosaic-X5、Novatel PwrPak7、Emlid Reach M+、Swift Duro、Garmin GNSS 18x、SiRF Atlas

**触发命令**：
```
/px4-gnss-gen <芯片型号> <总线类型>
```

**特点**：支持 RTK 高精度定位

---

#### px4-mmwave-radar-gen - 毫米波雷达驱动代码生成器

**支持芯片**：TI IWR1443、IWR1642、IWR1843、AWR1443、AWR1642、AWR1843、Bosch ARS430、ARS441、MRR4、Delphi ESR、Continental ARS、MRR

**触发命令**：
```
/px4-mmwave-radar-gen <芯片型号> <总线类型>
```

---

#### px4-sensor-codegen - 通用传感器代码生成器

**支持类型**：IMU、磁力计、气压计、测距仪、光流、空速计、GPS、360° 测距、自定义

**触发命令**：
```
/px4-sensor-codegen <传感器类型> <自定义参数>
```

**特点**：支持完全自定义传感器类型和数据字段

---

#### px4-uorb-msg - uORB 消息代码生成器

**用途**：一键生成自定义 uORB 消息定义、发布器、订阅器、单元测试

**触发命令**：
```
/px4-uorb-msg <消息名> <字段列表>

示例：
/px4-uorb-msg custom_sensor_data "uint32_t sensor_id, float temperature_c, uint16_t pressure_pa"
```

---

#### px4-param-define - 参数定义代码生成器

**用途**：一键生成参数定义、DEFINE_PARAMETERS 代码、QGC 配置

**触发命令**：
```
/px4-param-define <参数列表>

示例：
/px4-param-define "CUSTOM_APP_GAIN FLOAT 1.0 0.0 10.0, CUSTOM_APP_TIMEOUT INT32 1000 100 5000"
```

---

#### px4-crid-backport - C-RID 驱动迁移生成器

**用途**：从 PX4 main 分支获取 C-RID 驱动代码，迁移到 1.15.0 版本

**触发命令**：
```
/px4-crid-backport
```

**输出**：完整的 C-RID 驱动框架 + 仿真测试

---

### PX4 固件开发（12 个）

#### px4-sensor-driver - 传感器驱动开发

**用途**：创建或核实传感器驱动（驱动 → uORB → MAVLink → QGC）

**触发命令**：
```
/px4-sensor-driver <传感器名> <总线类型>
```

---

#### px4-workqueue - WorkQueue 驱动/任务

**用途**：创建基于 ScheduledWorkItem 的驱动或周期任务

**触发命令**：
```
/px4-workqueue <驱动名> <调度方式>
```

---

#### px4-module - PX4 业务模块

**用途**：创建 PX4 业务模块（WorkQueue + uORB + 参数）

**触发命令**：
```
/px4-module <模块名> <功能描述>
```

---

#### px4-mavlink-custom - 自定义 MAVLink 消息

**用途**：定义自定义 MAVLink 消息并配置发送/接收

**触发命令**：
```
/px4-mavlink-custom <消息名> <字段列表>
```

---

#### px4-uavcan-custom - 自定义 DroneCAN 消息

**用途**：添加自定义 UAVCAN v0 (DroneCAN) 节点

**触发命令**：
```
/px4-uavcan-custom <节点名> <功能>
```

---

#### px4-control-law - 自定义飞行控制律

**用途**：设计和实现自定义飞行控制律（PID/MPC/自适应）

**触发命令**：
```
/px4-control-law <控制律类型>
```

---

#### px4-param-tune - 参数调优

**用途**：调整 PX4 飞控参数（PID/EKF2/振动滤波）

**触发命令**：
```
/px4-param-tune <参数类型>

示例：
/px4-param-tune PID
/px4-param-tune EKF2
```

---

#### px4-mixer-actuator - 执行器混控配置

**用途**：配置电机映射、PWM、DShot

**触发命令**：
```
/px4-mixer-actuator <机型> <电机数>
```

---

#### px4-failsafe-config - 故障保护配置

**用途**：配置故障保护逻辑（RC 丢失/低电量/围栏/RTL）

**触发命令**：
```
/px4-failsafe-config <故障类型>
```

---

#### px4-board-bringup - 飞控硬件板级支持

**用途**：添加自定义飞控硬件（板级支持、引脚、NuttX、驱动、校准）

**触发命令**：
```
/px4-board-bringup <硬件名>
```

---

#### px4-log-analyze - 飞行日志分析

**用途**：分析 ULog 飞行日志（支持 pyulog、PlotJuggler、flight_review）

**触发命令**：
```
/px4-log-analyze <日志文件路径>
```

---

#### px4-diagnose - 日志诊断 + 调参建议

**用途**：自动诊断飞行日志问题并给出调参建议

**触发命令**：
```
/px4-diagnose <日志文件路径>
```

---

### 仿真与集成（4 个）

#### px4-sim-start - SITL 仿真启动

**用途**：启动 PX4 SITL 仿真（Gazebo 或 AirSim）

**触发命令**：
```
/px4-sim-start <仿真器>

示例：
/px4-sim-start gazebo
/px4-sim-start airsim
```

---

#### px4-hil-setup - 硬件在环仿真配置

**用途**：配置硬件在环（HIL）仿真环境

**触发命令**：
```
/px4-hil-setup
```

---

#### px4-offboard - Offboard 外部控制

**用途**：开发 Offboard 外部控制接口（MAVSDK/ROS2）

**触发命令**：
```
/px4-offboard <接口类型>

示例：
/px4-offboard MAVSDK
/px4-offboard ROS2
```

---

#### px4-ros2-bridge - ROS2 与 PX4 桥接

**用途**：配置 ROS2 与飞控的通信桥接（uXRCE-DDS）

**触发命令**：
```
/px4-ros2-bridge
```

---

### 地面站（1 个）

#### qgc-display - QGC 自定义数据图表

**用途**：在 QGroundControl 中接收自定义 MAVLink 消息并展示为实时图表

**触发命令**：
```
/qgc-display <消息名> <显示类型>
```

---

## Layer 1：基础设施（5 个）

通用开发工具，支持所有 Skill。

| Skill | 用途 |
|-------|------|
| `/commit` | 生成规范 git 提交信息 |
| `/review` | 代码安全审查（内存/空指针/PX4 规范） |
| `/handoff` | 生成会话交接文档 |
| `/simplify` | 代码冗余审查 |
| `/clean-contract` | 清理残留契约文件 |

---

## Layer 0.5：环境安装（7 个）

一键安装 PX4 开发环境。

| Skill | 用途 |
|-------|------|
| `/setup-all` | 完整开发环境一键安装 |
| `/setup-wsl2` | WSL2 + Ubuntu 22.04（Windows 11 专用） |
| `/setup-px4` | PX4 工具链 + SITL 编译 |
| `/setup-gazebo` | Gazebo Classic 11 |
| `/setup-qgc` | QGroundControl + 网络配置 |
| `/setup-airsim` | AirSim settings.json 配置 |
| `/setup-ros2` | ROS2 Humble + uXRCE-DDS |

---

## 使用示例

### 示例 1：快速开始（新手）

```
1. /setup-all                    ← 安装开发环境
2. /px4-sim-start gazebo         ← 启动仿真
3. /px4-imu-gen ICM42688 SPI     ← 生成驱动
4. /px4-e2e-sensor ICM42688 SPI  ← 完整开发链路
```

### 示例 2：避障系统开发

```
1. /px4-e2e-avoidance 毫米波雷达 DroneCAN 单点测距 AirSim ROS2方案
   ↓
   自动调用：
   - /px4-uavcan-custom          ← DroneCAN 驱动
   - /airsim-sensor              ← 仿真配置
   - /px4-ros2-bridge            ← ROS2 桥接
   - /px4-offboard               ← 外部控制
   - /qgc-display                ← QGC 显示
   - /px4-failsafe-config        ← 故障保护
```

### 示例 3：参数调优

```
1. /px4-log-analyze ~/logs/flight.ulg    ← 分析日志
2. /px4-diagnose ~/logs/flight.ulg       ← 自动诊断
3. /px4-param-tune PID                   ← 调参建议
```

---

## 获取帮助

- **快速启动**：[QUICK_START.md](./QUICK_START.md)
- **详细安装**：[INSTALLATION.md](./INSTALLATION.md)
- **项目 README**：[README.md](../README.md)
