---
name: airsim-sensor
version: "1.0.0"
description: 在 AirSim 中配置自定义传感器仿真（settings.json + 可选 Unreal 插件）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
在 AirSim 中添加自定义传感器仿真：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 契约检查（优先执行）

启动前先检查 `.claude/contracts/` 下是否存在 `*.contract.md` 文件：
- **存在** → 读取契约，提取：传感器类型、采样率、数据单位、仿真器字段（必须为 airsim）
  - 若 `sim` 字段不是 `airsim`，**停止执行**并提示：`契约指定仿真器为 <sim>，与本 skill 不符，请确认。`
  - 使用契约参数，跳过第一步的重复询问
- **不存在** → 正常询问参数

---

## 第一步：确认传感器参数

若无契约，询问：
1. 传感器类型（Distance / Lidar / Camera / IMU / 自定义）
2. 采样率（Hz）
3. 数据量程（如距离传感器的 min/max_distance，单位 m）
4. 在 Unreal 场景中的挂载位置（飞机坐标系偏移，x/y/z，单位 m）

---

## 第二步：配置 settings.json

配置文件路径：`~/Documents/AirSim/settings.json`

1. 读取现有 settings.json（若不存在则创建最小化模板）
2. 在对应载具的 `Sensors` 节点下添加传感器配置：

**Distance 传感器示例：**
```json
"<SensorName>": {
    "SensorType": 5,
    "Enabled": true,
    "DrawDebugPoints": false,
    "ReportFrequency": <采样率Hz>,
    "MinDistance": <最小距离m>,
    "MaxDistance": <最大距离m>,
    "X": <x>, "Y": <y>, "Z": <z>,
    "Roll": 0, "Pitch": 0, "Yaw": 0
}
```

**Lidar 传感器示例：**
```json
"<SensorName>": {
    "SensorType": 6,
    "Enabled": true,
    "NumberOfChannels": 16,
    "RotationsPerSecond": <采样率/360>,
    "PointsPerSecond": <点数>,
    "X": <x>, "Y": <y>, "Z": <z>
}
```

3. 展示完整 settings.json 改动，等待用户确认后写入

---

## 第三步：验证数据注入

1. 启动 AirSim + PX4 SITL（`/px4-sim-start` 流程或手动）
2. 验证 AirSim 侧数据：
   ```bash
   # Python AirSim API 验证
   python3 -c "
   import airsim, time
   c = airsim.MultirotorClient()
   c.confirmConnection()
   d = c.getDistanceSensorData('<SensorName>')
   print(f'distance={d.distance}, time={d.time_stamp}')
   "
   ```
3. 验证 PX4 侧 uORB 数据（若已完成驱动开发）：
   ```bash
   listener distance_sensor
   ```
4. 若链路完整，确认 MAVLink Inspector 中数据频率与配置一致

---

## 编码规范（AirSim 侧）

- settings.json 路径禁止硬编码，使用 `~/Documents/AirSim/settings.json`
- 多机场景下传感器配置在各自载具节点下，禁止共享传感器实例
- `LockStep: true` 时仿真时钟与 PX4 同步，禁止用系统时钟做超时判断
- Unreal 插件修改需同步更新 `AirSim/Unreal/Plugins/AirSim/Source/` 对应模块
