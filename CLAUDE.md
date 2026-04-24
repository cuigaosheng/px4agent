# px4agent — Claude Code 项目上下文

## 项目定位

本项目是 **PX4 无人系统 AI 开发平台**，通过 Claude Code Skills 让工程师用自然语言驱动 PX4 全链路开发。

核心工作流：`自然语言需求 → Skill 调度 → 代码生成 → 仿真验证`

---

## 关键路径

| 资源 | 路径 |
|------|------|
| PX4 固件源码 | `~/px4agent` |
| QGroundControl 源码 | `~/qgroundcontrol` |
| Gazebo Classic 源码 | `~/gazebo-classic` |
| AirSim 源码 | `~/AirSim` |
| ROS2 工作空间 | `~/ros2_ws/` |
| PlotJuggler 源码 | `~/PlotJuggler` |
| flight_review 源码 | `~/flight_review` |
| bagel 源码 | `~/bagel` |
| Skills 目录 | `.claude/commands/` |
| 飞行日志目录（SITL） | `~/px4agent/build/px4_sitl_default/rootfs/log/` |
| 飞行日志目录（真机） | `/fs/microsd/log/` |
| AirSim 配置 | `~/Documents/AirSim/settings.json` |

---

## 运行环境

- **平台**：Linux（Ubuntu 22.04）
- **PX4 版本**：v1.15.0
- **ROS2 版本**：Humble（LTS）
- **仿真引擎**：Gazebo Classic（主力）、AirSim（高保真视觉）

---

## 角色配置

根据本次任务涉及的子模块，取消注释对应行（可多选）：

@.claude/px4/CLAUDE.md
# @.claude/qgc/CLAUDE.md
# @.claude/gazebo/CLAUDE.md
# @.claude/ros2/CLAUDE.md
# @.claude/airsim/CLAUDE.md
# @.claude/plotjuggler/CLAUDE.md
# @.claude/flight-review/CLAUDE.md
# @.claude/bagel/CLAUDE.md

---

## 子模块默认版本

所有 Skill 生成的代码以下列版本为基准，开发者未指定时自动采用：

| 子模块 | 默认版本 |
|--------|---------|
| PX4-Autopilot | v1.15.0 |
| QGroundControl | v4.4 |
| ROS2 | Humble |
| Gazebo Classic | 11 |

子模块仅作参考文档，不在本项目内编译，代码改动输出到开发者自己的工作目录。

---

## AI 工作流（所有 Skill 强制执行）

每个 Skill 启动时必须按以下顺序执行：

1. **需求确认**：询问开发者要实现的具体功能，明确输入/输出/行为
2. **影响分析**：判断需要修改哪些子模块（PX4 / QGC / ROS2 / 其他）
3. **版本确认**：询问各子模块是否有版本要求；无要求则采用上表默认版本，并告知开发者
4. **代码生成**：按确认的版本生成代码，标注每段代码的目标文件路径和插入位置
5. **集成说明**：列出完整改动清单（文件列表 + 构建系统变更）→ 等待确认
6. **验证命令**：给出端到端验证步骤

**AI 不得在步骤 5 用户确认前修改任何源码。**

---

## AI 编码规范

> AI 行为模式参考 [andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)，结合 PX4 领域特性适配。

### 编码前先思考
- 明确列出所有假设，不确定时提出多种解读，询问开发者确认后再动手
- 识别需求中的隐含约束（实时性、内存限制、硬件接口等）

### 保持简单
- 生成代码前必须搜索现有实现，优先复用，禁止重复造轮子
- 只实现当前需求，不添加"将来可能用到"的功能或抽象
- 三行能解决的问题不写辅助函数

### 精准修改
- 各子模块的编码规范以其自身 CLAUDE.md 为准（如有）；无 CLAUDE.md 则遵守该子模块官方贡献指南
- 只改动与需求直接相关的代码，不顺手重构周边代码
- 生成的代码片段必须标注目标文件路径和插入位置
- 涉及多文件改动时，必须列出完整改动清单再执行

### 目标驱动
- 每次生成前明确验证标准（能跑通哪条命令、输出什么结果）
- 验证命令必须在代码生成后给出，不得省略
- 验证失败时分析根因，不重复尝试同一方案

---

## 子模块说明

以下目录为 Git Submodule，仅作为参考文档使用，不在本项目内编译：

- `PX4-Autopilot/` — 上游参考，实际固件在 `~/px4agent`
- `qgroundcontrol/` — 地面站参考
- `AirSim/`, `gazebo-classic/` — 仿真引擎参考
- `ros2/`, `PlotJuggler/`, `flight_review/`, `bagel/` — 工具参考

---

## 路线图（待实现）

- [ ] `ci-test` — 自动化测试与 CI 配置（GitHub Actions + PX4 单元测试）
