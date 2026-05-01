# PX4Agent Skills 上传清单

> 生成时间：2026-05-01
> 总数：36 个技能包

## 上传说明

所有技能包已打包成 `.zip` 格式，位置：
```
C:\Users\cuiga\px4agent\.claude\skills\<skill-name>\<skill-name>.zip
```

## 技能包列表

### 环境安装（7 个）
- [ ] setup-all.zip - PX4 完整开发环境一键安装
- [ ] setup-wsl2.zip - WSL2 + Ubuntu 22.04 配置
- [ ] setup-px4.zip - PX4 工具链安装
- [ ] setup-gazebo.zip - Gazebo Classic 11 安装
- [ ] setup-ros2.zip - ROS2 Humble 安装
- [ ] setup-qgc.zip - QGroundControl 安装
- [ ] setup-airsim.zip - AirSim 配置

### PX4 核心开发（15 个）
- [ ] px4-module.zip - 创建 PX4 业务模块
- [ ] px4-sensor-driver.zip - 添加传感器驱动
- [ ] px4-mavlink-custom.zip - 自定义 MAVLink 消息
- [ ] px4-workqueue.zip - 创建 WorkQueue 任务
- [ ] px4-uavcan-custom.zip - 自定义 DroneCAN 节点
- [ ] px4-param-tune.zip - 飞控参数调优
- [ ] px4-failsafe-config.zip - 故障保护配置
- [ ] px4-control-law.zip - 自定义飞行控制律
- [ ] px4-mixer-actuator.zip - 执行器与混控配置
- [ ] px4-board-bringup.zip - 新飞控硬件支持
- [ ] px4-sim-start.zip - 启动 SITL 仿真
- [ ] px4-hil-setup.zip - 硬件在环仿真配置
- [ ] px4-diagnose.zip - 飞行日志分析诊断
- [ ] px4-e2e-sensor.zip - 传感器端到端开发
- [ ] px4-e2e-control.zip - 控制律端到端开发

### 系统集成（4 个）
- [ ] px4-ros2-bridge.zip - ROS2 与 PX4 桥接
- [ ] px4-offboard.zip - Offboard 外部控制
- [ ] px4-swarm-mission.zip - 多机协同任务
- [ ] px4-e2e-swarm.zip - 多机协同端到端开发

### 仿真与可视化（4 个）
- [ ] gazebo-sensor.zip - Gazebo 自定义传感器
- [ ] airsim-sensor.zip - AirSim 自定义传感器
- [ ] qgc-display.zip - QGC 自定义消息显示
- [ ] px4-e2e-avoidance.zip - 避障全链路开发

### 通用工具（4 个）
- [ ] commit.zip - Git 提交规范化
- [ ] review.zip - 代码安全审查
- [ ] simplify.zip - 代码质量优化
- [ ] handoff.zip - 会话交接文档

### 维护工具（1 个）
- [ ] clean-contract.zip - 清理残留契约文件

---

## 上传方式

### 方式 1：Web UI 手动上传（推荐新手）

1. 访问 `http://139.196.49.7`
2. 登录：admin / ChangeMe!2026
3. 找到"上传技能包"按钮
4. 逐个上传 zip 文件
5. 填写名称、描述、标签

### 方式 2：API 批量上传（需要解决认证问题）

等待 API 认证问题解决后，可以用脚本批量上传。

---

## 网站分类标签建议

上传时使用以下标签便于用户搜索：

| 分类 | 标签 |
|------|------|
| 快速开始 | `setup`, `installation`, `beginner` |
| PX4 开发 | `px4`, `development`, `firmware` |
| 仿真验证 | `simulation`, `sitl`, `gazebo`, `airsim` |
| 系统集成 | `ros2`, `integration`, `offboard` |
| 硬件支持 | `hardware`, `board`, `driver` |
| 可视化 | `visualization`, `qgc`, `plotting` |
| 工具 | `tools`, `utility`, `automation` |

---

## 下一步

1. **上传所有 36 个 zip 文件到 px4skill.com**
2. **配置网站分类和标签**
3. **完成域名解析和 HTTPS 配置**
4. **在 PX4 社区和 Claude Code 社区推广**

---

## 文件位置参考

所有 zip 文件都在：
```
C:\Users\cuiga\px4agent\.claude\skills\
```

可以用以下命令查看：
```bash
find C:/Users/cuiga/px4agent/.claude/skills -name "*.zip" -type f
```
