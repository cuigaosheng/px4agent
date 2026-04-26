---
name: px4-workqueue
version: "1.0.0"
description: 在 PX4 中创建一个基于 WorkQueue 的驱动或周期任务。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
在 PX4 中创建一个基于 WorkQueue 的驱动或任务：$ARGUMENTS

## 项目路径
- PX4 项目：`~/px4agent`
- 驱动目录：`src/drivers/`
- 模块目录：`src/modules/`

---

## 第一步：确认需求
询问用户：
- 驱动/模块名称
- 调度方式：固定周期（`ScheduleOnInterval`）还是事件触发（`ScheduleNow` / `ScheduleDelayed`）
- 工作队列选择：`wq:I2C0`/`wq:SPI0`（总线驱动）或 `wq:hp_default`（高优先级）或 `wq:lp_default`（低优先级）
- 需要订阅/发布的 uORB topics

---

## 第二步：搜索参考驱动
在 `src/drivers/` 或 `src/modules/` 下查找继承 `ScheduledWorkItem` 的类似实现作参考。

---

## 第三步：创建文件结构

```
src/drivers/<name>/
├── <Name>.hpp
├── <Name>.cpp
├── CMakeLists.txt
└── Kconfig
```

---

## 第四步：实现驱动框架

### 头文件模板要点
```cpp
#include <px4_platform_common/px4_work_queue/ScheduledWorkItem.hpp>
#include <px4_platform_common/module.h>
#include <px4_platform_common/module_params.h>
#include <uORB/Subscription.hpp>
#include <uORB/Publication.hpp>
#include <lib/perf/perf_counter.h>

class <Name> : public ModuleBase<<Name>>, public ModuleParams,
               public px4::ScheduledWorkItem {
public:
    <Name>();
    ~<Name>() override;

    static int task_spawn(int argc, char *argv[]);
    static int custom_command(int argc, char *argv[]);
    static int print_usage(const char *reason = nullptr);

    bool init();
    int print_status() override;

private:
    void RunImpl() override;

    // perf counters
    perf_counter_t _loop_perf;
    perf_counter_t _loop_interval_perf;

    // uORB
    uORB::Subscription _<topic>_sub{ORB_ID(<topic>)};
    uORB::Publication<<topic>_s> _<topic>_pub{ORB_ID(<topic>)};
};
```

### 实现要点
- 构造函数中指定工作队列：`px4::ScheduledWorkItem(MODULE_NAME, px4::wq_configurations::<queue>)`
- `init()` 中调用 `ScheduleOnInterval(<interval_us>)` 启动调度
- `RunImpl()` 中：
  - `perf_begin(_loop_perf)`
  - 执行采样/处理逻辑
  - publish uORB
  - `perf_end(_loop_perf)`
- 析构中：`ScheduleClear()`、`perf_free(_loop_perf)`、`perf_free(_loop_interval_perf)`

### 禁止事项（必须检查）
- [ ] 禁止在 `RunImpl()` 中使用任何阻塞调用（`sleep`、`usleep`、`pthread_mutex_lock` 等）
- [ ] 禁止在驱动层使用浮点运算，用定点数或整型
- [ ] 禁止动态内存分配（`new`/`delete`/`malloc`/`free`）
- [ ] 禁止独立线程（`px4_task_spawn_cmd`）
- [ ] 禁止 `printf`/`fprintf`，用 `PX4_DEBUG`/`PX4_INFO`/`PX4_WARN`/`PX4_ERR`
- [ ] 禁止裸调 `param_get()`，用 `DEFINE_PARAMETERS` + `ModuleParams`
- [ ] 禁止使用系统时钟，用 `hrt_absolute_time()`

---

## 第五步：CMakeLists.txt
```cmake
px4_add_module(
    MODULE drivers__<name>
    MAIN <name>
    SRCS
        <Name>.cpp
    DEPENDS
        px4_work_queue
)
```

---

## 第六步：单元测试
- 在 `src/drivers/<name>/test/test_<name>.cpp` 编写 Google Test
- 用 `px4_add_unit_gtest` 注册到 `CMakeLists.txt`
- 覆盖：正常调度流程、超时处理、边界输入、uORB publish 验证

---

## 第七步：验证
- 编译：`make px4_sitl_default`
- 运行：`<name> start`
- 检查：`<name> status` 查看 perf 统计
- uORB 验证：`listener <topic>` 确认数据正常发布
