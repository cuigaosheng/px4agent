---
name: qgc-display
version: "1.0.0"
description: 在 QGroundControl 中接收自定义 MAVLink 消息并展示为实时图表。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
在 QGroundControl 中添加自定义 MAVLink 数据显示：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 契约检查（优先执行）

启动前先检查 `.claude/contracts/` 下是否存在 `*.contract.md` 文件：
- **存在** → 读取契约，提取：MAVLink 消息名/ID、数据字段名、单位、QGC 图表变量
  - 使用这些参数，跳过第一步的重复询问
- **不存在** → 正常询问参数

---

## 第一步：确认显示参数

若无契约，询问：
1. MAVLink 消息名称和 msg ID
2. 需要显示的字段名及单位（如 `current_distance`，单位 cm）
3. QGC 源码路径
4. 显示形式：实时折线图 / 仪表盘 / 文字标签

---

## 第二步：添加 MAVLink 消息处理

文件：`src/Vehicle/<VehicleClass>.cc` / `src/Vehicle/<VehicleClass>.h`

1. 搜索现有类似消息处理作为参考（如 `DISTANCE_SENSOR`）
2. 在 `_handleMessage()` 的 switch-case 中添加新消息处理：

```cpp
case MAVLINK_MSG_ID_<MSG_NAME>: {
    mavlink_<msg_name>_t msg;
    mavlink_msg_<msg_name>_decode(&message, &msg);
    // 范围校验后再使用
    if (msg.<field> >= <min> && msg.<field> <= <max>) {
        emit <fieldName>Changed(msg.<field>);
    }
    break;
}
```

3. 在头文件中声明 Qt 信号：
```cpp
Q_PROPERTY(double <fieldName> READ <fieldName> NOTIFY <fieldName>Changed)
signals:
    void <fieldName>Changed(double value);
```

4. 确认 QGC 侧 MAVLink 头文件版本与 PX4 侧一致

完成后展示改动，等待用户确认。

---

## 第三步：添加 QML 图表组件

1. 在 `src/FlightDisplay/` 或 `src/AnalyzePage/` 中添加 QML 组件
2. 订阅 Vehicle 信号，绑定到实时折线图：

```qml
import QtCharts 2.3

ChartView {
    id: chart
    anchors.fill: parent

    LineSeries {
        id: series
        name: "<DisplayName> (<unit>)"
    }

    Connections {
        target: QGroundControl.multiVehicleManager.activeVehicle
        function on<FieldName>Changed(value) {
            series.append(Date.now(), value)
            if (series.count > 200) series.remove(0)
        }
    }
}
```

3. 在对应页面的 QML 中注册新组件

---

## 第四步：验证

1. 编译 QGC：`cd qgroundcontrol/build && make`
2. 连接 SITL，打开 MAVLink Inspector，确认消息接收
3. 打开自定义图表页面，确认数据曲线更新
4. 核验：字段值单位与 PX4 侧发送一致（注意 cm vs m 等单位换算）

---

## 编码规范（QGC 侧）

- UI 用 QML，业务逻辑用 C++/Qt，禁止在 QML 写复杂逻辑
- 消息处理在 `src/Vehicle/` 中添加，发出 Qt 信号
- 禁止在主线程做耗时操作
- MAVLink 头文件版本必须与 PX4 侧一致
- 日志用 `qCDebug`/`qCWarning`/`qCCritical`，禁止 `printf`
