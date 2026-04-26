---
name: px4-uavcan-custom
version: "1.0.0"
description: 用户需要在 PX4 中添加自定义 UAVCAN（DroneCAN v0）消息或节点功能。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
用户需要在 PX4 中添加自定义 UAVCAN（DroneCAN v0）消息或节点功能：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 项目：`~/px4agent`
- UAVCAN 驱动：`src/drivers/uavcan/`
- UAVCAN 主节点：`src/drivers/uavcan/uavcan_main.cpp` / `uavcan_main.hpp`
- 传感器适配层：`src/drivers/uavcan/sensors/`
- 执行器适配层：`src/drivers/uavcan/actuators/`
- DSDL 自定义消息：`src/drivers/uavcan/dsdl/com.px4agent/`（按厂商命名空间）
- uORB 消息：`msg/`
- Libuavcan 头文件：`src/drivers/uavcan/libuavcan/`

---

## 第一步：确认需求

询问用户以下信息，**全部确认后再继续**：

1. 功能类型：
   - **发布节点**（PX4 → UAVCAN 总线）
   - **订阅节点**（外设 → PX4）
   - **双向**（发布 + 订阅）
2. 自定义消息名称（如 `MyData`）
3. 消息字段列表（字段名、数据类型、单位、描述）
4. DSDL Data Type ID（1~65535，避开标准消息段）
5. 对应 uORB topic 名称（已有 topic 优先复用）

---

## 第二步：定义 DSDL 消息

1. 在 `src/drivers/uavcan/dsdl/com.px4agent/` 下新建目录结构：
   ```
   src/drivers/uavcan/dsdl/
   └── com.px4agent/
       └── <DataTypeID>.<MessageName>.uavcan
   ```
2. 按 UAVCAN v0 DSDL 格式编写消息
3. 确认 Data Type ID 不与标准段冲突（建议使用 300~399 段）
4. 在 `src/drivers/uavcan/CMakeLists.txt` 中注册 DSDL 路径

完成后展示 DSDL 文件内容，等待用户确认。

---

## 第三步：配置 uORB 消息

1. 搜索 `msg/` 确认是否有可复用 topic
2. **有可复用 → 告知用户，等确认**；无 → 新建 `msg/<topic_name>.msg`
3. 消息字段与 DSDL 对齐，添加 `uint64 timestamp` 字段
4. 在 `msg/CMakeLists.txt` 注册新 topic
5. 如有量纲转换，注明换算关系（禁止在驱动层使用浮点）

完成后等待用户确认。

---

## 第四步：实现 PX4 端适配层

根据第一步确认的功能类型选择对应实现路径。

### 4a 订阅节点（外设数据 → PX4 uORB）

在 `src/drivers/uavcan/sensors/` 下新建 `<name>.hpp`：

```cpp
#pragma once
#include <uavcan/uavcan.hpp>
#include <com/px4agent/<MessageName>.hpp>
#include <uORB/Publication.hpp>
#include <uORB/topics/<topic_name>.h>
#include <drivers/drv_hrt.h>

class UavcanCustom<Name>Bridge {
public:
    static const char *const NAME;
    UavcanCustom<Name>Bridge(uavcan::INode &node);
    int init();
    static int get_num_redundant_channels() { return 0; }
    void print_status() const;
private:
    void cb_<name>(const uavcan::ReceivedDataStructure<com::px4agent::<MessageName>> &msg);
    typedef uavcan::MethodBinder<UavcanCustom<Name>Bridge *,
        void (UavcanCustom<Name>Bridge::*)
        (const uavcan::ReceivedDataStructure<com::px4agent::<MessageName>> &)>
        CallbackBinder;
    uavcan::Subscriber<com::px4agent::<MessageName>, CallbackBinder> _sub;
    uORB::Publication<<topic_name>_s> _pub{ORB_ID(<topic_name>)};
};
```

### 4b 发布节点（PX4 uORB → UAVCAN 总线）

在 `src/drivers/uavcan/actuators/` 下新建 `<name>.hpp` 并实现 `update()` 方法。

完成后展示适配层代码，等待用户确认。

---

## 第五步：CMakeLists.txt 集成

在 `src/drivers/uavcan/CMakeLists.txt` 中追加源文件并确认 DSDL 生成规则。

---

## 第六步：节点参数配置

参数命名格式：`UAVCAN_<NAME>_*`，在 `Kconfig` 中添加对应配置项。

---

## 第七步：Gazebo SITL 端到端验证

```bash
make px4_sitl_default
uavcan status
listener <topic_name>
```

---

## 单元测试（必须同步完成）

覆盖：DSDL 字段解析、uORB publish 验证、异常帧处理、频率限制。

---

## 编码规范（必须遵守）

- 只用 **UAVCAN v0 (DroneCAN)**，**禁止 Cyphal (v1)**
- 禁止 `printf`/`fprintf`，用 `PX4_DEBUG`/`PX4_INFO`/`PX4_WARN`/`PX4_ERR`
- 时间：`hrt_absolute_time()`，禁止系统时钟
- 参数：`DEFINE_PARAMETERS` + `ModuleParams`，禁止裸调 `param_get()`
- 禁止动态内存分配（`new`/`delete`/`malloc`/`free`）
- 禁止在回调/驱动层使用浮点运算，用定点数或整型
- 回调函数禁止阻塞，超时用 `ScheduleDelayed()`
- 数组访问用 `ARRAY_SIZE()` 做边界检查
- 通信数据先范围校验再写 uORB，防止非法值
- DSDL 自定义消息 Data Type ID 必须与标准段隔离（建议 300~399）
