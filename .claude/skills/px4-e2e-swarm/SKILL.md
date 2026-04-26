---
name: px4-e2e-swarm
version: "1.0.0"
description: 多机协同全链路场景编排（多实例 + 协同任务 + 通信 + 仿真）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
执行多机协同全链路开发：$ARGUMENTS

**本 skill 是编排层，自身不生成任何任务规划或通信代码。每个步骤通过读取对应 Layer 2 skill 文件来获取具体执行指令。**

---

## Layer 3 约束

- 本 skill 只做：生成/检查接口契约、按序调用 Layer 2 skill、校验完成标记
- 禁止在本 skill 内直接生成飞行任务、通信逻辑代码

---

## Step 0：契约检查与生成

### 0.1 检查旧契约

读取 `.claude/contracts/` 目录：
- 发现旧契约 → 询问继续或清除
- 多个契约 → 停止，提示运行 `/clean-contract`

### 0.2 收集接口参数

询问：
1. 机型和机体数量（N 架）
2. 任务类型（编队飞行 / 区域巡检 / 协同避障 / 分布式搜索）
3. 通信方式（uXRCE-DDS / MAVLink offboard / 两者结合）
4. 仿真器（单选）：Gazebo（多实例）/ AirSim / 无
5. 协同算法位置（PX4 内部模块 / ROS2 外部节点）

### 0.3 生成接口契约

创建 `.claude/contracts/<task_type>_swarm.contract.md`，包含：
- 机体数量、任务类型
- 通信方式（锁定）
- 仿真器（锁定）
- 话题命名空间规则（`/px4_N/fmu/in|out/<topic>`）
- 完成标记

---

## Step 1：多机仿真环境

根据契约 `sim` 字段：
- `gazebo` → **读取 `.claude/skills/px4-sim-start/SKILL.md`，按该文件指令启动多机 Gazebo SITL（`-i N` 参数）**
- `airsim` → **读取 `.claude/skills/px4-sim-start/SKILL.md`，按该文件指令配置多机 AirSim 连接（端口 4560+N）**
- `无` → 跳过

完成后标记 `- [x] 仿真环境`，等待确认。

---

## Step 2：协同任务规划

**读取 `.claude/skills/px4-swarm-mission/SKILL.md`，按该文件指令执行。使用契约中的机体数量和任务类型参数。**

完成后标记 `- [x] 协同任务规划`，等待确认。

---

## Step 3：通信桥接

根据契约 `comms` 字段：

若包含 `ros2`：**读取 `.claude/skills/px4-ros2-bridge/SKILL.md`，按该文件指令为每架飞机配置独立命名空间（`/px4_N`）。**

若包含 `offboard`：**读取 `.claude/skills/px4-offboard/SKILL.md`，按该文件指令配置多机 MAVSDK 接口。**

完成后标记 `- [x] 通信桥接`，等待确认。

---

## Step 4：安全配置

**读取 `.claude/skills/px4-failsafe-config/SKILL.md`，按该文件指令配置多机场景下的故障保护。**

重点：通信中断 → 单机悬停，不影响编队其他飞机。

完成后标记 `- [x] 安全配置`，等待确认。

---

## Step 5：验证与日志分析

**读取 `.claude/skills/px4-log-analyze/SKILL.md`，按该文件指令分析每架飞机的飞行日志。**

验证标准：
- 所有飞机保持预设队形误差 < 0.5m
- 通信延迟 < 100ms
- 无飞机触发故障保护

完成后标记 `- [x] 验证`。

---

## 完成校验

所有标记 ✓ → 提示运行 `/review` → `/commit` → 删除契约。
