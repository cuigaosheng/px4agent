---
name: px4-e2e-control
version: "1.0.0"
description: 控制律全链路场景编排（内环/外环 + 仿真验证 + ROS2 接口）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
执行控制律全链路开发：$ARGUMENTS

**本 skill 是编排层，自身不生成任何控制律代码。每个步骤通过读取对应 Layer 2 skill 文件来获取具体执行指令。**

---

## Layer 3 约束

- 本 skill 只做：生成/检查接口契约、按序调用 Layer 2 skill、校验完成标记
- 禁止在本 skill 内直接生成控制律、模块代码

---

## Step 0：契约检查与生成

### 0.1 检查旧契约

读取 `.claude/contracts/` 目录：
- 发现旧契约 → 询问继续或清除
- 多个契约 → 停止，提示运行 `/clean-contract`

### 0.2 收集接口参数

询问：
1. 控制律类型（自定义 PID / MPC / 自适应 / 云台控制 / 降落控制）
2. 控制层级（内环 rate control / 外环 position control / 全链路）
3. 仿真器（单选）：AirSim / Gazebo / 无
4. 是否需要 ROS2 外部接入（offboard 模式）
5. 目标飞行模式（仿真验证用）

### 0.3 生成接口契约

创建 `.claude/contracts/<control_type>_control.contract.md`，包含：
- 控制律类型、层级、参数名称前缀（如 `MC_ROLL_*`）
- 仿真器（锁定）
- ros2_enabled 字段
- 完成标记

---

## Step 1：控制律实现

**读取 `.claude/skills/px4-control-law/SKILL.md`，按该文件指令执行。使用契约中的控制律类型和参数名称前缀。**

完成后标记 `- [x] 控制律实现`，等待确认。

---

## Step 2：仿真验证环境

根据契约 `sim` 字段：
- `airsim` → **读取 `.claude/skills/airsim-sensor/SKILL.md` 配置仿真传感器**
- `gazebo` → **读取 `.claude/skills/gazebo-sensor/SKILL.md` 配置仿真传感器**
- `无` → 跳过

**读取 `.claude/skills/px4-sim-start/SKILL.md`，按该文件指令启动仿真环境。**

完成后标记 `- [x] 仿真环境`，等待确认。

---

## Step 3：ROS2 接口（可选）

若契约 `ros2_enabled=true`：

**读取 `.claude/skills/px4-ros2-bridge/SKILL.md`，按该文件指令配置 uXRCE-DDS 桥接。**
**读取 `.claude/skills/px4-offboard/SKILL.md`，按该文件指令配置外部控制接口。**

完成后标记 `- [x] ROS2 接口`，等待确认。

---

## Step 4：参数调优

**读取 `.claude/skills/px4-param-tune/SKILL.md`，按该文件指令配置控制律参数。**

完成后标记 `- [x] 参数调优`，等待确认。

---

## Step 5：飞行日志验证

**读取 `.claude/skills/px4-log-analyze/SKILL.md`，按该文件指令分析控制律响应。**

完成后标记 `- [x] 日志验证`。

---

## 完成校验

所有标记 ✓ → 提示运行 `/review` → `/commit` → 删除契约。
