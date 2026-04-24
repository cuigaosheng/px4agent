# px4agent

> 基于 PX4 的无人系统智能开发平台 —— 以先进 AI 技术加速无人系统进化

---

## 项目定位

无人系统的开发门槛长期偏高：飞控固件、通信协议、仿真环境、地面站、数据分析……每个环节都需要专深的领域知识，团队协作成本极大。

**px4agent** 的目标是打破这一壁垒。

本项目将 PX4 完整生态集成为统一工作空间，并在其上构建一套 **AI 开发代理层**（Claude Code Skills）。开发者只需用自然语言描述需求，AI 即可完成从需求分析、代码生成、规范审查到验证的全链路工作，将无人系统的迭代速度提升一个量级。

---

## 核心理念

```
自然语言需求  ──►  AI 代理理解与规划  ──►  符合 PX4 规范的代码  ──►  仿真验证
```

- **人机协作**：AI 负责重复性的工程实现，工程师专注系统设计与决策
- **规范内嵌**：PX4 编码规范、安全约束、架构模式直接编码进每个 AI Skill，而不是靠人记
- **端到端闭环**：从驱动、通信协议到地面站 UI、数据分析，整条链路在同一平台内完成

---

## 生态组件

本项目通过 Git Submodule 集成了 PX4 完整技术栈：

| 组件 | 仓库 | 职责 |
|------|------|------|
| **PX4-Autopilot** | PX4/PX4-Autopilot | 飞控固件核心，驱动 / 模块 / uORB / MAVLink |
| **QGroundControl** | mavlink/qgroundcontrol | 地面控制站，任务规划、参数调试、实时监控 |
| **AirSim** | microsoft/AirSim | 高保真物理 + 视觉仿真，支持多旋翼 / 固定翼 |
| **Gazebo Classic** | gazebosim/gazebo-classic | PX4 官方 SITL 仿真引擎 |
| **ROS2** | ros2/ros2 | 机器人操作系统，算法研发与系统集成 |
| **PlotJuggler** | facontidavide/PlotJuggler | 高性能时序数据可视化，实时调试利器 |
| **flight_review** | PX4/flight_review | 飞行日志（ULog）在线分析平台 |
| **bagel** | shouhengyi/bagel | 无人系统数据包录制与回放工具 |

---

## AI 开发技能（Skills）

Skills 是本项目的核心能力层。每个 Skill 是一个结构化的 AI 提示程序，内嵌了对应领域的 PX4 规范、文件路径、代码模板和验证流程。

在 Claude Code 中输入 `/<skill-name> <你的需求>` 即可启动对话式开发流程。

### 可用 Skills 一览

#### 仿真环境

- **`/sim-start`** — 启动 PX4 SITL 仿真环境
  编译固件 → 启动 Gazebo 或 AirSim → 连接 QGroundControl → 验证仿真链路，支持多机仿真配置

#### 固件开发

- **`/sensor-driver <传感器名称>`** — 全流程创建 PX4 传感器驱动
  驱动代码 → uORB 消息 → MAVLink 流 → QGC 显示 → SITL 验证

- **`/px4-module <模块名称>`** — 在 PX4 中创建新业务模块
  WorkQueue 框架、参数定义、uORB 订阅/发布，含单元测试

- **`/px4-workqueue <驱动名称>`** — 创建基于 `ScheduledWorkItem` 的高性能驱动
  内置完整的禁止项检查清单（禁阻塞、禁浮点、禁动态内存）

#### 通信协议

- **`/mavlink-custom <消息名称>`** — 定义自定义 MAVLink 消息
  XML 定义 → PX4 流实现 → QGC 解析 → 端到端验证

- **`/uavcan-custom <节点功能>`** — 添加自定义 DroneCAN (UAVCAN v0) 节点
  DSDL 定义 → 适配层（传感器订阅/执行器发布）→ uORB 集成

#### 工程质量

- **`/review`** — 对当前修改进行安全审查
  内存安全、空指针、状态机完整性、通信数据校验、PX4 规范合规性

- **`/commit`** — 生成规范的 git 提交信息
  自动分析改动内容，按约定式提交格式生成描述

- **`/handoff`** — 生成会话交接文档
  记录任务状态、关键决策、待处理问题和下步行动，保存为 `HANDOFF.md`

#### 飞行数据与调参

- **`/log-analyze <日志路径>`** — 分析 PX4 ULog 飞行日志
  提取姿态跟踪误差、振动频谱、EKF 健康、电源状态、故障时间线，生成 HTML 报告

- **`/param-tune <描述>`** — 飞控参数调优
  多旋翼/固定翼/VTOL 的 PID、位置控制、EKF2、振动滤波全套调参流程，含 Ziegler-Nichols 方法

#### 外部控制与系统集成

- **`/offboard <需求描述>`** — 开发 Offboard 外部控制
  MAVSDK/ROS2/MAVLink 接口，支持位置/速度/姿态/角速率控制，含超时保护和安全机制

- **`/ros2-bridge <需求描述>`** — 配置 ROS2 与 PX4 桥接
  uXRCE-DDS（推荐）或 MAVROS 方案，含工作空间配置、话题映射、QoS 设置

#### 控制律设计

- **`/control-law <需求描述>`** — 设计和实现自定义飞行控制律
  支持姿态/位置/自适应/MPC 控制律，提供标准 PID 和 MPC 参考实现，含 SITL 验证指标

### Skill 工作模式

每个 Skill 采用**分步确认**工作模式：

```
Step 1: AI 分析现有代码库，搜索参考实现
   ↓ (汇报结果，等待确认)
Step 2: AI 生成代码框架
   ↓ (展示代码，等待确认)
Step 3: AI 集成进构建系统
   ↓ (展示改动，等待确认)
...
最终: AI 给出验证命令，确认端到端正常
```

这种模式确保 AI 不会越权修改代码，每一步改动都经过工程师审核。

---

## 内嵌编码规范

所有 Skills 共同遵守以下 PX4 硬性约束，AI 会自动检查并拒绝生成违规代码：

- **禁止动态内存分配**（`new` / `delete` / `malloc` / `free`）
- **禁止独立线程**，统一使用 `ScheduledWorkItem` WorkQueue
- **禁止在驱动层使用浮点运算**，用定点数或整型
- **禁止阻塞调用**（`sleep` / `usleep` / mutex lock），用 `ScheduleDelayed()`
- **禁止 `printf`**，用 `PX4_DEBUG` / `PX4_INFO` / `PX4_WARN` / `PX4_ERR`
- **禁止裸调 `param_get()`**，用 `DEFINE_PARAMETERS` + `ModuleParams`
- **时间戳统一用 `hrt_absolute_time()`**，禁止系统时钟
- **只用 UAVCAN v0 (DroneCAN)**，禁止 Cyphal v1
- **通信数据先范围校验再写 uORB**，防止外部非法值注入

---

## 目录结构

```
px4agent/
├── .claude/
│   └── commands/          # AI Skills 定义文件（14 个）
│       ├── sim-start.md        # 仿真环境启动
│       ├── sensor-driver.md    # 传感器驱动开发
│       ├── px4-module.md       # PX4 模块开发
│       ├── px4-workqueue.md    # WorkQueue 驱动
│       ├── mavlink-custom.md   # 自定义 MAVLink 消息
│       ├── uavcan-custom.md    # 自定义 DroneCAN 节点
│       ├── review.md           # 代码安全审查
│       ├── commit.md           # 规范提交
│       ├── handoff.md          # 会话交接文档
│       ├── log-analyze.md      # ULog 飞行日志分析
│       ├── param-tune.md       # 飞控参数调优
│       ├── offboard.md         # Offboard 外部控制
│       ├── ros2-bridge.md      # ROS2 与 PX4 桥接
│       └── control-law.md      # 自定义飞行控制律
├── CLAUDE.md              # 项目级 AI 上下文（Claude Code 配置）
├── PX4-Autopilot/         # 飞控固件 (submodule)
├── qgroundcontrol/        # 地面控制站 (submodule)
├── AirSim/                # 高保真仿真 (submodule)
├── gazebo-classic/        # SITL 仿真引擎 (submodule)
├── ros2/                  # 机器人操作系统 (submodule)
├── PlotJuggler/           # 数据可视化 (submodule)
├── flight_review/         # 飞行日志分析 (submodule)
├── bagel/                 # 数据包录制回放 (submodule)
└── README.md
```

---

## 快速开始

### 1. 克隆仓库

```bash
git clone --recurse-submodules https://github.com/<your-org>/px4agent.git
cd px4agent
```

如果已克隆但未初始化子模块：

```bash
git submodule update --init --recursive
```

### 2. 安装 Claude Code

```bash
npm install -g @anthropic/claude-code
```

### 3. 启动 AI 开发代理

在项目根目录启动 Claude Code：

```bash
claude
```

### 4. 使用 Skill 开始开发

示例：为 I2C 温度传感器添加 PX4 驱动

```
/sensor-driver MY_TEMP，I2C 接口，输出温度（0.01°C 精度），采样率 10 Hz
```

示例：添加自定义 DroneCAN 消息

```
/uavcan-custom 电池扩展信息节点，发布单体电压数组（16节）和温度
```

---

## 开发路线图

- [x] 仿真环境启动 Skill（sim-start）—— Gazebo & AirSim
- [x] 传感器驱动 Skill（sensor-driver）
- [x] 模块开发 Skill（px4-module）
- [x] WorkQueue 驱动 Skill（px4-workqueue）
- [x] 自定义 MAVLink 消息 Skill（mavlink-custom）
- [x] 自定义 UAVCAN 节点 Skill（uavcan-custom）
- [x] 代码安全审查 Skill（review）
- [x] ULog 飞行数据分析 Skill（log-analyze）
- [x] 飞控参数调优 Skill（param-tune）
- [x] Offboard 外部控制 Skill（offboard）
- [x] ROS2 节点与 PX4 桥接 Skill（ros2-bridge）
- [x] 飞行控制律设计 Skill（control-law）
- [ ] 硬件在环（HIL）配置 Skill（hil-setup）
- [ ] 多机协同任务规划 Skill（swarm-mission）

---

## 参与贡献

欢迎提交新的 Skill 或改进现有 Skill。Skill 文件位于 `.claude/commands/`，使用 Markdown 编写，无需编译。

贡献一个新 Skill 的步骤：

1. 在 `.claude/commands/` 下新建 `<skill-name>.md`
2. 第一行格式：`<功能简述>：$ARGUMENTS`
3. 按领域规范编写分步骤执行流程
4. 在本 README 的 Skills 表格中注册
5. 提交 PR，附上使用示例

---

## License

本仓库代码（Skills 定义）采用 MIT License。各子模块遵循其各自的开源许可证。
