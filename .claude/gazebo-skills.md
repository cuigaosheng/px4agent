# Gazebo 仿真开发 Skills

## 可用 Skills

| Skill | 用途 |
|-------|------|
| `/sim-start` | 启动 PX4 SITL 仿真（Gazebo / AirSim） |
| `/hil-setup` | 配置硬件在环（HIL）仿真环境 |
| `/swarm-mission` | 多机协同任务规划（多机 Gazebo SITL） |
| `/sensor-driver` | 创建传感器驱动（含 Gazebo 仿真插件） |
| `/control-law` | 自定义飞行控制律（SITL 验证） |
| `/log-analyze` | 分析 ULog 飞行日志（仿真数据） |
| `/review` | 代码安全审查 |
| `/commit` | 生成规范 git 提交信息 |
| `/handoff` | 生成会话交接文档（HANDOFF.md） |

## Gazebo 编码规范

适用于所有涉及 Gazebo Classic 插件和仿真环境的开发，关键约束如下：

- 插件继承对应基类（`ModelPlugin` / `WorldPlugin` / `SensorPlugin`），禁止直接操作物理引擎内部状态
- 仿真插件中禁止阻塞调用，使用 Gazebo 事件机制（`ConnectWorldUpdateBegin` 等）
- 传感器数据注入通过 MAVLink HIL 消息（`HIL_SENSOR` / `HIL_GPS`），禁止绕过 MAVLink 直接写 uORB
- 世界文件（`.world`）和模型文件（`.sdf`）修改需同步更新 `CMakeLists.txt` 安装规则
- 仿真时钟使用 Gazebo 仿真时间（`world->SimTime()`），禁止使用系统时钟
- 多机仿真实例通过 `-i N` 参数区分，端口按 `14540+N` 规则分配，禁止硬编码端口号
