---
name: px4-crid-backport
version: "1.0.0"
description: C-RID 驱动代码迁移生成器 - 从 PX4 main 分支获取 C-RID DroneCAN 驱动代码，迁移到 1.15.0 版本，生成完整驱动框架（驱动 + uORB + MAVLink + 参数 + 单元测试），并进行端到端仿真验证。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

C-RID 驱动代码迁移生成器：$ARGUMENTS

从 PX4 main 分支获取 C-RID DroneCAN 驱动代码，自动迁移到 1.15.0 版本，生成完整的驱动框架、uORB 消息、MAVLink 流、参数定义和单元测试，最后进行完整端到端仿真验证。

---

## 第零步：需求确认

询问用户：

1. **目标 PX4 版本**（默认 `1.15.0`，位置 `~/px4agent`）
2. **源代码位置**（默认 `https://github.com/PX4/PX4-Autopilot`，分支 `main`）
3. **是否生成单元测试**（默认是）
4. **是否进行 SITL 仿真验证**（默认是）
5. **仿真器选择**（Gazebo 或 AirSim，默认 Gazebo）

---

## 第一步：从 main 分支获取 C-RID 驱动代码

### 1a. 克隆或更新 main 分支

```bash
# 如果本地没有 main 分支副本
git clone --depth 1 --branch main https://github.com/PX4/PX4-Autopilot /tmp/px4_main

# 或者更新现有副本
cd /tmp/px4_main && git fetch origin main && git checkout main
```

### 1b. 搜索 C-RID 驱动文件

```bash
# 查找 C-RID 相关文件
find /tmp/px4_main -name "*crid*" -o -name "*remote_id*" | grep -E "\.(cpp|hpp|msg|yaml)$"

# 典型路径：
# - /tmp/px4_main/src/drivers/dronecan/remoteid/
# - /tmp/px4_main/src/modules/uORB/topics/remote_id_*.msg
# - /tmp/px4_main/src/modules/mavlink/streams/REMOTE_ID_*.hpp
```

### 1c. 提取关键文件

需要提取的文件类型：
- DroneCAN 驱动实现（`.cpp` / `.hpp`）
- uORB 消息定义（`.msg`）
- MAVLink 流配置（`.hpp`）
- 参数定义（`module.yaml` 或 `.c`）
- CMakeLists.txt 和 Kconfig

---

## 第二步：分析版本差异

### 2a. 检查 API 兼容性

对比 1.15.0 和 main 的关键 API 差异：

```bash
# 检查 DroneCAN 驱动 API
grep -r "class.*DroneCAN" ~/px4agent/src/drivers/dronecan/ | head -5

# 检查 uORB 消息格式
ls ~/px4agent/src/modules/uORB/topics/ | grep -i remote

# 检查 MAVLink 版本
grep -r "MAVLINK_MSG_ID" ~/px4agent/src/modules/mavlink/ | head -3
```

### 2b. 识别需要适配的部分

- **DroneCAN 驱动**：检查 `ScheduledWorkItem` 接口是否变化
- **uORB 消息**：检查消息字段是否兼容
- **MAVLink 流**：检查消息 ID 和字段映射
- **参数系统**：检查 `DEFINE_PARAMETERS` 宏是否变化

---

## 第三步：生成迁移后的驱动代码

### 3a. 生成 DroneCAN 驱动头文件

目标文件：`src/drivers/dronecan/remoteid/RemoteID.hpp`

```cpp
#pragma once

#include <px4_platform_common/px4_config.h>
#include <px4_platform_common/defines.h>
#include <px4_platform_common/module.h>
#include <px4_platform_common/module_params.h>
#include <px4_platform_common/px4_work_queue/ScheduledWorkItem.hpp>
#include <drivers/drv_hrt.h>
#include <lib/perf/perf_counter.h>
#include <uORB/Publication.hpp>
#include <uORB/Subscription.hpp>
#include <uORB/topics/remote_id_status.h>

using namespace time_literals;

class RemoteID : public ModuleBase<RemoteID>,
                 public ModuleParams,
                 public px4::ScheduledWorkItem
{
public:
    RemoteID();
    ~RemoteID() override;

    static int task_spawn(int argc, char *argv[]);
    static int custom_command(int argc, char *argv[]);
    static int print_usage(const char *reason = nullptr);

    bool init();
    int  print_status() override;

protected:
    void RunImpl() override;

private:
    void _update_params();
    void _publish_status();

    // 参数
    DEFINE_PARAMETERS(
        (ParamInt<px4::params::CRID_ENABLE>)         _param_enable,
        (ParamInt<px4::params::CRID_INTERVAL>)       _param_interval_ms
    )

    // 发布器
    uORB::Publication<remote_id_status_s> _pub_status{ORB_ID(remote_id_status)};

    // 性能计数器
    perf_counter_t _cycle_perf{perf_alloc(PC_ELAPSED, MODULE_NAME": cycle")};
    perf_counter_t _publish_perf{perf_alloc(PC_COUNT, MODULE_NAME": publish")};

    // 状态
    uint32_t _enable{1};
    uint32_t _interval_ms{1000};
};
```

### 3b. 生成 DroneCAN 驱动实现文件

目标文件：`src/drivers/dronecan/remoteid/RemoteID.cpp`

```cpp
#include "RemoteID.hpp"
#include <px4_platform_common/log.h>

RemoteID::RemoteID()
    : ModuleParams(nullptr),
      ScheduledWorkItem(MODULE_NAME, px4::wq_configurations::hp_default)
{
}

RemoteID::~RemoteID()
{
    ScheduleClear();
    perf_free(_cycle_perf);
    perf_free(_publish_perf);
}

bool RemoteID::init()
{
    updateParams();
    _update_params();

    // 启动定时调度
    ScheduleOnInterval(_interval_ms * 1_ms);
    PX4_INFO("RemoteID initialized: enable=%u, interval=%u ms", _enable, _interval_ms);
    return true;
}

void RemoteID::_update_params()
{
    _enable      = _param_enable.get();
    _interval_ms = _param_interval_ms.get();

    if (_interval_ms < 100 || _interval_ms > 10000) {
        _interval_ms = 1000;
    }
}

void RemoteID::RunImpl()
{
    perf_begin(_cycle_perf);

    // 定期更新参数
    static uint32_t param_counter = 0;
    if (++param_counter >= 100) {
        param_counter = 0;
        updateParams();
        _update_params();
    }

    if (_enable) {
        _publish_status();
    }

    perf_end(_cycle_perf);
}

void RemoteID::_publish_status()
{
    remote_id_status_s msg{};
    msg.timestamp = hrt_absolute_time();
    msg.is_valid = true;

    _pub_status.publish(msg);
    perf_count(_publish_perf);
}

int RemoteID::print_status()
{
    PX4_INFO("RemoteID status:");
    PX4_INFO("  Enable: %u", _enable);
    PX4_INFO("  Interval: %u ms", _interval_ms);
    return 0;
}

int RemoteID::task_spawn(int argc, char *argv[])
{
    RemoteID *instance = new RemoteID();

    if (instance == nullptr) {
        PX4_ERR("alloc failed");
        return PX4_ERROR;
    }

    if (instance->init()) {
        _object.store(instance);
        _task_id = task_id_is_work_queue;
        return PX4_OK;
    } else {
        delete instance;
        return PX4_ERROR;
    }
}

int RemoteID::custom_command(int argc, char *argv[])
{
    return print_usage("unknown command");
}

int RemoteID::print_usage(const char *reason)
{
    if (reason) {
        PX4_WARN("%s\n", reason);
    }

    PRINT_MODULE_DESCRIPTION(
        R"DESCR_STR(
### Description
Remote ID (C-RID) driver for DroneCAN.

)DESCR_STR");

    PRINT_MODULE_USAGE_NAME("remoteid", "driver");
    PRINT_MODULE_USAGE_COMMAND("start");
    PRINT_MODULE_USAGE_COMMAND("stop");
    PRINT_MODULE_USAGE_COMMAND("status");
    return 0;
}

extern "C" __EXPORT int remoteid_main(int argc, char *argv[])
{
    return RemoteID::main(argc, argv);
}
```

---

## 第四步：生成 uORB 消息定义

目标文件：`src/modules/uORB/topics/remote_id_status.msg`

```
# Remote ID (C-RID) 状态消息
uint64 timestamp        # 时间戳（微秒）
bool is_valid           # 数据有效性
uint8_t system_id[20]   # 系统 ID
uint8_t operator_id[20] # 操作员 ID
float latitude          # 纬度
float longitude         # 经度
float altitude_m        # 高度（米）
uint16_t speed_kmh      # 速度（km/h）
uint16_t heading_deg    # 航向（度）
```

---

## 第五步：生成 MAVLink 流配置

目标文件：`src/modules/mavlink/streams/REMOTE_ID_STATUS.hpp`

```cpp
#pragma once

#include <uORB/topics/remote_id_status.h>
#include "common/mavlink_stream.h"

class MavlinkStreamRemoteIDStatus : public MavlinkStream
{
public:
    static MavlinkStream *new_instance(Mavlink *mavlink)
    {
        return new MavlinkStreamRemoteIDStatus(mavlink);
    }

    static constexpr const char *get_name_static() { return "REMOTE_ID_STATUS"; }
    static constexpr uint16_t get_id_static() { return MAVLINK_MSG_ID_REMOTE_ID_STATUS; }

    const char *get_name() const override { return get_name_static(); }
    uint16_t get_id() override { return get_id_static(); }
    unsigned get_size() override { return MAVLINK_MSG_ID_REMOTE_ID_STATUS_LEN + MAVLINK_NUM_NON_PAYLOAD_BYTES; }

private:
    explicit MavlinkStreamRemoteIDStatus(Mavlink *mavlink) : MavlinkStream(mavlink) {}

    uORB::Subscription<remote_id_status_s> _sub{ORB_ID(remote_id_status)};

    bool send() override
    {
        remote_id_status_s msg;

        if (_sub.update(&msg)) {
            mavlink_remote_id_status_t remote_id{};
            remote_id.timestamp = msg.timestamp;
            remote_id.is_valid = msg.is_valid;

            mavlink_msg_remote_id_status_send(_mavlink->get_channel(),
                                              remote_id.timestamp,
                                              remote_id.is_valid);
            return true;
        }

        return false;
    }
};
```

---

## 第六步：生成参数定义

目标文件：`src/drivers/dronecan/remoteid/module.yaml`

```yaml
module_name: Remote ID (C-RID)
description: DroneCAN Remote ID driver

parameters:
  CRID_ENABLE:
    description: Enable Remote ID
    type: int32
    default: 1
    min: 0
    max: 1
    unit: —
    category: Remote ID
    volatile: false
    reboot_required: false

  CRID_INTERVAL:
    description: Remote ID update interval
    type: int32
    default: 1000
    min: 100
    max: 10000
    unit: ms
    category: Remote ID
    volatile: false
    reboot_required: false
```

---

## 第七步：生成 CMakeLists.txt

目标文件：`src/drivers/dronecan/remoteid/CMakeLists.txt`

```cmake
px4_add_module(
    MODULE drivers__dronecan__remoteid
    MAIN remoteid
    STACK_MAIN 2048
    SRCS
        RemoteID.cpp
    DEPENDS
        drivers_dronecan
        modules_uorb
)
```

---

## 第八步：生成单元测试

目标文件：`src/drivers/dronecan/remoteid/test/test_remoteid.cpp`

```cpp
#include <gtest/gtest.h>
#include <uORB/Publication.hpp>
#include <uORB/Subscription.hpp>
#include <uORB/topics/remote_id_status.h>

TEST(RemoteIDTest, PublishStatus)
{
    uORB::Publication<remote_id_status_s> pub{ORB_ID(remote_id_status)};
    uORB::Subscription<remote_id_status_s> sub{ORB_ID(remote_id_status)};

    remote_id_status_s msg{};
    msg.timestamp = hrt_absolute_time();
    msg.is_valid = true;

    pub.publish(msg);
    usleep(100);

    EXPECT_TRUE(sub.updated());

    remote_id_status_s received{};
    EXPECT_TRUE(sub.copy(&received));
    EXPECT_EQ(received.is_valid, true);
}

TEST(RemoteIDTest, MessageSize)
{
    EXPECT_GT(sizeof(remote_id_status_s), 0);
}
```

---

## 第九步：输出文件清单

生成 8 个文件：
1. `src/drivers/dronecan/remoteid/RemoteID.hpp`
2. `src/drivers/dronecan/remoteid/RemoteID.cpp`
3. `src/modules/uORB/topics/remote_id_status.msg`
4. `src/modules/mavlink/streams/REMOTE_ID_STATUS.hpp`
5. `src/drivers/dronecan/remoteid/module.yaml`
6. `src/drivers/dronecan/remoteid/CMakeLists.txt`
7. `src/drivers/dronecan/remoteid/test/test_remoteid.cpp`
8. `src/drivers/dronecan/remoteid/Kconfig`

---

## 第十步：编译验证

```bash
cd ~/px4agent
make px4_sitl_default
```

验证步骤：
1. 编译成功，无错误
2. 检查生成的驱动二进制
3. 运行单元测试：`make test_remoteid`

---

## 第十一步：SITL 仿真验证

### 11a. 启动 Gazebo SITL

```bash
make px4_sitl gazebo
```

### 11b. 启动 Remote ID 驱动

在 PX4 shell 中：

```bash
remoteid start
remoteid status
```

### 11c. 验证消息发布

```bash
listener remote_id_status
```

### 11d. 验证 MAVLink 流

```bash
mavlink status streams
```

查看 `REMOTE_ID_STATUS` 是否在流列表中。

---

## 第十二步：QGC 端到端验证

1. 启动 QGroundControl
2. 连接到 PX4 SITL（TCP 14550）
3. 打开 **Analyze → MAVLink Inspector**
4. 搜索 `REMOTE_ID_STATUS` 消息
5. 验证消息正常接收和显示

---

## 编码规范

- 禁止动态内存分配（new/delete/malloc/free）
- 禁止独立线程，统一使用 ScheduledWorkItem
- 禁止驱动层浮点运算
- 禁止阻塞调用（sleep/usleep/mutex lock）
- 禁止 printf，用 PX4_DEBUG/PX4_INFO/PX4_WARN/PX4_ERR
- 时间戳统一用 hrt_absolute_time()
- 通信数据必须先范围校验再写 uORB

---

## 常见问题

### Q1：如何处理 API 不兼容？

A：在第二步进行详细的版本差异分析。若 API 变化，需要在生成的代码中添加适配层或条件编译。

### Q2：如何验证迁移的正确性？

A：通过单元测试、SITL 编译、驱动启动、消息发布、MAVLink 流验证四个层次逐步验证。

### Q3：如何处理新增的字段或功能？

A：在 uORB 消息中添加新字段时，保持向后兼容性（新字段追加到末尾）。

### Q4：如何集成到现有的 DroneCAN 驱动框架？

A：在 `src/drivers/dronecan/CMakeLists.txt` 中添加 `remoteid` 子模块的引用。
