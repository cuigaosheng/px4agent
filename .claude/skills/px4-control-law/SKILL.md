---
name: px4-control-law
version: "1.0.0"
description: 在 PX4 中设计和实现自定义飞行控制律（PID/MPC/自适应）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
在 PX4 中设计和实现自定义飞行控制律：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 项目：`~/px4agent`
- 多旋翼姿态控制：`src/modules/mc_att_control/`
- 多旋翼速率控制：`src/modules/mc_rate_control/`
- 多旋翼位置控制：`src/modules/mc_pos_control/`
- 固定翼姿态控制：`src/modules/fw_att_control/`
- 控制分配：`src/modules/control_allocator/`
- uORB 消息：`msg/`

---

## 第一步：确认需求

询问用户：
1. **机型**：多旋翼 / 固定翼 / VTOL
2. **控制目标**：姿态控制律 / 位置控制律 / 自定义飞行模式 / 自适应控制 / MPC
3. **修改范围**：在现有模块内扩展（推荐）/ 新建独立控制模块
4. **验证方式**：SITL 仿真 / HIL / 真机

---

## 第二步：理解现有控制架构

### 多旋翼控制链路
```
位置 setpoint
    ↓ mc_pos_control（位置环 + 速度环）
速度/加速度 setpoint
    ↓ mc_att_control（姿态环）
角速率 setpoint
    ↓ mc_rate_control（速率环 PID）
执行器力矩指令
    ↓ control_allocator（控制分配）
电机 PWM 输出
```

---

## 第三步：在现有模块内扩展控制律

### 3a 扩展速率控制（mc_rate_control）

在 `src/modules/mc_rate_control/RateControl/RateControl.cpp` 中修改速率控制逻辑。

### 3b 新建独立控制模块

继承 `ModuleBase` + `ScheduledWorkItem`：

```cpp
#include <px4_platform_common/module.h>
#include <px4_platform_common/px4_work_queue/ScheduledWorkItem.hpp>
#include <uORB/Subscription.hpp>
#include <uORB/Publication.hpp>
#include <uORB/topics/vehicle_attitude.h>
#include <uORB/topics/vehicle_rates_setpoint.h>

class MyController : public ModuleBase<MyController>,
                     public px4::ScheduledWorkItem {
public:
    MyController();
    ~MyController() override;
    static int task_spawn(int argc, char *argv[]);
    static int custom_command(int argc, char *argv[]);
    static int print_usage(const char *reason = nullptr);
    bool init();
private:
    void Run() override;
    uORB::Subscription _attitude_sub{ORB_ID(vehicle_attitude)};
    uORB::Publication<vehicle_rates_setpoint_s> _rates_sp_pub{ORB_ID(vehicle_rates_setpoint)};
    DEFINE_PARAMETERS(
        (ParamFloat<px4::params::MY_CTRL_ROLL_P>) _param_roll_p,
        (ParamFloat<px4::params::MY_CTRL_PITCH_P>) _param_pitch_p
    )
};
```

---

## 第四步：实现控制算法

### 4a 标准 PID（参考实现）

```cpp
void MyController::Run() {
    if (!_attitude_sub.updated()) return;
    vehicle_attitude_s att{};
    _attitude_sub.copy(&att);
    // 四元数误差 → 姿态误差 → P 控制
    vehicle_rates_setpoint_s rates_sp{};
    rates_sp.timestamp = hrt_absolute_time();
    _rates_sp_pub.publish(rates_sp);
}
```

---

## 第五步：禁用原有控制模块（如需完全替换）

在 `ROMFS/px4fmu_common/init.d-posix/rcS` 中：
```bash
mc_att_control stop
mc_rate_control stop
my_controller start
```

---

## 第六步：添加参数定义（module.yaml）

```yaml
parameters:
  - group: My Controller
    definitions:
      MY_CTRL_ROLL_P:
        description:
          short: Roll proportional gain
        type: float
        min: 0.0
        max: 20.0
        default: 6.5
        unit: "1/s"
```

---

## 第七步：SITL 验证

```bash
cd ~/px4agent && make px4_sitl gazebo
listener vehicle_rates_setpoint
listener actuator_controls
```

验证指标：
- 阶跃响应超调 < 10%
- 调节时间 < 0.5 s
- 稳态误差 < 1°
- 无持续振荡

---

## 编码规范（必须遵守）
- 禁止动态内存分配（`new`/`delete`/`malloc`/`free`）
- 禁止独立线程，使用 `ScheduledWorkItem`
- 禁止在 `Run()` 中阻塞
- 禁止 `printf`，用 `PX4_DEBUG`/`PX4_INFO`/`PX4_WARN`/`PX4_ERR`
- 时间戳用 `hrt_absolute_time()`
- 参数用 `DEFINE_PARAMETERS` + `ModuleParams`
- 控制输出必须限幅（`math::constrain`）
- 积分项必须有抗饱和保护
