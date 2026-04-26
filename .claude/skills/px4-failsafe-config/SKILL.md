---
name: px4-failsafe-config
version: "1.0.0"
description: 在 PX4 中配置故障保护逻辑（RC丢失/低电量/围栏/RTL）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
在 PX4 中配置故障保护（Failsafe）逻辑：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 源码：`~/px4agent`
- Commander 模块：`src/modules/commander/`
- Failsafe 状态机：`src/modules/commander/Failsafe/`
- Navigator 模块：`src/modules/navigator/`（RTL/降落逻辑）

---

## Failsafe 架构概览

```
触发源（RC丢失/低电量/地理围栏/数据链断/传感器故障）
    ↓ Commander 检测
Failsafe 状态机评估（优先级：高→低）
    1. 紧急降落（最高优先级）
    2. Return-to-Launch（RTL）
    3. Hold（悬停）
    4. Land（就地降落）
    5. 继续任务
    ↓
Navigator 执行具体动作
```

---

## 第一步：确认需求

询问用户：
1. **应用场景**：SITL 开发验证 / 室内飞行 / 室外 GPS 飞行 / 超视距
2. **需要配置的 Failsafe 类型**（可多选）
3. **RTL 配置**：返航高度、降落半径、悬停时间
4. **特殊需求**：Offboard 模式丢失处理 / 任务完成自动降落

---

## 第二步：RC 丢失故障保护

```bash
param set COM_RC_LOSS_T 0.5    # RC 丢失触发时间（秒）
param set NAV_RCL_ACT 3        # RTL（室外默认）
# param set NAV_RCL_ACT 4      # 就地降落（室内）
# param set NAV_RCL_ACT 0      # 禁用（SITL 调试时）
param set COM_RCL_EXCEPT 4     # Offboard 模式豁免
```

---

## 第三步：数据链丢失故障保护

```bash
param set COM_DL_LOSS_T 10     # 10s 无心跳触发
param set NAV_DLL_ACT 0        # 禁用（Offboard/自主飞行常用）
```

---

## 第四步：低电量故障保护

```bash
param set BAT_LOW_THR 0.15     # 15% 触发警告
param set BAT_CRIT_THR 0.07    # 7% 触发严重告警
param set COM_LOW_BAT_ACT 3    # 智能选择
param set BAT_EMERGEN_THR 0.02 # 2% 立即降落
```

---

## 第五步：地理围栏（Geofence）

```bash
param set GF_MAX_HOR_DIST 500  # 500m 半径围栏（0=禁用）
param set GF_MAX_VER_DIST 120  # 120m 高度限制（0=禁用）
param set GF_ACTION 3          # RTL
```

---

## 第六步：Return-to-Launch（RTL）配置

```bash
param set RTL_RETURN_ALT 30    # 返航前上升到的最低高度（m）
param set RTL_DESCEND_ALT 10   # 到达起飞点上方后的悬停高度（m）
param set RTL_LAND_DELAY 0     # 0=立即降落（推荐）
param set RTL_RETURN_SPD 12    # 水平返航速度
```

---

## 第七步：传感器故障保护

```bash
param set EKF2_GPS_P_GATE 5.0  # GPS 位置检测门限
param set EKF2_REQ_HDOP 2.5    # 水平精度因子
param set EKF2_REQ_SACC 0.5    # 速度精度（m/s）
```

---

## 常见配置场景模板

### 室外 GPS 飞行
```bash
param set NAV_RCL_ACT 3
param set BAT_CRIT_THR 0.10
param set GF_MAX_HOR_DIST 500
param set GF_ACTION 3
param set RTL_RETURN_ALT 40
```

### SITL 开发调试（宽松配置）
```bash
param set NAV_RCL_ACT 0
param set NAV_DLL_ACT 0
param set GF_MAX_HOR_DIST 0
param set COM_RCL_EXCEPT 7
```

---

## 编码规范（Failsafe 相关开发）
- 新增 Failsafe 触发条件必须在 `Commander` 状态机中添加，不得绕过
- Failsafe 动作执行前必须记录 `PX4_WARN` 日志，方便飞行日志回溯
- 禁止在 Failsafe 处理路径中有阻塞调用
- Failsafe 状态变化必须发布到 `vehicle_status` topic
