# bagel 开发 Skills

## 可用 Skills

| Skill | 用途 |
|-------|------|
| `/log-analyze` | 结合 bagel 数据包分析飞行数据 |
| `/review` | 代码安全审查 |
| `/commit` | 生成规范 git 提交信息 |
| `/handoff` | 生成会话交接文档（HANDOFF.md） |

## bagel 编码规范

适用于所有涉及 bagel 数据包录制与回放工具的开发，关键约束如下：

- 数据包格式扩展需保持向后兼容，新增字段使用可选字段，禁止修改已有字段的偏移量
- 录制插件实现 `RecorderPlugin` 接口，回放插件实现 `PlayerPlugin` 接口
- 高频数据（IMU / 传感器）录制使用零拷贝机制，禁止在录制回调中做内存分配
- 时间戳统一使用单调时钟（`CLOCK_MONOTONIC`），禁止使用系统时钟（`CLOCK_REALTIME`）
- 数据包索引文件与数据文件分离存储，支持随机访问回放
- 新增数据源类型需在 `topic_registry` 中注册，禁止硬编码 topic 类型判断
