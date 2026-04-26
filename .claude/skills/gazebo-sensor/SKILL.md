---
name: gazebo-sensor
version: "1.0.0"
description: 在 Gazebo Classic 中开发自定义传感器插件并配置 SDF。
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
1. 传感器类型（距离传感器 / 激光雷达 / 相机 / 自定义）
2. 采样率（Hz）
3. 数据量程（min/max）及单位
4. 挂载模型名称（Gazebo 模型中的 link 名）
5. 数据注入方式：MAVLink HIL 消息 还是 Gazebo Topic

---

## 第二步：开发 Gazebo 传感器插件

插件目录：`gazebo-classic/src/plugins/`（或开发者指定目录）

1. 搜索现有类似插件作为参考
2. 创建继承自 `gazebo::SensorPlugin`（或 `ModelPlugin`）的类：

```cpp
// <SensorName>Plugin.hh
class <SensorName>Plugin : public gazebo::SensorPlugin {
public:
    void Load(gazebo::sensors::SensorPtr sensor, sdf::ElementPtr sdf) override;
    void OnUpdate();
private:
    gazebo::event::ConnectionPtr update_connection_;
    // 禁止阻塞调用，使用 Gazebo 事件机制
};
```

3. 在 `OnUpdate()` 中读取传感器数据，通过 MAVLink `HIL_SENSOR` 消息注入 PX4：
   - 禁止绕过 MAVLink 直接写 uORB
   - 仿真时钟使用 `world->SimTime()`，禁止系统时钟

4. 配置 CMakeLists.txt，注册插件

完成后展示代码框架，等待用户确认。

---

## 第三步：配置 SDF 模型文件

1. 在对应模型的 `.sdf` 文件中添加传感器节点：

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
            <min><最小距离></min>
            <max><最大距离></max>
        </range>
    </ray>
    <plugin name="<plugin_name>" filename="lib<SensorName>Plugin.so"/>
</sensor>
```

2. 同步更新 CMakeLists.txt 安装规则

---

## 第四步：验证

1. 编译插件：`cd gazebo-classic/build && make`
2. 启动仿真：`make px4_sitl gazebo`
3. 验证 uORB 数据：`listener distance_sensor`
4. 验证 MAVLink 流：`mavlink status streams`

---

## 编码规范（Gazebo 侧）

- 插件中禁止阻塞调用，使用 `ConnectWorldUpdateBegin` 等事件机制
- 传感器数据注入通过 `HIL_SENSOR` / `HIL_GPS`，禁止绕过 MAVLink
- 多机仿真端口按 `14540+N` 分配，禁止硬编码
- SDF / world 修改需同步更新 CMakeLists.txt 安装规则
