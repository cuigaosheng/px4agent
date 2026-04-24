分析 PX4 ULog 飞行日志：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 项目：`~/px4agent`
- 日志目录：`build/px4_sitl_default/rootfs/log/` 或 SD 卡 `/fs/microsd/log/`
- flight_review：`~/px4agent/flight_review/`
- PlotJuggler：`~/px4agent/PlotJuggler/`

---

## 第一步：确认日志来源

询问用户：
1. 日志文件路径（`.ulg` 文件）或日志目录
2. 分析目标：
   - **飞行性能**（姿态跟踪、位置控制、振动）
   - **故障排查**（坠机、解锁失败、传感器异常）
   - **参数调优**（PID 响应、EKF 状态）
   - **自定义 topic 验证**（新开发模块的 uORB 数据）
3. 是否需要生成可视化报告

---

## 第二步：提取日志基本信息

使用 `pyulog` 工具解析日志：

```bash
# 安装 pyulog（如未安装）
pip install pyulog

# 查看日志基本信息
ulog_info <log_file>.ulg

# 列出所有记录的 topic
ulog_info -v <log_file>.ulg | grep "Topic"

# 导出为 CSV（便于分析）
ulog2csv <log_file>.ulg -o output_dir/
```

输出关键信息：
- 飞行时长、起飞/降落时间
- 记录的 topic 列表
- 系统信息（固件版本、机型）

---

## 第三步：核心指标分析

根据用户目标选择对应分析项：

### 3a 姿态控制性能
```bash
# 提取姿态数据
ulog2csv <log>.ulg -m vehicle_attitude,vehicle_attitude_setpoint
```
检查项：
- `roll/pitch/yaw` 实际值 vs 设定值跟踪误差
- 跟踪误差 > 5° 为异常
- 响应延迟 > 100ms 需调整 PID

### 3b 振动分析
```bash
ulog2csv <log>.ulg -m sensor_accel,sensor_gyro
```
检查项：
- 加速度计高频噪声（> 10 m/s² 峰值为异常）
- 陀螺仪振动（> 0.1 rad/s 高频分量需检查机架）
- IMU 一致性（多 IMU 偏差 > 1 m/s² 需校准）

### 3c EKF 状态
```bash
ulog2csv <log>.ulg -m estimator_status,estimator_innovations
```
检查项：
- `ekf_error_flags`：非零表示 EKF 异常
- 速度/位置新息（innovation）超出 3σ 为异常
- GPS 精度：`hdop > 2.0` 时位置估计不可靠

### 3d 电源系统
```bash
ulog2csv <log>.ulg -m battery_status,system_power
```
检查项：
- 电压跌落曲线（大油门时跌落 > 0.5V 需检查电池内阻）
- 电流峰值（超过电调额定值为危险）
- 剩余电量估算误差

### 3e 故障事件
```bash
ulog2csv <log>.ulg -m vehicle_status,failsafe_flags
```
检查项：
- `failsafe` 触发记录及时间点
- RC 信号丢失事件
- 传感器健康状态变化

---

## 第四步：PlotJuggler 可视化

```bash
# 启动 PlotJuggler（需已编译）
cd ~/px4agent/PlotJuggler
./build/PlotJuggler

# 或直接用系统安装版
plotjuggler
```

操作步骤：
1. File → Load data → 选择 `.ulg` 文件（PlotJuggler 原生支持 ULog）
2. 拖拽 topic 字段到绘图区
3. 推荐对比组合：
   - `vehicle_attitude.roll` vs `vehicle_attitude_setpoint.roll_body`
   - `actuator_outputs.output[0~3]` 电机输出
   - `battery_status.voltage_v` 电压曲线

---

## 第五步：flight_review 报告生成

```bash
cd ~/px4agent/flight_review

# 安装依赖
pip install -r requirements.txt

# 生成 HTML 报告
python plot_app.py --log <log_file>.ulg --output report.html

# 启动本地 Web 服务查看
python tornado_handlers.py
# 浏览器打开 http://localhost:5006
```

报告包含：
- 飞行轨迹 3D 图
- 姿态/位置控制性能评分
- 振动频谱分析
- 故障事件时间线

---

## 第六步：问题诊断与建议

根据分析结果，按以下格式输出：

```
【问题】<描述>
【时间点】<日志中的时间戳>
【数据证据】<具体数值>
【建议】<调参/硬件/软件修复方案>
```

常见问题对照表：

| 现象 | 可能原因 | 建议 |
|------|---------|------|
| 姿态振荡 | P 增益过高 | 降低 MC_ROLL_P / MC_PITCH_P 10~20% |
| 起飞时侧翻 | 电机顺序/方向错误 | 检查 mixer 配置 |
| EKF 发散 | GPS 信号差 | 检查天线位置，增加 EKF2_GPS_DELAY |
| 电压跌落严重 | 电池老化/内阻大 | 更换电池或降低最大油门 |
| 高频振动 | 桨叶不平衡/机架共振 | 动平衡校准，加减振垫 |

---

## 编码规范（自定义 topic 验证场景）
- 确认 topic 时间戳连续性（无跳变）
- 确认数据范围合理（无 NaN/Inf）
- 确认发布频率符合设计（用 `ulog_info -v` 查看实际频率）
