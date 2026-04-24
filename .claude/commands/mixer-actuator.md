在 PX4 中配置执行器与混控（电机映射/ESC校准/PWM输出）：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 源码：`~/px4agent`
- 控制分配模块：`src/modules/control_allocator/`
- 执行器输出驱动：`src/drivers/actuators/`
- 机型配置：`ROMFS/px4fmu_common/init.d/`
- 机架定义：`src/lib/airframes/`

---

## 第一步：确认需求

询问用户：
1. **机型**：多旋翼（几轴）/ 固定翼 / VTOL / 自定义混合
2. **电调协议**：
   - PWM（标准，最通用）
   - DShot150 / DShot300 / DShot600（推荐，数字协议，无需校准）
   - UAVCAN/DroneCAN（总线电调）
3. **连接方式**：主输出（MAIN 口）/ 辅助输出（AUX 口）/ IO 板
4. **问题类型**：
   - 新机型首次配置电机映射
   - 电机方向/顺序错误
   - ESC 无响应或油门曲线异常
   - 自定义混控（特殊机型）
5. **飞控板型号**：Pixhawk 4 / 6C / Cube Orange / 自定义

---

## 第二步：理解 PX4 执行器架构（v1.15）

```
控制律输出（actuator_motors / actuator_servos）
    ↓ control_allocator（控制分配，将力矩转为电机指令）
执行器指令（0.0 ~ 1.0 归一化）
    ↓ 输出驱动（pwm_out / dshot / uavcan）
PWM 信号 / DShot 帧 / CAN 帧 → ESC → 电机
```

### 关键 uORB Topics
| Topic | 含义 |
|-------|------|
| `actuator_motors` | 控制分配器输出的电机指令（归一化 -1~1 或 0~1） |
| `actuator_servos` | 舵机指令 |
| `actuator_outputs` | 最终 PWM 输出值（us）|
| `vehicle_thrust_setpoint` | 期望推力矢量 |
| `vehicle_torque_setpoint` | 期望力矩矢量 |

---

## 第三步：电机映射配置

### 3a 通过 QGroundControl（推荐，图形化）

1. QGC → **Vehicle Setup** → **Actuators**
2. 选择机架类型（Airframe）
3. 在 Actuator Output 面板中：
   - 拖动分配每个电机到对应输出端口
   - 设置电机旋转方向（CW/CCW）
4. 点击 **Apply** 保存

### 3b 通过参数直接设置

```bash
# 多旋翼标准四轴（X 型，电机编号从右前开始顺时针）
# 电机 1（右前，CCW）→ MAIN1
# 电机 2（左后，CCW）→ MAIN2
# 电机 3（左前，CW） → MAIN3
# 电机 4（右后，CW） → MAIN4

# PWM 输出使能
param set PWM_MAIN_FUNC1 101   # 电机 1
param set PWM_MAIN_FUNC2 102   # 电机 2
param set PWM_MAIN_FUNC3 103   # 电机 3
param set PWM_MAIN_FUNC4 104   # 电机 4

# AUX 口分配（如需舵机）
param set PWM_AUX_FUNC1 201    # 舵机 1
param set PWM_AUX_FUNC2 202    # 舵机 2
```

### 3c 功能编号对照表

| 编号范围 | 含义 |
|---------|------|
| 0 | 禁用（输出 disarmed 值） |
| 101~108 | 电机 1~8 |
| 201~208 | 舵机 1~8 |
| 301 | 云台 Roll |
| 302 | 云台 Pitch |
| 400 | 降落伞释放 |

---

## 第四步：PWM 参数配置

### 4a 基本 PWM 参数

```bash
# 最小油门（怠速，ESC 解锁）单位 us
param set PWM_MAIN_MIN 1000    # 通常 900~1100

# 最大油门（全速）单位 us
param set PWM_MAIN_MAX 2000    # 通常 1900~2100

# 解锁但不飞时的输出值（disarmed）
param set PWM_MAIN_DISARM 900  # 低于 ESC 最小油门

# 单独设置某路输出（覆盖全局值）
param set PWM_MAIN_MIN1 1050   # 仅第 1 路
param set PWM_MAIN_MAX1 1950   # 仅第 1 路
```

### 4b DShot 配置（推荐数字协议，无需校准）

```bash
# 启用 DShot（设置后需重启）
# 0=PWM  1=DShot150  2=DShot300  3=DShot600
param set DSHOT_CONFIG 2       # DShot300（推荐，速度与可靠性平衡）

# DShot 遥测（需要电调支持）
param set DSHOT_TEL_CFG 101    # 从 UART1 接收电调遥测
```

### 4c 油门曲线（非线性校正）

```bash
# 电机推力曲线系数（0=线性，正值=上凸，负值=下凸）
# 解决：小油门响应不灵敏或大油门饱和
param set THR_MDL_FAC 0.3     # 轻型机建议 0.3，重型机 0.5
```

---

## 第五步：ESC 校准（PWM 协议必须执行）

**注意：校准前必须拆除螺旋桨！**

### 方法 A：通过 QGroundControl

1. QGC → **Vehicle Setup** → **Power** → **Calibrate ESCs**
2. 按提示将油门推到最高 → 等待 ESC 提示音
3. 油门推到最低 → 等待 ESC 提示音
4. 完成校准

### 方法 B：通过 PX4 控制台

```bash
# PX4 控制台（SITL 或真机串口）
# 步骤 1：输出最大 PWM
pwm max -c 1234 -p 2000

# 步骤 2：等待 ESC 提示音后输出最小 PWM
pwm min -c 1234 -p 1000

# 步骤 3：恢复正常控制
pwm disarmed -c 1234 -p 900
```

### DShot 协议无需 ESC 校准

DShot 使用数字指令，不依赖 PWM 宽度，跳过此步骤。

---

## 第六步：电机方向验证与修改

### 检查电机旋转方向

```bash
# 测试单个电机（拆除螺旋桨）
# 在 PX4 控制台：
actuator_test set -m 1 -v 0.2 -t 2  # 电机 1，20% 油门，持续 2 秒
actuator_test set -m 2 -v 0.2 -t 2  # 电机 2
actuator_test set -m 3 -v 0.2 -t 2  # 电机 3
actuator_test set -m 4 -v 0.2 -t 2  # 电机 4
```

### 修改电机方向

**DShot 方式（无需调换电线）**：
```bash
# 反转电机方向（DShot 指令，需电调支持 ESC 3D 模式）
dshot reverse -m 1   # 反转电机 1 方向
dshot save -m 1      # 保存到电调 EEPROM
```

**PWM 方式**：物理调换电机两根相线（任意两根对调）。

---

## 第七步：控制分配配置（自定义机型）

针对非标准机型（异形多旋翼、共轴双桨、VTOL 等）：

### 7a 机架参数

```bash
# 选择机架（重启生效）
# 查看所有机架
param show SYS_AUTOSTART

# 常用机架编号
# 4001：四旋翼 X 型
# 4501：六旋翼 X 型
# 13000：自定义（完全手动配置）
param set SYS_AUTOSTART 4001
```

### 7b 自定义控制分配矩阵

```bash
# 启用自定义控制分配
param set CA_AIRFRAME 0    # 0=多旋翼，1=固定翼，2=VTOL

# 配置旋翼数量和位置（以四旋翼 X 型为例）
param set CA_ROTOR_COUNT 4

# 旋翼 0（右前，-45°，CW）
param set CA_ROTOR0_PX  0.707   # X 位置（归一化）
param set CA_ROTOR0_PY -0.707   # Y 位置（归一化）
param set CA_ROTOR0_KM -0.05    # 负值=CW

# 旋翼 1（左后，135°，CW）
param set CA_ROTOR1_PX -0.707
param set CA_ROTOR1_PY  0.707
param set CA_ROTOR1_KM -0.05

# 旋翼 2（左前，225°，CCW）
param set CA_ROTOR2_PX  0.707
param set CA_ROTOR2_PY  0.707
param set CA_ROTOR2_KM  0.05    # 正值=CCW

# 旋翼 3（右后，315°，CCW）
param set CA_ROTOR3_PX -0.707
param set CA_ROTOR3_PY -0.707
param set CA_ROTOR3_KM  0.05
```

---

## 第八步：验证执行器输出

```bash
# 1. 确认控制分配模块运行
control_allocator status

# 2. 查看归一化电机指令
listener actuator_motors

# 3. 查看最终 PWM 输出值（us）
listener actuator_outputs

# 4. 解锁后观察怠速输出
commander arm
listener actuator_outputs   # 应接近 PWM_MAIN_MIN

# 5. 测试各电机（拆除螺旋桨）
actuator_test set -m 1 -v 0.3 -t 1
actuator_test set -m 2 -v 0.3 -t 1
actuator_test set -m 3 -v 0.3 -t 1
actuator_test set -m 4 -v 0.3 -t 1
```

---

## 常见问题排查

| 现象 | 原因 | 解决 |
|------|------|------|
| 解锁后某路无输出 | PWM_MAIN_FUNCx 未设置 | 检查功能编号是否正确 |
| 电机全速运转无法停止 | PWM_MAIN_DISARM 值过高 | 降低至 900 us |
| 起飞时机体侧翻 | 电机顺序/方向错误 | actuator_test 逐一验证 |
| DShot 无响应 | 电调不支持 DShot | 改用 PWM 或更换电调 |
| PWM 最大油门达不到 | PWM_MAIN_MAX 设置偏低 | 用示波器测量电调实际响应范围 |
| ESC 校准后油门不线性 | THR_MDL_FAC 不匹配 | 参考推力测试数据调整 |

---

## 编码规范（执行器相关代码）
- 执行器输出值必须通过 `math::constrain()` 限幅在 [0, 1] 或 [-1, 1]
- 禁止直接操作 PWM 寄存器，统一通过 `actuator_motors` / `actuator_servos` uORB 发布
- DShot 指令通过 `dshot` 驱动接口发送，禁止裸写 DShot 帧
- 电机测试完毕必须调用 `actuator_test stop`，防止电机持续运转
