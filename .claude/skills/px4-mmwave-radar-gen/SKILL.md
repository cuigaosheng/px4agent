---
name: px4-mmwave-radar-gen
version: "1.0.0"
description: 毫米波雷达驱动代码生成器 - 输入芯片型号，一键生成完整驱动代码（驱动 + uORB + MAVLink + 单元测试）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

毫米波雷达驱动代码生成器：$ARGUMENTS

根据用户输入的芯片型号，自动生成完整的 PX4 毫米波雷达驱动代码。

---

## 支持的毫米波雷达芯片库

| 芯片型号 | 制造商 | 总线 | 频段 | 检测范围 | 特性 |
|---------|------|------|------|---------|------|
| IWR1443 | TI | CAN/SPI | 77 GHz | 100 m | 单芯片 3D 雷达 |
| IWR1642 | TI | CAN/SPI | 77 GHz | 150 m | 高分辨率 |
| IWR1843 | TI | CAN/SPI | 77 GHz | 150 m | 最新款 |
| AWR1443 | TI | CAN/SPI | 77 GHz | 100 m | 汽车级 |
| AWR1642 | TI | CAN/SPI | 77 GHz | 150 m | 高精度 |
| AWR1843 | TI | CAN/SPI | 77 GHz | 150 m | 工业级 |
| ARS430 | Bosch | CAN/Ethernet | 77 GHz | 200 m | 中距离雷达 |
| ARS441 | Bosch | CAN/Ethernet | 77 GHz | 250 m | 长距离雷达 |
| MRR4 | Bosch | CAN | 77 GHz | 160 m | 中距离 |
| ESR | Delphi | CAN/Ethernet | 77 GHz | 200 m | 自适应巡航 |
| ARS | Continental | CAN/Ethernet | 77 GHz | 250 m | 工业级 |
| MRR | Continental | CAN | 77 GHz | 160 m | 中距离 |

---

## 第零步：需求确认

询问用户：

1. **芯片型号**（从上表选择或输入新型号）
2. **总线类型**（CAN、Ethernet、UART、SPI）
3. **功能需求**：
   - 目标检测（距离、速度、角度、RCS）
   - 原始点云数据
   - 避障功能
   - 自适应巡航（ACC）
   - 碰撞预警（CW）
4. **输出数据格式**：
   - 目标列表（最多检测目标数）
   - 点云数据（分辨率）
5. **输出目录**（默认 `~/px4agent/src/drivers/radar/`）

---

## 第一步：芯片参数库查询

根据用户输入的芯片型号，从库中查询参数：

```json
{
  "IWR1843": {
    "manufacturer": "TI",
    "bus_types": ["CAN", "SPI"],
    "default_can_baudrate": 1000000,
    "protocol": "TI_MMWAVE",
    "frequency": 77,
    "range_max": 150,
    "range_unit": "m",
    "sample_rate_max": 30,
    "max_targets": 128,
    "point_cloud_capable": true,
    "registers": {
      "SYNC_CHAR_1": "0x02",
      "SYNC_CHAR_2": "0x01"
    }
  },
  "ARS441": {
    "manufacturer": "Bosch",
    "bus_types": ["CAN", "Ethernet"],
    "default_can_baudrate": 500000,
    "protocol": "Bosch_ARS",
    "frequency": 77,
    "range_max": 250,
    "range_unit": "m",
    "sample_rate_max": 20,
    "max_targets": 64,
    "point_cloud_capable": false,
    "registers": {
      "HEADER_ID": "0x600"
    }
  }
}
```

若芯片不在库中，询问用户是否提供芯片手册或使用通用模板。

---

## 第二步：生成驱动头文件

根据芯片参数自动生成 `<chip_model>.hpp`：

```cpp
#pragma once

#include <px4_platform_common/px4_config.h>
#include <px4_platform_common/defines.h>
#include <px4_platform_common/module.h>
#include <px4_platform_common/module_params.h>
#include <px4_platform_common/px4_work_queue/ScheduledWorkItem.hpp>
#include <drivers/drv_hrt.h>
#include <lib/drivers/device/device.h>
#include <lib/perf/perf_counter.h>
#include <uORB/Publication.hpp>
#include <uORB/topics/radar_target.h>

using namespace time_literals;

class <ChipModel> : public px4::ScheduledWorkItem, public ModuleParams
{
public:
	<ChipModel>(const char *port, uint32_t baudrate);
	virtual ~<ChipModel>();

	static int task_spawn(int argc, char *argv[]);
	static int custom_command(int argc, char *argv[]);
	static int print_usage(const char *reason = nullptr);

	virtual int init();
	virtual int probe();

	void print_status();

protected:
	virtual void RunImpl();

private:
	// 硬件参数（从芯片库生成）
	static constexpr uint32_t CAN_BAUDRATE = <CAN_BAUDRATE>;
	static constexpr uint8_t MAX_TARGETS = <MAX_TARGETS>;
	static constexpr float RANGE_MAX = <RANGE_MAX>;

	// 数据读取
	int read_radar_data();
	int parse_radar_message(const uint8_t *buffer, size_t length);
	int configure_radar();

	// 目标检测
	struct RadarTarget {
		float distance;      // 距离 (m)
		float velocity;      // 速度 (m/s)
		float angle;         // 角度 (rad)
		float rcs;           // 雷达截面积 (dBsm)
		uint8_t confidence;  // 置信度 (0-100)
	};

	// uORB 发布
	uORB::Publication<radar_target_s> _radar_target_pub{ORB_ID(radar_target)};

	// 性能计数
	perf_counter_t _sample_perf{perf_alloc(PC_ELAPSED, MODULE_NAME": read")};
	perf_counter_t _comms_errors{perf_alloc(PC_COUNT, MODULE_NAME": comms_errors")};
	perf_counter_t _parse_errors{perf_alloc(PC_COUNT, MODULE_NAME": parse_errors")};

	// 参数
	DEFINE_PARAMETERS(
		(ParamFloat<px4::params::RADAR_RANGE_MAX>) _radar_range_max,
		(ParamFloat<px4::params::RADAR_VELOCITY_MAX>) _radar_velocity_max
	)

	// 状态
	bool _initialized{false};
	uint32_t _last_read_time{0};
	uint32_t _timeout_us{100_ms};
	int _can_fd{-1};
	RadarTarget _targets[<MAX_TARGETS>];
	uint8_t _target_count{0};
};
```

---

## 第三步：生成驱动实现文件

根据芯片参数自动生成 `<chip_model>.cpp`，包含：

- `init()` - 雷达初始化与配置
- `probe()` - 雷达探测
- `RunImpl()` - 数据读取循环
- `read_radar_data()` - 雷达数据读取
- `parse_radar_message()` - 雷达协议解析
- `configure_radar()` - 雷达配置

---

## 第四步：生成 uORB 消息定义

自动生成 `msg/radar_target.msg`（若不存在）：

```
uint64 timestamp                # 时间戳 (microseconds)
uint32 device_id                # 设备 ID
uint8 target_count              # 检测到的目标数
float32 distance[128]           # 距离 (m)
float32 velocity[128]           # 速度 (m/s)
float32 angle[128]              # 角度 (rad)
float32 rcs[128]                # 雷达截面积 (dBsm)
uint8 confidence[128]           # 置信度 (0-100)
```

---

## 第五步：生成 MAVLink 流配置

自动生成 `src/modules/mavlink/streams/RADAR_TARGET.hpp`：

```cpp
class MavlinkStreamRadarTarget : public MavlinkStream
{
public:
	const char *get_name() const override { return MavlinkStreamRadarTarget::get_name_static(); }
	static const char *get_name_static() { return "RADAR_TARGET"; }
	static uint16_t get_id_static() { return MAVLINK_MSG_ID_RADAR_TARGET; }

	bool send() override
	{
		radar_target_s radar;

		if (_radar_sub.update(&radar)) {
			for (uint8_t i = 0; i < radar.target_count && i < 10; i++) {
				mavlink_radar_target_t msg{};
				msg.timestamp = radar.timestamp;
				msg.target_id = i;
				msg.distance = radar.distance[i];
				msg.velocity = radar.velocity[i];
				msg.angle = radar.angle[i];
				msg.rcs = radar.rcs[i];
				msg.confidence = radar.confidence[i];

				mavlink_msg_radar_target_send(_mavlink->get_channel(), msg.timestamp, msg.target_id, msg.distance, msg.velocity, msg.angle, msg.rcs, msg.confidence);
			}
			return true;
		}
		return false;
	}

private:
	uORB::Subscription _radar_sub{ORB_ID(radar_target)};
};
```

---

## 第六步：生成 CMakeLists.txt

自动生成 `src/drivers/radar/<chip_model>/CMakeLists.txt`。

---

## 第七步：生成 Kconfig

自动生成 `src/drivers/radar/<chip_model>/Kconfig`。

---

## 第八步：生成单元测试框架

自动生成 `src/drivers/radar/<chip_model>/test/test_<chip_model>.cpp`。

---

## 第九步：生成完整文件清单

输出生成的文件列表。

---

## 参数库扩充指南

若需添加新芯片，编辑 `.claude/skills/px4-mmwave-radar-gen/chip_library.json`。

---

## 编码规范

- 禁止浮点运算在驱动层（校准参数除外）
- 禁止动态内存分配
- 禁止阻塞调用
- 使用 WorkQueue 模式
- 数据范围校验后再写 uORB
- 超时检测与健康异常上报
- 雷达数据必须进行有效性检查（距离范围、速度范围、置信度）

---

## 使用示例

### 示例 1：生成 TI IWR1843 CAN 驱动

```bash
/px4-mmwave-radar-gen IWR1843 CAN
```

**用户输入**：
- 芯片型号：IWR1843
- 总线类型：CAN
- CAN 波特率：1000000（默认）
- 功能需求：目标检测 + 点云数据
- 输出目录：~/px4agent/src/drivers/radar/（默认）

**生成的文件**：
```
src/drivers/radar/iwr1843/
├── iwr1843.hpp
├── iwr1843.cpp
├── CMakeLists.txt
├── Kconfig
└── test/
    └── test_iwr1843.cpp
msg/radar_target.msg
src/modules/mavlink/streams/RADAR_TARGET.hpp
```

### 示例 2：生成 Bosch ARS441 Ethernet 驱动

```bash
/px4-mmwave-radar-gen ARS441 Ethernet
```

**用户输入**：
- 芯片型号：ARS441
- 总线类型：Ethernet
- 功能需求：目标检测 + 自适应巡航
- 输出目录：~/px4agent/src/drivers/radar/（默认）

**生成的文件**：同上，但使用 Ethernet 通信

### 示例 3：生成 TI AWR1843 SPI 驱动

```bash
/px4-mmwave-radar-gen AWR1843 SPI
```

**用户输入**：
- 芯片型号：AWR1843
- 总线类型：SPI
- SPI 频率：10 MHz
- 功能需求：目标检测 + 避障
- 输出目录：~/px4agent/src/drivers/radar/（默认）

**生成的文件**：同上，但使用 SPI 通信

### 示例 4：生成 Bosch MRR4 CAN 驱动

```bash
/px4-mmwave-radar-gen MRR4 CAN
```

**用户输入**：
- 芯片型号：MRR4
- 总线类型：CAN
- CAN 波特率：500000（默认）
- 功能需求：目标检测 + 碰撞预警
- 输出目录：~/px4agent/src/drivers/radar/（默认）

**生成的文件**：同上

### 示例 5：生成 Continental ARS CAN 驱动

```bash
/px4-mmwave-radar-gen ARS CAN
```

**用户输入**：
- 芯片型号：ARS
- 总线类型：CAN
- CAN 波特率：500000（默认）
- 功能需求：工业级目标检测
- 输出目录：~/px4agent/src/drivers/radar/（默认）

**生成的文件**：同上

### 示例 6：添加新芯片到库

编辑 `.claude/skills/px4-mmwave-radar-gen/chip_library.json`，添加新芯片：

```json
{
  "Delphi-ESR": {
    "manufacturer": "Delphi",
    "bus_types": ["CAN", "Ethernet"],
    "default_can_baudrate": 500000,
    "protocol": "Delphi_ESR",
    "frequency": 77,
    "range_max": 200,
    "range_unit": "m",
    "sample_rate_max": 20,
    "max_targets": 64,
    "point_cloud_capable": false,
    "registers": {
      "HEADER_ID": "0x700"
    }
  }
}
```

下次运行时，新芯片自动可用：

```bash
/px4-mmwave-radar-gen Delphi-ESR CAN
```

### 示例 7：生成自定义毫米波雷达驱动

```bash
/px4-mmwave-radar-gen 自定义雷达 CAN
```

**用户输入**：
- 芯片型号：自定义雷达
- 总线类型：CAN
- CAN 波特率：500000
- 协议类型：自定义
- 功能需求：目标检测
- 输出目录：~/px4agent/src/drivers/radar/（默认）

**生成的文件**：同上，使用通用模板
