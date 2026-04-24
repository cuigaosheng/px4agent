# ROS2 开发 Skills

## 可用 Skills

| Skill | 用途 |
|-------|------|
| `/ros2-bridge` | 配置 ROS2 与 PX4 桥接（uXRCE-DDS） |
| `/offboard` | Offboard 外部控制（ROS2 节点实现） |
| `/swarm-mission` | 多机协同任务规划（ROS2 多命名空间方案） |
| `/mavlink-custom` | 自定义 MAVLink 消息（含 ROS2 话题映射） |
| `/sensor-driver` | 传感器驱动（含 ROS2 话题发布） |
| `/review` | 代码安全审查 |
| `/commit` | 生成规范 git 提交信息 |
| `/handoff` | 生成会话交接文档（HANDOFF.md） |

## ROS2 编码规范

适用于所有涉及 ROS2 Humble 的开发，以 ROS2 官方风格指南为准，关键约束如下：

- 节点继承 `rclcpp::Node`，禁止在构造函数中做耗时初始化
- 订阅 PX4 uXRCE-DDS 话题必须使用 `best_effort()` QoS，与 PX4 侧匹配
- 定时控制循环用 `create_wall_timer()`，禁止 `while + sleep` 阻塞循环
- 话题命名遵循 `/px4_N/fmu/in|out/<topic>` 命名空间规则，禁止硬编码话题名
- 多机场景每个实例使用独立命名空间（`/px4_0`、`/px4_1`），禁止共用话题
- 日志用 `RCLCPP_INFO` / `RCLCPP_WARN` / `RCLCPP_ERROR`，禁止 `printf` / `std::cout`
- `px4_msgs` 版本必须与 PX4 固件版本对应，切换固件版本时同步切换 tag
