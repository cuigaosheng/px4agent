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
2. **调参目标**：
   - 姿态 PID（Roll/Pitch/Yaw 响应）
   - 位置控制（悬停精度、速度响应）
   - EKF2（传感器融合、GPS/视觉定位）
   - 振动滤波（陀螺仪/加速度计低通滤波）
   - 电机/执行器（怠速、最大油门）
3. **当前问题描述**（如：起飞振荡、位置漂移、响应迟钝）
4. **是否有飞行日志**（`.ulg` 文件，用于数据支撑）

---

## 第二步：读取当前参数

### 在 PX4 控制台（SITL 或真机）
```bash
# 查看单个参数
param show MC_ROLL_P

# 查看一组参数
param show MC_*
param show EKF2_*
param show IMU_*

# 导出所有参数到文件
param save /fs/microsd/params_backup.txt
```

### 通过 QGroundControl
- Vehicle Setup → Parameters → 搜索参数名

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

### 调参步骤（Ziegler-Nichols 简化法）
1. 将 I、D 设为 0，逐步增大 P 直到出现持续振荡，记录临界 P 值 `Ku`
2. 设 `P = 0.6 * Ku`，`I = 1.2 * Ku / Tu`，`D = 0.075 * Ku * Tu`（Tu 为振荡周期）
3. 在 SITL 中验证阶跃响应，再上真机

---

## 第四步：位置控制调参

| 参数 | 含义 | 默认值 | 说明 |
|------|------|--------|------|
| `MPC_XY_P` | 水平位置 P | 0.95 | 悬停漂移→增大 |
| `MPC_Z_P` | 垂直位置 P | 1.0 | 高度响应 |
| `MPC_XY_VEL_P_ACC` | 水平速度 P | 1.8 | 速度跟踪 |
| `MPC_Z_VEL_P_ACC` | 垂直速度 P | 4.0 | 爬升/下降响应 |
| `MPC_LAND_SPEED` | 降落速度 m/s | 0.7 | 降落平稳性 |
| `MPC_TKO_SPEED` | 起飞速度 m/s | 1.5 | 起飞平稳性 |

---

## 第五步：EKF2 调参

### GPS 定位场景
| 参数 | 含义 | 默认值 | 说明 |
|------|------|--------|------|
| `EKF2_GPS_DELAY` | GPS 延迟 ms | 110 | 根据实际 GPS 模块调整 |
| `EKF2_GPS_POS_X/Y/Z` | GPS 天线偏移 m | 0 | 精确测量后填入 |
| `EKF2_REQ_HDOP` | 最低 HDOP 要求 | 2.5 | 降低→更严格 |

### 视觉定位场景（无 GPS）
| 参数 | 含义 | 默认值 | 说明 |
|------|------|--------|------|
| `EKF2_AID_MASK` | 融合源选择 | 1 (GPS) | 24=视觉位置+偏航 |
| `EKF2_EV_DELAY` | 视觉延迟 ms | 175 | 根据视觉系统延迟调整 |
| `EKF2_EV_POS_X/Y/Z` | 视觉传感器偏移 | 0 | 精确测量后填入 |

### 气压计
| 参数 | 含义 | 默认值 | 说明 |
|------|------|--------|------|
| `EKF2_BARO_DELAY` | 气压计延迟 ms | 0 | 一般无需修改 |
| `EKF2_BARO_NOISE` | 气压计噪声 m | 3.5 | 室内气流干扰→增大 |

---

## 第六步：振动滤波调参

```bash
# 查看当前滤波参数
param show IMU_GYRO_CUTOFF
param show IMU_ACCEL_CUTOFF
param show IMU_DGYRO_CUTOFF
```

| 参数 | 含义 | 默认值 | 说明 |
|------|------|--------|------|
| `IMU_GYRO_CUTOFF` | 陀螺仪低通截止频率 Hz | 30 | 振动严重→降低（最低 10） |
| `IMU_ACCEL_CUTOFF` | 加速度计低通截止频率 Hz | 30 | 同上 |
| `MC_DTERM_CUTOFF` | D 项低通截止频率 Hz | 30 | D 项噪声→降低 |

---

## 第七步：应用参数并验证

### SITL 验证
```bash
# 在 PX4 控制台设置参数
param set MC_ROLL_P 7.0
param save

# 重启使部分参数生效
reboot

# 观察姿态响应
listener vehicle_attitude
listener rate_ctrl_status
```

### 真机验证流程
1. 先在 SITL 中验证参数无明显振荡
2. 真机首飞在低高度（1~2m）悬停，观察稳定性
3. 用 QGC 实时查看姿态曲线
4. 飞行后下载日志，用 `/log-analyze` 分析

---

## 参数备份与恢复

```bash
# 备份当前参数
param save /fs/microsd/params_$(date +%Y%m%d).txt

# 恢复参数
param load /fs/microsd/params_backup.txt
param save  # 写入 EEPROM

# 恢复出厂默认
param reset_all
```

---

## 编码规范（修改参数相关代码时）
- 新增参数用 `DEFINE_PARAMETERS` + `ModuleParams`，禁止裸调 `param_get()`
- 参数命名格式：`<MODULE>_<NAME>`，全大写，下划线分隔
- 参数范围约束必须在 `module.yaml` 中定义 `min`/`max`
- 禁止硬编码参数默认值，统一在 `module.yaml` 的 `default` 字段定义
