用户需要在 PX4 中添加一个新传感器驱动：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 项目：`~/px4agent`
- 驱动目录：`src/drivers/`
- uORB 消息：`msg/`
- MAVLink XML：`src/modules/mavlink/mavlink/message_definitions/v1.0/`
- MAVLink 流：`src/modules/mavlink/streams/`
- MAVLink 主模块：`src/modules/mavlink/mavlink_main.cpp`

---

## 第一步：PX4 传感器驱动开发
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
