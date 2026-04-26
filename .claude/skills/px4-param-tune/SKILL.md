---
name: px4-param-tune
version: "1.0.0"
description: 调整 PX4 飞控参数（PID/EKF2/传感器/振动滤波）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
调整 PX4 飞控参数（PID/EKF2/传感器）：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 项目：`~/px4agent`
- 参数定义：`src/modules/*/module.yaml` 和 `src/modules/*/params.c`
- 多旋翼姿态控制：`src/modules/mc_att_control/`
- 多旋翼位置控制：`src/modules/mc_pos_control/`
- EKF2：`src/modules/ekf2/`

---

## 第一步：确认调参需求

询问用户：
1. **机型**：多旋翼 / 固定翼 / 垂起
2. **调参目标**：姿态 PID / 位置控制 / EKF2 / 振动滤波 / 电机/执行器
3. **当前问题描述**（如：起飞振荡、位置漂移、响应迟钝）
4. **是否有飞行日志**（`.ulg` 文件，用于数据支撑）

---

## 第二步：读取当前参数

```bash
param show MC_ROLL_P
param show MC_*
param show EKF2_*
param save /fs/microsd/params_backup.txt
```

---

## 第三步：多旋翼姿态 PID 调参

### 角速度环（Rate Loop）— 内环，先调
| 参数 | 含义 | 默认值 | 调整方向 |
|------|------|--------|---------|
| `MC_ROLLRATE_P` | Roll 速率 P | 0.15 | 振荡→减小，响应慢→增大 |
| `MC_ROLLRATE_I` | Roll 速率 I | 0.2 | 稳态误差→增大 |
| `MC_ROLLRATE_D` | Roll 速率 D | 0.003 | 高频振动→减小 |
| `MC_PITCHRATE_P` | Pitch 速率 P | 0.15 | 同 Roll |
| `MC_YAWRATE_P` | Yaw 速率 P | 0.2 | Yaw 响应 |

### 姿态环（Attitude Loop）— 外环，后调
| 参数 | 含义 | 默认值 | 调整方向 |
|------|------|--------|---------|
| `MC_ROLL_P` | Roll 姿态 P | 6.5 | 超调→减小，响应慢→增大 |
| `MC_PITCH_P` | Pitch 姿态 P | 6.5 | 同 Roll |
| `MC_YAW_P` | Yaw 姿态 P | 2.8 | Yaw 跟踪 |

---

## 第四步：位置控制调参

| 参数 | 含义 | 默认值 |
|------|------|--------|
| `MPC_XY_P` | 水平位置 P | 0.95 |
| `MPC_Z_P` | 垂直位置 P | 1.0 |
| `MPC_XY_VEL_P_ACC` | 水平速度 P | 1.8 |
| `MPC_Z_VEL_P_ACC` | 垂直速度 P | 4.0 |

---

## 第五步：EKF2 调参

### GPS 定位场景
| 参数 | 含义 | 默认值 |
|------|------|--------|
| `EKF2_GPS_DELAY` | GPS 延迟 ms | 110 |
| `EKF2_REQ_HDOP` | 最低 HDOP 要求 | 2.5 |

### 视觉定位场景（无 GPS）
| 参数 | 含义 | 默认值 |
|------|------|--------|
| `EKF2_AID_MASK` | 融合源选择 | 1 (GPS) |
| `EKF2_EV_DELAY` | 视觉延迟 ms | 175 |

---

## 第六步：振动滤波调参

| 参数 | 含义 | 默认值 |
|------|------|--------|
| `IMU_GYRO_CUTOFF` | 陀螺仪低通截止频率 Hz | 30 |
| `IMU_ACCEL_CUTOFF` | 加速度计低通截止频率 Hz | 30 |
| `MC_DTERM_CUTOFF` | D 项低通截止频率 Hz | 30 |

---

## 第七步：应用参数并验证

```bash
param set MC_ROLL_P 7.0
param save
reboot
listener vehicle_attitude
listener rate_ctrl_status
```

---

## 参数备份与恢复

```bash
param save /fs/microsd/params_$(date +%Y%m%d).txt
param load /fs/microsd/params_backup.txt
param save
param reset_all
```

---

## 编码规范（修改参数相关代码时）
- 新增参数用 `DEFINE_PARAMETERS` + `ModuleParams`，禁止裸调 `param_get()`
- 参数命名格式：`<MODULE>_<NAME>`，全大写，下划线分隔
- 参数范围约束必须在 `module.yaml` 中定义 `min`/`max`
- 禁止硬编码参数默认值，统一在 `module.yaml` 的 `default` 字段定义
