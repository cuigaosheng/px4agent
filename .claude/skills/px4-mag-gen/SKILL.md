---
name: px4-mag-gen
version: "1.0.0"
description: 磁力计驱动代码生成器 - 输入芯片型号，一键生成完整驱动代码（驱动 + uORB + MAVLink + 单元测试）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

磁力计驱动代码生成器：$ARGUMENTS

根据用户输入的芯片型号，自动生成完整的 PX4 磁力计驱动代码。

---

## 支持的磁力计芯片库

| 芯片型号 | 制造商 | 总线 | 采样率 | 量程 | 特性 |
|---------|------|------|--------|------|------|
| HMC5883L | Honeywell | I2C | 160 Hz | ±8 Gauss | 经典磁力计，成本低 |
| IST8310 | iSentek | I2C | 200 Hz | ±1600 mT | 低功耗，高精度 |
| QMC5883L | QST | I2C | 200 Hz | ±800 mT | 国产替代品 |
| LIS3MDL | STMicroelectronics | I2C/SPI | 1000 Hz | ±16 Gauss | 高采样率 |
| BMM150 | Bosch | I2C | 300 Hz | ±1300 mT | 集成温度补偿 |
| AK8963 | Asahi Kasei | I2C | 100 Hz | ±4912 µT | 高精度 |
| AK09916 | Asahi Kasei | I2C | 100 Hz | ±4912 µT | 最新款 |
| RM3100 | PNI | I2C/SPI | 600 Hz | ±200 µT | 工业级 |

---

## 第零步：需求确认

询问用户：

1. **芯片型号**（从上表选择或输入新型号）
2. **总线类型**（I2C 或 SPI）
3. **I2C 地址**（如 0x0D，仅 I2C 需要）
4. **SPI 频率**（如 10 MHz，仅 SPI 需要）
5. **输出目录**（默认 `~/px4agent/src/drivers/magnetometer/`）

---

## 第一步：芯片参数库查询

根据用户输入的芯片型号，从库中查询参数：

```json
{
  "HMC5883L": {
    "manufacturer": "Honeywell",
    "bus_types": ["I2C"],
    "default_i2c_addr": "0x1E",
    "chip_id_reg": "0x0A",
    "chip_id_value": "0x48",
    "range_options": [0.88, 1.3, 1.9, 2.5, 4.0, 4.7, 5.6, 8.1],
    "sample_rate_max": 160,
    "temp_sensor": false,
    "registers": {
      "CONFIG_A": "0x00",
      "CONFIG_B": "0x01",
      "MODE": "0x02",
      "DATA_X_H": "0x03"
    }
  },
  "IST8310": {
    "manufacturer": "iSentek",
    "bus_types": ["I2C"],
    "default_i2c_addr": "0x0E",
    "chip_id_reg": "0x00",
    "chip_id_value": "0x10",
    "range_options": [200, 400, 800, 1600],
    "sample_rate_max": 200,
    "temp_sensor": true,
    "registers": {
      "STAT1": "0x02",
      "DATA_X_L": "0x03",
      "TEMP_L": "0x1C"
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
#include <lib/drivers/device/i2c.h>
#include <lib/drivers/device/spi.h>
#include <lib/perf/perf_counter.h>
#include <uORB/Publication.hpp>
#include <uORB/topics/sensor_mag.h>

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
	static constexpr uint32_t SPI_SPEED = <SPI_SPEED>;

	// 数据读取
	int read_mag(int16_t &x, int16_t &y, int16_t &z);
	int read_temperature(int16_t &temp);
	int write_register(uint8_t reg, uint8_t value);
	int read_register(uint8_t reg, uint8_t &value);

	// 校准与补偿
	void apply_calibration(int16_t &x, int16_t &y, int16_t &z);

	// uORB 发布
	uORB::Publication<sensor_mag_s> _sensor_mag_pub{ORB_ID(sensor_mag)};

	// 性能计数
	perf_counter_t _sample_perf{perf_alloc(PC_ELAPSED, MODULE_NAME": read")};
	perf_counter_t _comms_errors{perf_alloc(PC_COUNT, MODULE_NAME": comms_errors")};
	perf_counter_t _range_errors{perf_alloc(PC_COUNT, MODULE_NAME": range_errors")};

	// 参数
	DEFINE_PARAMETERS(
		(ParamInt<px4::params::CAL_MAG0_XOFF>) _mag_x_offset,
		(ParamInt<px4::params::CAL_MAG0_YOFF>) _mag_y_offset,
		(ParamInt<px4::params::CAL_MAG0_ZOFF>) _mag_z_offset,
		(ParamFloat<px4::params::CAL_MAG0_XSCALE>) _mag_x_scale,
		(ParamFloat<px4::params::CAL_MAG0_YSCALE>) _mag_y_scale,
		(ParamFloat<px4::params::CAL_MAG0_ZSCALE>) _mag_z_scale
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
- `RunImpl()` - 数据读取循环（磁场 + 温度）
- `read_mag()` - 磁场读取（带范围校验）
- `read_temperature()` - 温度读取
- `apply_calibration()` - 磁力计校准

---

## 第四步：生成 uORB 消息定义

自动生成 `msg/sensor_mag.msg`（若不存在）：

```
uint64 timestamp                # 时间戳 (microseconds)
uint32 device_id                # 设备 ID
float32 x                        # 磁场 X (Gauss)
float32 y                        # 磁场 Y (Gauss)
float32 z                        # 磁场 Z (Gauss)
float32 temperature             # 温度 (°C)
```

---

## 第五步：生成 MAVLink 流配置

自动生成 `src/modules/mavlink/streams/MAGNETOMETER.hpp`：

```cpp
class MavlinkStreamMagnetometer : public MavlinkStream
{
public:
	const char *get_name() const override { return MavlinkStreamMagnetometer::get_name_static(); }
	static const char *get_name_static() { return "MAGNETOMETER"; }
	static uint16_t get_id_static() { return MAVLINK_MSG_ID_MAGNETOMETER; }

	bool send() override
	{
		sensor_mag_s mag;

		if (_mag_sub.update(&mag)) {
			mavlink_magnetometer_t msg{};
			msg.time_usec = mag.timestamp;
			msg.x = mag.x;
			msg.y = mag.y;
			msg.z = mag.z;

			mavlink_msg_magnetometer_send(_mavlink->get_channel(), msg.time_usec, msg.x, msg.y, msg.z);
			return true;
		}
		return false;
	}

private:
	uORB::Subscription _mag_sub{ORB_ID(sensor_mag)};
};
```

---

## 第六步：生成 CMakeLists.txt

自动生成 `src/drivers/magnetometer/<chip_model>/CMakeLists.txt`。

---

## 第七步：生成 Kconfig

自动生成 `src/drivers/magnetometer/<chip_model>/Kconfig`。

---

## 第八步：生成单元测试框架

自动生成 `src/drivers/magnetometer/<chip_model>/test/test_<chip_model>.cpp`。

---

## 第九步：生成完整文件清单

输出生成的文件列表。

---

## 参数库扩充指南

若需添加新芯片，编辑 `.claude/skills/px4-mag-gen/chip_library.json`。

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

### 示例 1：生成 HMC5883L I2C 驱动

```bash
/px4-mag-gen HMC5883L I2C
```

**用户输入**：
- 芯片型号：HMC5883L
- 总线类型：I2C
- I2C 地址：0x1E（默认）
- 输出目录：~/px4agent/src/drivers/magnetometer/（默认）

**生成的文件**：
```
src/drivers/magnetometer/hmc5883l/
├── hmc5883l.hpp
├── hmc5883l.cpp
├── CMakeLists.txt
├── Kconfig
└── test/
    └── test_hmc5883l.cpp
msg/sensor_mag.msg
src/modules/mavlink/streams/MAGNETOMETER.hpp
```

### 示例 2：生成 IST8310 I2C 驱动

```bash
/px4-mag-gen IST8310 I2C
```

**用户输入**：
- 芯片型号：IST8310
- 总线类型：I2C
- I2C 地址：0x0E（默认）
- 输出目录：~/px4agent/src/drivers/magnetometer/（默认）

**生成的文件**：同上

### 示例 3：添加新芯片到库

编辑 `.claude/skills/px4-mag-gen/chip_library.json`，添加新芯片：

```json
{
  "LIS3MDL": {
    "manufacturer": "STMicroelectronics",
    "bus_types": ["I2C", "SPI"],
    "default_i2c_addr": "0x1C",
    "chip_id_reg": "0x0F",
    "chip_id_value": "0x3D",
    "range_options": [4, 8, 12, 16],
    "sample_rate_max": 1000,
    "temp_sensor": true,
    "registers": {
      "CTRL_REG1": "0x20",
      "OUT_X_L": "0x28",
      "TEMP_OUT_L": "0x2E"
    }
  }
}
```

下次运行时，新芯片自动可用：

```bash
/px4-mag-gen LIS3MDL I2C
```
