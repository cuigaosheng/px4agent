# PX4Agent 技能包架构设计（v2.0）

> 日期：2026-05-01
> 目标：从 36 个碎片化技能包 → 8 个核心技能包 + 3 个辅助工具

---

## 一、架构总览

```
px4agent/.claude/skills/
│
├─ 【第一层：环境与基础】
│  ├── setup-all/              ⭐ 一键安装所有开发环境
│  └── setup-wsl2/             WSL2 + Ubuntu 22.04 配置（setup-all 的子步骤）
│
├─ 【第二层：PX4 核心开发】
│  ├── px4-develop/            ⭐ PX4 源码二次开发（统一入口）
│  │   ├─ 添加 uORB 消息
│  │   ├─ 添加 MAVLink 消息
│  │   ├─ 添加传感器驱动
│  │   ├─ 添加业务模块
│  │   ├─ 添加 WorkQueue 任务
│  │   └─ 添加 DroneCAN 节点
│  │
│  ├── px4-param-tune/         飞控参数调优（PID/EKF2/滤波）
│  └── px4-failsafe-config/    故障保护配置（RC丢失/低电量/围栏/RTL）
│
├─ 【第三层：仿真与验证】
│  ├── px4-sim/                ⭐ 仿真环境启动与配置
│  │   ├─ SITL 仿真（Gazebo/AirSim）
│  │   ├─ HIL 硬件在环仿真
│  │   └─ 多机仿真
│  │
│  ├── px4-diagnose/           飞行日志分析与诊断
│  └── px4-control-law/        自定义飞行控制律设计
│
├─ 【第四层：系统集成】
│  ├── px4-ros2-bridge/        ROS2 与 PX4 桥接（uXRCE-DDS）
│  ├── px4-offboard/           Offboard 外部控制（MAVSDK/ROS2）
│  └── px4-swarm-mission/      多机协同任务规划
│
├─ 【第五层：硬件支持】
│  ├── px4-board-bringup/      新飞控硬件板级支持
│  └── px4-mixer-actuator/     执行器与混控配置
│
├─ 【第六层：地面站与可视化】
│  ├── qgc-display/            QGC 自定义消息显示
│  └── gazebo-sensor/          Gazebo 自定义传感器仿真
│
├─ 【第七层：通用工具】
│  ├── commit/                 Git 提交规范化
│  ├── review/                 代码安全审查
│  ├── simplify/               代码质量优化
│  └── handoff/                会话交接文档
│
└─ 【第八层：维护工具】
   └── clean-contract/         清理残留契约文件
```

---

## 二、核心技能包详解

### 2.1 `setup-all` ⭐ 一键安装
**用途**：新手一键安装完整开发环境
**包含**：
- WSL2 + Ubuntu 22.04
- PX4 工具链
- Gazebo Classic 11
- ROS2 Humble
- QGroundControl
- AirSim（可选）

**工作流**：
1. 检测操作系统（Windows/Linux）
2. 询问用户要安装的组件
3. 逐个执行安装脚本
4. 验证环装完成

---

### 2.2 `px4-develop` ⭐ PX4 源码二次开发（统一入口）
**用途**：处理 PX4 源码的所有常见二次开发任务
**替代**：px4-module, px4-mavlink-custom, px4-sensor-driver, px4-workqueue, px4-uavcan-custom

**工作流**：
```
用户输入需求
    ↓
px4-develop 判断任务类型
    ├─ "我要添加 uORB 消息" → 调用 uORB 子流程
    ├─ "我要添加 MAVLink 消息" → 调用 MAVLink 子流程
    ├─ "我要添加传感器驱动" → 调用驱动子流程
    ├─ "我要添加业务模块" → 调用模块子流程
    ├─ "我要添加 WorkQueue 任务" → 调用 WorkQueue 子流程
    └─ "我要添加 DroneCAN 节点" → 调用 DroneCAN 子流程
    ↓
执行对应子流程
    ↓
生成代码 + 编译验证
```

**内部子流程**（在同一个 SKILL.md 中用 Markdown 标题分隔）：
- **uORB 消息定义**：msg/ 目录，CMakeLists.txt 注册
- **MAVLink 消息**：XML 定义 + streams/ 实现 + mavlink_main.cpp 注册
- **传感器驱动**：src/drivers/ + uORB 发布 + MAVLink 流
- **业务模块**：src/modules/ + CMakeLists.txt + 参数定义
- **WorkQueue 任务**：ScheduledWorkItem + 定时调度
- **DroneCAN 节点**：UAVCAN v0 协议 + 节点实现

---

### 2.3 `px4-sim` ⭐ 仿真环境启动与配置
**用途**：启动和配置 PX4 SITL 仿真
**替代**：px4-sim-start, px4-hil-setup（部分）

**工作流**：
```
用户选择仿真类型
    ├─ SITL + Gazebo
    ├─ SITL + AirSim
    ├─ HIL 硬件在环
    └─ 多机 SITL
    ↓
配置仿真参数
    ├─ 飞行器型号（四旋翼/固定翼/VTOL）
    ├─ 传感器配置
    ├─ 初始位置/天气
    └─ 多机实例数量
    ↓
启动仿真环境
    ↓
验证连接（MAVLink/ROS2）
```

---

### 2.4 `px4-param-tune` 飞控参数调优
**用途**：调整 PX4 飞控参数
**包含**：
- PID 参数调优（姿态/位置环）
- EKF2 滤波器配置
- 振动滤波配置
- 传感器校准参数

---

### 2.5 `px4-failsafe-config` 故障保护配置
**用途**：配置 PX4 故障保护逻辑
**包含**：
- RC 信号丢失处理
- 低电量保护
- 地理围栏
- RTL（返航）配置

---

### 2.6 `px4-diagnose` 飞行日志分析
**用途**：分析 ULog 飞行日志，诊断问题
**包含**：
- pyulog 自动分析
- PlotJuggler 可视化
- flight_review 报告生成
- 常见问题诊断

---

### 2.7 `px4-control-law` 自定义飞行控制律
**用途**：设计和实现自定义飞行控制律
**包含**：
- PID 控制律
- MPC（模型预测控制）
- 自适应控制
- SITL 验证

---

### 2.8 `px4-ros2-bridge` ROS2 与 PX4 桥接
**用途**：配置 uXRCE-DDS 桥接
**包含**：
- Micro-XRCE-DDS-Agent 安装
- px4_msgs 配置
- 话题映射
- 多机命名空间

---

### 2.9 `px4-offboard` Offboard 外部控制
**用途**：开发 Offboard 控制程序
**包含**：
- MAVSDK 接口
- ROS2 节点实现
- 位置/速度/姿态控制
- 安全检查

---

### 2.10 `px4-swarm-mission` 多机协同任务
**用途**：规划多机协同任务
**包含**：
- 编队飞行
- 搜索任务
- 协同控制
- 通信协议

---

### 2.11 `px4-board-bringup` 新飞控硬件支持
**用途**：为新飞控硬件添加板级支持
**包含**：
- 引脚定义
- NuttX 配置
- 驱动集成
- 校准流程

---

### 2.12 `px4-mixer-actuator` 执行器与混控
**用途**：配置电机映射和混控
**包含**：
- 电机映射
- ESC 配置
- PWM/DShot 协议
- 混控矩阵

---

### 2.13 `qgc-display` QGC 自定义消息显示
**用途**：在 QGroundControl 中显示自定义 MAVLink 消息
**包含**：
- QML 界面设计
- MAVLink 消息解析
- 实时图表显示

---

### 2.14 `gazebo-sensor` Gazebo 自定义传感器
**用途**：在 Gazebo 中开发自定义传感器仿真
**包含**：
- 传感器插件开发
- SDF 配置
- 单点/360° 扫描雷达
- 数据注入

---

## 三、技能包之间的依赖关系

```
setup-all
    ↓
px4-develop ← 核心开发入口
    ├─ 需要 px4-sim 验证
    ├─ 需要 px4-diagnose 调试
    └─ 需要 px4-param-tune 调优

px4-sim
    ├─ 需要 px4-control-law 测试控制律
    ├─ 需要 px4-ros2-bridge 集成 ROS2
    └─ 需要 px4-offboard 测试外部控制

px4-ros2-bridge
    ├─ 需要 px4-offboard 实现控制
    └─ 需要 px4-swarm-mission 多机协同

px4-board-bringup
    ├─ 需要 px4-develop 添加驱动
    └─ 需要 px4-mixer-actuator 配置执行器

qgc-display
    ├─ 需要 px4-develop 定义 MAVLink 消息
    └─ 需要 px4-sim 测试显示

gazebo-sensor
    ├─ 需要 px4-develop 定义 uORB 消息
    └─ 需要 px4-sim 测试传感器
```

---

## 四、迁移计划

### 第一阶段：合并技能包（本周）
- [ ] 创建 `px4-develop` 统一技能包（合并 5 个碎片化技能包）
- [ ] 创建 `px4-sim` 统一技能包（合并 3 个仿真技能包）
- [ ] 删除旧的碎片化技能包

### 第二阶段：优化现有技能包（下周）
- [ ] 更新 `setup-all` 的交互流程
- [ ] 完善 `px4-diagnose` 的诊断规则
- [ ] 增强 `px4-control-law` 的验证步骤

### 第三阶段：上传到 px4skill.com（下周）
- [ ] 上传 14 个核心技能包
- [ ] 编写每个技能包的使用文档
- [ ] 在网站上配置分类标签

---

## 五、用户使用流程对比

### 旧架构（36 个技能包）
```
用户：我要添加一个传感器驱动
AI：你可以用 /px4-sensor-driver
用户：我还要添加 MAVLink 消息
AI：那用 /px4-mavlink-custom
用户：还要添加 uORB 消息
AI：那用... 等等，这个没有单独的技能包，需要在 /px4-sensor-driver 里做
用户：😕 太复杂了
```

### 新架构（8 个核心技能包）
```
用户：我要在 PX4 中添加一个完整的传感器系统
AI：用 /px4-develop，我会引导你完成：
   1. 定义 uORB 消息
   2. 实现驱动代码
   3. 添加 MAVLink 消息
   4. 配置 QGC 显示
   5. 用 /px4-sim 验证
用户：✅ 清晰明了
```

---

## 六、px4skill.com 网站分类

上传到网站时，使用以下分类标签：

| 分类 | 技能包 |
|------|--------|
| 🚀 快速开始 | setup-all |
| 💻 PX4 开发 | px4-develop, px4-param-tune, px4-failsafe-config |
| 🎮 仿真验证 | px4-sim, px4-diagnose, px4-control-law |
| 🔗 系统集成 | px4-ros2-bridge, px4-offboard, px4-swarm-mission |
| 🛠️ 硬件支持 | px4-board-bringup, px4-mixer-actuator |
| 📊 可视化 | qgc-display, gazebo-sensor |
| 🔧 工具 | commit, review, simplify, handoff, clean-contract |

---

## 七、下一步行动

1. **确认架构**：你觉得这个设计如何？有什么调整吗？
2. **开始合并**：我可以帮你创建 `px4-develop` 和 `px4-sim` 这两个统一技能包
3. **上传网站**：合并完成后，一起上传到 px4skill.com

---

**你的想法？** 这个架构是否符合你的需求？
