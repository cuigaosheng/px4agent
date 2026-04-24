# PX4 开发 Skills

## 可用 Skills

| Skill | 用途 |
|-------|------|
| `/sim-start` | 启动 PX4 SITL 仿真（Gazebo / AirSim） |
| `/sensor-driver` | 创建传感器驱动（驱动→uORB→MAVLink→QGC） |
| `/px4-module` | 创建 PX4 业务模块 |
| `/px4-workqueue` | 创建 WorkQueue 驱动 |
| `/mavlink-custom` | 定义自定义 MAVLink 消息 |
| `/uavcan-custom` | 添加自定义 DroneCAN (UAVCAN v0) 节点 |
| `/review` | 代码安全审查 |
| `/commit` | 生成规范 git 提交信息 |
| `/handoff` | 生成会话交接文档（HANDOFF.md） |
| `/log-analyze` | 分析 ULog 飞行日志 |
| `/param-tune` | 飞控参数调优（PID/EKF2/振动滤波） |
| `/offboard` | 开发 Offboard 外部控制（MAVSDK/ROS2） |
| `/ros2-bridge` | 配置 ROS2 与 PX4 桥接（uXRCE-DDS） |
| `/control-law` | 设计自定义飞行控制律 |
| `/hil-setup` | 配置硬件在环（HIL）仿真环境 |
| `/swarm-mission` | 多机协同任务规划（编队/搜索/协同） |
| `/mixer-actuator` | 配置执行器与混控（电机映射/ESC/PWM/DShot） |
| `/failsafe-config` | 配置故障保护逻辑（RC丢失/低电量/围栏/RTL） |
| `/board-bringup` | 新飞控硬件板级支持（引脚/NuttX/驱动/校准） |

## PX4 编码规范

适用于所有涉及 PX4-Autopilot 源码的 Skill，以 PX4 官方贡献指南为准，关键约束如下：

- 禁止动态内存分配（`new` / `delete` / `malloc` / `free`）
- 禁止独立线程，统一使用 `ScheduledWorkItem` WorkQueue
- 禁止驱动层浮点运算，用定点数或整型
- 禁止阻塞调用（`sleep` / `usleep` / mutex lock），用 `ScheduleDelayed()`
- 禁止 `printf`，用 `PX4_DEBUG` / `PX4_INFO` / `PX4_WARN` / `PX4_ERR`
- 禁止裸调 `param_get()`，用 `DEFINE_PARAMETERS` + `ModuleParams`
- 时间戳统一用 `hrt_absolute_time()`，禁止系统时钟
- 只用 UAVCAN v0 (DroneCAN)，禁止 Cyphal v1
- 通信数据（MAVLink / DroneCAN 输入）必须先范围校验再写 uORB
