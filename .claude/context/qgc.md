# QGroundControl 开发 Skills

## 可用 Skills

| Skill | 用途 |
|-------|------|
| `/mavlink-custom` | 定义自定义 MAVLink 消息（含 QGC 解析端） |
| `/review` | 代码安全审查 |
| `/commit` | 生成规范 git 提交信息 |
| `/handoff` | 生成会话交接文档（HANDOFF.md） |
| `/log-analyze` | 分析 ULog 飞行日志（flight_review / PlotJuggler） |
| `/param-tune` | 飞控参数调优（QGC 参数面板配置） |
| `/offboard` | Offboard 外部控制（MAVSDK 接口） |

## QGC 编码规范

适用于所有涉及 QGroundControl 源码的开发，以 QGC 官方贡献指南为准，关键约束如下：

- UI 组件使用 QML，业务逻辑使用 C++/Qt，禁止在 QML 中写复杂逻辑
- 新增 MAVLink 消息处理在 `src/Vehicle/` 对应类中添加，发出 Qt 信号供 QML 订阅
- 禁止在主线程做耗时操作，网络/串口通信统一走 Qt 异步机制
- MAVLink 头文件版本必须与 PX4 侧保持一致
- 参数读写通过 `ParameterManager` 接口，禁止直接操作 MAVLink PARAM 消息
- 日志用 `qCDebug` / `qCWarning` / `qCCritical`，禁止 `printf` / `std::cout`
