---
name: gazebo-sensor
version: "1.1.0"
description: 在 Gazebo Classic 中开发自定义传感器插件并配置 SDF（支持单点和 360° 扫描雷达）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
在 Gazebo Classic 中添加自定义传感器仿真插件：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 契约检查（优先执行）

启动前先检查 `.claude/contracts/` 下是否存在 `*.contract.md` 文件：
- **存在** → 读取契约，提取：传感器类型、采样率、数据单位、仿真器字段（必须为 gazebo）
  - 若 `sim` 字段不是 `gazebo`，**停止执行**并提示：`契约指定仿真器为 <sim>，与本 skill 不符，请确认。`
  - 使用契约参数，跳过第一步的重复询问
- **不存在** → 正常询问参数

---

## 第一步：确认传感器参数

若无契约，询问：
1. **传感器扫描类型（决定配置路径）**：
   - `单点测距`：单线 ray，输出 `distance_sensor` uORB
   - `360° 扫描`：全向 gpu_ray，输出 `obstacle_distance` uORB（72元素，5°/格）
2. 采样率（Hz）
3. 数据量程（min/max）及单位（m）
4. 挂载模型名称（Gazebo 模型中的 link 名）
5. 数据注入方式：MAVLink HIL 消息（**推荐**）还是 Gazebo Topic

---

## 第二步：配置 SDF 传感器节点

### 分支 A：单点测距传感器

在模型 `.sdf` 文件中添加：

```xml
<sensor name="<sensor_name>" type="ray">
    <update_rate><采样率></update_rate>
    <ray>
        <scan>
            <horizontal>
                <samples>1</samples>
                <resolution>1</resolution>
                <min_angle>0</min_angle>
                <max_angle>0</max_angle>
            </horizontal>
        </scan>
        <range>
            <min><最小距离m></min>
            <max><最大距离m></max>
            <resolution>0.01</resolution>
        </range>
    </ray>
    <plugin name="<plugin_name>" filename="lib<SensorName>Plugin.so"/>
</sensor>
```

### 分支 B：360° 扫描雷达（如 Lightware SF45）

使用 `gpu_ray` 类型实现 360° 水平扫描，对应 PX4 `obstacle_distance` 的 72 个角度格（每格 5°）：

```xml
<sensor name="sf45_lidar" type="gpu_ray">
    <update_rate><采样率Hz></update_rate>
    <ray>
        <scan>
            <horizontal>
                <samples>72</samples>          <!-- 对应 obstacle_distance 72 个格 -->
                <resolution>1</resolution>
                <min_angle>-3.14159</min_angle> <!-- -180° -->
                <max_angle>3.14159</max_angle>  <!-- +180° -->
            </horizontal>
            <vertical>
                <samples>1</samples>
                <resolution>1</resolution>
                <min_angle>0</min_angle>
                <max_angle>0</max_angle>
            </vertical>
        </scan>
        <range>
            <min>0.1</min>                     <!-- 对应 SF45 最小距离 -->
            <max><最大距离m></max>
            <resolution>0.01</resolution>
        </range>
        <noise>
            <type>gaussian</type>
            <mean>0.0</mean>
            <stddev>0.01</stddev>
        </noise>
    </ray>
    <plugin name="sf45_plugin" filename="libSF45Plugin.so">
        <update_rate><采样率Hz></update_rate>
        <mavlink_addr>127.0.0.1</mavlink_addr>
        <mavlink_udp_port>14560</mavlink_udp_port>
    </plugin>
</sensor>
```

⚠️ **360° 配置要点**：
- `samples=72` 对应 `obstacle_distance.distances[72]`，每格覆盖 5°
- 角度顺序：Gazebo 从 -180° 到 +180°（逆时针），需在插件中按 PX4 `MAV_FRAME_BODY_FRD` 顺序重新映射
- 使用 `gpu_ray`（而非 `ray`），性能更好，支持高采样率

同步更新 CMakeLists.txt 安装规则。等待用户确认。

---

## 第三步：开发 Gazebo 传感器插件

插件目录：`gazebo-classic/src/plugins/`（或开发者指定目录）

1. 搜索现有类似插件作为参考
2. 单点测距：继承 `gazebo::SensorPlugin`；360° 扫描：继承 `gazebo::ModelPlugin` 并使用 `GpuRaySensorPtr`
3. 在 `OnUpdate()` 中读取传感器数据，注入 PX4：
   - 单点：通过 MAVLink `HIL_SENSOR` 消息注入
   - 360°：通过 MAVLink `OBSTACLE_DISTANCE` 消息注入，将 72 个 Range() 读数填入 `distances[72]`，单位 cm，无效值填 `UINT16_MAX`
   - **禁止**绕过 MAVLink 直接写 uORB；仿真时钟使用 `world->SimTime()`
4. 配置 CMakeLists.txt，注册插件

完成后展示代码框架，等待用户确认。

---

## 第四步：验证

1. 编译插件：`cd gazebo-classic/build && make`
2. 启动仿真：`make px4_sitl gazebo`
3. 验证 uORB 数据：
   ```bash
   listener obstacle_distance   # 360° 传感器
   listener distance_sensor     # 单点传感器
   ```
4. 360° 额外验证：确认 72 个距离格均有有效数据（非全 0 或全 65535）
5. 验证 MAVLink 流：`mavlink status streams`

---

## 编码规范（Gazebo 侧）

- 禁止阻塞调用，使用 `ConnectWorldUpdateBegin` 等事件机制
- 360°：`OBSTACLE_DISTANCE`（72格，5°/格，cm 单位，Gazebo 逆时针→PX4 顺时针需映射）
- 单点：`HIL_SENSOR`；禁止绕过 MAVLink
- 多机端口按 `14540+N` 分配，禁止硬编码
- SDF / world 修改需同步更新 CMakeLists.txt 安装规则
