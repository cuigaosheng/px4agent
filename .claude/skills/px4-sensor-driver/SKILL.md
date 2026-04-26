---
name: px4-sensor-driver
version: "1.1.0"
description: 用户需要在 PX4 中添加或核实传感器驱动（驱动→uORB→MAVLink→QGC）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
用户需要处理 PX4 传感器驱动：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 项目：`~/px4agent`
- 驱动目录：`src/drivers/`
- uORB 消息：`msg/`
- MAVLink XML：`src/modules/mavlink/mavlink/message_definitions/v1.0/`
- MAVLink 流：`src/modules/mavlink/streams/`
- MAVLink 主模块：`src/modules/mavlink/mavlink_main.cpp`

---

## 第零步：判断驱动是否已存在（必须优先执行）

询问用户传感器名称，然后搜索 `src/drivers/` 目录：

```bash
find src/drivers/ -type d -iname "*<sensor_name>*"
```

### 分支 A：驱动已存在 → 走核实流程

进入**驱动核实流程**（见下方），跳过第一步~第二步的"新建"部分。

### 分支 B：驱动不存在 → 走新建流程

继续执行第一步（PX4 传感器驱动开发）。

---

## 【核实流程】现有驱动核实（分支 A 专用）

**目标：验证现有驱动符合项目编码规范，发布正确的 uORB 数据。**

### 核实第一步：代码规范检查

读取驱动的 `.cpp` 和 `.hpp` 文件，逐条核验：

| 检查项 | 正确做法 | 结论 |
|--------|---------|------|
| 线程模型 | 继承 `px4::ScheduledWorkItem`，禁止独立线程 | |
| 浮点运算 | 驱动层禁止浮点，用定点数/整型 | |
| 动态内存 | 禁止 `new`/`delete`/`malloc`/`free` | |
| 阻塞调用 | 禁止 `sleep`/`usleep`，用 `ScheduleDelayed()` | |
| 日志 | 禁止 `printf`，用 `PX4_DEBUG`/`PX4_INFO`/`PX4_WARN`/`PX4_ERR` | |
| 时间 | `hrt_absolute_time()`，禁止系统时钟 | |
| 参数 | `DEFINE_PARAMETERS` + `ModuleParams`，禁止裸调 `param_get()` | |
| perf_counter | 析构中调用 `perf_free()`，防止资源泄漏 | |
| 数组访问 | 用 `ARRAY_SIZE()` 做边界检查 | |
| 传感器超时 | 超时后上报健康异常，不能静默失败 | |

输出核验报告，标注每项"✅ 合规"或"❌ <具体问题>"。

等待用户确认后继续。

### 核实第二步：uORB 发布确认

1. 确认驱动发布的 uORB topic 名称和消息类型
2. **360° 扫描型传感器**（如 SF45）：必须发布 `obstacle_distance`（72元素数组，5°/格）
3. **单点测距型传感器**：必须发布 `distance_sensor`
4. 检查发布频率是否与硬件额定采样率匹配
5. 确认 `orb_advertise_queue()` 队列深度设置合理

### 核实第三步：MAVLink 流核实

1. 检查 `streams/` 目录是否有对应的 MAVLink 流文件
2. 对于 `obstacle_distance` → 检查 `OBSTACLE_DISTANCE.hpp` 是否存在且已注册
3. 对于 `distance_sensor` → 检查 `DISTANCE_SENSOR.hpp` 是否存在且已注册
4. 确认 stream 在 `mavlink_main.cpp` 中已注册

### 核实第四步：编译验证

```bash
# 编译目标（使用开发者实际项目路径）
make px4_sitl_default
```

确认驱动编译无警告、无错误。

### 核实第五步：运行时数据验证

启动 SITL 后：

```bash
# 确认驱动启动
<driver_name> start

# 验证 uORB 数据
listener obstacle_distance      # 360° 传感器
# 或
listener distance_sensor        # 单点传感器

# 验证 MAVLink 流
mavlink status streams
```

检查：
- 数据频率是否达到额定采样率的 90% 以上
- 距离值是否在传感器量程内（无异常 0 值或最大值填充）
- 360° 传感器：72 个角度格是否均有有效数据（非全 0 或全 UINT16_MAX）

**核实完成后跳转至第三步（MAVLink 消息）继续后续链路。**

---

## 第一步：PX4 传感器驱动开发（分支 B 新建专用）
1. 询问用户：传感器名称、总线类型（**DroneCAN 优先**，其次 I2C/SPI）、数据格式、采样率
2. 在 `src/drivers/` 下查找类似驱动作参考
3. 建立驱动目录：`src/drivers/<sensor_name>/`
4. 创建继承自 `px4::ScheduledWorkItem` 的驱动类（**禁止独立线程**）
5. 实现核心逻辑：
   - `init()`：初始化设备，注册 `ScheduleOnInterval()`
   - `RunImpl()`：读取传感器数据，**禁止浮点运算（用定点数/整型）**
   - `print_status()`：打印驱动状态
6. 添加 `perf_counter` 统计采样周期和错误次数
7. 传感器超时检测：超时时上报健康异常到 `vehicle_status`
8. 配置 `CMakeLists.txt`（用 `px4_add_module`）和 `Kconfig`
9. **禁止动态内存分配（new/delete/malloc/free）**

完成后展示驱动代码框架，等待用户确认。

---

## 第二步：配置 uORB 消息
1. 搜索 `msg/` 目录，确认是否有可复用的消息
2. **有类似消息 → 告知用户，等确认后再决定复用或新建**
3. 无可复用 → 在 `msg/` 下新建 `<sensor_name>.msg`
4. 在 `msg/CMakeLists.txt` 中注册新 topic
5. 驱动中 `#include <uORB/topics/<topic>.h>` 并 publish
6. 用 `orb_advertise_queue()` 发布，队列深度根据采样率设定

完成后用 `listener <topic>` 格式说明验证方法，等待用户确认。

---

## 第三步：PX4 侧 MAVLink 消息
1. 搜索 `message_definitions/v1.0/` 确认是否有对应 MAVLink 消息
2. **有类似消息 → 告知用户，等确认**；无 → 在 `development.xml` 新增消息定义
3. 检查 message ID 无冲突
4. 在 `streams/` 下新建 `MAVLINK_MSG_<NAME>.hpp`：
   - 继承 `MavlinkStream`
   - `send()` 中订阅 uORB topic，填充并发送
5. 在 `mavlink_main.cpp` 中注册 stream

完成后等待用户确认。

---

## 第四步：修改 QGroundControl
1. 询问用户 QGC 源码路径
2. 在对应 Vehicle 类（`src/Vehicle/`）中添加消息处理方法
3. 发出对应 Qt 信号，供 UI 组件订阅
4. 如需 UI 展示，更新 QML 组件
5. 确认 QGC 侧 MAVLink 头文件版本与 PX4 侧一致

完成后等待用户确认。

---

## 第五步：Gazebo SITL 端到端验证
1. 编译：`make px4_sitl gazebo`（PX4 项目根目录）
2. 启动后验证链路：
   - `listener <uorb_topic>` → 确认 uORB 数据正常
   - `mavlink status streams` → 确认 stream 已注册
   - MAVLink Inspector → 确认消息发出，字段值合理
   - QGC 界面 → 确认数据正确显示
3. 如任一环节失败，按链路逐级排查

---

## 单元测试（必须同步完成）
- 在 `src/drivers/<sensor_name>/test/test_<sensor_name>.cpp` 编写 Google Test
- 用 `px4_add_unit_gtest` 注册到 `CMakeLists.txt`
- 覆盖：正常采样流程、传感器超时、边界值输入、uORB publish 验证

---

## 编码规范（必须遵守）
- 语言：C++
- 禁止 `printf`/`fprintf`，用 `PX4_DEBUG`（高频采样）/`PX4_INFO`/`PX4_WARN`/`PX4_ERR`
- 时间：`hrt_absolute_time()`，禁止系统时钟
- 参数：`DEFINE_PARAMETERS` + `ModuleParams`，命名格式 `SENS_<NAME>_*`
- 禁止在驱动层使用浮点运算
- 禁止动态内存分配
- WorkQueue 驱动禁止在 `RunImpl()` 中阻塞，用 `ScheduleDelayed()` 代替
- perf_free() 在析构中调用，防止资源泄漏
- 数组访问用 `ARRAY_SIZE()` 做边界检查
