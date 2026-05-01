---
name: px4-magnetometer
version: "1.0.0"
description: 在 PX4 中添加或修复磁力计驱动，解决磁力计数据异常导致的 Yaw 漂移问题（驱动 + 校准 + 诊断）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

在 PX4 中处理磁力计驱动与校准：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

---

## 项目路径

- PX4 项目：`~/px4agent`
- 驱动目录：`src/drivers/magnetometer/`
- uORB 消息：`msg/sensor_mag.msg`
- MAVLink 消息：`src/modules/mavlink/mavlink/message_definitions/v1.0/common.xml`
- MAVLink 流：`src/modules/mavlink/streams/MAGNETOMETER.hpp`
- 校准参数：`src/modules/sensors/vehicle_magnetometer/VehicleMagnetometer.cpp`
- 诊断工具：`src/modules/commander/Failsafe.cpp`

---

## 第零步：需求确认

询问用户以下信息：

1. **磁力计型号**（如 HMC5883L、IST8310、QMC5883L）
2. **总线类型**（I2C 或 SPI）
3. **问题描述**：
   - 是否存在 Yaw 漂移？
   - 是否有磁力计数据异常（如固定值、噪声过大）？
   - 是否需要新建驱动还是修复现有驱动？
4. **校准状态**：是否已进行过磁力计校准？

---

## 第一步：诊断现有磁力计问题

### 1.1 检查驱动是否存在

```bash
find src/drivers/magnetometer/ -type d -iname "*<mag_model>*"
```

- **驱动已存在** → 进入第二步（驱动核实）
- **驱动不存在** → 进入第三步（新建驱动）

### 1.2 运行时诊断（SITL 环境）

启动 SITL 后执行：

```bash
# 检查磁力计是否启动
mag start

# 监听磁力计原始数据
listener sensor_mag

# 检查磁力计健康状态
mag status

# 查看磁力计参数
param show CAL_MAG*
param show SENS_MAG_*
```

**诊断清单**：
- [ ] 磁力计数据是否在合理范围内（±50000 mGauss）？
- [ ] 数据更新频率是否达到 50 Hz 以上？
- [ ] 是否存在固定值或周期性异常？
- [ ] 校准参数是否已加载（`CAL_MAG0_*`）？

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
| 数据范围校验 | 磁力计数据必须先范围校验再写 uORB | |
| 超时检测 | 超时后上报健康异常，不能静默失败 | |

输出核验报告，标注每项"✅ 合规"或"❌ <具体问题>"。

### 2.2 uORB 发布确认

1. 确认驱动发布的 uORB topic：`sensor_mag`
2. 检查消息结构是否包含：
   - `x`, `y`, `z`（磁场强度，单位 Gauss）
   - `temperature`（温度补偿）
   - `timestamp`（时间戳）
   - `device_id`（设备 ID）
3. 检查发布频率是否与硬件额定采样率匹配（通常 50-100 Hz）
4. 确认 `orb_advertise_queue()` 队列深度设置合理

### 2.3 MAVLink 流核实

1. 检查 `streams/` 目录是否有 `MAGNETOMETER.hpp`
2. 确认 stream 在 `mavlink_main.cpp` 中已注册
3. 验证 MAVLink 消息 ID 无冲突

### 2.4 编译验证

```bash
make px4_sitl_default
```

确认驱动编译无警告、无错误。

---

## 第三步：新建磁力计驱动（分支 B：驱动不存在）

### 3.1 驱动框架生成

在 `src/drivers/magnetometer/` 下创建驱动目录：

```
src/drivers/magnetometer/<mag_model>/
├── CMakeLists.txt
├── Kconfig
├── <mag_model>.cpp
├── <mag_model>.hpp
└── test/
    └── test_<mag_model>.cpp
```

### 3.2 驱动头文件模板（`<mag_model>.hpp`）

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
#include <uORB/topics/sensor_mag.h>

using namespace time_literals;

class <MagModel> : public px4::ScheduledWorkItem, public device::I2C, public ModuleParams
{
public:
	<MagModel>(I2CSPIBusOption bus_option, int bus, int address, uint32_t device_type, int spi_mode, int bus_frequency);
	virtual ~<MagModel>();

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
	static constexpr uint8_t REG_ID = 0x0A;           // 芯片 ID 寄存器
	static constexpr uint8_t CHIP_ID = 0x48;          // 预期芯片 ID

	// 数据读取
	int read_data(int16_t &x, int16_t &y, int16_t &z);
	int write_register(uint8_t reg, uint8_t value);
	int read_register(uint8_t reg, uint8_t &value);

	// 校准与补偿
	void apply_calibration(int16_t &x, int16_t &y, int16_t &z);
	int read_temperature(int16_t &temp);

	// uORB 发布
	uORB::Publication<sensor_mag_s> _sensor_mag_pub{ORB_ID(sensor_mag)};

	// 性能计数
	perf_counter_t _sample_perf{perf_alloc(PC_ELAPSED, MODULE_NAME": read")};
	perf_counter_t _comms_errors{perf_alloc(PC_COUNT, MODULE_NAME": comms_errors")};
	perf_counter_t _range_errors{perf_alloc(PC_COUNT, MODULE_NAME": range_errors")};

	// 参数
	DEFINE_PARAMETERS(
		(ParamInt<px4::params::SENS_MAG_XOFF>) _mag_x_offset,
		(ParamInt<px4::params::SENS_MAG_YOFF>) _mag_y_offset,
		(ParamInt<px4::params::SENS_MAG_ZOFF>) _mag_z_offset,
		(ParamFloat<px4::params::SENS_MAG_XSCALE>) _mag_x_scale,
		(ParamFloat<px4::params::SENS_MAG_YSCALE>) _mag_y_scale,
		(ParamFloat<px4::params::SENS_MAG_ZSCALE>) _mag_z_scale
	)

	// 状态
	bool _initialized{false};
	uint32_t _last_read_time{0};
	uint32_t _timeout_us{100_ms};
};
```

### 3.3 驱动实现模板（`<mag_model>.cpp`）

```cpp
#include "<mag_model>.hpp"

<MagModel>::<MagModel>(I2CSPIBusOption bus_option, int bus, int address, uint32_t device_type, int spi_mode, int bus_frequency)
	: ScheduledWorkItem(MODULE_NAME, px4::wq_configurations::hp_default),
	  I2C(bus, address, bus_frequency),
	  ModuleParams(nullptr)
{
	_device_id.devid_s.bus_type = DeviceBusType_I2C;
	_device_id.devid_s.bus = bus;
	_device_id.devid_s.address = address;
	_device_id.devid_s.devtype = device_type;
}

<MagModel>::~<MagModel>()
{
	perf_free(_sample_perf);
	perf_free(_comms_errors);
	perf_free(_range_errors);
}

int <MagModel>::init()
{
	// 1. 探测芯片
	if (probe() != PX4_OK) {
		PX4_ERR("probe failed");
		return PX4_ERROR;
	}

	// 2. 初始化硬件
	if (write_register(0x0B, 0x01) != PX4_OK) { // 使能测量
		PX4_ERR("failed to enable measurement");
		return PX4_ERROR;
	}

	// 3. 加载校准参数
	updateParams();

	// 4. 启动定时任务（50 Hz）
	ScheduleOnInterval(20_ms);

	_initialized = true;
	PX4_INFO("initialized successfully");
	return PX4_OK;
}

int <MagModel>::probe()
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

void <MagModel>::RunImpl()
{
	perf_begin(_sample_perf);

	int16_t x = 0, y = 0, z = 0;
	int16_t temp = 0;

	// 读取磁力计数据
	if (read_data(x, y, z) != PX4_OK) {
		perf_count(_comms_errors);
		perf_end(_sample_perf);
		return;
	}

	// 范围校验（±50000 mGauss）
	if (x < -50000 || x > 50000 || y < -50000 || y > 50000 || z < -50000 || z > 50000) {
		perf_count(_range_errors);
		PX4_WARN("data out of range: x=%d, y=%d, z=%d", x, y, z);
		perf_end(_sample_perf);
		return;
	}

	// 应用校准参数
	apply_calibration(x, y, z);

	// 读取温度
	read_temperature(temp);

	// 发布 uORB 消息
	sensor_mag_s mag{};
	mag.timestamp = hrt_absolute_time();
	mag.x = x / 1000.0f; // 转换为 Gauss
	mag.y = y / 1000.0f;
	mag.z = z / 1000.0f;
	mag.temperature = temp / 100.0f;
	mag.device_id = _device_id.devid;
	mag.is_external = false;

	_sensor_mag_pub.publish(mag);

	_last_read_time = mag.timestamp;
	perf_end(_sample_perf);
}

int <MagModel>::read_data(int16_t &x, int16_t &y, int16_t &z)
{
	uint8_t data[6] = {0};
	if (transfer(nullptr, 0, data, sizeof(data)) != PX4_OK) {
		return PX4_ERROR;
	}

	// 根据芯片手册调整字节顺序
	x = (int16_t)(data[0] << 8 | data[1]);
	y = (int16_t)(data[2] << 8 | data[3]);
	z = (int16_t)(data[4] << 8 | data[5]);

	return PX4_OK;
}

void <MagModel>::apply_calibration(int16_t &x, int16_t &y, int16_t &z)
{
	// 应用偏移
	x -= _mag_x_offset.get();
	y -= _mag_y_offset.get();
	z -= _mag_z_offset.get();

	// 应用缩放（定点数运算，避免浮点）
	x = (int16_t)(x * _mag_x_scale.get());
	y = (int16_t)(y * _mag_y_scale.get());
	z = (int16_t)(z * _mag_z_scale.get());
}

int <MagModel>::write_register(uint8_t reg, uint8_t value)
{
	uint8_t data[2] = {reg, value};
	return transfer(data, sizeof(data), nullptr, 0);
}

int <MagModel>::read_register(uint8_t reg, uint8_t &value)
{
	uint8_t data = reg;
	if (transfer(&data, 1, &data, 1) != PX4_OK) {
		return PX4_ERROR;
	}
	value = data;
	return PX4_OK;
}

int <MagModel>::read_temperature(int16_t &temp)
{
	// 根据芯片手册实现温度读取
	uint8_t data[2] = {0};
	if (transfer(nullptr, 0, data, sizeof(data)) != PX4_OK) {
		return PX4_ERROR;
	}
	temp = (int16_t)(data[0] << 8 | data[1]);
	return PX4_OK;
}

void <MagModel>::print_status()
{
	I2C::print_status();
	perf_print_counter(_sample_perf);
	perf_print_counter(_comms_errors);
	perf_print_counter(_range_errors);
	PX4_INFO("initialized: %s", _initialized ? "yes" : "no");
}

extern "C" __EXPORT int <mag_model>_main(int argc, char *argv[]);

int <mag_model>_main(int argc, char *argv[])
{
	return I2CSPIDriverBase::main<MagModel>(argc, argv);
}
```

### 3.4 CMakeLists.txt

```cmake
px4_add_module(
	MODULE drivers__magnetometer__<mag_model>
	MAIN <mag_model>
	STACK_MAIN 2048
	SRCS
		<mag_model>.cpp
	DEPENDS
		drivers_device
		lib__drivers__device
		lib__perf
)
```

### 3.5 Kconfig

```
menuconfig DRIVERS_MAGNETOMETER_<MAG_MODEL>
	bool "<MagModel> Magnetometer"
	default n
	---help---
		Enable support for <MagModel> magnetometer via I2C
```

---

## 第四步：磁力计校准参数配置

### 4.1 校准参数定义

在 `src/modules/sensors/vehicle_magnetometer/VehicleMagnetometer.cpp` 中确认以下参数：

```cpp
// 磁力计偏移（mGauss）
DEFINE_PARAMETERS(
	(ParamInt<px4::params::CAL_MAG0_ID>) _mag0_id,
	(ParamInt<px4::params::CAL_MAG0_XOFF>) _mag0_x_offset,
	(ParamInt<px4::params::CAL_MAG0_YOFF>) _mag0_y_offset,
	(ParamInt<px4::params::CAL_MAG0_ZOFF>) _mag0_z_offset,
	(ParamFloat<px4::params::CAL_MAG0_XSCALE>) _mag0_x_scale,
	(ParamFloat<px4::params::CAL_MAG0_YSCALE>) _mag0_y_scale,
	(ParamFloat<px4::params::CAL_MAG0_ZSCALE>) _mag0_z_scale,
	(ParamInt<px4::params::CAL_MAG0_ROT>) _mag0_rotation
)
```

### 4.2 校准流程（QGC 地面站）

1. 连接飞控
2. 进入 **设置 → 传感器 → 罗盘**
3. 选择对应磁力计，点击 **校准**
4. 按照屏幕提示旋转飞机（8 字形或球形）
5. 校准完成后参数自动保存

### 4.3 手动校准参数调整

若校准后仍有 Yaw 漂移，可手动调整：

```bash
# 查看当前校准参数
param show CAL_MAG0_*

# 手动调整偏移（单位：mGauss）
param set CAL_MAG0_XOFF <value>
param set CAL_MAG0_YOFF <value>
param set CAL_MAG0_ZOFF <value>

# 调整缩放因子（通常 0.9 ~ 1.1）
param set CAL_MAG0_XSCALE 1.0
param set CAL_MAG0_YSCALE 1.0
param set CAL_MAG0_ZSCALE 1.0

# 保存参数
param save
```

---

## 第五步：Yaw 漂移诊断与修复

### 5.1 诊断步骤

**问题表现**：飞机在悬停时 Yaw 角度缓慢漂移（通常 1-5°/分钟）

**根本原因**：
1. 磁力计校准不准确
2. 磁力计数据噪声过大
3. 磁力计与飞机磁场干扰
4. EKF2 融合权重配置不当

### 5.2 诊断命令

```bash
# 1. 检查磁力计原始数据
listener sensor_mag

# 2. 检查 EKF2 融合状态
listener estimator_status

# 3. 查看 Yaw 角速度
listener vehicle_angular_velocity

# 4. 检查磁力计健康状态
mag status

# 5. 查看 EKF2 参数
param show EKF2_MAG_*
```

### 5.3 修复方案

**方案 A：重新校准磁力计**

```bash
# 在 QGC 中重新执行磁力计校准
# 或使用命令行工具
mag calibrate
```

**方案 B：调整 EKF2 磁力计融合权重**

```bash
# 降低磁力计权重（增加陀螺仪权重）
param set EKF2_MAG_NOISE 0.05  # 默认 0.05，可增加至 0.1

# 增加磁力计偏差学习率
param set EKF2_MAG_BIAS_NSTD 0.001

# 禁用磁力计 3D 融合，仅用 Yaw
param set EKF2_MAG_TYPE 1  # 0=3D, 1=Yaw only
```

**方案 C：检查磁力计安装位置**

- 磁力计应远离电源、电机、ESC（至少 10 cm）
- 磁力计应与飞机中心线平行
- 检查是否有金属物体靠近磁力计

**方案 D：软铁补偿**

若飞机周围有软铁干扰（如铝合金机架），需进行软铁补偿：

```bash
# 启用软铁补偿
param set EKF2_MAG_DECL 0  # 磁偏角（根据地理位置设置）

# 手动调整软铁矩阵（高级）
param set EKF2_MAG_BIAS_X 0
param set EKF2_MAG_BIAS_Y 0
param set EKF2_MAG_BIAS_Z 0
```

---

## 第六步：端到端验证

### 6.1 SITL 仿真验证

```bash
# 编译
make px4_sitl_default

# 启动 SITL
./build/px4_sitl_default/bin/px4 -i 0

# 在另一个终端启动磁力计驱动
mag start

# 监听数据
listener sensor_mag
listener estimator_status
```

### 6.2 实机验证

1. 上传固件到飞控
2. 在 QGC 中重新校准磁力计
3. 进行悬停测试（5 分钟），观察 Yaw 角漂移
4. 若漂移 < 2°，则校准成功

### 6.3 日志分析

```bash
# 下载飞行日志
# 使用 flight_review 或 PlotJuggler 分析：
# - sensor_mag.x/y/z：磁力计原始数据
# - estimator_status.mag_test_ratio：磁力计融合质量
# - vehicle_attitude.yaw：Yaw 角度变化
```

---

## 单元测试

在 `src/drivers/magnetometer/<mag_model>/test/test_<mag_model>.cpp` 编写测试：

```cpp
#include <gtest/gtest.h>
#include "../<mag_model>.hpp"

TEST(MagnetometerTest, DataRangeValidation)
{
	// 测试数据范围校验
	int16_t x = 60000, y = 0, z = 0; // 超出范围
	EXPECT_FALSE(is_valid_range(x, y, z));
}

TEST(MagnetometerTest, CalibrationApplication)
{
	// 测试校准参数应用
	int16_t x = 1000, y = 2000, z = 3000;
	apply_calibration(x, y, z);
	// 验证校准后的值
}

TEST(MagnetometerTest, TemperatureCompensation)
{
	// 测试温度补偿
	int16_t temp = 2500; // 25°C
	// 验证温度补偿逻辑
}
```

---

## 编码规范（必须遵守）

- 语言：C++
- 禁止 `printf`/`fprintf`，用 `PX4_DEBUG`/`PX4_INFO`/`PX4_WARN`/`PX4_ERR`
- 时间：`hrt_absolute_time()`，禁止系统时钟
- 参数：`DEFINE_PARAMETERS` + `ModuleParams`，命名格式 `SENS_MAG_*` 或 `CAL_MAG*`
- 禁止在驱动层使用浮点运算（校准参数除外）
- 禁止动态内存分配
- WorkQueue 驱动禁止在 `RunImpl()` 中阻塞，用 `ScheduleDelayed()` 代替
- `perf_free()` 在析构中调用，防止资源泄漏
- 数据必须先范围校验再写 uORB
- 磁力计超时检测：超时后上报健康异常

---

## 常见问题排查

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| Yaw 漂移 1-5°/分钟 | 磁力计校准不准 | 重新校准或调整 EKF2 权重 |
| 磁力计数据固定值 | 驱动通信失败 | 检查 I2C 总线、地址、时钟 |
| 磁力计噪声过大 | 电磁干扰 | 远离电源/电机，增加滤波 |
| EKF2 拒绝磁力计 | 数据质量差 | 检查 `estimator_status.mag_test_ratio` |
| 校准参数不保存 | 参数存储失败 | 检查 EEPROM，重新校准 |

