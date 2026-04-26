# flight_review 开发 Skills

## 可用 Skills

| Skill | 用途 |
|-------|------|
| `/log-analyze` | 分析 ULog 飞行日志（flight_review 报告生成） |
| `/review` | 代码安全审查 |
| `/commit` | 生成规范 git 提交信息 |
| `/handoff` | 生成会话交接文档（HANDOFF.md） |

## flight_review 编码规范

适用于所有涉及 flight_review Web 平台的开发，关键约束如下：

- 后端基于 Tornado，新增路由在 `tornado_handlers.py` 中注册，禁止在 handler 外直接处理请求
- ULog 解析使用 `pyulog` 库，禁止自行实现二进制解析
- 新增分析图表在 `plot_app.py` 中添加对应 Bokeh 图表函数，保持函数单一职责
- 数据库操作通过 `helper.py` 封装的接口，禁止在 handler 中直接写 SQL
- 前端使用 Bokeh 生成交互图表，禁止引入其他前端框架
- 新增分析指标需同步更新 `README.md` 中的指标说明
