# AirSim 开发 Skills

## 可用 Skills

| Skill | 用途 |
|-------|------|
| `/sim-start` | 启动 AirSim + PX4 SITL 仿真 |
| `/hil-setup` | 配置硬件在环（HIL）仿真（AirSim 方案） |
| `/sensor-driver` | 传感器驱动（AirSim 虚拟传感器注入） |
| `/offboard` | Offboard 外部控制（AirSim API） |
| `/review` | 代码安全审查 |
| `/commit` | 生成规范 git 提交信息 |
| `/handoff` | 生成会话交接文档（HANDOFF.md） |

## AirSim 编码规范

适用于所有涉及 AirSim 插件和 API 的开发，关键约束如下：

- AirSim 配置文件路径为 `~/Documents/AirSim/settings.json`，禁止硬编码绝对路径
- PX4 通过 TCP 4560 连接 AirSim，多机实例端口按 `4560+N` 规则分配
- 传感器数据注入通过 MAVLink `HIL_SENSOR` / `HIL_GPS` 消息，禁止绕过 MAVLink 直接操作飞控状态
- AirSim C++ API 调用需处理连接异常，禁止裸调不做错误检查
- `LockStep: true` 模式下仿真时钟与 PX4 同步，禁止在此模式下使用系统时钟做超时判断
- Unreal 插件修改需同步更新 `AirSim/Unreal/Plugins/AirSim/Source/` 对应模块
