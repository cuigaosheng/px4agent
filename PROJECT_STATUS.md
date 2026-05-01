# px4agent 项目状态文档

> 最后更新：2026-05-01（新增 9 个代码生成器 + 时间戳同步 Skill）
> 用途：新会话启动时读取此文件，了解架构全貌和当前状态，直接继续工作。

---

## 一、项目架构（4层）

```
Layer 3  场景技能（4个，永久固定）
         px4-e2e-sensor / px4-e2e-avoidance / px4-e2e-control / px4-e2e-swarm

Layer 2  组件技能（25个）
         PX4固件12个 + 仿真集成7个 + 地面站1个 + 运维诊断1个

Layer 1  基础设施（5个）
         commit / review / handoff / simplify / clean-contract

Layer 0  行为准则 + 领域知识（常驻）
         CLAUDE.md + .claude/context/*.md（8个领域文件）
```

**接口契约机制**：Layer 3 场景在 Step 0 生成 `.claude/contracts/<task>.contract.md`，锁定所有跨组件接口参数。Layer 2 skill 启动时先读契约，有则跳过重复询问。`/clean-contract` 可手动清理残留契约。

---

## 二、完整 Skill 清单（当前版本）

### Layer 3 场景技能

| Skill | 版本 | 触发命令 | 关键参数 |
|-------|------|---------|---------|
| px4-e2e-sensor | 1.0.0 | `/px4-e2e-sensor <传感器> <总线>` | 传感器名、总线类型、仿真器（单选）|
| px4-e2e-avoidance | **1.1.0** | `/px4-e2e-avoidance <传感器> <总线> <扫描类型> <仿真器> <算法>` | sensor_type（单点/360°）、algorithm_type（internal/ros2/mavsdk）|
| px4-e2e-control | 1.0.0 | `/px4-e2e-control <控制律类型>` | 控制层级、仿真器、ros2_enabled |
| px4-e2e-swarm | 1.0.0 | `/px4-e2e-swarm <机型> <任务>` | 机体数量、任务类型、通信方式 |

### Layer 2 组件技能

#### PX4 固件组

| Skill | 版本 | 说明 |
|-------|------|------|
| px4-sensor-driver | **1.1.0** | 驱动已存在→核实流程；不存在→新建流程 |
| px4-magnetometer | **1.0.0** | 磁力计驱动 + 校准 + Yaw 漂移诊断修复 |
| px4-barometer | **1.0.0** | 气压计驱动 + 校准 + 高度估计偏差诊断修复 |
| px4-imu-gen | **1.0.0** | IMU 代码生成器（9 款芯片库，一键生成驱动） |
| px4-mag-gen | **1.0.0** | 磁力计代码生成器（8 款芯片库，一键生成驱动） |
| px4-rangefinder-gen | **1.0.0** | 测距仪代码生成器（8 款芯片库，一键生成驱动） |
| px4-gnss-gen | **1.0.0** | GNSS 代码生成器（10 款芯片库，支持 RTK，一键生成驱动） |
| px4-mmwave-radar-gen | **1.0.0** | 毫米波雷达代码生成器（12 款芯片库，支持多总线，一键生成驱动） |
| px4-sensor-codegen | **1.0.0** | 通用传感器代码生成器（支持自定义传感器类型） |
| px4-timestamp-sync | **1.0.0** | 精准时间戳处理与同步（多传感器对齐、精度验证、校准） |
| px4-workqueue | 1.0.0 | ScheduledWorkItem 完整驱动框架 |
| px4-module | 1.0.0 | PX4 业务模块（WorkQueue+uORB+参数）|
| px4-mavlink-custom | 1.0.0 | 自定义 MAVLink 消息 |
| px4-uavcan-custom | 1.0.0 | 自定义 DroneCAN (UAVCAN v0) 节点 |
| px4-control-law | 1.0.0 | 自定义飞行控制律 |
| px4-param-tune | 1.0.0 | PID / EKF2 / 振动滤波调参 |
| px4-mixer-actuator | 1.0.0 | 电机映射 / PWM / DShot |
| px4-failsafe-config | 1.0.0 | 故障保护逻辑 |
| px4-board-bringup | 1.0.0 | 新飞控硬件板级支持 |
| px4-log-analyze | 1.0.0 | ULog 日志分析 |
| px4-diagnose | 1.0.0 | 日志自动诊断 + PID 调参建议 |

#### 仿真与集成组

| Skill | 版本 | 说明 |
|-------|------|------|
| px4-sim-start | 1.0.0 | SITL + Gazebo/AirSim 启动 |
| px4-hil-setup | 1.0.0 | HIL 配置 |
| px4-offboard | 1.0.0 | MAVSDK/ROS2 外部控制 |
| px4-ros2-bridge | 1.0.0 | uXRCE-DDS 桥接 |
| px4-swarm-mission | 1.0.0 | 多机协同任务规划 |
| airsim-sensor | 1.0.0 | AirSim 传感器仿真配置 |
| gazebo-sensor | **1.1.0** | Gazebo 传感器插件（含360°gpu_ray模板）|

#### 地面站 + 运维

| Skill | 版本 | 说明 |
|-------|------|------|
| qgc-display | 1.0.0 | QGC 自定义数据图表 |
| px4-diagnose | 1.0.0 | 日志诊断+调参（pyulog自动，GUI人工）|

### Layer 1 基础设施

| Skill | 版本 | 说明 |
|-------|------|------|
| review | 1.0.0 | 代码安全审查 |
| commit | 1.0.0 | 生成规范 git 提交信息 |
| handoff | 1.0.0 | 生成会话交接文档 |
| simplify | 1.0.0 | 代码冗余审查 |
| clean-contract | 1.0.0 | 清理残留契约文件 |

### Layer 0.5 环境安装技能（新增）

| Skill | 版本 | 说明 |
|-------|------|------|
| setup-all | **1.1.0** | 一键安装入口，询问平台+组件状态后编排子 Skill |
| setup-wsl2 | 1.0.0 | WSL2 + Ubuntu 22.04（Windows 11 专用）|
| setup-px4 | 1.0.0 | PX4 工具链 + SITL 编译（WSL/Linux 通用）|
| setup-gazebo | 1.0.0 | Gazebo Classic 11 + WSLg 图形验证 |
| setup-qgc | 1.0.0 | QGC 安装 + WSL2 NAT 网络配置 |
| setup-airsim | 1.0.0 | AirSim settings.json + TCP 4560 验证 |
| setup-ros2 | 1.0.0 | ROS2 Humble + px4_msgs + uXRCE-DDS Agent |

---

## 三、本次会话完成的工作

### 架构审查发现并修复的问题

| 问题 | 修复方式 | 文件 |
|------|---------|------|
| Layer 3 调用 Layer 2 机制不清晰 | 每个 L3 step 明确写 `读取 .claude/skills/<l2>/SKILL.md` | 所有 L3 SKILL.md |
| context 文件手动注释切换 | 迁移到 `.claude/context/`，CLAUDE.md 全量 @import | CLAUDE.md |
| 旧 `.claude/commands/` 机制 | 迁移为 `.claude/skills/<name>/SKILL.md` 独立目录 | 全部 skills |
| SKILL.md 缺少版本号 | 所有现有文件加 `version: "1.0.0"` | 19个文件 |
| `clean-contract` 无执行路径 | 新建 Layer 1 skill | clean-contract/SKILL.md |

### 新增 Skill

- Layer 1：`simplify`、`clean-contract`
- Layer 2：`airsim-sensor`、`gazebo-sensor`、`qgc-display`、`px4-diagnose`
- Layer 3：`px4-e2e-sensor`、`px4-e2e-avoidance`、`px4-e2e-control`、`px4-e2e-swarm`

### SF45 审查发现并修复的问题

| 问题 | 修复方式 |
|------|---------|
| SF45 只发布 `obstacle_distance`，ros2/mavsdk 路径订阅 `distance_sensor` 会静默失败 | `px4-e2e-avoidance` 加 sensor_type 字段，360° 强制 internal，ros2/mavsdk 加禁用拦截 |
| `px4-sensor-driver` 只有新建流程，SF45 驱动已存在 | 加 Step 0 判断，驱动已存在走核实流程 |
| "避障后 hold" 未覆盖 | 内嵌到 `px4-e2e-avoidance` Step 3 internal 路径，含状态机接口说明 |
| Gazebo 360° 扫描配置缺失 | `gazebo-sensor` 加 gpu_ray 360° SDF 模板及 OBSTACLE_DISTANCE 数据填充说明 |

---

## 四、四个已验证需求的触发命令

### 需求一：毫米波雷达避障（单点，ROS2）

```
/px4-e2e-avoidance 毫米波雷达 DroneCAN 单点测距 AirSim ROS2方案
```

关键路径：`px4-uavcan-custom` → `airsim-sensor` → `px4-ros2-bridge` + `px4-offboard` → `qgc-display` → `px4-failsafe-config` → `px4-hil-setup` + `px4-log-analyze`

### 需求二：CUAV RFID 驱动开发（DroneCAN，无仿真）

```
/px4-e2e-sensor CUAV_RFID DroneCAN
```

关键路径：`px4-uavcan-custom` → 跳过仿真 → `px4-mavlink-custom` → `qgc-display`

### 需求三：外场抖动诊断 + PID 调参

```
/px4-diagnose ~/logs/<flight_log>.ulg
```

流程：bagel 定时间锚点（人工）→ pyulog 自动分析 → flight_review 确认图表（人工）→ 输出参数建议表

### 需求四：SF45 360° 激光雷达避障 + 避障后 Hold

```
/px4-e2e-avoidance SF45 UART 360°扫描 Gazebo internal
```

关键路径：`px4-sensor-driver`（核实流程）→ `gazebo-sensor`（gpu_ray 360°）→ `px4-module`（CP + hold 状态机）→ `qgc-display` → `px4-failsafe-config` → `px4-hil-setup` + `px4-log-analyze`

**SF45 专属约束**：
- 驱动已存在于 `src/drivers/distance_sensor/lightware_sf45_serial/`，只发布 `obstacle_distance`
- CP 模块在 `src/lib/collision_prevention/`，已存在
- MAVLink 流 `OBSTACLE_DISTANCE.hpp` 已存在
- 算法只能用 `internal`，ros2/mavsdk 无数据源

---

## 五、架构设计决策记录

| 决策 | 内容 | 原因 |
|------|------|------|
| Layer 3 固定 4 个场景 | sensor / avoidance / control / swarm，新需求走参数 | 防止场景膨胀，维护成本失控 |
| Layer 3 不直接生成代码 | 只做契约+编排+完成度校验，代码全在 Layer 2 | 层间职责清晰，Layer 2 可独立复用 |
| 单契约限制 | 同时只允许一个 `*.contract.md` | 简化状态管理，多契约靠 `/clean-contract` 清理 |
| 360° 传感器强制 internal | SF45 不发布 `distance_sensor`，ros2/mavsdk 路径无数据源 | 源码确认，硬性约束写入 skill |
| 不新增 Layer 4 | 当前需求均为独立单链，无跨链接口耦合场景 | 过度设计，等真实需求出现再评估 |
| "避障后 hold" 内嵌 e2e-avoidance | 不建独立 skill，直接在 Step 3 描述状态机接口 | 用户需要端到端场景，不需要细粒度 Layer 2 拆分 |
| px4-diagnose 合并日志+调参 | 替代手动 `/px4-log-analyze` → `/handoff` → `/px4-param-tune` 三步 | 运维链路的诊断结论传递自动化 |

---

## 六、已知待处理项

| 优先级 | 项目 | 说明 |
|--------|------|------|
| P3 | Context 按需加载 | 当前全量加载 8 个 context 文件，影响 token 消耗 |
| P3 | 版本号无强制执行机制 | SKILL.md 版本是文本，改动时需人工记得升版本 |
| P3 | 运维链路结构化传递 | `/px4-diagnose` 靠人工描述图表，待观察是否需要"诊断契约" |
| P3 | 自动完成度校验 | 契约完成标记靠 AI 更新，无技术强制 |
| 待观察 | qgc-display 72元素数组 | `obstacle_distance.distances[72]` 的 QML 极坐标显示模板尚未完善 |

---

## 七、源码关键路径（droneyee_px4v1.15.0）

| 组件 | 路径 | 状态 |
|------|------|------|
| SF45 驱动 | `src/drivers/distance_sensor/lightware_sf45_serial/` | ✅ 存在 |
| CP 模块 | `src/lib/collision_prevention/` | ✅ 存在 |
| ObstacleDistance msg | `msg/ObstacleDistance.msg` | ✅ 存在（72元素，5°/格）|
| OBSTACLE_DISTANCE 流 | `src/modules/mavlink/streams/OBSTACLE_DISTANCE.hpp` | ✅ 存在 |
| DistanceSensor msg | `msg/DistanceSensor.msg` | ✅ 存在（单点）|

---

## 八、新会话启动检查清单

```
1. 读取本文件（PROJECT_STATUS.md）了解当前状态
2. 确认 git 状态：cd px4agent && git log --oneline -5
3. 确认 contracts/ 无残留：ls .claude/contracts/
4. 按需触发对应场景 skill，参考第四节的触发命令
5. 开发完成后：/review → /commit → 确认 contracts/ 已清空
```

### 2026-04-27 工作摘要（setup-all 平台询问改造）
- setup-all v1.0.0 → v1.1.0：删除 `uname -s` 自动检测，改为直接询问用户平台（Windows 11 / Ubuntu）
- setup-all 第二步同步改为询问用户各组件安装状态，不再执行自动检测命令
- README 交互示例同步更新，体现"询问平台 → 询问组件 → 生成计划表"流程
- 原因：自动检测在 Windows PowerShell 环境下不可靠，且安装类操作必须用户知情确认

### 2026-04-27 工作摘要（安装 Skill 包）
- 新建 7 个环境安装 Skill（Layer 0.5）：setup-all / setup-wsl2 / setup-px4 / setup-gazebo / setup-qgc / setup-airsim / setup-ros2
- 每个 Skill 均实现：智能检测已有组件 → 跳过已有步骤 → 执行安装 → 验证
- setup-all 支持 Windows 11 和 Ubuntu 双平台，自动生成安装计划表，顺序编排子 Skill
- setup-wsl2 含 .wslconfig 内存配置（PX4 编译需要 ≥8GB）
- setup-qgc 含 WSL2 NAT 网络配置（端口转发方案 + Mirrored 网络模式两种方案）
- setup-ros2 含 px4_msgs v1.15 版本对应、Micro-XRCE-DDS-Agent 编译安装
- README 新增"新手安装"章节及组件单独触发命令表
- PROJECT_STATUS 新增 Layer 0.5 技能清单

### 2026-05-01 工作摘要（新增毫米波雷达驱动代码生成器）
- 新建 `px4-mmwave-radar-gen` v1.0.0（Layer 2 代码生成器）
  - 内置 12 款毫米波雷达芯片库（TI IWR1443/1642/1843、AWR1443/1642/1843、Bosch ARS430/441/MRR4、Delphi ESR、Continental ARS/MRR）
  - 支持 CAN/Ethernet/UART/SPI 多总线
  - 支持目标检测、点云数据、避障、自适应巡航、碰撞预警等功能
  - 一键生成：驱动头文件 + 实现文件 + uORB 消息 + MAVLink 流 + CMakeLists.txt + Kconfig + 单元测试
  - 包含 7 个详细使用示例（IWR1843、ARS441、AWR1843、MRR4、ARS、自定义、参数库扩充）
  - 参数库可扩充（JSON 格式）

### 2026-05-01 工作摘要（新增 GNSS 接收机驱动代码生成器）
- 新建 `px4-gnss-gen` v1.0.0（Layer 2 代码生成器）
  - 内置 10 款 GNSS 芯片库（u-blox NEO-M8N/M9N/ZED-F9P/F9R、Septentrio mosaic-X5、Novatel PwrPak7、Emlid Reach M+、Swift Duro、Garmin GNSS 18x、SiRF Atlas）
  - 支持 UART/I2C/SPI/Ethernet/CAN 多总线
  - 支持 RTK 高精度定位（ZED-F9P、mosaic-X5 等）
  - 支持多频 GNSS（GPS/GLONASS/Galileo/BeiDou）
  - 一键生成：驱动头文件 + 实现文件 + uORB 消息 + MAVLink 流 + CMakeLists.txt + Kconfig + 单元测试
  - 包含 6 个详细使用示例（NEO-M8N、ZED-F9P、mosaic-X5、Reach M+、Garmin、自定义）
  - 参数库可扩充（JSON 格式）

### 2026-05-01 工作摘要（新增 4 个参数化代码生成器 Skills）
- 新建 `px4-imu-gen` v1.0.0（Layer 2 代码生成器）
  - 内置 9 款 IMU 芯片库（MPU6050/6000/9250、ICM20689/42688、BMI088/160、LSM6DSL/DSO）
  - 支持 I2C/SPI 总线自动配置
  - 一键生成：驱动头文件 + 实现文件 + uORB 消息 + MAVLink 流 + CMakeLists.txt + Kconfig + 单元测试
  - 参数库可扩充（JSON 格式）

- 新建 `px4-mag-gen` v1.0.0（Layer 2 代码生成器）
  - 内置 8 款磁力计芯片库（HMC5883L、IST8310、QMC5883L、LIS3MDL、BMM150、AK8963/09916、RM3100）
  - 支持 I2C/SPI 总线自动配置
  - 一键生成完整驱动代码框架
  - 参数库可扩充

- 新建 `px4-rangefinder-gen` v1.0.0（Layer 2 代码生成器）
  - 内置 8 款测距仪芯片库（VL53L0X/L1X、SF45、TF-Luna/Mini、HC-SR04、MB1242、PX4FLOW）
  - 支持 I2C/SPI/UART/GPIO/Analog 多总线
  - 支持单点和 360° 扫描类型
  - 一键生成完整驱动代码框架
  - 参数库可扩充

- 新建 `px4-sensor-codegen` v1.0.0（Layer 2 通用代码生成器）
  - 支持 9 种标准传感器类型（IMU、磁力计、气压计、测距仪、光流、空速计、GPS、360° 测距、自定义）
  - 用户可定义自定义传感器类型和数据字段
  - 自动生成完整驱动框架（驱动 + uORB + MAVLink + 单元测试）
  - 参数库可扩充

### 2026-05-01 工作摘要（新增磁力计 + 气压计专用 Skills）
- 新建 `px4-magnetometer` v1.0.0（Layer 2 组件技能）
  - 磁力计驱动完整模板（I2C/SPI，ScheduledWorkItem 模式）
  - 校准参数配置（CAL_MAG0_* 参数定义）
  - Yaw 漂移诊断与修复方案（EKF2 融合权重调整、软铁补偿）
  - SITL 验证命令和实机验证流程
  - 单元测试框架（Google Test）
  - 编码规范核验清单

- 新建 `px4-barometer` v1.0.0（Layer 2 组件技能）
  - 气压计驱动完整模板（I2C/SPI，ScheduledWorkItem 模式）
  - 校准参数配置（SENS_BARO_* 参数定义）
  - 高度估计异常诊断与修复方案（EKF2 融合权重调整）
  - SITL 验证命令和实机验证流程
  - 单元测试框架（Google Test）
  - 编码规范核验清单

### 2026-05-01 工作摘要（新增磁力计专用 Skill）
- 新建 `px4-magnetometer` v1.0.0（Layer 2 组件技能）
- 包含磁力计驱动完整模板（I2C/SPI，ScheduledWorkItem 模式）
- 集成校准参数配置（CAL_MAG0_* 参数定义）
- 包含 Yaw 漂移诊断与修复方案（EKF2 融合权重调整、软铁补偿）
- 提供 SITL 验证命令和实机验证流程
- 包含单元测试框架（Google Test）
- 编码规范核验清单（禁止浮点、禁止动态内存、WorkQueue 模式等）

### 2026-04-27 工作摘要（本次会话）
- 完成 px4agent skill 包从零到可用的全量建设（架构审查 → P0/P1/P2 任务 → SF45 专项修复）
- 新建 10 个 skill（L1×2、L2×5、L3×4），修改 4 个现有 skill 至 v1.1.0
- 建立 PROJECT_STATUS.md 持久化机制 + CLAUDE.md 新会话自动询问规则
- README 补充毫米波/SF45 双场景样例及会话状态持久化章节
- 所有改动已 push 至远端（最新提交 57de8b7）

---

## 九、git 提交记录（最近）

| 提交 | 内容 |
|------|------|
| 57de8b7 | README 补充会话状态持久化机制说明 |
| 6e195d7 | 新会话自动询问 + PROJECT_STATUS.md 持续追加机制 |
| 7a20496 | 更新 README 样例并创建持久化项目状态文档 |
| 64c6a2d | 完善技能包以支持 SF45 360° 避障场景 |
| 8ec05ae | 重构技能架构为4层，新增场景技能与运维诊断技能 |

---

## 十、本文件维护说明（供 AI 参考）

**更新触发条件**：新建/修改 Skill、做出架构决策、完成具体需求开发、触发 `/handoff`。

**更新规则**：
- 修改顶部 `最后更新` 日期
- 第二节：更新有变动的 skill 版本号
- 第三节：追加工作摘要（格式见下）
- 第六节：更新待处理项
- 第九节：顶部插入最新 git 提交
- **禁止覆盖或删除已有内容，只追加**

**追加格式**：
```markdown
### YYYY-MM-DD 工作摘要
- 改动1
- 改动2
```
