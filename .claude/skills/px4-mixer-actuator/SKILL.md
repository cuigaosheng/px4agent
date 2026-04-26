---
name: px4-mixer-actuator
version: "1.0.0"
description: 在 PX4 中配置执行器与混控（电机映射/ESC/PWM/DShot）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
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
2. **电调协议**：PWM（标准）/ DShot150/300/600（推荐）/ UAVCAN/DroneCAN
3. **连接方式**：主输出（MAIN 口）/ 辅助输出（AUX 口）
4. **问题类型**：新机型配置 / 电机方向/顺序错误 / ESC 无响应 / 自定义混控

---

## 第二步：理解 PX4 执行器架构（v1.15）

```
控制律输出（actuator_motors / actuator_servos）
    ↓ control_allocator（控制分配）
执行器指令（0.0 ~ 1.0 归一化）
    ↓ 输出驱动（pwm_out / dshot / uavcan）
PWM 信号 / DShot 帧 / CAN 帧 → ESC → 电机
```

---

## 第三步：电机映射配置

### 3a 通过 QGroundControl（推荐，图形化）
QGC → Vehicle Setup → Actuators → 拖动分配电机到对应输出端口

### 3b 通过参数直接设置
```bash
param set PWM_MAIN_FUNC1 101   # 电机 1
param set PWM_MAIN_FUNC2 102   # 电机 2
param set PWM_MAIN_FUNC3 103   # 电机 3
param set PWM_MAIN_FUNC4 104   # 电机 4
param set PWM_AUX_FUNC1 201    # 舵机 1
```

---

## 第四步：PWM 参数配置

```bash
param set PWM_MAIN_MIN 1000    # 最小油门（怠速）us
param set PWM_MAIN_MAX 2000    # 最大油门 us
param set PWM_MAIN_DISARM 900  # 解锁但不飞时的输出值

# DShot 配置（推荐数字协议，无需校准）
# 0=PWM  1=DShot150  2=DShot300  3=DShot600
param set DSHOT_CONFIG 2       # DShot300
```

---

## 第五步：ESC 校准（PWM 协议必须执行）

**注意：校准前必须拆除螺旋桨！**

```bash
pwm max -c 1234 -p 2000   # 输出最大 PWM
pwm min -c 1234 -p 1000   # 等待 ESC 提示音后输出最小 PWM
pwm disarmed -c 1234 -p 900
```

**DShot 协议无需 ESC 校准。**

---

## 第六步：电机方向验证与修改

```bash
actuator_test set -m 1 -v 0.2 -t 2  # 测试电机 1（拆除螺旋桨）

# DShot 反转电机方向（无需调换电线）
dshot reverse -m 1
dshot save -m 1
```

---

## 第七步：自定义控制分配配置

```bash
param set CA_AIRFRAME 0    # 0=多旋翼，1=固定翼，2=VTOL
param set CA_ROTOR_COUNT 4

# 旋翼 0（右前，CW）
param set CA_ROTOR0_PX  0.707
param set CA_ROTOR0_PY -0.707
param set CA_ROTOR0_KM -0.05    # 负值=CW
```

---

## 第八步：验证执行器输出

```bash
control_allocator status
listener actuator_motors
listener actuator_outputs
actuator_test set -m 1 -v 0.3 -t 1
actuator_test set -m 2 -v 0.3 -t 1
```

---

## 编码规范（执行器相关代码）
- 执行器输出值必须通过 `math::constrain()` 限幅在 [0, 1] 或 [-1, 1]
- 禁止直接操作 PWM 寄存器，统一通过 `actuator_motors` / `actuator_servos` uORB 发布
- DShot 指令通过 `dshot` 驱动接口发送，禁止裸写 DShot 帧
- 电机测试完毕必须调用 `actuator_test stop`
