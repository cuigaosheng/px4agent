---
name: setup-airsim
version: "1.0.0"
description: 配置 AirSim settings.json（PX4 SITL 模板）并验证 TCP 4560 连通。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
配置 AirSim 与 PX4 SITL 对接：$ARGUMENTS

**前提**：Unreal Engine 和 AirSim 插件已安装（本 Skill 不负责安装 UE/AirSim 本体）。若 Unreal Engine 未安装，提示用户先安装 UE5 + AirSim 插件，然后再回来执行此 Skill。

---

## 第一步：检测 AirSim 配置状态

### Windows 11（AirSim 运行在 Windows 侧）

```powershell
# [PowerShell] 检测 settings.json 是否存在
$settingsPath = "$env:USERPROFILE\Documents\AirSim\settings.json"
if (Test-Path $settingsPath) {
    Write-Host "settings.json 已存在"
    Get-Content $settingsPath
} else {
    Write-Host "settings.json 不存在，将创建"
}

# 检测 TCP 4560 是否被占用
netstat -an | Select-String ":4560"
```

### Ubuntu Linux

```bash
# [WSL/Linux] 检测 settings.json
ls ~/Documents/AirSim/settings.json 2>/dev/null && echo "settings.json 已存在" || echo "不存在"

# 检测 TCP 4560
ss -tlnp | grep 4560 || echo "TCP 4560 未占用"
```

**判断逻辑**：
- `settings.json` 已存在且包含 `PX4Multirotor` 配置 → **询问用户是否覆盖更新**
- `settings.json` 不存在 → 直接创建

---

## 第二步：创建 settings.json（PX4 SITL 标准模板）

### Windows 11

```powershell
# [PowerShell] 创建 AirSim 目录和 settings.json
$airsimDir = "$env:USERPROFILE\Documents\AirSim"
New-Item -ItemType Directory -Force -Path $airsimDir

$settings = @'
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
        "Imu": {
          "SensorType": 2,
          "Enabled": true
        },
        "Magnetometer": {
          "SensorType": 4,
          "Enabled": true
        },
        "Barometer": {
          "SensorType": 1,
          "Enabled": true
        },
        "Gps": {
          "SensorType": 3,
          "Enabled": true
        }
      },
      "Parameters": {
        "NAV_RCL_ACT": 0,
        "NAV_DLL_ACT": 0,
        "COM_RCL_EXCEPT": 4,
        "EKF2_AID_MASK": 1,
        "EKF2_HGT_MODE": 0
      }
    }
  }
}
'@
$settings | Out-File -FilePath "$airsimDir\settings.json" -Encoding utf8
Write-Host "settings.json 已创建：$airsimDir\settings.json"
```

### Ubuntu Linux

```bash
# [WSL/Linux] 创建目录和 settings.json
mkdir -p ~/Documents/AirSim
cat > ~/Documents/AirSim/settings.json << 'EOF'
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
        "Imu": {
          "SensorType": 2,
          "Enabled": true
        },
        "Magnetometer": {
          "SensorType": 4,
          "Enabled": true
        },
        "Barometer": {
          "SensorType": 1,
          "Enabled": true
        },
        "Gps": {
          "SensorType": 3,
          "Enabled": true
        }
      },
      "Parameters": {
        "NAV_RCL_ACT": 0,
        "NAV_DLL_ACT": 0,
        "COM_RCL_EXCEPT": 4,
        "EKF2_AID_MASK": 1,
        "EKF2_HGT_MODE": 0
      }
    }
  }
}
EOF
```

**关键参数说明**：
- `LockStep: true`：仿真时钟与 PX4 同步（推荐，避免仿真/飞控时钟偏差）
- `UseTcp: true`：使用 TCP 4560 连接（取代旧版 UDP）
- `TcpPort: 4560`：PX4 默认 AirSim TCP 端口
- `NAV_RCL_ACT: 0`、`NAV_DLL_ACT: 0`：禁用 RC 丢失和数据链丢失故障保护（仿真专用）

---

## 第三步：验证 TCP 4560 连通

**验证步骤**：

1. 在 Windows 侧启动 AirSim（双击 UE 项目或 `.exe`），等待场景加载出现飞机。

2. 在 Linux/WSL 侧启动 PX4 SITL：

```bash
# [WSL/Linux] 启动 AirSim 模式的 SITL
cd ~/PX4-Autopilot
make px4_sitl none_iris
```

3. 观察 PX4 控制台输出。

**成功标志**：
- PX4 控制台出现：`INFO [simulator] Simulator connected on TCP port 4560`
- AirSim 飞机开始响应飞控指令（桨叶旋转）
- PX4 控制台出现：`INFO [commander] Ready for takeoff!`

---

## 第四步：多机配置（可选）

若需要多架飞机，在 `Vehicles` 中添加多个条目：

```json
{
  "SettingsVersion": 1.2,
  "SimMode": "Multirotor",
  "Vehicles": {
    "PX4_0": {
      "VehicleType": "PX4Multirotor",
      "UseTcp": true,
      "TcpPort": 4560,
      "X": 0, "Y": 0, "Z": 0
    },
    "PX4_1": {
      "VehicleType": "PX4Multirotor",
      "UseTcp": true,
      "TcpPort": 4561,
      "X": 5, "Y": 0, "Z": 0
    }
  }
}
```

对应 PX4 启动端口按 `4560+N` 规则分配（见 `/px4-sim-start` 多机章节）。

---

## 常见报错

| 现象 | 原因 | 解决 |
|------|------|------|
| `Simulator connected` 未出现 | TCP 4560 未连通 | 确认 AirSim 先于 PX4 SITL 启动 |
| AirSim 加载后飞机坠地 | EKF 未收敛 | 等待约 5 秒，LockStep 模式会自动同步 |
| `settings.json` 加载失败 | JSON 格式错误 | 用 JSON 校验器检查语法 |
| TCP 4560 被占用 | 有残留 SITL 进程 | `pkill -f px4` 终止残留进程 |
| AirSim 显示 No HeartBeat | PX4 未启动 | 先启动 PX4 SITL，再等待连接 |
