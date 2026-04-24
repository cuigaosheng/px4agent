在 PX4 中设计和实现自定义飞行控制律：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 项目：`C:/Users/cuiga/droneyee_px4v1.15.0`
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
2. **控制目标**：
   - 姿态控制律（替换或扩展现有 PID）
   - 位置控制律（轨迹跟踪、悬停精度）
   - 自定义飞行模式（新增状态机分支）
   - 自适应控制（在线参数估计）
   - 模型预测控制（MPC）
3. **修改范围**：
   - 在现有模块内扩展（推荐，改动小）
   - 新建独立控制模块（完全自定义）
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

### 关键 uORB topic
| Topic | 方向 | 含义 |
|-------|------|------|
| `vehicle_attitude` | 输入 | 当前姿态（四元数） |
| `vehicle_attitude_setpoint` | 输入/输出 | 姿态设定值 |
| `vehicle_rates_setpoint` | 输入/输出 | 角速率设定值 |
| `vehicle_local_position` | 输入 | 当前位置/速度 |
| `trajectory_setpoint` | 输入 | 轨迹设定值 |
| `actuator_controls` | 输出 | 执行器控制量 |

---

## 第三步：在现有模块内扩展控制律

### 3a 扩展速率控制（mc_rate_control）

在 `src/modules/mc_rate_control/RateControl/RateControl.cpp` 中修改：

```cpp
// 现有 PID 控制器
Vector3f RateControl::update(const Vector3f &rate, const Vector3f &rate_sp,
                              const Vector3f &angular_accel, const float dt,
                              const bool landed) {
    // 计算误差
    Vector3f rate_error = rate_sp - rate;

    // === 在此处添加自定义控制律 ===
    // 示例：带前馈的 PID
    Vector3f torque = _gain_p.emult(rate_error)
                    + _gain_i.emult(_rate_int)
                    - _gain_d.emult(angular_accel)
                    + _gain_ff.emult(rate_sp);  // 前馈项

    // 积分限幅（防止积分饱和）
    for (int i = 0; i < 3; i++) {
        if (fabsf(_rate_int(i)) > _lim_int(i)) {
            _rate_int(i) = math::constrain(_rate_int(i), -_lim_int(i), _lim_int(i));
        } else {
            _rate_int(i) += rate_error(i) * dt;
        }
    }

    return torque;
}
```

### 3b 新建独立控制模块

```bash
# 在 src/modules/ 下创建新模块
mkdir -p src/modules/my_controller
```

模块结构：
```
src/modules/my_controller/
├── MyController.hpp
├── MyController.cpp
├── CMakeLists.txt
├── Kconfig
└── module.yaml
```

继承 `ModuleBase` + `ScheduledWorkItem`：
```cpp
#include <px4_platform_common/module.h>
#include <px4_platform_common/px4_work_queue/ScheduledWorkItem.hpp>
#include <uORB/Subscription.hpp>
#include <uORB/Publication.hpp>
#include <uORB/topics/vehicle_attitude.h>
#include <uORB/topics/vehicle_attitude_setpoint.h>
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
    uORB::Subscription _attitude_sp_sub{ORB_ID(vehicle_attitude_setpoint)};
    uORB::Publication<vehicle_rates_setpoint_s> _rates_sp_pub{ORB_ID(vehicle_rates_setpoint)};

    // 控制律参数
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

    vehicle_attitude_setpoint_s att_sp{};
    _attitude_sp_sub.copy(&att_sp);

    // 四元数误差 → 姿态误差
    matrix::Quatf q_att(att.q);
    matrix::Quatf q_sp(att_sp.q_d);
    matrix::Quatf q_err = q_att.inversed() * q_sp;

    // 转换为轴角误差
    matrix::Vector3f angle_err = matrix::AxisAnglef(q_err).axis()
                                 * matrix::AxisAnglef(q_err).angle();

    // P 控制
    vehicle_rates_setpoint_s rates_sp{};
    rates_sp.roll  = _param_roll_p.get()  * angle_err(0);
    rates_sp.pitch = _param_pitch_p.get() * angle_err(1);
    rates_sp.yaw   = _param_roll_p.get()  * angle_err(2);
    rates_sp.timestamp = hrt_absolute_time();

    _rates_sp_pub.publish(rates_sp);
}
```

### 4b 模型预测控制（MPC 框架）
```cpp
// MPC 预测步骤（简化版，实际需要求解器）
void MyController::run_mpc(const matrix::Vector3f &state,
                            const matrix::Vector3f &state_sp) {
    // 预测时域 N 步
    const int N = 10;
    const float dt = 0.01f;  // 预测步长 10ms

    matrix::Vector3f x = state;
    matrix::Vector3f u_opt{0.0f, 0.0f, 0.0f};

    // 简化：梯度下降求解
    for (int i = 0; i < N; i++) {
        matrix::Vector3f error = state_sp - x;
        // 状态方程：x_{k+1} = A*x_k + B*u_k
        // 此处填入实际系统模型
        u_opt += error * 0.1f;  // 简化梯度步
    }

    // 限幅
    u_opt = matrix::Vector3f(
        math::constrain(u_opt(0), -1.0f, 1.0f),
        math::constrain(u_opt(1), -1.0f, 1.0f),
        math::constrain(u_opt(2), -1.0f, 1.0f)
    );
}
```

---

## 第五步：禁用原有控制模块（如需完全替换）

在 `ROMFS/px4fmu_common/init.d-posix/rcS` 或对应机型配置中：
```bash
# 停止原有控制模块
mc_att_control stop
mc_rate_control stop

# 启动自定义控制模块
my_controller start
```

或在 Kconfig 中互斥配置：
```kconfig
config MODULES_MY_CONTROLLER
    bool "My custom controller"
    default n
    select MODULES_CONTROL_ALLOCATOR
    ---help---
        Custom flight controller replacing mc_att_control
```

---

## 第六步：添加参数定义

在 `module.yaml` 中定义控制律参数：
```yaml
parameters:
  - group: My Controller
    definitions:
      MY_CTRL_ROLL_P:
        description:
          short: Roll proportional gain
          long: Roll axis proportional gain for attitude control
        type: float
        decimal: 2
        min: 0.0
        max: 20.0
        default: 6.5
        unit: "1/s"

      MY_CTRL_PITCH_P:
        description:
          short: Pitch proportional gain
        type: float
        decimal: 2
        min: 0.0
        max: 20.0
        default: 6.5
        unit: "1/s"
```

---

## 第七步：SITL 验证

```bash
# 编译
cd ~/droneyee_px4v1.15.0
make px4_sitl gazebo

# 启动仿真后验证
listener vehicle_rates_setpoint   # 确认控制输出
listener actuator_controls        # 确认执行器指令

# 阶跃响应测试
# 在 QGC 中施加 Roll/Pitch 指令，观察响应曲线
# 用 /log-analyze 分析飞行日志
```

验证指标：
- 阶跃响应超调 < 10%
- 调节时间 < 0.5 s
- 稳态误差 < 1°
- 无持续振荡

---

## 单元测试

```cpp
// src/modules/my_controller/test/test_my_controller.cpp
#include <gtest/gtest.h>
#include "../MyController.hpp"

TEST(MyControllerTest, ZeroError) {
    // 误差为零时，输出应为零
    matrix::Vector3f zero_error{0.0f, 0.0f, 0.0f};
    // ... 测试逻辑
}

TEST(MyControllerTest, StepResponse) {
    // 阶跃输入响应测试
    // ... 测试逻辑
}
```

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
- 状态机 enum 必须有 `default` 分支
