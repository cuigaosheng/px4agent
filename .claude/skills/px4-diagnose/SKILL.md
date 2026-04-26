---
name: px4-diagnose
version: "1.0.0"
description: 飞行日志诊断 + 参数调整建议（pyulog 自动分析，GUI 工具点人工介入）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Glob, Grep]
---
对 PX4 飞行日志进行自动诊断并给出参数调整建议：$ARGUMENTS

请严格按以下步骤执行。**pyulog 分析阶段全自动推进；遇到需要 GUI 工具的节点，暂停并明确告知需要你做什么，你确认后继续。**

---

## 第一步：确认日志文件

1. 若已提供日志路径，直接使用；否则询问：
   - ULog 文件路径（`.ulg`）
   - 故障描述（如：第几秒、什么现象、飞手判断）

2. 确认 pyulog 已安装：
   ```bash
   ulog_info --version
   ```
   若未安装：`pip install pyulog`，安装后继续。

3. 读取日志基本信息：
   ```bash
   ulog_info <logfile.ulg>
   ```
   输出：飞行时长、系统类型、记录的 topic 列表。

---

## 第二步：bagel 时间锚定（人工节点 1）

**⏸ 暂停——需要你操作：**

```
请用 bagel 打开日志文件做 3D 动画回放：
  bagel <logfile.ulg>

回放时观察：
  - 抖动/异常姿态出现在第几秒？
  - 哪个轴（roll / pitch / yaw）最明显？

观察完成后，告诉我：异常时间段（如 46.5~49.2 秒）和异常轴。
```

等待你输入时间锚点后继续。

---

## 第三步：pyulog 自动数据提取（自动）

根据故障描述，提取以下 topic 的时间锚点附近数据：

```bash
# 提取角速度跟踪误差
ulog2csv <logfile.ulg> -m rate_ctrl_status

# 提取执行器输出（是否饱和）
ulog2csv <logfile.ulg> -m actuator_controls_0

# 提取角速度测量值
ulog2csv <logfile.ulg> -m vehicle_angular_velocity

# 提取姿态误差
ulog2csv <logfile.ulg> -m vehicle_attitude_setpoint
```

AI 自动读取生成的 CSV 文件，聚焦时间锚点前后 ±5 秒，分析：
- roll/pitch/yaw rate 跟踪误差是否持续偏大
- `actuator_controls` 是否出现饱和（值持续 ≥ 0.95 或 ≤ -0.95）
- 积分项（`rate_ctrl_status.roll_integ` 等）是否异常累积
- 角速度测量值是否有高频抖动

输出**数值化诊断摘要**，例如：
```
时间锚点：46.5~49.2 秒
roll rate 跟踪误差：均值 0.18 rad/s（正常应 < 0.05）
actuator_controls[0]：在 47.1s 后持续饱和
roll_integ：在锚点段从 0.12 累积至 0.41（饱和迹象）
高频抖动：无明显 > 50Hz 分量
初步判断：roll 轴积分项过大，导致积分饱和振荡
```

---

## 第四步：flight_review 图表确认（人工节点 2）

**⏸ 暂停——需要你操作：**

```
请运行 flight_review 生成可视化报告：
  cd flight_review
  python3 generate_plots.py <logfile.ulg> ./output/
  # 用浏览器打开 output/ 下的 HTML 文件

重点查看以下图表：
  - Rate controller tracking（roll/pitch rate 跟踪曲线）
  - Actuator outputs（执行器输出是否饱和）
  - Vibration（振动频谱）

看完后告诉我：
  1. 跟踪曲线图中，setpoint 和 actual 的偏差有多大？
  2. 是否看到振动频谱异常峰值？峰值频率是多少？
  3. 执行器输出是否有明显截断/饱和？
```

等待你描述图表内容后继续。

---

## 第五步：综合诊断（自动）

整合 pyulog 数值分析（第三步）+ flight_review 图表信息（第四步），给出结构化诊断结论：

```
【诊断结论】
故障轴：roll
根本原因：<具体原因，如"MC_ROLLRATE_I 过大导致积分饱和">
支撑证据：
  - pyulog：roll_integ 在锚点段累积 0.29（超出正常范围）
  - flight_review：roll rate actual 与 setpoint 偏差持续扩大，actuator 输出饱和
  - 振动：<是否有高频噪声放大问题>
排除项：<已排除的可能原因>
```

---

## 第六步：参数调整建议（自动）

根据诊断结论，给出具体参数修改建议，格式如下：

| 参数 | 当前值 | 建议值 | 修改理由 |
|------|--------|--------|---------|
| `MC_ROLLRATE_I` | — | 降低 30~50% | 积分饱和，需减小 I 项 |
| `MC_ROLLRATE_D` | — | 适当增加 0.001 | 抑制残余振荡 |
| `IMU_GYRO_CUTOFF` | — | 检查是否偏高 | 滤波截止频率过高会放大噪声进入控制环 |

> ⚠️ 当前值需通过 QGC 参数面板或 `param show <NAME>` 确认，建议值为相对调整量，**最终修改前必须确认当前值**。

修改验证方法：
```bash
# 连接飞控后确认当前值
param show MC_ROLLRATE_I

# SITL 仿真验证（推荐先仿真再上机）
make px4_sitl gazebo
# 复现相同机动，观察 roll rate 跟踪是否改善
```

---

## 工具能力说明

| 工具 | 本 skill 中的角色 | 是否自动 |
|------|-----------------|---------|
| pyulog | 主力数值分析 | ✅ 全自动 |
| bagel | 时间锚点定位 | ⏸ 人工操作 |
| flight_review | 图表辅助确认 | ⏸ 人工描述 |
| PlotJuggler | 本 skill 不使用（可选自行查看）| — |
