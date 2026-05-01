---
name: px4-imu-gen
version: "1.0.0"
description: IMU 驱动代码生成器 - 输入芯片型号，一键生成完整驱动代码（驱动 + uORB + MAVLink + 单元测试）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

IMU 驱动代码生成器：$ARGUMENTS

根据用户输入的芯片型号，自动生成完整的 PX4 IMU 驱动代码。

---

## 支持的 IMU 芯片库

| 芯片型号 | 制造商 | 总线 | 采样率 | 量程 | 特性 |
|---------|------|------|--------|------|------|
| MPU6050 | InvenSense | I2C/SPI | 1 kHz | ±16g / ±2000°/s | 经典 6 轴，成本低 |
| MPU9250 | InvenSense | I2C/SPI | 1 kHz | ±16g / ±2000°/s | 集成磁力计 |
| ICM20689 | InvenSense | I2C/SPI | 1 kHz | ±16g / ±2000°/s | 低功耗，高精度 |
| ICM42688 | InvenSense | I2C/SPI | 8 kHz | ±16g / ±2000°/s | 最新款，低噪声 |
| BMI088 | Bosch | SPI | 1.6 kHz | ±24g / ±2000°/s | 工业级，高可靠性 |
| BMI160 | Bosch | I2C/SPI | 1.6 kHz | ±16g / ±2000°/s | 集成步数计 |
| LSM6DSL | STMicroelectronics | I2C/SPI | 1.66 kHz | ±16g / ±2000°/s | 低功耗 |
| LSM6DSO | STMicroelectronics | I2C/SPI | 1.66 kHz | ±16g / ±2000°/s | 最新款 |
| MPU6000 | InvenSense | SPI | 1 kHz | ±16g / ±2000°/s | 航空级 |

---

## 第零步：需求确认

询问用户：

1. **芯片型号**（从上表选择或输入新型号）
2. **总线类型**（I2C 或 SPI）
3. **I2C 地址**（如 0x68，仅 I2C 需要）
4. **SPI 频率**（如 10 MHz，仅 SPI 需要）
5. **输出目录**（默认 `~/px4agent/src/drivers/imu/`）

---

## 第一步：芯片参数库查询

根据用户输入的芯片型号，从库中查询参数：

```json
{
  "MPU6050": {
    "manufacturer": "InvenSense",
    "bus_types": ["I2C", "SPI"],
    "default_i2c_addr": "0x68",
    "chip_id_reg": "0x75",
    "chip_id_value": "0x68",
    "accel_range": [2, 4, 8, 16],
    "gyro_range": [250, 500, 1000, 2000],
    "sample_rate_max": 1000,
    "temp_sensor": true,
    "registers": {
      "PWR_MGMT_1": "0x6B",
      "ACCEL_XOUT_H": "0x3B",
      "GYRO_XOUT_H": "0x43",
      "TEMP_OUT_H": "0x41"
    }
  },
  "ICM42688": {
    "manufacturer": "InvenSense",
    "bus_types": ["I2C", "SPI"],
    "default_i2c_addr": "0x68",
    "chip_id_reg": "0x75",
    "chip_id_value": "0x47",
    "accel_range": [2, 4, 8, 16],
    "gyro_range": [250, 500, 1000, 2000],
    "sample_rate_max": 8000,
    "temp_sensor": true,
    "registers": {
      "PWR_MGMT0": "0x4E",
      "ACCEL_DATA_X1": "0x0B",
      "GYRO_DATA_X1": "0x11",
      "TEMP_DATA1": "0x09"
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
#include <uORB/topics/sensor_accel.h>
#include <uORB/topics/sensor_gyro.h>

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
	int read_accel(float &x, float &y, float &z);
	int read_gyro(float &x, float &y, float &z);
	int read_temperature(float &temp);
	int write_register(uint8_t reg, uint8_t value);
	int read_register(uint8_t reg, uint8_t &value);

	// 校准与补偿
	void apply_accel_calibration(float &x, float &y, float &z);
	void apply_gyro_calibration(float &x, float &y, float &z);

	// uORB 发布
	uORB::Publication<sensor_accel_s> _sensor_accel_pub{ORB_ID(sensor_accel)};
	uORB::Publication<sensor_gyro_s> _sensor_gyro_pub{ORB_ID(sensor_gyro)};

	// 性能计数
	perf_counter_t _sample_perf{perf_alloc(PC_ELAPSED, MODULE_NAME": read")};
	perf_counter_t _comms_errors{perf_alloc(PC_COUNT, MODULE_NAME": comms_errors")};
	perf_counter_t _range_errors{perf_alloc(PC_COUNT, MODULE_NAME": range_errors")};

	// 参数
	DEFINE_PARAMETERS(
		(ParamInt<px4::params::SENS_ACCEL_XOFF>) _accel_x_offset,
		(ParamInt<px4::params::SENS_ACCEL_YOFF>) _accel_y_offset,
		(ParamInt<px4::params::SENS_ACCEL_ZOFF>) _accel_z_offset,
		(ParamFloat<px4::params::SENS_ACCEL_XSCALE>) _accel_x_scale,
		(ParamFloat<px4::params::SENS_ACCEL_YSCALE>) _accel_y_scale,
		(ParamFloat<px4::params::SENS_ACCEL_ZSCALE>) _accel_z_scale,
		(ParamInt<px4::params::SENS_GYRO_XOFF>) _gyro_x_offset,
		(ParamInt<px4::params::SENS_GYRO_YOFF>) _gyro_y_offset,
		(ParamInt<px4::params::SENS_GYRO_ZOFF>) _gyro_z_offset,
		(ParamFloat<px4::params::SENS_GYRO_XSCALE>) _gyro_x_scale,
		(ParamFloat<px4::params::SENS_GYRO_YSCALE>) _gyro_y_scale,
		(ParamFloat<px4::params::SENS_GYRO_ZSCALE>) _gyro_z_scale
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
- `RunImpl()` - 数据读取循环（加速度 + 陀螺仪 + 温度）
- `read_accel()` - 加速度读取（带范围校验）
- `read_gyro()` - 陀螺仪读取（带范围校验）
- `read_temperature()` - 温度读取
- `apply_accel_calibration()` - 加速度校准
- `apply_gyro_calibration()` - 陀螺仪校准

---

## 第四步：生成 uORB 消息定义

自动生成 `msg/sensor_accel.msg` 和 `msg/sensor_gyro.msg`（若不存在）：

```
uint64 timestamp                # 时间戳 (microseconds)
uint32 device_id                # 设备 ID
float32 x                        # 加速度 X (m/s^2)
float32 y                        # 加速度 Y (m/s^2)
float32 z                        # 加速度 Z (m/s^2)
float32 temperature             # 温度 (°C)
```

---

## 第五步：生成 MAVLink 流配置

自动生成 `src/modules/mavlink/streams/IMU_DATA.hpp`：

```cpp
class MavlinkStreamIMUData : public MavlinkStream
{
public:
	const char *get_name() const override { return MavlinkStreamIMUData::get_name_static(); }
	static const char *get_name_static() { return "IMU_DATA"; }
	static uint16_t get_id_static() { return MAVLINK_MSG_ID_IMU_DATA; }

	bool send() override
	{
		sensor_accel_s accel;
		sensor_gyro_s gyro;

		if (_accel_sub.update(&accel) && _gyro_sub.update(&gyro)) {
			mavlink_imu_data_t msg{};
			msg.time_usec = accel.timestamp;
			msg.xacc = accel.x;
			msg.yacc = accel.y;
			msg.zacc = accel.z;
			msg.xgyro = gyro.x;
			msg.ygyro = gyro.y;
			msg.zgyro = gyro.z;

			mavlink_msg_imu_data_send(_mavlink->get_channel(), msg.time_usec, msg.xacc, msg.yacc, msg.zacc, msg.xgyro, msg.ygyro, msg.zgyro);
			return true;
		}
		return false;
	}

private:
	uORB::Subscription _accel_sub{ORB_ID(sensor_accel)};
	uORB::Subscription _gyro_sub{ORB_ID(sensor_gyro)};
};
```

---

## 第六步：生成 CMakeLists.txt

自动生成 `src/drivers/imu/<chip_model>/CMakeLists.txt`：

```cmake
px4_add_module(
	MODULE drivers__imu__<chip_model>
	MAIN <chip_model>
	STACK_MAIN 2048
	SRCS
		<chip_model>.cpp
	DEPENDS
		drivers_device
		lib__drivers__device
		lib__perf
)
```

---

## 第七步：生成 Kconfig

自动生成 `src/drivers/imu/<chip_model>/Kconfig`：

```
menuconfig DRIVERS_IMU_<CHIP_MODEL>
	bool "<ChipModel> IMU"
	default n
	---help---
		Enable support for <ChipModel> IMU via <BusType>
```

---

## 第八步：生成单元测试框架

自动生成 `src/drivers/imu/<chip_model>/test/test_<chip_model>.cpp`：

```cpp
#include <gtest/gtest.h>
#include "../<chip_model>.hpp"

TEST(IMUTest, AccelRangeValidation)
{
	float x = 100.0f, y = 0.0f, z = 0.0f; // 超出范围
	EXPECT_FALSE(is_valid_accel_range(x, y, z));
}

TEST(IMUTest, GyroRangeValidation)
{
	float x = 5000.0f, y = 0.0f, z = 0.0f; // 超出范围
	EXPECT_FALSE(is_valid_gyro_range(x, y, z));
}

TEST(IMUTest, CalibrationApplication)
{
	float x = 9.81f, y = 0.0f, z = 0.0f;
	apply_accel_calibration(x, y, z);
	// 验证校准后的值
}
```

---

## 第九步：生成完整文件清单

输出生成的文件列表：

```
生成的文件：
✓ src/drivers/imu/<chip_model>/<chip_model>.hpp
✓ src/drivers/imu/<chip_model>/<chip_model>.cpp
✓ src/drivers/imu/<chip_model>/CMakeLists.txt
✓ src/drivers/imu/<chip_model>/Kconfig
✓ src/drivers/imu/<chip_model>/test/test_<chip_model>.cpp
✓ src/modules/mavlink/streams/IMU_DATA.hpp
✓ msg/sensor_accel.msg（若不存在）
✓ msg/sensor_gyro.msg（若不存在）

总计：8 个文件
```

---

## 第十步：编译验证

```bash
make px4_sitl_default
```

确认编译无错误。

---

## 参数库扩充指南

若需添加新芯片，编辑 `.claude/skills/px4-imu-gen/chip_library.json`：

```json
{
  "新芯片型号": {
    "manufacturer": "制造商",
    "bus_types": ["I2C", "SPI"],
    "default_i2c_addr": "0xXX",
    "chip_id_reg": "0xXX",
    "chip_id_value": "0xXX",
    "accel_range": [2, 4, 8, 16],
    "gyro_range": [250, 500, 1000, 2000],
    "sample_rate_max": 1000,
    "temp_sensor": true,
    "registers": {
      "寄存器名": "0xXX"
    }
  }
}
```

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

### 示例 1：生成 MPU6050 I2C 驱动

```bash
/px4-imu-gen MPU6050 I2C
```

**用户输入**：
- 芯片型号：MPU6050
- 总线类型：I2C
- I2C 地址：0x68（默认）
- 输出目录：~/px4agent/src/drivers/imu/（默认）

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

### 示例 2：生成 ICM42688 SPI 驱动

```bash
/px4-imu-gen ICM42688 SPI
```

**用户输入**：
- 芯片型号：ICM42688
- 总线类型：SPI
- SPI 频率：10 MHz
- 输出目录：~/px4agent/src/drivers/imu/（默认）

**生成的文件**：同上，但总线配置为 SPI

### 示例 3：添加新芯片到库

编辑 `.claude/skills/px4-imu-gen/chip_library.json`，添加新芯片：

```json
{
  "LSM6DSOX": {
    "manufacturer": "STMicroelectronics",
    "bus_types": ["I2C", "SPI"],
    "default_i2c_addr": "0x6A",
    "chip_id_reg": "0x0F",
    "chip_id_value": "0x6C",
    "accel_range": [2, 4, 8, 16],
    "gyro_range": [250, 500, 1000, 2000],
    "sample_rate_max": 1666,
    "temp_sensor": true,
    "registers": {
      "CTRL1_XL": "0x10",
      "OUTX_L_A": "0x28",
      "OUTX_L_G": "0x22",
      "OUT_TEMP_L": "0x20"
    }
  }
}
```

下次运行时，新芯片自动可用：

```bash
/px4-imu-gen LSM6DSOX I2C
```
