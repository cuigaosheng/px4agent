用户需要在无人机系统中添加一条自定义 MAVLink 消息：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 项目：`~/px4agent`
- MAVLink XML 定义：`src/modules/mavlink/mavlink/message_definitions/v1.0/`
- MAVLink 消息流：`src/modules/mavlink/streams/`
- MAVLink 接收器：`src/modules/mavlink/mavlink_receiver.cpp`
- MAVLink 主模块：`src/modules/mavlink/mavlink_main.cpp`

---

## 第一步：搜索现有消息定义
1. 搜索 `message_definitions/v1.0/` 下所有 XML 文件
2. 查找是否有类似功能的消息可复用
3. **有类似消息 → 告知用户，等用户确认后再决定复用还是新增**
4. 无类似消息 → 提议在 `development.xml` 中新增，等用户确认

---

## 第二步：定义 MAVLink 消息
1. 向用户确认消息名称、字段列表（字段名、类型、单位、描述）
2. 检查 `common.xml` 和 `development.xml` 确认 message ID 无冲突
3. 按 MAVLink XML 格式写入消息定义，包含 `<description>` 和每字段 `<description>`

---

## 第三步：修改 PX4 端

### 3a 发送消息（PX4 → GCS）
- 在 `streams/` 下参考已有文件新建 `MAVLINK_MSG_<NAME>.hpp`
- 继承 `MavlinkStream`，实现 `get_name()`、`get_id()`、`get_message_size()`、`send()`
- `send()` 中订阅对应 uORB topic，填充并发送消息
- 在 `mavlink_main.cpp` 的 `configure_streams_to_default()` 中注册
- 如 uORB topic 不存在，先完成 uORB 定义再回来

### 3b 接收消息（GCS → PX4，如需要）
- 在 `mavlink_receiver.cpp` 的 `handle_message()` switch 中添加 case
- 实现 `handle_message_<name>(mavlink_message_t *msg)` 方法
- 解析后 publish 到对应 uORB topic
- 做范围校验后再写 uORB，防止非法数据

---

## 第四步：修改 QGroundControl 端
1. 询问用户 QGC 源码路径
2. 在 `src/Vehicle/` 或对应组件中添加消息处理
3. 如需要 UI 展示，更新对应 QML 组件
4. 确认 QGC 引用的 MAVLink 头文件与 PX4 侧版本一致

---

## 第五步：Gazebo SITL 验证
1. 编译：`make px4_sitl gazebo`（在 PX4 项目根目录执行）
2. 启动仿真后执行 `mavlink status streams` 确认新 stream 已注册
3. 用 MAVLink Inspector 或 `listener` 命令验证消息正常发出
4. 确认 QGC 能收到并正确解析
5. 如失败，检查：stream 注册、message ID 冲突、XML 格式错误

---

## 编码规范（必须遵守）
- 禁止 `printf`/`fprintf`，用 `PX4_DEBUG`（高频）/`PX4_INFO`/`PX4_WARN`/`PX4_ERR`
- 时间用 `hrt_absolute_time()`，禁止系统时钟
- 参数用 `DEFINE_PARAMETERS` + `ModuleParams`，禁止裸调 `param_get()`
- 禁止动态内存分配（new/delete/malloc/free）
- 只用 UAVCAN v0，禁止 Cyphal(v1)
- 状态机 enum 必须有 default 分支
- 通信数据先范围校验再写 uORB
