# PlotJuggler 开发 Skills

## 可用 Skills

| Skill | 用途 |
|-------|------|
| `/log-analyze` | 分析 ULog 飞行日志（PlotJuggler 可视化） |
| `/review` | 代码安全审查 |
| `/commit` | 生成规范 git 提交信息 |
| `/handoff` | 生成会话交接文档（HANDOFF.md） |

## PlotJuggler 编码规范

适用于所有涉及 PlotJuggler 插件开发的场景，关键约束如下：

- 插件继承对应接口类（`DataLoader` / `StatePublisher` / `ToolboxPlugin`），实现纯虚函数
- 数据解析插件禁止在 UI 线程做耗时操作，使用 Qt 异步或后台线程
- 自定义数据格式解析器注册到 `DataLoadPlugin`，通过工厂模式加载
- 插件元数据（名称、版本、描述）在 `pluginName()` / `version()` 中返回，禁止硬编码在其他位置
- ULog 解析依赖 `ulog_cpp` 库，禁止自行实现 ULog 二进制解析
- Qt 信号槽连接使用新式语法（`&Class::signal`），禁止字符串形式 `SIGNAL()` / `SLOT()`
