---
name: px4-sensor-codegen
version: "1.0.0"
description: 通用传感器驱动代码生成器 - 支持自定义传感器类型，一键生成完整驱动代码框架（驱动 + uORB + MAVLink + 单元测试）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

通用传感器驱动代码生成器：$ARGUMENTS

根据用户定义的传感器类型和参数，自动生成完整的 PX4 传感器驱动代码框架。

---

## 支持的传感器类型

| 类型 | 说明 | uORB Topic | 数据字段 |
|------|------|-----------|---------|
| IMU | 惯性测量单元 | sensor_accel / sensor_gyro | x, y, z, temperature |
| Magnetometer | 磁力计 | sensor_mag | x, y, z, temperature |
| Barometer | 气压计 | sensor_baro | pressure, temperature |
| Distance | 测距仪 | distance_sensor | distance, signal_quality |
| Optical Flow | 光流 | optical_flow | x, y, quality |
| Airspeed | 空速计 | airspeed | indicated_airspeed, true_airspeed |
| GPS | 全球定位系统 | sensor_gps | lat, lon, alt, satellites_used |
| Rangefinder | 测距仪（360°） | obstacle_distance | distances[72] |
| Custom | 自定义传感器 | 用户定义 | 用户定义 |

---

## 第零步：需求确认

询问用户：

1. **传感器类型**（从上表选择或输入自定义类型）
2. **芯片型号**（如 MPU6050）
3. **总线类型**（I2C、SPI、UART、GPIO、Analog）
4. **数据字段**（如 x, y, z, temperature）
5. **采样率**（Hz）
6. **输出目录**（默认 `~/px4agent/src/drivers/`）

---

## 第一步：参数库查询与验证

根据用户输入的传感器类型和芯片型号，查询参数库：

```json
{
  "sensor_types": {
    "IMU": {
      "uorb_topic": "sensor_accel",
      "data_fields": ["x", "y", "z", "temperature"],
      "range_validation": "±16g / ±2000°/s",
      "sample_rate_typical": 1000
    },
    "Custom": {
      "uorb_topic": "custom_sensor",
      "data_fields": "user_defined",
      "range_validation": "user_defined",
      "sample_rate_typical": "user_defined"
    }
  }
}
```

---

## 第二步：生成驱动头文件

根据传感器参数自动生成 `<sensor_name>.hpp`：

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
#include <uORB/topics/<uorb_topic>.h>

using namespace time_literals;

class <SensorName> : public px4::ScheduledWorkItem, public ModuleParams
{
public:
	<SensorName>(I2CSPIBusOption bus_option, int bus, int address, uint32_t device_type, int spi_mode, int bus_frequency);
	virtual ~<SensorName>();

	static I2CSPIDriverBase *instantiate(const BusCLIArguments &cli, const BusInstanceIterator &iterator, int runtime_instance);
	static void print_usage();

	virtual int init();
	virtual int probe();

	void print_status();

protected:
	virtual void RunImpl();

private:
	// 硬件参数
	static constexpr uint8_t CHIP_ID_REG = <CHIP_ID_REG>;
	static constexpr uint8_t CHIP_ID_VALUE = <CHIP_ID_VALUE>;
	static constexpr uint32_t I2C_SPEED = 400 * 1000;

	// 数据读取
	int read_sensor_data(<data_fields>);
	int write_register(uint8_t reg, uint8_t value);
	int read_register(uint8_t reg, uint8_t &value);

	// 校准与补偿
	void apply_calibration(<data_fields>);

	// uORB 发布
	uORB::Publication<<uorb_message_type>> _sensor_pub{ORB_ID(<uorb_topic>)};

	// 性能计数
	perf_counter_t _sample_perf{perf_alloc(PC_ELAPSED, MODULE_NAME": read")};
	perf_counter_t _comms_errors{perf_alloc(PC_COUNT, MODULE_NAME": comms_errors")};
	perf_counter_t _range_errors{perf_alloc(PC_COUNT, MODULE_NAME": range_errors")};

	// 参数
	DEFINE_PARAMETERS(
		// 用户定义的参数
	)

	// 状态
	bool _initialized{false};
	uint32_t _last_read_time{0};
	uint32_t _timeout_us{100_ms};
};
```

---

## 第三步：生成驱动实现文件

根据传感器参数自动生成 `<sensor_name>.cpp`，包含：

- `init()` - 传感器初始化
- `probe()` - 传感器探测
- `RunImpl()` - 数据读取循环
- `read_sensor_data()` - 数据读取
- `apply_calibration()` - 校准应用

---

## 第四步：生成 uORB 消息定义

根据用户定义的数据字段自动生成 `msg/<sensor_name>.msg`：

```
uint64 timestamp                # 时间戳 (microseconds)
uint32 device_id                # 设备 ID
<user_defined_fields>           # 用户定义的数据字段
```

---

## 第五步：生成 MAVLink 流配置

自动生成 `src/modules/mavlink/streams/<SENSOR_NAME>.hpp`。

---

## 第六步：生成 CMakeLists.txt

自动生成 `src/drivers/<sensor_type>/<sensor_name>/CMakeLists.txt`。

---

## 第七步：生成 Kconfig

自动生成 `src/drivers/<sensor_type>/<sensor_name>/Kconfig`。

---

## 第八步：生成单元测试框架

自动生成 `src/drivers/<sensor_type>/<sensor_name>/test/test_<sensor_name>.cpp`。

---

## 第九步：生成完整文件清单

输出生成的文件列表。

---

## 参数库扩充指南

若需添加新传感器类型，编辑 `.claude/skills/px4-sensor-codegen/sensor_library.json`。

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

### 示例 1：生成标准 IMU 驱动

```bash
/px4-sensor-codegen IMU MPU6050 I2C
```

**用户输入**：
- 传感器类型：IMU
- 芯片型号：MPU6050
- 总线类型：I2C
- 数据字段：x, y, z, temperature（自动）
- 采样率：1000 Hz（自动）

**生成的文件**：
```
src/drivers/imu/mpu6050/
├── mpu6050.hpp
├── mpu6050.cpp
├── CMakeLists.txt
├── Kconfig
└── test/
    └── test_mpu6050.cpp
msg/sensor_accel.msg
msg/sensor_gyro.msg
src/modules/mavlink/streams/IMU_DATA.hpp
```

### 示例 2：生成自定义温度传感器驱动

```bash
/px4-sensor-codegen Custom 温度传感器 I2C
```

**用户输入**：
- 传感器类型：Custom
- 芯片型号：温度传感器
- 总线类型：I2C
- 数据字段：temperature, humidity, pressure
- 采样率：10 Hz
- uORB topic 名称：sensor_env
- MAVLink 消息名称：ENVIRONMENT_DATA

**生成的文件**：
```
src/drivers/custom/temperature_sensor/
├── temperature_sensor.hpp
├── temperature_sensor.cpp
├── CMakeLists.txt
├── Kconfig
└── test/
    └── test_temperature_sensor.cpp
msg/sensor_env.msg
src/modules/mavlink/streams/ENVIRONMENT_DATA.hpp
```

### 示例 3：生成光流传感器驱动

```bash
/px4-sensor-codegen Optical\ Flow PX4FLOW I2C
```

**用户输入**：
- 传感器类型：Optical Flow
- 芯片型号：PX4FLOW
- 总线类型：I2C
- 数据字段：x, y, quality（自动）
- 采样率：50 Hz（自动）

**生成的文件**：
```
src/drivers/optical_flow/px4flow/
├── px4flow.hpp
├── px4flow.cpp
├── CMakeLists.txt
├── Kconfig
└── test/
    └── test_px4flow.cpp
msg/optical_flow.msg
src/modules/mavlink/streams/OPTICAL_FLOW.hpp
```

### 示例 4：添加新传感器类型到库

编辑 `.claude/skills/px4-sensor-codegen/sensor_library.json`，添加新传感器类型：

```json
{
  "sensor_types": {
    "Humidity": {
      "uorb_topic": "sensor_humidity",
      "data_fields": ["humidity", "temperature"],
      "range_validation": "0-100% / -40-85°C",
      "sample_rate_typical": 10
    }
  }
}
```

下次运行时，新传感器类型自动可用：

```bash
/px4-sensor-codegen Humidity DHT22 I2C
```
