# PX4Agent AI 核心行为准则 (最高优先级)

1. **先思后行 (Think Before Coding)**:
   - 在规划任何代码修改前，**必须**先列出你的核心假设（如：修改的模块、影响的接口）。
   - 如果用户需求存在歧义或信息不足，**必须**提出 1-2 个澄清性问题，**禁止**自行猜测关键参数。

2. **手术式改动 (Surgical Changes)**:
   - 修改现有代码时，**只改动**与任务直接相关的行。
   - **绝对禁止**进行任何"顺便"的重构、格式化或注释修改。

3. **目标驱动 (Goal-Driven Execution)**:
   - 复杂任务（如调参、添加新模块）必须被分解为"目标 + 验证标准"的子任务。
   - 尽可能先提供验证方案（如仿真测试用例），再生成代码。

4. **简洁至上 (Simplicity First)**:
   - 只实现当前需求明确要求的功能。
   - 禁止添加任何"未来可能有用"的抽象、参数或代码结构。

5. **新会话启动（Session Start）**:
   - 每次新会话开始，**必须**先检查根目录是否存在 `PROJECT_STATUS.md`。
   - 若存在，**主动询问用户**：
     > 检测到 `PROJECT_STATUS.md`，是否读取以了解项目当前状态和待办事项？（推荐）
   - 用户确认后读取并简要汇报：当前 skill 版本、四个已验证需求、待处理项。
   - 用户拒绝则直接进入工作。

6. **PROJECT_STATUS.md 维护（持续追加）**:
   - 以下事件发生后，**必须**更新 `PROJECT_STATUS.md`：
     - 新建或修改了任何 Skill 文件
     - 做出架构决策（新增 skill、修改层间关系、废弃某路径）
     - 完成一个具体需求的端到端开发
     - 触发 `/handoff`
   - 更新格式：修改"最后更新"时间戳 + 在第二节追加 skill 版本变更 + 在第三节追加本次工作摘要。
   - **禁止覆盖历史记录**，只追加。

---

# px4agent — Claude Code 项目上下文

## 项目定位

本项目是 **PX4 无人系统 AI 开发平台**，通过 Claude Code Skills 让工程师用自然语言驱动 PX4 全链路开发。

核心工作流：`自然语言需求 → Skill 调度 → 代码生成 → 仿真验证`

---

## 子模块路径与默认版本

开发者未指定版本时自动采用下表默认版本：

| 子模块 | 路径 | 默认版本 |
|--------|------|---------|
| PX4-Autopilot | `PX4-Autopilot/` | v1.15.0 |
| QGroundControl | `qgroundcontrol/` | v4.4 |
| Gazebo Classic | `gazebo-classic/` | 11 |
| ROS2 | `ros2/` | Humble |
| AirSim | `AirSim/` | — |
| PlotJuggler | `PlotJuggler/` | — |
| flight_review | `flight_review/` | — |
| bagel | `bagel/` | — |

| 资源 | 路径 |
|------|------|
| Skills 目录 | `.claude/skills/` |
| 飞行日志目录（SITL） | `PX4-Autopilot/build/px4_sitl_default/rootfs/log/` |
| 飞行日志目录（真机） | `/fs/microsd/log/` |
| AirSim 配置 | `~/Documents/AirSim/settings.json` |

子模块仅作参考文档，不在本项目内编译，代码改动输出到开发者自己的工作目录。

---

## 领域知识（全量加载）

@.claude/context/px4.md
@.claude/context/qgc.md
@.claude/context/gazebo.md
@.claude/context/ros2.md
@.claude/context/airsim.md
@.claude/context/plotjuggler.md
@.claude/context/flight-review.md
@.claude/context/bagel.md

---

## 运行环境

- **平台**：Linux（Ubuntu 22.04）
- **ROS2 版本**：Humble（LTS）
- **仿真引擎**：Gazebo Classic（主力）、AirSim（高保真视觉）

每个 Skill 启动时必须按以下顺序执行：

1. **需求确认**：询问开发者要实现的具体功能，明确输入/输出/行为
2. **影响分析**：判断需要修改哪些子模块（PX4 / QGC / ROS2 / 其他）
3. **版本确认**：询问各子模块是否有版本要求；无要求则采用上表默认版本，并告知开发者
4. **代码生成**：按确认的版本生成代码，标注每段代码的目标文件路径和插入位置
5. **集成说明**：列出完整改动清单（文件列表 + 构建系统变更）→ 等待确认
6. **验证命令**：给出端到端验证步骤

**AI 不得在步骤 5 用户确认前修改任何源码。**

---

## 路线图（待实现）

- [ ] `ci-test` — 自动化测试与 CI 配置（GitHub Actions + PX4 单元测试）

---

## 错误处理与复盘

1. **编译/测试失败**：
   - 首先，**独立分析**错误日志，定位到具体文件和行号。
   - 其次，提出**至少一个**可能的修复方案，并解释原因。
   - **禁止**在没有分析的情况下，盲目重试或请求用户提供更多信息。

2. **规范违反**：
   - 如果生成的代码被 `review` Skill 指出违反了"内嵌编码规范"，必须：
     a. 承认具体违反了哪一条。
     b. 解释为什么会产生这个错误。
     c. 提供修正后的代码片段。

---

## CLAUDE.md 维护指南

- 本文件描述项目的**静态事实**（目录、组件、规范）和 AI 的**通用行为准则**。
- 具体的**操作流程**（如如何写一个驱动）请参考 `.claude/skills/` 下对应的 Skill 文件。
- 修改本文件时，请注意保持与 README.md 和 Skill 文件的描述一致。
