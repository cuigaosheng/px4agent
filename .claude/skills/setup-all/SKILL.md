---
name: setup-all
version: "1.1.0"
description: PX4 完整开发环境一键安装入口（Windows 11 / Ubuntu 22.04，询问平台后按需安装）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
PX4 完整开发环境一键安装：$ARGUMENTS

新手在全新机器上运行此 skill，AI 询问平台和已有组件状态，跳过已有步骤，完成整套安装。

---

## 第一步：询问用户平台

**直接问用户**，不做自动检测：

> 你的电脑操作系统是哪种？
> 1. Windows 11
> 2. Ubuntu 22.04（原生 Linux，不是 WSL）

等待用户回答，根据回答确定后续路径：
- 用户选 **1（Windows 11）** → 使用 Windows 路径（包含 WSL2 安装步骤）
- 用户选 **2（Ubuntu）** → 使用 Linux 路径（跳过 WSL2）

---

## 第二步：询问已有组件状态

根据平台，逐项询问用户每个组件是否已安装，**不做自动检测**：

### Windows 11 询问清单

> 以下组件你已经安装了哪些？没装过的直接说"都没有"。
> 1. WSL2 + Ubuntu 22.04（在 PowerShell 里能运行 `wsl -l -v` 看到 Ubuntu）
> 2. PX4 源码并编译过（WSL 里有 `~/PX4-Autopilot/build/` 目录）
> 3. Gazebo Classic 11（WSL 里运行 `gazebo --version` 有输出）
> 4. QGroundControl（Windows 桌面上有 QGC 图标）
> 5. AirSim settings.json（`%USERPROFILE%\Documents\AirSim\settings.json` 存在）
> 6. ROS2 Humble（WSL 里运行 `ros2 --version` 有输出）

### Ubuntu Linux 询问清单

> 以下组件你已经安装了哪些？没装过的直接说"都没有"。
> 1. PX4 源码并编译过（`~/PX4-Autopilot/build/` 目录存在）
> 2. Gazebo Classic 11（`gazebo --version` 有输出）
> 3. QGroundControl（桌面有 QGC 或 `~/QGroundControl.AppImage` 存在）
> 4. AirSim settings.json（`~/Documents/AirSim/settings.json` 存在）
> 5. ROS2 Humble（`ros2 --version` 有输出）

等待用户回答后，根据回答标记各组件状态（已安装/未安装）。

---

## 第三步：生成安装计划表并展示给用户

根据检测结果，生成如下格式的计划表：

```
┌──────────────────┬──────────┬──────────────────────────┐
│ 组件             │ 状态     │ 操作                     │
├──────────────────┼──────────┼──────────────────────────┤
│ WSL2 + Ubuntu    │ ❌ 未安装 │ 将执行 /setup-wsl2       │
│ PX4 工具链+编译  │ ❌ 未安装 │ 将执行 /setup-px4        │
│ Gazebo Classic   │ ✅ 已安装 │ 跳过                     │
│ QGroundControl   │ ❌ 未安装 │ 将执行 /setup-qgc        │
│ AirSim 配置      │ ✅ 已配置 │ 跳过                     │
│ ROS2 Humble      │ ❌ 未安装 │ 将执行 /setup-ros2       │
└──────────────────┴──────────┴──────────────────────────┘

预计需要安装：WSL2 + PX4 + QGC + ROS2（Gazebo 和 AirSim 已就绪）
```

**询问用户**：确认后按此计划执行，是否继续？

---

## 第四步：按序执行各子 Skill

### Windows 11 安装顺序

1. **WSL2**（如未安装）→ 读取并按照 `.claude/skills/setup-wsl2/SKILL.md` 执行
2. **PX4**（如未安装）→ 读取并按照 `.claude/skills/setup-px4/SKILL.md` 执行
3. **Gazebo**（如未安装）→ 读取并按照 `.claude/skills/setup-gazebo/SKILL.md` 执行
4. **QGC**（如未安装）→ 读取并按照 `.claude/skills/setup-qgc/SKILL.md` 执行
5. **AirSim**（如未配置）→ 读取并按照 `.claude/skills/setup-airsim/SKILL.md` 执行
6. **ROS2**（如未安装）→ 读取并按照 `.claude/skills/setup-ros2/SKILL.md` 执行

### Ubuntu Linux 安装顺序

1. **PX4**（如未安装）→ 读取并按照 `.claude/skills/setup-px4/SKILL.md` 执行
2. **Gazebo**（如未安装）→ 读取并按照 `.claude/skills/setup-gazebo/SKILL.md` 执行
3. **QGC**（如未安装）→ 读取并按照 `.claude/skills/setup-qgc/SKILL.md` 执行
4. **AirSim**（如未配置）→ 读取并按照 `.claude/skills/setup-airsim/SKILL.md` 执行
5. **ROS2**（如未安装）→ 读取并按照 `.claude/skills/setup-ros2/SKILL.md` 执行

每个子 Skill 执行完后报告 `✅ <组件> 安装完成` 或 `⚠️ <组件> 安装遇到问题，请查看上方错误`。

---

## 第五步：端到端验证

所有组件安装完成后，运行以下验证序列：

### 验证 1：SITL + Gazebo 启动

```bash
# [WSL/Linux] 在一个终端启动 SITL
cd ~/PX4-Autopilot
make px4_sitl gazebo
# 成功标志：Gazebo 窗口出现，PX4 控制台输出 "Ready for takeoff!"
```

### 验证 2：QGC 连接

```
1. 启动 QGroundControl
2. 等待 SITL 运行时 QGC 自动连接 UDP 14550
3. 成功标志：QGC 左上角出现飞机图标，地图上有飞机位置
```

### 验证 3：ROS2 话题（若安装了 ROS2）

```bash
# [WSL/Linux] 终端 1：启动 Micro XRCE-DDS Agent
MicroXRCEAgent udp4 -p 8888

# [WSL/Linux] 终端 2：检查话题
source /opt/ros/humble/setup.bash
source ~/ros2_ws/install/setup.bash
ros2 topic list
# 成功标志：出现 /px4_0/fmu/out/ 开头的话题
```

---

## 常见报错速查

| 现象 | 解决 |
|------|------|
| WSL 安装后重启丢失 | 正常现象，重启后再运行 `wsl --install` 确认 Ubuntu 出现 |
| PX4 编译报 Python 包缺失 | `pip3 install --user -r ~/PX4-Autopilot/Tools/setup/requirements.txt` |
| Gazebo 窗口黑屏 | WSLg 图形未就绪，关掉重开终端再试 |
| QGC 连不上 SITL | WSL IP 变化，见 `/setup-qgc` 防火墙规则章节 |
| ROS2 话题列表为空 | 确认 MicroXRCEAgent 已启动，且 PX4 侧 `uxrce_dds_client start -t udp -p 8888` |
