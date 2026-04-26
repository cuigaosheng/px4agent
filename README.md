# px4agent

> 基于 PX4 的无人系统智能开发平台 —— 以先进 AI 技术加速无人系统进化

---

## 项目定位

无人系统的开发门槛长期偏高：飞控固件、通信协议、仿真环境、地面站、数据分析……每个环节都需要专深的领域知识，团队协作成本极大。

**px4agent** 的目标是打破这一壁垒。

本项目将 PX4 完整生态集成为统一工作空间，并在其上构建一套 **AI 开发代理层**（Claude Code Skills）。开发者只需用自然语言描述需求，AI 即可完成从需求分析、代码生成、规范审查到验证的全链路工作。

---

## 核心理念

```
自然语言需求  ──►  AI 代理理解与规划  ──►  符合 PX4 规范的代码  ──►  仿真验证
```

- **人机协作**：AI 负责重复性的工程实现，工程师专注系统设计与决策
- **规范内嵌**：PX4 编码规范、安全约束、架构模式直接编码进每个 Skill
- **端到端闭环**：从驱动、通信协议到地面站 UI、数据分析，整条链路在同一平台内完成
- **接口契约**：跨组件开发时自动生成接口契约文件，保证 uORB / MAVLink / 仿真器参数全链路一致

---

## 典型使用场景

### 场景一：毫米波雷达避障全链路开发

开发者只需一条命令，AI 自动完成感知→仿真→算法→安全→验证的全链路开发：

```
/px4-e2e-avoidance 毫米波雷达 DroneCAN，4米，20Hz，AirSim，ROS2方案
```

AI 执行步骤：

| 步骤 | 内容 | 涉及 Skill |
|------|------|-----------|
| Step 0 | 生成接口契约，锁定 uORB topic / MAVLink ID / 仿真器 / 算法方案 | — |
| Step 1 | DroneCAN 雷达驱动开发，发布 `distance_sensor` uORB | `/px4-uavcan-custom` |
| Step 2 | AirSim Distance 传感器仿真配置（settings.json） | `/airsim-sensor` |
| Step 3 | ROS2 避障节点，订阅 `distance_sensor`，发布 `trajectory_setpoint` | `/px4-ros2-bridge` + `/px4-offboard` |
| Step 4 | QGC 障碍物距离曲线显示 | `/qgc-display` |
| Step 5 | 故障保护：传感器超时→悬停，CP 触发 3s→RTL | `/px4-failsafe-config` |
| Step 6 | HIL 闭环验证 + 飞行日志复盘 | `/px4-hil-setup` + `/px4-log-analyze` |

契约机制保证所有组件使用相同的接口参数，无需人工对齐。

---

### 场景二：CUAV RFID 模块驱动开发

RFID 模块通过 DroneCAN 接入，需要完整的驱动→MAVLink→QGC 显示链路：

```
/px4-e2e-sensor CUAV_RFID DroneCAN
```

AI 执行步骤：

| 步骤 | 内容 | 涉及 Skill |
|------|------|-----------|
| Step 0 | 生成接口契约，锁定 DSDL / uORB / MAVLink / QGC 字段，仿真器写入"无" | — |
| Step 1 | DroneCAN 驱动：DSDL 定义 → 解析适配 → 发布 `rfid_report` uORB | `/px4-uavcan-custom` |
| Step 2 | 仿真层：**自动跳过**（无硬件仿真需求） | — |
| Step 3 | MAVLink 流：定义 `RFID_REPORT` 消息，配置推送频率 | `/px4-mavlink-custom` |
| Step 4 | QGC 显示：tag_id / signal_strength / timestamp 实时曲线 | `/qgc-display` |

与毫米波雷达共用同一个场景 Skill，通过参数区分处理分支，无需新建场景。

---

### 场景三：外场抖动诊断 + PID 自动调参

飞行人员发现飞机抖动，怀疑积分饱和，一条命令完成诊断到建议：

```
/px4-diagnose ~/logs/flight_2026-04-26.ulg
```

AI 执行流程：

```
1. pyulog 自动提取 rate_ctrl_status / actuator_controls（全自动）
   → 发现 roll_integ 在第 46.5~49.2s 异常累积，actuator 输出饱和

2. ⏸ 暂停：请用 bagel 做 3D 回放，确认抖动时间段和轴

3. ⏸ 暂停：请打开 flight_review HTML 报告，描述跟踪曲线偏差

4. AI 综合以上输入，输出结构化诊断：
   根本原因：MC_ROLLRATE_I 过大导致积分饱和振荡

5. 自动给出参数修改建议表：
   MC_ROLLRATE_I  0.15 → 0.08  降低 I 项，减少积分饱和风险
   MC_ROLLRATE_D  0.003 → 0.004 适当增加 D 项，抑制残余振荡
```

> 与分别触发 `/px4-log-analyze` → `/handoff` → `/px4-param-tune` 三步相比，`/px4-diagnose` 将诊断结论的传递自动化，只在需要人工读图时暂停。

---

## Skill 分层架构

Skills 按职责分为四层：

```
┌─────────────────────────────────────────────────────┐
│  Layer 3：场景技能层（4 个，固定不新增）              │
│  /px4-e2e-sensor  /px4-e2e-avoidance                │
│  /px4-e2e-control  /px4-e2e-swarm                   │
├─────────────────────────────────────────────────────┤
│  Layer 2：组件技能层（25 个）                        │
│  PX4固件(12) + 仿真集成(7) + 地面站(1) + 运维(1)   │
├─────────────────────────────────────────────────────┤
│  Layer 1：基础设施技能层（5 个）                     │
│  /commit  /review  /handoff  /simplify              │
│  /clean-contract                                    │
├─────────────────────────────────────────────────────┤
│  Layer 0：行为准则与领域知识层（常驻加载）            │
│  CLAUDE.md + .claude/context/*.md                   │
└─────────────────────────────────────────────────────┘
```

### Layer 3：场景技能（跨组件编排）

场景数量永久固定为 4 个，新需求通过参数区分，不新增场景。

| Skill | 触发命令 | 覆盖链路 |
|-------|---------|---------|
| px4-e2e-sensor | `/px4-e2e-sensor <传感器> <总线>` | 驱动 → MAVLink → 仿真 → QGC 显示 |
| px4-e2e-avoidance | `/px4-e2e-avoidance <传感器> <算法>` | 感知 → 仿真 → 算法 → 安全 → 验证 |
| px4-e2e-control | `/px4-e2e-control <控制律类型>` | 控制律 → 仿真 → ROS2 接口 → 调参 |
| px4-e2e-swarm | `/px4-e2e-swarm <机型> <任务>` | 多实例仿真 → 协同任务 → 通信 → 安全 |

### Layer 2：组件技能

#### PX4 固件组

| Skill | 触发命令 | 功能 |
|-------|---------|------|
| px4-sensor-driver | `/px4-sensor-driver` | 传感器驱动（I2C/SPI/UART → uORB → MAVLink → QGC） |
| px4-workqueue | `/px4-workqueue` | ScheduledWorkItem 完整驱动框架 |
| px4-module | `/px4-module` | PX4 业务模块（WorkQueue + uORB + 参数） |
| px4-mavlink-custom | `/px4-mavlink-custom` | 自定义 MAVLink 消息定义与流实现 |
| px4-uavcan-custom | `/px4-uavcan-custom` | 自定义 DroneCAN (UAVCAN v0) 节点 |
| px4-control-law | `/px4-control-law` | 自定义飞行控制律（PID/MPC/自适应） |
| px4-param-tune | `/px4-param-tune` | PID / EKF2 / 振动滤波参数调优 |
| px4-mixer-actuator | `/px4-mixer-actuator` | 电机映射 / PWM / DShot 配置 |
| px4-failsafe-config | `/px4-failsafe-config` | 故障保护逻辑（RC 丢失/低电量/围栏/RTL） |
| px4-board-bringup | `/px4-board-bringup` | 新飞控硬件板级支持 |
| px4-log-analyze | `/px4-log-analyze` | ULog 飞行日志分析 |
| px4-diagnose | `/px4-diagnose` | 日志自动诊断 + PID 调参建议（pyulog 全自动，GUI 工具人工介入）|

#### 仿真与集成组

| Skill | 触发命令 | 功能 |
|-------|---------|------|
| px4-sim-start | `/px4-sim-start` | SITL + Gazebo / AirSim 仿真启动 |
| px4-hil-setup | `/px4-hil-setup` | 硬件在环（HIL）通用配置 |
| px4-offboard | `/px4-offboard` | MAVSDK / ROS2 外部控制接口 |
| px4-ros2-bridge | `/px4-ros2-bridge` | uXRCE-DDS 桥接配置 |
| px4-swarm-mission | `/px4-swarm-mission` | 多机协同任务规划 |
| airsim-sensor | `/airsim-sensor` | AirSim 自定义传感器仿真（settings.json） |
| gazebo-sensor | `/gazebo-sensor` | Gazebo 传感器插件开发 + SDF 配置 |

#### 地面站组

| Skill | 触发命令 | 功能 |
|-------|---------|------|
| qgc-display | `/qgc-display` | QGC 自定义 MAVLink 数据图表显示 |

### Layer 1：基础设施技能

| Skill | 触发命令 | 功能 |
|-------|---------|------|
| review | `/review` | 安全审查：内存 / 空指针 / PX4 规范合规 |
| commit | `/commit` | 生成约定式 git 提交信息 |
| handoff | `/handoff` | 生成会话交接文档 HANDOFF.md |
| simplify | `/simplify` | 审查代码冗余，给出精简建议 |
| clean-contract | `/clean-contract` | 清除 `.claude/contracts/` 下残留契约文件 |

---

## 接口契约机制

Layer 3 场景 Skill 在 Step 0 自动生成接口契约文件（`.claude/contracts/<task>.contract.md`），锁定所有跨组件接口参数：

```
uORB topic    MAVLink 消息 ID    数据单位    采样率    仿真器    算法方案
```

后续各组件 Skill 读取契约参数，跳过重复询问，保证链路参数全程一致。

契约文件生命周期：任务启动时创建 → 全部步骤完成后自动删除。会话中断可恢复，手动清理用 `/clean-contract`。

---

## 内嵌编码规范

所有 Skills 共同遵守以下 PX4 硬性约束：

- **禁止动态内存分配**（`new` / `delete` / `malloc` / `free`）
- **禁止独立线程**，统一使用 `ScheduledWorkItem` WorkQueue
- **禁止驱动层浮点运算**，用定点数或整型
- **禁止阻塞调用**（`sleep` / `usleep` / mutex lock），用 `ScheduleDelayed()`
- **禁止 `printf`**，用 `PX4_DEBUG` / `PX4_INFO` / `PX4_WARN` / `PX4_ERR`
- **禁止裸调 `param_get()`**，用 `DEFINE_PARAMETERS` + `ModuleParams`
- **时间戳统一用 `hrt_absolute_time()`**，禁止系统时钟
- **只用 UAVCAN v0 (DroneCAN)**，禁止 Cyphal v1
- **通信数据先范围校验再写 uORB**，防止非法值注入

---

## 生态组件

| 组件 | 路径 | 职责 |
|------|------|------|
| PX4-Autopilot | `PX4-Autopilot/` | 飞控固件核心 |
| QGroundControl | `qgroundcontrol/` | 地面控制站 |
| AirSim | `AirSim/` | 高保真物理 + 视觉仿真 |
| Gazebo Classic | `gazebo-classic/` | PX4 官方 SITL 仿真引擎 |
| ROS2 | `ros2/` | 机器人操作系统 |
| PlotJuggler | `PlotJuggler/` | 高性能时序数据可视化 |
| flight_review | `flight_review/` | 飞行日志在线分析平台 |
| bagel | `bagel/` | 数据包录制与回放工具 |

---

## 目录结构

```
px4agent/
├── CLAUDE.md                      # Layer 0 行为准则（全量加载 context/）
├── .claude/
│   ├── context/                   # Layer 0 领域知识（全量加载）
│   │   ├── px4.md
│   │   ├── qgc.md
│   │   ├── gazebo.md
│   │   ├── ros2.md
│   │   ├── airsim.md
│   │   ├── plotjuggler.md
│   │   ├── flight-review.md
│   │   └── bagel.md
│   ├── contracts/                 # 接口契约（运行时生成，不入库）
│   │   └── .gitkeep
│   └── skills/                    # 全部技能（入库）
│       ├── [Layer 1] commit/ handoff/ review/ simplify/ clean-contract/
│       ├── [Layer 2] px4-sensor-driver/ px4-workqueue/ px4-module/
│       │            px4-mavlink-custom/ px4-uavcan-custom/ px4-control-law/
│       │            px4-param-tune/ px4-mixer-actuator/ px4-failsafe-config/
│       │            px4-board-bringup/ px4-log-analyze/ px4-diagnose/
│       │            px4-sim-start/ px4-hil-setup/ px4-offboard/
│       │            px4-ros2-bridge/ px4-swarm-mission/
│       │            airsim-sensor/ gazebo-sensor/ qgc-display/
│       └── [Layer 3] px4-e2e-sensor/ px4-e2e-avoidance/
│                     px4-e2e-control/ px4-e2e-swarm/
├── PX4-Autopilot/                 # 飞控固件 (submodule)
├── qgroundcontrol/                # 地面控制站 (submodule)
├── AirSim/                        # 高保真仿真 (submodule)
├── gazebo-classic/                # SITL 仿真引擎 (submodule)
├── ros2/                          # 机器人操作系统 (submodule)
├── PlotJuggler/                   # 数据可视化 (submodule)
├── flight_review/                 # 飞行日志分析 (submodule)
└── bagel/                         # 数据包录制回放 (submodule)
```

---

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/<your-org>/px4agent.git
cd px4agent

# 按需初始化子模块，例如只做 PX4 + Gazebo 开发
git submodule update --init PX4-Autopilot
git submodule update --init gazebo-classic
```

### 2. 安装 Claude Code

```bash
npm install -g @anthropic/claude-code
```

### 3. 启动 AI 开发代理

```bash
cd px4agent
claude
```

---

## 参与贡献

Skill 文件位于 `.claude/skills/<skill-name>/SKILL.md`，使用 Markdown 编写，无需编译。

**贡献新 Skill 的步骤：**

1. 确认目标层级（Layer 1 基础设施 / Layer 2 单组件 / Layer 3 跨组件场景）
2. 在 `.claude/skills/<skill-name>/` 下创建 `SKILL.md`
3. 头部格式：
   ```yaml
   ---
   name: <skill-name>
   version: "1.0.0"
   description: <一句话描述>
   disable-model-invocation: false
   allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
   ---
   ```
4. Layer 2 Skill：开头加"契约检查"步骤（若契约存在则读取参数，跳过重复询问）
5. Layer 3 Skill：每个步骤明确写 `读取 .claude/skills/<layer2>/SKILL.md，按该文件指令执行`，自身不生成任何业务代码
6. 在本 README 的对应 Skill 表格中注册
7. 提交 PR，附上使用示例

---

## License

本仓库代码（Skills 定义）采用 MIT License。各子模块遵循其各自的开源许可证。
