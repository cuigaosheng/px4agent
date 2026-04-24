在 PX4 中配置故障保护（Failsafe）逻辑：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 源码：`C:/Users/cuiga/droneyee_px4v1.15.0`（WSL 内：`~/droneyee_px4v1.15.0`）
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
    5. 继续任务（Loiter/Mission）
    ↓
Navigator 执行具体动作
```

---

## 第一步：确认需求

询问用户：
1. **应用场景**：SITL 开发验证 / 室内飞行 / 室外 GPS 飞行 / 超视距（FPV/自动）
2. **需要配置的 Failsafe 类型**（可多选）：
   - RC 信号丢失（遥控器断连）
   - 数据链丢失（地面站断连）
   - 低电量告警与保护
   - 地理围栏越界
   - 传感器故障（GPS 精度差 / EKF 失效）
   - 解锁条件检查
3. **RTL 配置**：返航高度、降落半径、悬停时间
4. **特殊需求**：Offboard 模式丢失处理 / 任务完成自动降落

---

## 第二步：RC 丢失故障保护

### 触发条件
- RC 信号中断时间 > `COM_RC_LOSS_T`（默认 0.5s）

### 配置参数

```bash
# RC 丢失触发时间（秒）
param set COM_RC_LOSS_T 0.5    # 0.5s 无信号触发

# RC 丢失动作
# 0=禁用  1=警告  2=Hold  3=RTL  4=Land（推荐室外）
param set NAV_RCL_ACT 3        # RTL（室外默认）
# param set NAV_RCL_ACT 4      # 就地降落（室内）
# param set NAV_RCL_ACT 0      # 禁用（SITL 调试时）

# Offboard 模式下 RC 丢失不触发（Offboard 任务用）
# COM_RCL_EXCEPT 位掩码：bit0=Mission, bit1=Hold, bit2=Offboard
param set COM_RCL_EXCEPT 4     # bit2=1：Offboard 模式豁免
```

### SITL 验证

```bash
# 在 SITL 控制台模拟 RC 丢失
commander mode manual      # 切到手动模式
# 断开 RC 输入（等待 0.5s）
param set SIM_RC_LOSS 1    # 模拟 RC 丢失（SITL 专用）

# 观察飞控响应
listener vehicle_status    # 检查 rc_signal_lost 标志
listener commander_state   # 检查 failsafe 触发
```

---

## 第三步：数据链丢失故障保护

### 触发条件
- GCS（QGC）心跳包中断时间 > `COM_DL_LOSS_T`

### 配置参数

```bash
# 数据链丢失触发时间（秒）
param set COM_DL_LOSS_T 10     # 10s 无心跳触发

# 数据链丢失动作
# 0=禁用  1=警告  2=Hold  3=RTL  4=Land  5=终止（解除锁定）
param set NAV_DLL_ACT 0        # 禁用（Offboard/自主飞行常用）
# param set NAV_DLL_ACT 3      # RTL（地面站监控飞行）
```

---

## 第四步：低电量故障保护

### 三级保护机制

```bash
# ── 第一级：电量警告（15%）──
# 触发警告提示，飞手决定是否返航
param set BAT_LOW_THR 0.15     # 15% 触发警告

# ── 第二级：电量严重不足（7%）──
# 自动执行 COM_LOW_BAT_ACT 动作
param set BAT_CRIT_THR 0.07    # 7% 触发严重告警

# 严重低电量动作
# 0=警告  1=RTL  2=Land（就地降落）  3=Return if >5min else Land
param set COM_LOW_BAT_ACT 3    # 智能选择

# ── 第三级：电量紧急（2%）──
# 立即就地降落，不可配置为其他动作
param set BAT_EMERGEN_THR 0.02 # 2% 立即降落
```

### 电压阈值（备用，无电量估算时）

```bash
# 单体电压低压保护（锂电 3.5V/格 为临界）
# 4S 电池：3.5 * 4 = 14.0V
param set BAT_V_EMPTY 3.5      # 单体空电压（V）
param set BAT_V_CHARGED 4.2    # 单体满电压（V）
param set BAT_N_CELLS 4        # 电芯数量
```

### 验证

```bash
# 查看当前电量状态
listener battery_status        # 检查 remaining（剩余量）和 warning

# SITL 模拟低电量
# 在 Gazebo 中电池会根据飞行时间消耗，或手动注入
param set SIM_BAT_DRAIN 1      # SITL 加速电量消耗（如支持）
```

---

## 第五步：地理围栏（Geofence）

### 5a 圆形围栏（简单水平距离限制）

```bash
# 最大水平距离（m，相对起飞点）
param set GF_MAX_HOR_DIST 500  # 500m 半径围栏（0=禁用）

# 最大垂直高度（m，相对起飞点）
param set GF_MAX_VER_DIST 120  # 120m 高度限制（0=禁用）

# 围栏越界动作
# 0=无  1=警告  2=Hold（悬停）  3=RTL  4=终止  5=Land
param set GF_ACTION 3          # RTL
```

### 5b 多边形围栏（通过 QGC 绘制）

1. QGC → **Plan** → **GeoFence** → 绘制多边形围栏
2. 上传到飞控
3. 参数设置：

```bash
param set GF_ACTION 3          # 触发 RTL
param set GF_SOURCE 0          # 0=全局位置（GPS）1=本地位置
```

### 5c 验证

```bash
# 查看围栏状态
listener geofence_result
# geofence_violated = true 时触发
```

---

## 第六步：Return-to-Launch（RTL）配置

```bash
# 返航前上升到的最低高度（m，相对起飞点）
param set RTL_RETURN_ALT 30    # 30m（障碍物较少环境）
# param set RTL_RETURN_ALT 60  # 高障碍物环境（建筑/树木）

# 到达起飞点上方后的悬停高度（m）
param set RTL_DESCEND_ALT 10   # 到家后先降到 10m 再落地

# 悬停时间（秒，然后执行降落）
param set RTL_LAND_DELAY 0     # 0=立即降落（推荐）
# param set RTL_LAND_DELAY 5   # 悬停 5s 等待手动接管

# RTL 速度（m/s）
param set RTL_RETURN_SPD 12    # 水平返航速度

# Home 点设置模式
# 0=起飞点  1=首次解锁点  2=任务开始点
param set RTL_HOME_MODE 0      # 使用起飞点
```

---

## 第七步：传感器故障保护

### EKF2 故障检测

```bash
# EKF 创新量检查阈值（超出则认为 EKF 不可信）
param set EKF2_BARO_GATE 5.0   # 气压计检测门限（sigma）
param set EKF2_GPS_P_GATE 5.0  # GPS 位置检测门限
param set EKF2_GPS_V_GATE 5.0  # GPS 速度检测门限

# EKF 故障时的动作（在 commander 中判断）
# ekf_error_flags 触发时自动进入 Failsafe
```

### GPS 精度要求

```bash
# 解锁时 GPS 最低要求
param set EKF2_REQ_HDOP 2.5    # 水平精度因子（越小越严格）
param set EKF2_REQ_VDOP 4.0    # 垂直精度因子
param set EKF2_REQ_SACC 0.5    # 速度精度（m/s）
param set EKF2_REQ_HACC 0.7    # 水平位置精度（m）
param set COM_ARM_EKF_HGT 0.25 # EKF 高度一致性检查（m）
```

---

## 第八步：解锁前检查项配置

```bash
# ── 传感器校准检查 ──
param set COM_ARM_MAG_ANG 30   # 磁力计偏差角度限制（度）
param set COM_ARM_MAG_STR 0    # 磁场强度检查（0=禁用）

# ── 遥控器检查 ──
param set COM_RC_IN_MODE 0     # 0=RC 必须连接  1=摇杆可用  2=两者皆可

# ── 飞行前自检 ──
param set COM_PREARM_MODE 0    # 0=禁用  1=解锁时  2=始终

# ── 最大偏航误差（GPS 上锁时）──
param set COM_ARM_YAW_ERR 30   # 30° 内才能解锁

# ── CPU 负载上限 ──
param set COM_CPU_MAX 90.0     # CPU 占用超 90% 拒绝解锁
```

---

## 第九步：完整 Failsafe 优先级验证

```bash
# 在 SITL 控制台验证各 Failsafe 触发顺序
commander status        # 查看当前状态
listener vehicle_status # 监控所有 failsafe 标志

# 关键标志字段：
# rc_signal_lost        → RC 丢失
# data_link_lost        → 数据链丢失
# gps_failure           → GPS 故障
# battery_warning       → 电量警告
# geofence_violated     → 围栏越界
# offboard_control_lost → Offboard 丢失
```

### Failsafe 优先级（由高到低）

| 优先级 | 触发条件 | 默认动作 |
|--------|---------|---------|
| 1 | 电量紧急（< BAT_EMERGEN_THR） | 立即降落 |
| 2 | EKF 完全失效 | 就地降落 |
| 3 | 地理围栏越界 | 由 GF_ACTION 决定 |
| 4 | 电量严重不足（< BAT_CRIT_THR） | 由 COM_LOW_BAT_ACT 决定 |
| 5 | RC 丢失（飞行中） | 由 NAV_RCL_ACT 决定 |
| 6 | 数据链丢失 | 由 NAV_DLL_ACT 决定 |
| 7 | 电量低（< BAT_LOW_THR） | 警告 |

---

## 常见配置场景模板

### 室外 GPS 飞行（推荐配置）
```bash
param set NAV_RCL_ACT 3        # RC 丢失→RTL
param set NAV_DLL_ACT 1        # 数据链丢失→警告
param set BAT_CRIT_THR 0.10    # 10% 触发 RTL
param set COM_LOW_BAT_ACT 1    # 严重低电→RTL
param set GF_MAX_HOR_DIST 500  # 500m 围栏
param set GF_ACTION 3          # 围栏越界→RTL
param set RTL_RETURN_ALT 40    # RTL 高度 40m
```

### SITL 开发调试（宽松配置）
```bash
param set NAV_RCL_ACT 0        # 禁用 RC 丢失 Failsafe
param set NAV_DLL_ACT 0        # 禁用数据链 Failsafe
param set BAT_CRIT_THR 0.02    # 仅紧急情况触发
param set GF_MAX_HOR_DIST 0    # 禁用围栏
param set COM_RCL_EXCEPT 7     # 所有模式豁免 RC 丢失
```

### Offboard 自主飞行
```bash
param set NAV_RCL_ACT 3        # RC 丢失→RTL
param set COM_RCL_EXCEPT 4     # Offboard 模式豁免 RC 丢失
param set NAV_DLL_ACT 0        # 数据链丢失→禁用（地面站可断开）
param set BAT_CRIT_THR 0.10    # 10% 触发保护
param set GF_MAX_HOR_DIST 1000 # 1km 围栏
```

---

## 常见问题排查

| 现象 | 原因 | 解决 |
|------|------|------|
| SITL 中 RC 丢失立即触发 | SITL 无 RC 输入 | `COM_RCL_EXCEPT 7` 或 `NAV_RCL_ACT 0` |
| 低电量但飞机不 RTL | `BAT_CRIT_THR` 偏低 | 提高阈值到 0.10 |
| 围栏越界但飞机继续飞 | `GF_ACTION 0`（禁用）| 改为 3（RTL） |
| RTL 后悬停不降落 | `RTL_LAND_DELAY` 设置过长 | 设为 0 |
| 解锁失败 | EKF 或 GPS 检查不通过 | `commander check` 查看具体原因 |

---

## 编码规范（Failsafe 相关开发）
- 新增 Failsafe 触发条件必须在 `Commander` 状态机中添加，不得绕过
- Failsafe 动作执行前必须记录 `PX4_WARN` 日志，方便飞行日志回溯
- 自定义 Failsafe 参数命名格式：`COM_<NAME>_ACT` 或 `NAV_<NAME>_ACT`
- 禁止在 Failsafe 处理路径中有阻塞调用
- Failsafe 状态变化必须发布到 `vehicle_status` topic，供外部节点（ROS2/MAVSDK）监听
