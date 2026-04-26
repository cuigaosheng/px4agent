---
name: px4-e2e-sensor
version: "1.0.0"
description: 传感器端到端全链路开发（驱动 + 仿真 + 地面站显示）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
执行传感器端到端全链路开发：$ARGUMENTS

**本 skill 是编排层，自身不生成任何驱动或插件代码。每个步骤通过读取对应 Layer 2 skill 文件来获取具体执行指令。**

---

## Layer 3 约束（执行前确认）

- 本 skill 只做三件事：生成/检查接口契约、按序调用 Layer 2 skill、校验完成标记
- 禁止在本 skill 内直接生成驱动、插件、QML 代码
- 判断标准：若某段逻辑"去掉 Layer 2 也能独立运行"，立即停止，告知用户应使用对应 Layer 2 skill

---

## Step 0：契约检查与生成

### 0.1 检查旧契约

读取 `.claude/contracts/` 目录下所有 `*.contract.md` 文件：

- **发现旧契约** → 展示契约内容（任务名、状态、生成时间），询问：
  - **继续上次任务** → 读取契约参数，跳转到上次未完成的步骤
  - **清除重来** → 删除旧契约，重新开始
- **发现多个契约** → 停止执行，提示：`检测到多个契约文件，请先运行 /clean-contract 清空后再继续。`
- **无契约** → 继续下一步

### 0.2 收集接口参数

询问用户以下参数（若契约已有则跳过）：

1. 传感器名称和型号
2. 总线类型（**DroneCAN 优先**，其次 I2C/SPI/UART）
3. uORB topic 名称（搜索现有 `msg/` 确认是否可复用）
4. MAVLink 消息名称和 ID（搜索 `message_definitions/v1.0/` 确认是否可复用）
5. 数据类型、单位、量程
6. 采样率（Hz）
7. 仿真器选择（**单选**：AirSim / Gazebo / 无仿真，选定后锁定）
8. QGC 显示字段

### 0.3 生成接口契约

创建 `.claude/contracts/<sensor_name>_sensor.contract.md`：

```markdown
# 接口契约：<sensor_name>_sensor
生成时间：<当前时间>
状态：进行中（已完成：无 | 进行中：Step 1 | 待完成：Step 2, Step 3）

## 技能版本快照
| 技能 | 版本 |
|------|------|
| px4-e2e-sensor | 1.0.0 |
| px4-sensor-driver（或 px4-uavcan-custom）| 1.0.0 |
| airsim-sensor / gazebo-sensor / 无 | 1.0.0 |
| qgc-display | 1.0.0 |

## 跨组件接口参数
| 参数名 | 值 | 使用方 |
|-------|-----|-------|
| 传感器名称 | <name> | 全部 |
| 总线类型 | <bus> | PX4 驱动 |
| uORB topic | <topic> | PX4 → QGC |
| MAVLink 消息 | <msg>（ID: <id>）| PX4 → QGC |
| 数据类型 | <type>，单位 <unit>，范围 <range> | PX4 / 仿真器 |
| 采样率 | <rate> Hz | PX4 / 仿真器 |
| 仿真器（单选，已锁定） | <sim> | Step 2 |
| QGC 图表变量 | <field> | QGC |

## 完成标记
- [ ] PX4 驱动
- [ ] 仿真器传感器配置
- [ ] QGC 显示
```

确认参数后写入契约文件，展示给用户确认。

---

## Step 1：PX4 驱动开发

**读取 `.claude/skills/px4-sensor-driver/SKILL.md`（总线为 DroneCAN 时读取 `.claude/skills/px4-uavcan-custom/SKILL.md`），按该文件中的指令执行。优先使用契约中的接口参数，跳过重复询问。**

完成后更新契约状态：`- [x] PX4 驱动`，等待用户确认继续。

---

## Step 2：仿真器传感器配置

根据契约中 `仿真器` 字段：

- `airsim` → **读取 `.claude/skills/airsim-sensor/SKILL.md`，按该文件指令执行**
- `gazebo` → **读取 `.claude/skills/gazebo-sensor/SKILL.md`，按该文件指令执行**
- `无` → **跳过本步骤**，在契约状态中标记为 `跳过`，继续 Step 3

完成后更新契约状态：`- [x] 仿真器传感器配置`，等待用户确认继续。

---

## Step 3：QGC 显示配置

**读取 `.claude/skills/qgc-display/SKILL.md`，按该文件中的指令执行。优先使用契约中的 MAVLink 消息名/ID 和图表变量字段，跳过重复询问。**

完成后更新契约状态：`- [x] QGC 显示`。

---

## 完成校验

检查契约中所有完成标记是否全部 ✓（跳过的步骤标为 `跳过` 也视为完成）：

- 全部完成 → 提示用户运行 `/review` → `/commit`
- 完成后自动删除契约文件，输出：`契约文件已清除，端到端链路开发完成。`

---

## 恢复中断任务

若契约版本快照中某技能的 Major 版本高于当前安装版本，提示：
`<skill-name> 版本已升级（契约: <old> → 当前: <new>），是否用新版重新执行该步骤？`
