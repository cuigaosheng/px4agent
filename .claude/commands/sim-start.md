启动 PX4 SITL 仿真环境（Gazebo / AirSim）：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 源码：`C:/Users/cuiga/droneyee_px4v1.15.0`（WSL 内路径：`~/droneyee_px4v1.15.0`）
- WSL 发行版：Ubuntu 20.04（或系统默认 WSL）
- Gazebo 子模块：`gazebo-classic/`（px4agent 工作空间内）
- AirSim 子模块：`AirSim/`（px4agent 工作空间内）
- QGroundControl 子模块：`qgroundcontrol/`

---

## 第一步：确认仿真需求

询问用户：
1. **仿真引擎**：Gazebo（推荐，开箱即用）还是 AirSim（高保真视觉）
2. **机型**：iris（默认四旋翼）/ tailsitter / plane / rover / custom
3. **是否需要重新编译固件**：首次或修改了源码需要编译；否则用已有构建

---

## 第二步：编译 PX4 SITL（首次或代码有改动时）

在 WSL 内执行：

### Gazebo 编译目标
```bash
# 进入 PX4 源码目录
cd ~/droneyee_px4v1.15.0

# 编译 SITL（含 Gazebo 插件），机型可替换为 iris / plane 等
make px4_sitl_default gazebo
```

### AirSim 编译目标（无需 Gazebo 插件）
```bash
cd ~/droneyee_px4v1.15.0
make px4_sitl_default none_iris
```

编译成功标志：`[100%] Linking CXX executable px4`，无 error。

---

## 第三步：启动仿真

### 方案 A：Gazebo + PX4 SITL（一键启动）

```bash
# 在 WSL 内，PX4 源码根目录执行
cd ~/droneyee_px4v1.15.0
make px4_sitl gazebo          # 默认 iris
# 或指定机型
make px4_sitl gazebo_iris
make px4_sitl gazebo_plane
make px4_sitl gazebo_tailsitter
```

启动成功标志：
- Gazebo 窗口打开，飞机模型出现
- PX4 控制台输出 `INFO [commander] Ready for takeoff!`

### 方案 B：AirSim + PX4 SITL（分步启动）

**步骤 B1：配置 AirSim settings.json**（Windows 端）

在 `%USERPROFILE%\Documents\AirSim\settings.json` 写入：
```json
{
  "SettingsVersion": 1.2,
  "SimMode": "Multirotor",
  "Vehicles": {
    "PX4": {
      "VehicleType": "PX4Multirotor",
      "UseSerial": false,
      "LockStep": true,
      "UseTcp": true,
      "TcpPort": 4560,
      "ControlPortLocal": 14540,
      "ControlPortRemote": 14580,
      "LocalHostIp": "127.0.0.1",
      "Sensors": {
        "Imu": { "SensorType": 2, "Enabled": true }
      },
      "Parameters": {
        "NAV_RCL_ACT": 0,
        "NAV_DLL_ACT": 0
      }
    }
  }
}
```

**步骤 B2：启动 AirSim（Windows 端，手动双击）**
- 打开 AirSim 的 Unreal 项目或预编译 `.exe`
- 等待场景加载完成，出现飞机模型

**步骤 B3：启动 PX4 SITL（WSL 端）**
```bash
cd ~/droneyee_px4v1.15.0
make px4_sitl none_iris
```

PX4 会通过 TCP 4560 自动连接 AirSim。

成功标志：PX4 控制台输出 `INFO [simulator] Simulator connected`

---

## 第四步：启动 QGroundControl

### 使用子模块内的 QGC（需编译）
```bash
# WSL 内或 Linux 上
cd ~/px4agent/qgroundcontrol
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
./QGroundControl
```

### 使用系统已安装的 QGC（推荐）
```bash
# Ubuntu
QGroundControl.AppImage
# Windows：直接运行 QGroundControl.exe
```

QGC 默认监听 UDP 14550，PX4 SITL 启动后自动连接。

连接成功标志：QGC 左上角显示飞机图标，参数面板可加载。

---

## 第五步：验证仿真链路

在 PX4 SITL 控制台依次执行：

```bash
# 1. 确认飞控状态
commander status

# 2. 确认传感器数据正常（Gazebo/AirSim 提供的虚拟传感器）
listener sensor_combined

# 3. 确认 MAVLink 连接（QGC 已连才有输出）
mavlink status streams

# 4. 起飞测试（在 QGC 中也可操作）
commander arm
commander takeoff
```

---

## 多机仿真（Gazebo）

```bash
# 终端 1：实例 0
cd ~/droneyee_px4v1.15.0
PX4_SIM_MODEL=iris ./build/px4_sitl_default/bin/px4 \
  -s ROMFS/px4fmu_common/init.d-posix/rcS -i 0 -w /tmp/px4_0

# 终端 2：实例 1
PX4_SIM_MODEL=iris ./build/px4_sitl_default/bin/px4 \
  -s ROMFS/px4fmu_common/init.d-posix/rcS -i 1 -w /tmp/px4_1

# Gazebo 多机启动
Tools/gazebo_sitl_multiple_run.sh -n 2 -m iris
```

---

## 常见问题排查

| 现象 | 原因 | 解决 |
|------|------|------|
| Gazebo 打开后飞机掉地 | EKF 未收敛 | 等待约 5 秒让传感器稳定 |
| `make: gazebo: No such target` | 未安装 Gazebo | `sudo apt install gazebo11 libgazebo11-dev` |
| AirSim 连接超时 | settings.json 路径错误或防火墙 | 确认文件在 `Documents\AirSim\` 且 TCP 4560 未被占用 |
| QGC 无法连接 | UDP 14550 防火墙或 WSL 网络 | WSL 内 `ip route` 查看宿主机 IP，在 QGC 中手动添加连接 |
| PX4 编译报依赖缺失 | 环境未初始化 | `bash ./Tools/setup/ubuntu.sh` 重新安装依赖 |
| `ROMFS not found` | 工作目录错误 | 在 PX4 源码根目录执行 make，或用 `-w` 指定工作目录 |

---

## MAVLink 端口规则

| 实例 | GCS（QGC）UDP | 板外控制 UDP | AirSim TCP |
|------|--------------|-------------|------------|
| 0 | 14550 | 14540 | 4560 |
| 1 | 14551 | 14541 | 4561 |
| N | 14550+N | 14540+N | 4560+N |
