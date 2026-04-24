用户需要在 PX4 中添加自定义 UAVCAN（DroneCAN v0）消息或节点功能：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 项目：`C:/Users/cuiga/droneyee_px4v1.15.0`
- UAVCAN 驱动：`src/drivers/uavcan/`
- UAVCAN 主节点：`src/drivers/uavcan/uavcan_main.cpp` / `uavcan_main.hpp`
- 传感器适配层：`src/drivers/uavcan/sensors/`
- 执行器适配层：`src/drivers/uavcan/actuators/`
- DSDL 自定义消息：`src/drivers/uavcan/dsdl/com.droneyee/`（按厂商命名空间）
- uORB 消息：`msg/`
- Libuavcan 头文件：`src/drivers/uavcan/libuavcan/`

---

## 第一步：确认需求

询问用户以下信息，**全部确认后再继续**：

1. 功能类型：
   - **发布节点**（PX4 → UAVCAN 总线，如发送控制指令给外设）
   - **订阅节点**（外设 → PX4，如读取自定义传感器数据）
   - **双向**（发布 + 订阅）
2. 自定义消息名称（如 `MyData`）
3. 消息字段列表（字段名、数据类型、单位、描述）
   - 支持类型：`uint8`、`uint16`、`uint32`、`int16`、`float16`、`float32`、`bool`、`uint8[<=64]` 等
4. DSDL Data Type ID（1~65535，避开标准消息段）
5. 对应 uORB topic 名称（已有 topic 优先复用）

---

## 第二步：定义 DSDL 消息

1. 在 `src/drivers/uavcan/dsdl/com.droneyee/` 下新建目录结构：
   ```
   src/drivers/uavcan/dsdl/
   └── com.droneyee/
       └── <DataTypeID>.<MessageName>.uavcan
   ```
2. 按 UAVCAN v0 DSDL 格式编写消息，示例：
   ```dsdl
   # <MessageName>.uavcan  Data Type ID: <DataTypeID>
   # <字段描述>

   float32 value        # 主数据值
   uint8 status         # 状态字节
   uint64 timestamp     # 时间戳 us
   ```
3. 确认 Data Type ID 不与以下标准段冲突：
   - 1~109：标准硬件专用消息
   - 110~127：标准网络服务消息
   - 128~255：标准诊断消息
   - 300~399：推荐自定义范围（建议使用此段）
4. 在 `src/drivers/uavcan/CMakeLists.txt` 中注册 DSDL 路径：
   ```cmake
   set(UAVCAN_DSDL_PATH "${CMAKE_CURRENT_SOURCE_DIR}/dsdl")
   ```

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
#include <com/droneyee/<MessageName>.hpp>   // DSDL 生成头文件
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
    void cb_<name>(const uavcan::ReceivedDataStructure<com::droneyee::<MessageName>> &msg);

    typedef uavcan::MethodBinder<UavcanCustom<Name>Bridge *,
        void (UavcanCustom<Name>Bridge::*)
        (const uavcan::ReceivedDataStructure<com::droneyee::<MessageName>> &)>
        CallbackBinder;

    uavcan::Subscriber<com::droneyee::<MessageName>, CallbackBinder> _sub;
    uORB::Publication<<topic_name>_s> _pub{ORB_ID(<topic_name>)};
};
```

在 `<name>.cpp` 中：
- `init()` 中调用 `_sub.start(CallbackBinder(this, &UavcanCustom<Name>Bridge::cb_<name>))`
- 回调中完成数据转换（**禁止浮点**）并 publish uORB
- 时间戳用 `hrt_absolute_time()`

在 `uavcan_main.cpp` 中注册：
```cpp
#include "sensors/<name>.hpp"
// 在 sensors 列表中追加
_sensor_bridges.push_back(new UavcanCustom<Name>Bridge(_node));
```

### 4b 发布节点（PX4 uORB → UAVCAN 总线）

在 `src/drivers/uavcan/actuators/` 下新建 `<name>.hpp`：

```cpp
#pragma once

#include <uavcan/uavcan.hpp>
#include <com/droneyee/<MessageName>.hpp>
#include <uORB/Subscription.hpp>
#include <uORB/topics/<topic_name>.h>

class UavcanCustom<Name>Controller {
public:
    UavcanCustom<Name>Controller(uavcan::INode &node);

    int init();
    void update();   // 由 uavcan_main 周期性调用

private:
    typedef uavcan::Publisher<com::droneyee::<MessageName>> Publisher;

    Publisher _pub;
    uORB::Subscription _sub{ORB_ID(<topic_name>)};
};
```

实现要点：
- `update()` 中检查 uORB 是否有新数据（`_sub.updated()`）
- 有更新时填充 DSDL 消息，调用 `_pub.broadcast(msg)`
- **发布频率不超过总线配置带宽**，建议 ≤ 100 Hz

完成后展示适配层代码，等待用户确认。

---

## 第五步：CMakeLists.txt 集成

在 `src/drivers/uavcan/CMakeLists.txt` 中追加源文件：

```cmake
# 订阅传感器
list(APPEND SRCS
    sensors/<name>.cpp
)

# 或发布执行器
list(APPEND SRCS
    actuators/<name>.cpp
)
```

确认 DSDL 生成规则已包含自定义命名空间路径。

---

## 第六步：节点参数配置

检查 `src/drivers/uavcan/` 中的 Kconfig 和参数定义：

1. 如需独立参数，在驱动中用 `DEFINE_PARAMETERS` 添加，命名格式：`UAVCAN_<NAME>_*`
2. 常用参数示例：
   - `UAVCAN_<NAME>_EN`：使能开关（int32，0/1）
   - `UAVCAN_<NAME>_RATE`：发布频率 Hz（int32）
3. 在 `Kconfig` 中添加对应配置项

---

## 第七步：Gazebo SITL 端到端验证

1. 编译：`make px4_sitl_default`（PX4 项目根目录）
2. 启动仿真后执行：
   - `uavcan status` → 确认 UAVCAN 节点在线
   - `listener <topic_name>` → 确认 uORB 数据正常（订阅场景）
   - `uavcan nodestatus` → 确认自定义节点已注册（发布场景）
3. 如失败，按链路排查：
   - DSDL Data Type ID 冲突 → 修改 ID
   - 头文件未生成 → 检查 CMakeLists DSDL 路径配置
   - 回调未触发 → 检查 `_sub.start()` 返回值
   - uORB 无数据 → 在回调中加 `PX4_INFO` 验证回调是否进入

---

## 单元测试（必须同步完成）

- 在对应目录下新建 `test/test_<name>.cpp`
- 用 `px4_add_unit_gtest` 注册
- 覆盖：DSDL 字段解析、uORB publish 验证、异常帧处理、频率限制

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
