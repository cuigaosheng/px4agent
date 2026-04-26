---
name: px4-e2e-avoidance
version: "1.0.0"
description: 避障全链路场景编排（传感器 + 仿真 + 算法 + 安全 + 验证）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
执行避障全链路开发：$ARGUMENTS

**本 skill 是编排层，自身不生成任何驱动或算法代码。每个步骤通过读取对应 Layer 2 skill 文件来获取具体执行指令。**

---

## Layer 3 约束（执行前确认）

- 本 skill 只做三件事：生成/检查接口契约、按序调用 Layer 2 skill、校验完成标记
- 禁止在本 skill 内直接生成驱动、算法、插件代码
- 判断标准：若某段逻辑"去掉 Layer 2 也能独立运行"，立即停止，告知用户应使用对应 Layer 2 skill

---

## Step 0：契约检查与生成

### 0.1 检查旧契约

读取 `.claude/contracts/` 目录下所有 `*.contract.md` 文件：

- **发现旧契约** → 展示内容，询问：**继续上次任务** 或 **清除重来**
- **发现多个契约** → 停止，提示：`检测到多个契约文件，请先运行 /clean-contract 清空后再继续。`
- **无契约** → 继续

### 0.2 收集接口参数

询问（契约已有则跳过）：

1. 传感器型号和总线类型（**DroneCAN 优先**）
2. 最大探测距离（m）、采样率（Hz）
3. 仿真器（**单选，选后锁定**）：
   - AirSim → 契约写入 `sim=airsim`
   - Gazebo → 契约写入 `sim=gazebo`
   - 无 → 契约写入 `sim=无`
   - ⚠️ 同时选两个仿真器：拒绝继续，要求重新选择
4. 算法方案（**单选，选后锁定**）：
   - 方案 A（internal）：PX4 内置 CP 模块
   - 方案 B（ros2）：ROS2 外部节点 + uXRCE-DDS
   - 方案 C（mavsdk）：MAVSDK 伴飞计算机
   - ⚠️ 三者互斥：选定后写入契约 `algorithm_type=<选择>`

### 0.3 生成接口契约

创建 `.claude/contracts/<sensor>_avoidance.contract.md`，内容包含：

- 技能版本快照（含所有参与 skill 的当前版本）
- 跨组件接口参数（uORB topic、MAVLink 消息 ID、数据单位、采样率）
- 仿真器字段（已锁定，Step 2 互斥校验依据）
- algorithm_type 字段（已锁定，Step 3 接口模板选择依据）
- 按 algorithm_type 展开的算法接口参数
- 完成标记（全部初始为 `[ ]`）

展示契约给用户确认后写入文件。

---

## Step 1：感知层 — PX4 驱动

**读取 `.claude/skills/px4-sensor-driver/SKILL.md`（DroneCAN 时读 `.claude/skills/px4-uavcan-custom/SKILL.md`），按该文件指令执行。**

- 若 algorithm_type=internal：目标 uORB topic 必须为 `obstacle_distance`（CP 模块专用）
- 其他方案：目标 uORB topic 为 `distance_sensor`

完成后在契约中标记 `- [x] PX4 驱动`，等待确认。

---

## Step 2：仿真层（强制单选，已在契约中锁定）

根据契约 `sim` 字段：

- `airsim` → **读取 `.claude/skills/airsim-sensor/SKILL.md`，按该文件指令执行**
- `gazebo` → **读取 `.claude/skills/gazebo-sensor/SKILL.md`，按该文件指令执行**
- `无` → **跳过**，标记为 `跳过`

完成后在契约中标记 `- [x] 仿真层`，等待确认。

---

## Step 3：算法层（根据 algorithm_type 选择执行路径）

根据契约 `algorithm_type` 字段：

**algorithm_type = internal**
**读取 `.claude/skills/px4-module/SKILL.md`，按该文件指令执行。**
- 订阅 `obstacle_distance`，CP 参数确认：CP_DIST / CP_DELAY / CP_GO_NO_DATA
- 实际由 `.claude/skills/px4-param-tune/SKILL.md` 指令完成参数配置

**algorithm_type = ros2**
**读取 `.claude/skills/px4-ros2-bridge/SKILL.md`，再读取 `.claude/skills/px4-offboard/SKILL.md`，按两个文件的指令执行。**
- 接口模板：ROS2 订阅 `distance_sensor`，发布 `trajectory_setpoint`
- 需开启 uXRCE-DDS，OFFBOARD 模式

**algorithm_type = mavsdk**
**读取 `.claude/skills/px4-offboard/SKILL.md`，按该文件指令执行。**
- 接口模板：订阅 MAVLink `DISTANCE_SENSOR`，发送 `SET_POSITION_TARGET_LOCAL_NED`
- 需 OFFBOARD 模式 + 心跳保活（1 Hz）

完成后在契约中标记 `- [x] 算法层`，等待确认。

---

## Step 4：可视化层

**读取 `.claude/skills/qgc-display/SKILL.md`，按该文件指令执行。优先使用契约参数。**

展示 obstacle_distance 或 distance_sensor 数据曲线 + 算法状态。

完成后标记 `- [x] QGC 显示`，等待确认。

---

## Step 5：安全层

**读取 `.claude/skills/px4-failsafe-config/SKILL.md`，按该文件指令执行。**

- 传感器超时 → 悬停
- CP 持续触发 3 秒 → RTL

完成后标记 `- [x] 安全配置`，等待确认。

---

## Step 6：验证层

**先读取 `.claude/skills/px4-hil-setup/SKILL.md` 执行 HIL 配置，再读取 `.claude/skills/px4-log-analyze/SKILL.md` 执行飞行日志复盘。**

验证标准：
- 数据频率 ≥ 采样率的 90%
- 靠近障碍物后飞机减速至 0（internal / ros2 / mavsdk 均适用）
- 移开障碍物后飞机恢复正常飞行

完成后标记 `- [x] HIL 验证`。

---

## 完成校验

检查契约所有标记全部 ✓：

- 全部完成 → 提示：`运行 /review → /commit，完成后契约文件将自动删除。`
- `/commit` 完成后删除契约文件，输出：`避障全链路开发完成，契约已清除。`

---

## 恢复中断任务

若契约版本快照中某技能 Major 版本升级，提示：
`<skill> 版本已升级（契约: <old> → 当前: <new>），是否用新版重新执行该步骤？`
