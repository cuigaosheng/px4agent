---
name: px4-rangefinder-gen
version: "1.0.0"
description: 测距仪驱动代码生成器 - 输入芯片型号，一键生成完整驱动代码（驱动 + uORB + MAVLink + 单元测试）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

测距仪驱动代码生成器：$ARGUMENTS

根据用户输入的芯片型号，自动生成完整的 PX4 测距仪驱动代码。

---

## 支持的测距仪芯片库

| 芯片型号 | 制造商 | 总线 | 测距范围 | 精度 | 特性 |
|---------|------|------|---------|------|------|
| VL53L0X | STMicroelectronics | I2C | 0.05-2 m | ±3% | ToF，低功耗 |
| VL53L1X | STMicroelectronics | I2C | 0.04-4 m | ±2% | ToF，长距离 |
| SF45 | Lightware | UART | 0.5-50 m | ±5 cm | 360° 激光雷达 |
| TF-Luna | Benewake | UART | 0.2-8 m | ±6 cm | 低成本 |
| TF-Mini | Benewake | UART | 0.3-12 m | ±6 cm | 紧凑型 |
| HC-SR04 | Generic | GPIO | 0.02-4 m | ±3% | 超声波 |
| MB1242 | MaxBotix | I2C/Analog | 0.3-7.65 m | ±1% | 工业级 |
| PX4FLOW | PX4 | I2C | 0.3-5 m | ±5% | 光流 + 测距 |

---

## 第零步：需求确认

询问用户：

1. **芯片型号**（从上表选择或输入新型号）
2. **总线类型**（I2C、SPI、UART、GPIO、Analog）
3. **I2C 地址**（如 0x29，仅 I2C 需要）
4. **UART 波特率**（如 115200，仅 UART 需要）
5. **测距类型**（单点 / 360° 扫描）
6. **输出目录**（默认 `~/px4agent/src/drivers/distance_sensor/`）

---

## 第一步：芯片参数库查询

根据用户输入的芯片型号，从库中查询参数：

```json
{
  "VL53L0X": {
    "manufacturer": "STMicroelectronics",
    "bus_types": ["I2C"],
    "default_i2c_addr": "0x29",
    "chip_id_reg": "0xC0",
    "chip_id_value": "0xEE",
    "range_min": 50,
    "range_max": 2000,
    "range_unit": "mm",
    "sample_rate_max": 50,
    "type": "single_point",
    "registers": {
      "SYSRANGE_START": "0x00",
      "RESULT_RANGE_STATUS": "0x14",
      "RESULT_CORE_AMBIENT_WINDOW_EVENTS_RTN": "0x06"
    }
  },
  "SF45": {
    "manufacturer": "Lightware",
    "bus_types": ["UART"],
    "default_uart_baudrate": 115200,
    "range_min": 500,
    "range_max": 50000,
    "range_unit": "mm",
    "sample_rate_max": 50,
    "type": "360_scan",
    "protocol": "binary",
    "message_format": "0x66"
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
#include <lib/drivers/device/i2c.h>
#include <lib/drivers/device/spi.h>
#include <lib/perf/perf_counter.h>
#include <uORB/Publication.hpp>
#include <uORB/topics/distance_sensor.h>

using namespace time_literals;

class <ChipModel> : public px4::ScheduledWorkItem, public ModuleParams
{
public:
	<ChipModel>(I2CSPIBusOption bus_option, int bus, int address, uint32_t device_type, int spi_mode, int bus_frequency);
	virtual ~<ChipModel>();

	static I2CSPIDriverBase *instantiate(const BusCLIArguments &cli, const BusInstanceIterator &iterator, int runtime_instance);
	static void print_usage();

	virtual int init();
	virtual int probe();

	void print_status();

protected:
	virtual void RunImpl();

private:
	// 硬件参数（从芯片库生成）
	static constexpr uint8_t CHIP_ID_REG = <CHIP_ID_REG>;
	static constexpr uint8_t CHIP_ID_VALUE = <CHIP_ID_VALUE>;
	static constexpr uint32_t I2C_SPEED = 400 * 1000;
	static constexpr uint32_t RANGE_MIN = <RANGE_MIN>;
	static constexpr uint32_t RANGE_MAX = <RANGE_MAX>;

	// 数据读取
	int read_distance(uint16_t &distance);
	int write_register(uint8_t reg, uint8_t value);
	int read_register(uint8_t reg, uint8_t &value);

	// 校准与补偿
	void apply_calibration(uint16_t &distance);

	// uORB 发布
	uORB::Publication<distance_sensor_s> _distance_pub{ORB_ID(distance_sensor)};

	// 性能计数
	perf_counter_t _sample_perf{perf_alloc(PC_ELAPSED, MODULE_NAME": read")};
	perf_counter_t _comms_errors{perf_alloc(PC_COUNT, MODULE_NAME": comms_errors")};
	perf_counter_t _range_errors{perf_alloc(PC_COUNT, MODULE_NAME": range_errors")};

	// 参数
	DEFINE_PARAMETERS(
		(ParamInt<px4::params::SENS_DIST_OFF>) _distance_offset
	)

	// 状态
	bool _initialized{false};
	uint32_t _last_read_time{0};
	uint32_t _timeout_us{100_ms};
};
```

---

## 第三步：生成驱动实现文件

根据芯片参数自动生成 `<chip_model>.cpp`，包含：

- `init()` - 芯片初始化（根据芯片手册配置寄存器）
- `probe()` - 芯片探测（读取 CHIP_ID）
- `RunImpl()` - 数据读取循环（距离 + 信号强度）
- `read_distance()` - 距离读取（带范围校验）
- `apply_calibration()` - 距离校准

---

## 第四步：生成 uORB 消息定义

自动生成 `msg/distance_sensor.msg`（若不存在）：

```
uint64 timestamp                # 时间戳 (microseconds)
uint32 device_id                # 设备 ID
uint16 distance                 # 距离 (cm)
uint16 signal_quality           # 信号质量 (0-100)
uint8 type                       # 传感器类型 (0=超声波, 1=激光, 2=红外)
```

---

## 第五步：生成 MAVLink 流配置

自动生成 `src/modules/mavlink/streams/DISTANCE_SENSOR.hpp`：

```cpp
class MavlinkStreamDistanceSensor : public MavlinkStream
{
public:
	const char *get_name() const override { return MavlinkStreamDistanceSensor::get_name_static(); }
	static const char *get_name_static() { return "DISTANCE_SENSOR"; }
	static uint16_t get_id_static() { return MAVLINK_MSG_ID_DISTANCE_SENSOR; }

	bool send() override
	{
		distance_sensor_s dist;

		if (_dist_sub.update(&dist)) {
			mavlink_distance_sensor_t msg{};
			msg.time_boot_ms = dist.timestamp / 1000;
			msg.min_distance = <RANGE_MIN>;
			msg.max_distance = <RANGE_MAX>;
			msg.current_distance = dist.distance;
			msg.type = dist.type;
			msg.id = 0;
			msg.orientation = MAV_SENSOR_ROTATION_PITCH_270;
			msg.covariance = 0;

			mavlink_msg_distance_sensor_send(_mavlink->get_channel(), msg.time_boot_ms, msg.min_distance, msg.max_distance, msg.current_distance, msg.type, msg.id, msg.orientation, msg.covariance);
			return true;
		}
		return false;
	}

private:
	uORB::Subscription _dist_sub{ORB_ID(distance_sensor)};
};
```

---

## 第六步：生成 CMakeLists.txt

自动生成 `src/drivers/distance_sensor/<chip_model>/CMakeLists.txt`。

---

## 第七步：生成 Kconfig

自动生成 `src/drivers/distance_sensor/<chip_model>/Kconfig`。

---

## 第八步：生成单元测试框架

自动生成 `src/drivers/distance_sensor/<chip_model>/test/test_<chip_model>.cpp`。

---

## 第九步：生成完整文件清单

输出生成的文件列表。

---

## 参数库扩充指南

若需添加新芯片，编辑 `.claude/skills/px4-rangefinder-gen/chip_library.json`。

---

## 编码规范

- 禁止浮点运算在驱动层（校准参数除外）
- 禁止动态内存分配
- 禁止阻塞调用
- 使用 WorkQueue 模式
- 数据范围校验后再写 uORB
- 超时检测与健康异常上报

---

## 使用示例

### 示例 1：生成 VL53L1X I2C 单点测距驱动

```bash
/px4-rangefinder-gen VL53L1X I2C
```

**用户输入**：
- 芯片型号：VL53L1X
- 总线类型：I2C
- I2C 地址：0x29（默认）
- 测距类型：单点
- 输出目录：~/px4agent/src/drivers/distance_sensor/（默认）

**生成的文件**：
```
src/drivers/distance_sensor/vl53l1x/
├── vl53l1x.hpp
├── vl53l1x.cpp
├── CMakeLists.txt
├── Kconfig
└── test/
    └── test_vl53l1x.cpp
msg/distance_sensor.msg
src/modules/mavlink/streams/DISTANCE_SENSOR.hpp
```

### 示例 2：生成 SF45 UART 360° 扫描驱动

```bash
/px4-rangefinder-gen SF45 UART
```

**用户输入**：
- 芯片型号：SF45
- 总线类型：UART
- UART 波特率：115200（默认）
- 测距类型：360° 扫描
- 输出目录：~/px4agent/src/drivers/distance_sensor/（默认）

**生成的文件**：同上，但支持 360° 扫描数据格式

### 示例 3：生成 TF-Mini UART 驱动

```bash
/px4-rangefinder-gen TF-Mini UART
```

**用户输入**：
- 芯片型号：TF-Mini
- 总线类型：UART
- UART 波特率：115200（默认）
- 测距类型：单点
- 输出目录：~/px4agent/src/drivers/distance_sensor/（默认）

**生成的文件**：同上

### 示例 4：添加新芯片到库

编辑 `.claude/skills/px4-rangefinder-gen/chip_library.json`，添加新芯片：

```json
{
  "VL53L0X": {
    "manufacturer": "STMicroelectronics",
    "bus_types": ["I2C"],
    "default_i2c_addr": "0x29",
    "chip_id_reg": "0xC0",
    "chip_id_value": "0xEE",
    "range_min": 50,
    "range_max": 2000,
    "range_unit": "mm",
    "sample_rate_max": 50,
    "type": "single_point",
    "registers": {
      "SYSRANGE_START": "0x00",
      "RESULT_RANGE_STATUS": "0x14"
    }
  }
}
```

下次运行时，新芯片自动可用：

```bash
/px4-rangefinder-gen VL53L0X I2C
```
