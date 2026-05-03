<div align="center">

![PX4 Skills](https://img.shields.io/badge/PX4-Skills-blue)
![Platforms](https://img.shields.io/badge/platforms-9-green)
![License](https://img.shields.io/badge/license-MIT-orange)
![Version](https://img.shields.io/badge/version-1.0.0-purple)
![Skills](https://img.shields.io/badge/skills-48-brightgreen)

**PX4 无人系统 AI 开发平台** - 让 AI 编程工具理解并使用 PX4 全链路开发

支持 **9 种主流 AI 工具** 的一键安装

[快速开始](#-快速开始) • [Skill 列表](#-skill-列表) • [平台支持](#-支持的平台) • [安装指南](#-安装指南)

</div>

---

## 📖 项目简介

**PX4Agent** 是一套专为 PX4 无人系统开发的 AI 技能包集合，让主流 AI 编程工具能够**自动理解并使用** PX4 的驱动框架、仿真环境、参数系统和最佳实践。

### ✨ 核心特性

- 🎯 **零学习成本** - AI 自动理解 PX4 架构，无需手动查文档
- 🛠️ **最佳实践内置** - 基于 PX4 官方规范的开发模板和编码规范
- 🔄 **完整工作流** - 从驱动开发到仿真验证的全流程支持
- 📚 **持续更新** - 跟随 PX4 版本更新，保持最新
- 🔌 **9 平台支持** - 支持所有主流 AI 编程工具，一键安装

### 🎯 包含 Skill

本项目包含 **48 个 Skill**，分为 4 层架构，涵盖 PX4 开发的各个场景：

| 层级 | 数量 | 类型 | 示例 |
|------|------|------|------|
| **Layer 3** | 4 个 | 场景技能 | px4-e2e-sensor、px4-e2e-avoidance、px4-e2e-control、px4-e2e-swarm |
| **Layer 2** | 25 个 | 组件技能 | px4-imu-gen、px4-sensor-driver、px4-param-define、px4-uorb-msg 等 |
| **Layer 1** | 5 个 | 基础设施 | commit、review、handoff、simplify、clean-contract |
| **Layer 0.5** | 7 个 | 环境安装 | setup-all、setup-px4、setup-gazebo、setup-ros2 等 |
| **Layer 0** | 2 个 | 核心规范 | CLAUDE.md、context 领域知识 |

---

## 📱 支持的平台

本项目支持 **9 种主流 AI 编程工具**，涵盖所有常用平台：

| 平台 | 兼容性 | 安装方式 | 目录位置 | 推荐度 |
|------|--------|----------|----------|--------|
| **Claude Code** | ✓ 原生 | 脚本/手动 | `~/.claude/skills/` | ⭐⭐⭐⭐⭐ |
| **Cursor** | ✓ 原生兼容 | 脚本/手动 | `~/.cursor/skills/` | ⭐⭐⭐⭐⭐ |
| **TRAE** | ✓ 原生兼容 | 脚本/手动 | `~/.trae/skills/` | ⭐⭐⭐⭐⭐ |
| **GitHub Copilot** | ✓ 原生兼容 | 脚本/手动 | `~/.copilot/skills/` | ⭐⭐⭐⭐ |
| **Google Antigravity** | ✓ 原生兼容 | 脚本/手动 | `~/.gemini/antigravity/skills/` | ⭐⭐⭐⭐ |
| **OpenCode** | ✓ 原生兼容 | 脚本/手动 | `~/.config/opencode/skill/` | ⭐⭐⭐⭐ |
| **Windsurf** | ⚡ 软链接 | 脚本自动 | `~/.codeium/windsurf/skills/` | ⭐⭐⭐⭐ |
| **Gemini CLI** | ⚡ 软链接 | 脚本自动 | `~/.gemini/skills/` | ⭐⭐⭐ |
| **OpenAI Codex** | ⚡ 软链接 | 脚本自动 | `~/.codex/skills/` | ⭐⭐⭐ |

**符号说明:**
- **✓ 原生** - 工具自动扫描或使用相同的目录结构，无需额外配置
- **⚡ 软链接** - 通过链接到 Claude 目录实现自动同步，更新一处全部同步

---

## 🚀 快速开始

### 💡 推荐策略："一次安装，到处运行"

**默认规则：全局安装到 Claude Code**

1. **为什么选择 Claude？**
   - ✅ Anthropic 官方工具，最标准的实现
   - ✅ 原生支持 skills，兼容性最好
   - ✅ 其他平台可以直接兼容或软链接

2. **"一次安装，到处运行"的优势：**
   - 🎯 **一次安装** - 只需在 `~/.claude/skills/` 安装一次
   - 🔄 **自动同步** - 原生兼容平台自动识别，软链接平台自动同步
   - 💾 **节省空间** - 避免多次复制，统一维护
   - ⚡ **更新简单** - 更新 Claude 目录，所有平台立即生效

### 📋 安装指南

#### macOS / Linux

```bash
# 1. 克隆仓库
git clone https://github.com/yourusername/px4agent.git
cd px4agent

# 2. 一键全局安装（推荐）
chmod +x install.sh
./install.sh --all --global

# 或仅安装到指定平台
./install.sh --claude --cursor
./install.sh --project              # 项目级安装
```

#### Windows PowerShell

```powershell
# 1. 克隆仓库
git clone https://github.com/yourusername/px4agent.git
cd px4agent

# 2. 一键全局安装（需要管理员权限）
.\install.ps1 -All -Global

# 或仅安装到指定平台
.\install.ps1 -Claude -Cursor
.\install.ps1 -Project              # 项目级安装
```

### ✅ 验证安装

在任一已安装的平台中测试：

```
你: 帮我启动 PX4 SITL 仿真
AI: [自动使用 px4-sim-start Skill，启动 Gazebo 仿真环境]

你: 帮我生成一个 IMU 驱动
AI: [自动使用 px4-imu-gen Skill，一键生成完整驱动代码]
```

📚 **需要更多帮助？** 查看 [详细安装指南](./docs/INSTALLATION.md) 或 [快速启动指南](./docs/QUICK_START.md)

---

## 典型使用场景

### 场景一：避障全链路开发（毫米波雷达 vs SF45 360° 激光雷达）

**两种传感器共用同一个 `/px4-e2e-avoidance` 场景 Skill，通过参数区分处理路径。**

#### 1a. 毫米波雷达避障（单点测距，ROS2 算法）

```
/px4-e2e-avoidance 毫米波雷达 DroneCAN 单点测距 AirSim ROS2方案
```

| 关键契约参数 | 值 |
|------------|-----|
| sensor_type | 单点测距 |
| uORB topic | `distance_sensor` |
| algorithm_type | ros2 |
| 仿真器 | AirSim |

| 步骤 | 内容 | 涉及 Skill |
|------|------|-----------|
| Step 0 | 生成契约，锁定 sensor_type=单点 / sim=airsim / algorithm=ros2 | — |
| Step 1 | DroneCAN 驱动，发布 `distance_sensor` | `/px4-uavcan-custom` |
| Step 2 | AirSim Distance 传感器仿真（settings.json） | `/airsim-sensor` |
| Step 3 | ROS2 节点订阅 `distance_sensor`，发布 `trajectory_setpoint` | `/px4-ros2-bridge` + `/px4-offboard` |
| Step 4 | QGC 距离曲线显示 | `/qgc-display` |
| Step 5 | 故障保护配置 | `/px4-failsafe-config` |
| Step 6 | HIL 验证 + 日志复盘 | `/px4-hil-setup` + `/px4-log-analyze` |

#### 1b. SF45 360° 激光雷达避障（全向扫描，PX4 内置 CP 模块 + 避障后 Hold）

```
/px4-e2e-avoidance SF45 UART 360°扫描 Gazebo internal
```

| 关键契约参数 | 值 | 说明 |
|------------|-----|------|
| sensor_type | 360° 扫描 | SF45 只发布 `obstacle_distance`，不发布 `distance_sensor` |
| uORB topic | `obstacle_distance` | 72 元素数组，5°/格，覆盖全向 |
| algorithm_type | internal（强制） | 360° 传感器不支持 ros2/mavsdk 路径 |
| 仿真器 | Gazebo |  |

| 步骤 | 内容 | 涉及 Skill |
|------|------|-----------|
| Step 0 | 生成契约，锁定 sensor_type=360° / sim=gazebo / algorithm=internal | — |
| Step 1 | **驱动核实**（SF45 驱动已存在）：规范检查 + 数据格式验证 + 编译确认 | `/px4-sensor-driver`（核实流程） |
| Step 2 | Gazebo gpu_ray 360° 插件配置（72 样本，-180°~+180°，OBSTACLE_DISTANCE 注入） | `/gazebo-sensor` |
| Step 3 | CP 模块参数配置（CP_DIST / CP_DELAY / CP_GO_NO_DATA）+ **避障后 Hold 状态机**开发 | `/px4-module` + `/px4-param-tune` |
| Step 4 | QGC 全向障碍物显示 | `/qgc-display` |
| Step 5 | 故障保护配置 | `/px4-failsafe-config` |
| Step 6 | HIL 验证（靠近障碍物减速→停止→障碍消除后切 HOLD）+ 日志复盘 | `/px4-hil-setup` + `/px4-log-analyze` |

> **两个场景的核心区别**：
> - 毫米波（单点）→ `distance_sensor` → 支持 internal / ros2 / mavsdk 三种算法
> - SF45（360°）→ `obstacle_distance` → **只能用 internal**（CP 模块直接读 72 格数据）
> - SF45 驱动已在项目中存在，Step 1 走"核实"而非"新建"

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

### Layer 0.5：环境安装技能（新手专用）

| Skill | 触发命令 | 功能 |
|-------|---------|------|
| setup-all | `/setup-all` | 一键安装入口，智能检测并按需执行各子 Skill |
| setup-wsl2 | `/setup-wsl2` | WSL2 + Ubuntu 22.04（Windows 11 专用） |
| setup-px4 | `/setup-px4` | PX4 工具链 + SITL 编译（WSL/Linux 通用） |
| setup-gazebo | `/setup-gazebo` | Gazebo Classic 11 + 图形显示验证 |
| setup-qgc | `/setup-qgc` | QGroundControl + MAVLink 网络配置 |
| setup-airsim | `/setup-airsim` | AirSim settings.json + TCP 4560 验证 |
| setup-ros2 | `/setup-ros2` | ROS2 Humble + px4_msgs + uXRCE-DDS Agent |

---

## 接口契约机制

Layer 3 场景 Skill 在 Step 0 自动生成接口契约文件（`.claude/contracts/<task>.contract.md`），锁定所有跨组件接口参数：

```
uORB topic    MAVLink 消息 ID    数据单位    采样率    仿真器    算法方案
```

后续各组件 Skill 读取契约参数，跳过重复询问，保证链路参数全程一致。

契约文件生命周期：任务启动时创建 → 全部步骤完成后自动删除。会话中断可恢复，手动清理用 `/clean-contract`。

---

## 会话状态持久化机制

### PROJECT_STATUS.md —— 跨会话状态文档

根目录的 `PROJECT_STATUS.md` 是项目级持久化状态文件，随代码一起提交到 git，记录：

- 完整 Skill 清单和版本号
- 已验证的需求触发命令
- 架构设计决策记录
- 待处理事项
- 源码关键路径

### 新会话自动询问

Claude 在 px4agent 项目中启动新会话时，会**主动询问**是否读取 `PROJECT_STATUS.md`：

```
检测到 PROJECT_STATUS.md，是否读取以了解项目当前状态和待办事项？（推荐）
```

确认后 Claude 自动汇报当前 Skill 版本、已验证需求和待处理项，**无需重复交代上下文，直接开始工作**。

### 定时追加更新

以下事件发生后，Claude 自动追加更新 `PROJECT_STATUS.md`（禁止覆盖历史记录）：

| 触发事件 | 更新内容 |
|---------|---------|
| 新建或修改 Skill 文件 | 第二节 Skill 清单版本号 |
| 做出架构决策 | 第五节设计决策记录 |
| 完成具体需求开发 | 第三节工作摘要（按日期追加）|
| 触发 `/handoff` | 全量同步：日期 + Skill版本 + 工作摘要 + 待处理项 + git提交 |

### 使用方式

```
# 新会话开始
Claude 自动询问 → 确认 → 读取 PROJECT_STATUS.md → 汇报状态 → 直接开始工作

# 会话结束前
/handoff   ← 生成 HANDOFF.md（本地临时）+ 同步更新 PROJECT_STATUS.md（持久化）
/commit    ← 提交所有改动，PROJECT_STATUS.md 作为普通文件一并提交
```

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
│       ├── [Layer 0.5] setup-all/ setup-wsl2/ setup-px4/
│       │              setup-gazebo/ setup-qgc/ setup-airsim/ setup-ros2/
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

## 新手安装（全新电脑）

在全新的 Windows 11 或 Ubuntu 22.04 机器上，一条命令完成整套 PX4 开发环境安装：

```
/setup-all
```

AI 自动检测当前环境状态，生成安装计划表，确认后按需安装各组件（跳过已有步骤）。

**覆盖组件**：WSL2 + Ubuntu 22.04 → PX4 工具链 → Gazebo Classic 11 → QGroundControl → AirSim → ROS2 Humble

**安装完成后验证**：

```bash
# SITL + Gazebo
cd ~/PX4-Autopilot && make px4_sitl gazebo

# SITL + QGC：打开 QGroundControl，观察飞机出现在地图上

# ROS2 话题（已安装 ROS2 时）
ros2 topic list   # 出现 /px4_0/fmu/out/ 开头的话题
```

若只需安装某个组件，也可单独触发：

| 命令 | 功能 |
|------|------|
| `/setup-wsl2` | 仅安装 WSL2 + Ubuntu 22.04（Windows 11 专用） |
| `/setup-px4` | 仅安装 PX4 工具链并编译 SITL |
| `/setup-gazebo` | 仅安装 Gazebo Classic 11 |
| `/setup-qgc` | 仅安装 QGroundControl 并配置网络 |
| `/setup-airsim` | 仅配置 AirSim settings.json |
| `/setup-ros2` | 仅安装 ROS2 Humble + uXRCE-DDS |

### 新手安装完整对话示例

以下是一名从未接触过 PX4 的新手，在全新 Windows 11 电脑上从零开始的真实交互过程：

---

**[新手在 PowerShell 里克隆项目并启动]**

```powershell
git clone https://github.com/your-org/px4agent.git
cd px4agent
claude
```

---

**Claude 自动询问**

> 检测到 `PROJECT_STATUS.md`，是否读取以了解项目当前状态和待办事项？（推荐）

**新手**：我是新手，我不知道这是什么项目，我只是想学 PX4 开发

**Claude**：这是一个 PX4 无人机 AI 开发平台，你用自然语言告诉我要做什么，我帮你生成代码和配置环境。在用任何功能之前，需要先把开发环境装好。你电脑上现在有没有安装过 WSL2、PX4、Gazebo、QGroundControl？

**新手**：都没有，这是台新电脑

**Claude**：明白，直接一键安装整套环境，运行：`/setup-all`

---

**新手**：`/setup-all`

---

**Claude 询问平台和已有组件**

> 你的电脑操作系统是 Windows 11 还是 Ubuntu 22.04？

**新手**：Windows 11

> 以下组件你已经安装了哪些？没装过的直接说"都没有"：WSL2、PX4、Gazebo、QGC、AirSim、ROS2

**新手**：都没有，这是台新电脑

**Claude 生成安装计划表**

```
┌──────────────────┬───────────┬──────────────────────────┐
│ 组件             │ 状态      │ 操作                     │
├──────────────────┼───────────┼──────────────────────────┤
│ WSL2 + Ubuntu    │ ❌ 未安装  │ 将执行 /setup-wsl2       │
│ PX4 工具链+编译  │ ❌ 未安装  │ 将执行 /setup-px4        │
│ Gazebo Classic   │ ❌ 未安装  │ 将执行 /setup-gazebo     │
│ QGroundControl   │ ❌ 未安装  │ 将执行 /setup-qgc        │
│ AirSim 配置      │ ❌ 未配置  │ 将执行 /setup-airsim     │
│ ROS2 Humble      │ ❌ 未安装  │ 将执行 /setup-ros2       │
└──────────────────┴───────────┴──────────────────────────┘
预计总耗时 1～2 小时（主要是 PX4 编译和 ROS2 下载）
```

是否继续？

**新手**：继续

---

**Claude 逐步引导，新手只需粘贴命令和回报结果：**

> **WSL2**：给出管理员 PowerShell 命令 → 新手重启电脑 → 创建 Ubuntu 用户 → 配置 `.wslconfig` 内存 → 验证通过 ✅
>
> **PX4**：安装依赖 → 克隆源码（新手嫌慢，Claude 改用 Gitee 镜像）→ 运行 ubuntu.sh → 编译 SITL（约 20 分钟）→ 输出 `[100%] Linking CXX executable px4` → 验证通过 ✅
>
> **Gazebo**：apt 安装 → 配置环境变量 → `gazebo --version` 输出 `11.13.0` → 验证通过 ✅
>
> **QGC**：引导下载 Windows 安装包 → 配置 WSL2 Mirrored 网络模式 → 验证通过 ✅
>
> **AirSim**：询问是否有 Unreal Engine → 新手说没有 → Claude 建议跳过，初学用 Gazebo 足够 ⏭
>
> **ROS2**：添加 apt 源 → 安装 ros-humble-desktop → 编译 px4_msgs → 编译 MicroXRCEAgent → 验证通过 ✅

---

**Claude 运行端到端验证**

```bash
# Ubuntu 终端：启动 SITL + Gazebo
cd ~/PX4-Autopilot && make px4_sitl gazebo
```

**新手**：Gazebo 出来了，有个四旋翼飞机，PX4 显示 Ready for takeoff!

**Claude**：打开 QGroundControl，等几秒，左上角有没有出现飞机图标？

**新手**：有！地图上能看到飞机位置

**Claude**：✅ QGC 连接成功。最后验证 ROS2 话题……`ros2 topic list` 有没有 `/px4_0/fmu/out/` 开头的话题？

**新手**：有，看到很多 /px4_0/fmu/out/vehicle_attitude 之类的

---

**Claude 输出最终状态**

```
✅ WSL2 + Ubuntu 22.04
✅ PX4 v1.15.0 工具链 + SITL 编译
✅ Gazebo Classic 11（SITL 可启动）
✅ QGroundControl（MAVLink 连通）
⏭ AirSim（跳过，未安装 UE）
✅ ROS2 Humble + uXRCE-DDS（话题正常）

下一步可以尝试：
  /px4-sim-start          ← 学习启动各种仿真场景
  /px4-param-tune         ← 调整 PID 参数
  /px4-sensor-driver      ← 添加传感器驱动
  /px4-e2e-avoidance      ← 完整避障开发链路
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
