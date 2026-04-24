# px4agent — Claude Code 项目上下文

## 项目定位

本项目是 **PX4 无人系统 AI 开发平台**，通过 Claude Code Skills 让工程师用自然语言驱动 PX4 全链路开发。

核心工作流：`自然语言需求 → Skill 调度 → 代码生成 → 仿真验证`

---

## 关键路径

| 资源 | 路径 |
|------|------|
| PX4 固件源码 | `C:/Users/cuiga/droneyee_px4v1.15.0`（WSL 内：`~/droneyee_px4v1.15.0`） |
| Skills 目录 | `.claude/commands/` |
| ROS2 工作空间 | `~/ros2_ws/`（WSL 内） |
| 飞行日志目录 | `build/px4_sitl_default/rootfs/log/` 或 `/fs/microsd/log/` |

---

## 运行环境

- **平台**：Windows 11 + WSL2（Ubuntu）
- **PX4 版本**：v1.15.0（自定义分支 `droneyee_px4v1.15.0`）
- **ROS2 版本**：Humble（LTS）
- **仿真引擎**：Gazebo Classic（主力）、AirSim（高保真视觉）
- **所有编译和运行命令必须在 WSL 中执行**

---

## 可用 Skills（14 个）

| Skill | 用途 |
|-------|------|
| `/sim-start` | 启动 PX4 SITL 仿真（Gazebo / AirSim） |
| `/sensor-driver` | 创建传感器驱动（驱动→uORB→MAVLink→QGC） |
| `/px4-module` | 创建 PX4 业务模块 |
| `/px4-workqueue` | 创建 WorkQueue 驱动 |
| `/mavlink-custom` | 定义自定义 MAVLink 消息 |
| `/uavcan-custom` | 添加自定义 DroneCAN (UAVCAN v0) 节点 |
| `/review` | 代码安全审查（23 项检查清单） |
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

---

## PX4 编码规范（所有 Skills 强制执行）

- **禁止**动态内存分配（`new` / `delete` / `malloc` / `free`）
- **禁止**独立线程，统一使用 `ScheduledWorkItem` WorkQueue
- **禁止**驱动层浮点运算，用定点数或整型
- **禁止**阻塞调用（`sleep` / `usleep` / mutex lock），用 `ScheduleDelayed()`
- **禁止** `printf`，用 `PX4_DEBUG` / `PX4_INFO` / `PX4_WARN` / `PX4_ERR`
- **禁止**裸调 `param_get()`，用 `DEFINE_PARAMETERS` + `ModuleParams`
- **禁止**系统时钟，时间戳统一用 `hrt_absolute_time()`
- **禁止** Cyphal v1，只用 UAVCAN v0 (DroneCAN)
- 通信数据（MAVLink / DroneCAN 输入）**必须先范围校验再写 uORB**

---

## Skill 工作原则

每个 Skill 采用**分步确认**模式：

1. AI 分析现有代码库，汇报结果 → **等待用户确认**
2. AI 生成代码框架，展示代码 → **等待用户确认**
3. AI 集成进构建系统，展示改动 → **等待用户确认**
4. AI 给出验证命令，端到端确认

**AI 不得在用户确认前自行修改 PX4 源码。**

---

## 子模块说明

以下目录为 Git Submodule，仅作为参考文档使用，不在本项目内编译：

- `PX4-Autopilot/` — 上游参考，实际固件在 `droneyee_px4v1.15.0`
- `qgroundcontrol/` — 地面站参考
- `AirSim/`, `gazebo-classic/` — 仿真引擎参考
- `ros2/`, `PlotJuggler/`, `flight_review/`, `bagel/` — 工具参考

---

## 路线图（待实现）

- [ ] `ci-test` — 自动化测试与 CI 配置（GitHub Actions + PX4 单元测试）
