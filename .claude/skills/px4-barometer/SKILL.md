---
name: px4-barometer
version: "1.0.0"
description: 在 PX4 中添加或修复气压计驱动，解决气压计数据异常导致的高度估计偏差问题（驱动 + 校准 + 诊断）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

在 PX4 中处理气压计驱动与校准：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

---

## 项目路径

- PX4 项目：`~/px4agent`
- 驱动目录：`src/drivers/barometer/`
- uORB 消息：`msg/sensor_baro.msg`
- MAVLink 消息：`src/modules/mavlink/mavlink/message_definitions/v1.0/common.xml`
- MAVLink 流：`src/modules/mavlink/streams/BAROMETER.hpp`
- 气压计模块：`src/modules/sensors/vehicle_barometer/VehicleBarometer.cpp`
- 高度估计：`src/modules/ekf2/EKF2.cpp`

---

## 第零步：需求确认

询问用户以下信息：

1. **气压计型号**（如 BMP280、BMP388、MS5611）
2. **总线类型**（I2C 或 SPI）
3. **问题描述**：
   - 是否存在高度估计偏差？
   - 气压计数据是否异常（如固定值、噪声过大、跳变）？
   - 是否需要新建驱动还是修复现有驱动？
4. **校准状态**：是否已进行过气压计校准？

---

## 第一步：诊断现有气压计问题

### 1.1 检查驱动是否存在

```bash
find src/drivers/barometer/ -type d -iname "*<baro_model>*"
```

- **驱动已存在** → 进入第二步（驱动核实）
- **驱动不存在** → 进入第三步（新建驱动）

### 1.2 运行时诊断（SITL 环境）

启动 SITL 后执行：

```bash
# 检查气压计是否启动
baro start

# 监听气压计原始数据
listener sensor_baro

# 检查气压计健康状态
baro status

# 查看气压计参数
param show SENS_BARO_*
```

**诊断清单**：
- [ ] 气压计数据是否在合理范围内（300-1100 hPa）？
- [ ] 数据更新频率是否达到 50 Hz 以上？
- [ ] 是否存在固定值或周期性异常？
- [ ] 校准参数是否已加载（`SENS_BARO_*`）？
- [ ] 高度估计是否稳定（EKF2 融合）？

---

## 第二步：驱动核实流程（分支 A：驱动已存在）

### 2.1 代码规范检查

读取驱动的 `.cpp` 和 `.hpp` 文件，逐条核验：

| 检查项 | 正确做法 | 结论 |
|--------|---------|------|
| 线程模型 | 继承 `px4::ScheduledWorkItem`，禁止独立线程 | |
| 浮点运算 | 驱动层禁止浮点，用定点数/整型 | |
| 动态内存 | 禁止 `new`/`delete`/`malloc`/`free` | |
| 阻塞调用 | 禁止 `sleep`/`usleep`，用 `ScheduleDelayed()` | |
| 日志 | 禁止 `printf`，用 `PX4_DEBUG`/`PX4_INFO`/`PX4_WARN`/`PX4_ERR` | |
| 时间 | `hrt_absolute_time()`，禁止系统时钟 | |
| 参数 | `DEFINE_PARAMETERS` + `ModuleParams`，禁止裸调 `param_get()` | |
| perf_counter | 析构中调用 `perf_free()`，防止资源泄漏 | |
| 数据范围校验 | 气压计数据必须先范围校验再写 uORB | |
| 超时检测 | 超时后上报健康异常，不能静默失败 | |

输出核验报告，标注每项"✅ 合规"或"❌ <具体问题>"。

### 2.2 uORB 发布确认

1. 确认驱动发布的 uORB topic：`sensor_baro`
2. 检查消息结构是否包含：
   - `pressure`（气压，单位 Pa）
   - `temperature`（温度，单位 °C）
   - `timestamp`（时间戳）
   - `device_id`（设备 ID）
3. 检查发布频率是否与硬件额定采样率匹配（通常 50-100 Hz）
4. 确认 `orb_advertise_queue()` 队列深度设置合理

### 2.3 MAVLink 流核实

1. 检查 `streams/` 目录是否有 `BAROMETER.hpp`
2. 确认 stream 在 `mavlink_main.cpp` 中已注册
3. 验证 MAVLink 消息 ID 无冲突

### 2.4 编译验证

```bash
make px4_sitl_default
```

确认驱动编译无警告、无错误。

---

## 第三步：新建气压计驱动（分支 B：驱动不存在）

### 3.1 驱动框架生成

在 `src/drivers/barometer/` 下创建驱动目录：

```
src/drivers/barometer/<baro_model>/
├── CMakeLists.txt
├── Kconfig
├── <baro_model>.cpp
├── <baro_model>.hpp
└── test/
    └── test_<baro_model>.cpp
```

### 3.2 驱动头文件模板（`<baro_model>.hpp`）

```cpp
#pragma once

#include <px4_platform_common/px4_config.h>
#include <px4_platform_common/defines.h>
#include <px4_platform_common/module.h>
#include <px4_platform_common/module_params.h>
#include <px4_platform_common/px4_work_queue/ScheduledWorkItem.hpp>
#include <drivers/drv_hrt.h>
#include <lib/drivers/device/i2c.h>
#include <lib/perf/perf_counter.h>
#include <uORB/Publication.hpp>
#include <uORB/topics/sensor_baro.h>

using namespace time_literals;

class <BaroModel> : public px4::ScheduledWorkItem, public device::I2C, public ModuleParams
{
public:
	<BaroModel>(I2CSPIBusOption bus_option, int bus, int address, uint32_t device_type, int spi_mode, int bus_frequency);
	virtual ~<BaroModel>();

	static I2CSPIDriverBase *instantiate(const BusCLIArguments &cli, const BusInstanceIterator &iterator, int runtime_instance);
	static void print_usage();

	virtual int init();
	virtual int probe();

	void print_status();

protected:
	virtual void RunImpl();

private:
	// 硬件参数
	static constexpr uint32_t I2C_SPEED = 400 * 1000; // 400 kHz
	static constexpr uint8_t REG_ID = 0xD0;           // 芯片 ID 寄存器
	static constexpr uint8_t CHIP_ID = 0x58;          // 预期芯片 ID

	// 数据读取
	int read_data(int32_t &pressure, int16_t &temperature);
	int write_register(uint8_t reg, uint8_t value);
	int read_register(uint8_t reg, uint8_t &value);

	// 校准与补偿
	void apply_calibration(int32_t &pressure, int16_t &temperature);
	int read_calibration_data();

	// uORB 发布
	uORB::Publication<sensor_baro_s> _sensor_baro_pub{ORB_ID(sensor_baro)};

	// 性能计数
	perf_counter_t _sample_perf{perf_alloc(PC_ELAPSED, MODULE_NAME": read")};
	perf_counter_t _comms_errors{perf_alloc(PC_COUNT, MODULE_NAME": comms_errors")};
	perf_counter_t _range_errors{perf_alloc(PC_COUNT, MODULE_NAME": range_errors")};

	// 参数
	DEFINE_PARAMETERS(
		(ParamInt<px4::params::SENS_BARO_PRESS_OFF>) _baro_press_offset,
		(ParamFloat<px4::params::SENS_BARO_PRESS_SCALE>) _baro_press_scale,
		(ParamInt<px4::params::SENS_BARO_TEMP_OFF>) _baro_temp_offset
	)

	// 状态
	bool _initialized{false};
	uint32_t _last_read_time{0};
	uint32_t _timeout_us{100_ms};

	// 校准数据（芯片特定）
	struct {
		uint16_t dig_T1;
		int16_t dig_T2;
		int16_t dig_T3;
		uint16_t dig_P1;
		int16_t dig_P2;
		int16_t dig_P3;
		int16_t dig_P4;
		int16_t dig_P5;
		int16_t dig_P6;
		int16_t dig_P7;
		int16_t dig_P8;
		int16_t dig_P9;
	} _calib_data;
};
```

### 3.3 驱动实现模板（`<baro_model>.cpp`）

```cpp
#include "<baro_model>.hpp"

<BaroModel>::<BaroModel>(I2CSPIBusOption bus_option, int bus, int address, uint32_t device_type, int spi_mode, int bus_frequency)
	: ScheduledWorkItem(MODULE_NAME, px4::wq_configurations::hp_default),
	  I2C(bus, address, bus_frequency),
	  ModuleParams(nullptr)
{
	_device_id.devid_s.bus_type = DeviceBusType_I2C;
	_device_id.devid_s.bus = bus;
	_device_id.devid_s.address = address;
	_device_id.devid_s.devtype = device_type;
}

<BaroModel>::~<BaroModel>()
{
	perf_free(_sample_perf);
	perf_free(_comms_errors);
	perf_free(_range_errors);
}

int <BaroModel>::init()
{
	// 1. 探测芯片
	if (probe() != PX4_OK) {
		PX4_ERR("probe failed");
		return PX4_ERROR;
	}

	// 2. 读取校准数据
	if (read_calibration_data() != PX4_OK) {
		PX4_ERR("failed to read calibration data");
		return PX4_ERROR;
	}

	// 3. 初始化硬件（设置采样率、过滤）
	if (write_register(0xF5, 0x00) != PX4_OK) { // 配置寄存器
		PX4_ERR("failed to configure device");
		return PX4_ERROR;
	}

	// 4. 加载校准参数
	updateParams();

	// 5. 启动定时任务（50 Hz）
	ScheduleOnInterval(20_ms);

	_initialized = true;
	PX4_INFO("initialized successfully");
	return PX4_OK;
}

int <BaroModel>::probe()
{
	uint8_t chip_id = 0;
	if (read_register(REG_ID, chip_id) != PX4_OK) {
		PX4_ERR("failed to read chip ID");
		return PX4_ERROR;
	}

	if (chip_id != CHIP_ID) {
		PX4_ERR("unexpected chip ID: 0x%02x (expected 0x%02x)", chip_id, CHIP_ID);
		return PX4_ERROR;
	}

	return PX4_OK;
}

void <BaroModel>::RunImpl()
{
	perf_begin(_sample_perf);

	int32_t pressure = 0;
	int16_t temperature = 0;

	// 读取气压计数据
	if (read_data(pressure, temperature) != PX4_OK) {
		perf_count(_comms_errors);
		perf_end(_sample_perf);
		return;
	}

	// 范围校验（300-1100 hPa = 30000-110000 Pa）
	if (pressure < 30000 || pressure > 110000) {
		perf_count(_range_errors);
		PX4_WARN("pressure out of range: %d Pa", pressure);
		perf_end(_sample_perf);
		return;
	}

	// 应用校准参数
	apply_calibration(pressure, temperature);

	// 发布 uORB 消息
	sensor_baro_s baro{};
	baro.timestamp = hrt_absolute_time();
	baro.pressure = pressure / 100.0f; // 转换为 hPa
	baro.temperature = temperature / 100.0f;
	baro.device_id = _device_id.devid;

	_sensor_baro_pub.publish(baro);

	_last_read_time = baro.timestamp;
	perf_end(_sample_perf);
}

int <BaroModel>::read_data(int32_t &pressure, int16_t &temperature)
{
	uint8_t data[6] = {0};
	if (transfer(nullptr, 0, data, sizeof(data)) != PX4_OK) {
		return PX4_ERROR;
	}

	// 根据芯片手册调整字节顺序
	pressure = (int32_t)(data[0] << 12 | data[1] << 4 | data[2] >> 4);
	temperature = (int16_t)(data[3] << 8 | data[4]);

	return PX4_OK;
}

void <BaroModel>::apply_calibration(int32_t &pressure, int16_t &temperature)
{
	// 应用偏移
	pressure -= _baro_press_offset.get();
	temperature -= _baro_temp_offset.get();

	// 应用缩放（定点数运算，避免浮点）
	pressure = (int32_t)(pressure * _baro_press_scale.get());
}

int <BaroModel>::read_calibration_data()
{
	// 根据芯片手册读取校准数据
	uint8_t calib[24] = {0};
	if (transfer(nullptr, 0, calib, sizeof(calib)) != PX4_OK) {
		return PX4_ERROR;
	}

	_calib_data.dig_T1 = (uint16_t)(calib[0] << 8 | calib[1]);
	_calib_data.dig_T2 = (int16_t)(calib[2] << 8 | calib[3]);
	_calib_data.dig_T3 = (int16_t)(calib[4] << 8 | calib[5]);
	// ... 继续读取其他校准数据

	return PX4_OK;
}

int <BaroModel>::write_register(uint8_t reg, uint8_t value)
{
	uint8_t data[2] = {reg, value};
	return transfer(data, sizeof(data), nullptr, 0);
}

int <BaroModel>::read_register(uint8_t reg, uint8_t &value)
{
	uint8_t data = reg;
	if (transfer(&data, 1, &data, 1) != PX4_OK) {
		return PX4_ERROR;
	}
	value = data;
	return PX4_OK;
}

void <BaroModel>::print_status()
{
	I2C::print_status();
	perf_print_counter(_sample_perf);
	perf_print_counter(_comms_errors);
	perf_print_counter(_range_errors);
	PX4_INFO("initialized: %s", _initialized ? "yes" : "no");
}

extern "C" __EXPORT int <baro_model>_main(int argc, char *argv[]);

int <baro_model>_main(int argc, char *argv[])
{
	return I2CSPIDriverBase::main<BaroModel>(argc, argv);
}
```

---

## 第四步：气压计校准参数配置

### 4.1 校准参数定义

在 `src/modules/sensors/vehicle_barometer/VehicleBarometer.cpp` 中确认以下参数：

```cpp
DEFINE_PARAMETERS(
	(ParamInt<px4::params::SENS_BARO_PRESS_OFF>) _baro_press_offset,
	(ParamFloat<px4::params::SENS_BARO_PRESS_SCALE>) _baro_press_scale,
	(ParamInt<px4::params::SENS_BARO_TEMP_OFF>) _baro_temp_offset
)
```

### 4.2 校准流程

1. 在已知高度处启动飞控
2. 等待 EKF2 收敛（通常 30 秒）
3. 记录气压计读数
4. 手动调整参数使高度估计准确

---

## 第五步：高度估计异常诊断与修复

### 5.1 诊断步骤

**问题表现**：高度估计偏差 > 5 米，或高度漂移 > 1 m/分钟

**根本原因**：
1. 气压计校准不准确
2. 气压计数据噪声过大
3. 气压计与飞机气流干扰
4. EKF2 融合权重配置不当

### 5.2 诊断命令

```bash
# 1. 检查气压计原始数据
listener sensor_baro

# 2. 检查 EKF2 融合状态
listener estimator_status

# 3. 查看高度估计
listener vehicle_local_position

# 4. 检查气压计健康状态
baro status

# 5. 查看 EKF2 参数
param show EKF2_BARO_*
```

### 5.3 修复方案

**方案 A：重新校准气压计**

在已知高度处重新校准。

**方案 B：调整 EKF2 气压计融合权重**

```bash
# 降低气压计权重
param set EKF2_BARO_NOISE 2.0  # 默认 2.0，可增加至 5.0

# 增加气压计偏差学习率
param set EKF2_BARO_BIAS_NSTD 0.001
```

**方案 C：检查气压计安装位置**

- 气压计应远离发热源（电机、ESC）
- 气压计应避免直接受气流影响
- 检查是否有堵塞或漏气

---

## 第六步：端到端验证

### 6.1 SITL 仿真验证

```bash
make px4_sitl_default
./build/px4_sitl_default/bin/px4 -i 0
baro start
listener sensor_baro
listener vehicle_local_position
```

### 6.2 实机验证

1. 上传固件到飞控
2. 在已知高度处启动飞控
3. 观察高度估计（应在 ±2 米内）
4. 进行垂直飞行测试，观察高度跟踪精度

### 6.3 日志分析

```bash
# 下载飞行日志
# 使用 flight_review 或 PlotJuggler 分析：
# - sensor_baro.pressure：气压计原始数据
# - vehicle_local_position.z：高度估计
# - estimator_status.baro_test_ratio：气压计融合质量
```

---

## 单元测试

在 `src/drivers/barometer/<baro_model>/test/test_<baro_model>.cpp` 编写测试：

```cpp
#include <gtest/gtest.h>
#include "../<baro_model>.hpp"

TEST(BarometerTest, PressureRangeValidation)
{
	int32_t pressure = 120000; // 超出范围
	EXPECT_FALSE(is_valid_range(pressure));
}

TEST(BarometerTest, CalibrationApplication)
{
	int32_t pressure = 101325;
	apply_calibration(pressure);
	// 验证校准后的值
}

TEST(BarometerTest, TemperatureCompensation)
{
	int16_t temp = 2500; // 25°C
	// 验证温度补偿逻辑
}
```

---

## 编码规范（必须遵守）

- 语言：C++
- 禁止 `printf`/`fprintf`，用 `PX4_DEBUG`/`PX4_INFO`/`PX4_WARN`/`PX4_ERR`
- 时间：`hrt_absolute_time()`，禁止系统时钟
- 参数：`DEFINE_PARAMETERS` + `ModuleParams`，命名格式 `SENS_BARO_*`
- 禁止在驱动层使用浮点运算（校准参数除外）
- 禁止动态内存分配
- WorkQueue 驱动禁止在 `RunImpl()` 中阻塞，用 `ScheduleDelayed()` 代替
- `perf_free()` 在析构中调用，防止资源泄漏
- 数据必须先范围校验再写 uORB
- 气压计超时检测：超时后上报健康异常

---

## 常见问题排查

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| 高度偏差 > 5 m | 气压计校准不准 | 重新校准或调整 EKF2 权重 |
| 高度漂移 > 1 m/分钟 | 气压计数据噪声大 | 增加滤波，检查安装位置 |
| 气压计数据固定值 | 驱动通信失败 | 检查 I2C 总线、地址、时钟 |
| EKF2 拒绝气压计 | 数据质量差 | 检查 `estimator_status.baro_test_ratio` |
| 校准参数不保存 | 参数存储失败 | 检查 EEPROM，重新校准 |
