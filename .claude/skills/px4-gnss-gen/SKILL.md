---
name: px4-gnss-gen
version: "1.0.0"
description: GNSS 接收机驱动代码生成器 - 输入芯片型号，一键生成完整驱动代码（驱动 + uORB + MAVLink + 单元测试）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

GNSS 接收机驱动代码生成器：$ARGUMENTS

根据用户输入的芯片型号，自动生成完整的 PX4 GNSS 接收机驱动代码。

---

## 支持的 GNSS 芯片库

| 芯片型号 | 制造商 | 总线 | 采样率 | 精度 | 特性 |
|---------|------|------|--------|------|------|
| u-blox NEO-M8N | u-blox | UART/I2C/SPI | 10 Hz | ±2.5 m | 经典 GPS，成本低 |
| u-blox NEO-M9N | u-blox | UART/I2C/SPI | 25 Hz | ±1.5 m | 多频 GNSS |
| u-blox ZED-F9P | u-blox | UART/I2C/SPI | 25 Hz | ±2 cm (RTK) | 高精度 RTK |
| u-blox F9R | u-blox | UART/I2C/SPI | 25 Hz | ±2 cm (RTK) | 集成 IMU |
| Septentrio mosaic-X5 | Septentrio | Ethernet/CAN | 100 Hz | ±2 cm (RTK) | 工业级，抗干扰 |
| Novatel PwrPak7 | Novatel | Ethernet/CAN | 100 Hz | ±2 cm (RTK) | 高精度，多频 |
| Emlid Reach M+ | Emlid | UART/Ethernet | 10 Hz | ±1.5 m / ±2 cm (RTK) | 开源友好 |
| Swift Navigation Duro | Swift | Ethernet | 100 Hz | ±2 cm (RTK) | 多天线 |
| Garmin GNSS 18x | Garmin | UART | 1 Hz | ±10 m | 低成本 |
| SiRF Atlas | SiRF | UART | 10 Hz | ±5 m | 低功耗 |

---

## 第零步：需求确认

询问用户：

1. **芯片型号**（从上表选择或输入新型号）
2. **总线类型**（UART、I2C、SPI、Ethernet、CAN）
3. **UART 波特率**（如 115200，仅 UART 需要）
4. **功能需求**：
   - 基础 GPS（纬度、经度、高度）
   - 速度和航向
   - RTK 高精度定位
   - 多频 GNSS（GPS/GLONASS/Galileo/BeiDou）
5. **输出目录**（默认 `~/px4agent/src/drivers/gps/`）

---

## 第一步：芯片参数库查询

根据用户输入的芯片型号，从库中查询参数：

```json
{
  "NEO-M8N": {
    "manufacturer": "u-blox",
    "bus_types": ["UART", "I2C", "SPI"],
    "default_uart_baudrate": 38400,
    "default_i2c_addr": "0x42",
    "protocol": "UBX",
    "sample_rate_max": 10,
    "rtk_capable": false,
    "multi_frequency": false,
    "registers": {
      "SYNC_CHAR_1": "0xB5",
      "SYNC_CHAR_2": "0x62"
    }
  },
  "ZED-F9P": {
    "manufacturer": "u-blox",
    "bus_types": ["UART", "I2C", "SPI"],
    "default_uart_baudrate": 115200,
    "default_i2c_addr": "0x42",
    "protocol": "UBX",
    "sample_rate_max": 25,
    "rtk_capable": true,
    "multi_frequency": true,
    "registers": {
      "SYNC_CHAR_1": "0xB5",
      "SYNC_CHAR_2": "0x62"
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
#include <uORB/topics/sensor_gps.h>

using namespace time_literals;

class <ChipModel> : public px4::ScheduledWorkItem, public ModuleParams
{
public:
	<ChipModel>(const char *port, uint32_t baudrate, bool rtk_enabled);
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
	static constexpr uint32_t UART_BAUDRATE = <UART_BAUDRATE>;
	static constexpr uint8_t SYNC_CHAR_1 = <SYNC_CHAR_1>;
	static constexpr uint8_t SYNC_CHAR_2 = <SYNC_CHAR_2>;

	// 数据读取
	int read_gps_data(double &lat, double &lon, float &alt, float &hdop, float &vdop);
	int parse_ubx_message(const uint8_t *buffer, size_t length);
	int configure_receiver();

	// RTK 支持
	int configure_rtk();
	int send_rtcm_correction(const uint8_t *data, size_t length);

	// uORB 发布
	uORB::Publication<sensor_gps_s> _sensor_gps_pub{ORB_ID(sensor_gps)};

	// 性能计数
	perf_counter_t _sample_perf{perf_alloc(PC_ELAPSED, MODULE_NAME": read")};
	perf_counter_t _comms_errors{perf_alloc(PC_COUNT, MODULE_NAME": comms_errors")};
	perf_counter_t _parse_errors{perf_alloc(PC_COUNT, MODULE_NAME": parse_errors")};

	// 参数
	DEFINE_PARAMETERS(
		(ParamInt<px4::params::GPS_YAW_OFFSET>) _gps_yaw_offset,
		(ParamFloat<px4::params::GPS_DELAY>) _gps_delay
	)

	// 状态
	bool _initialized{false};
	uint32_t _last_read_time{0};
	uint32_t _timeout_us{1000_ms};
	bool _rtk_enabled{false};
	int _uart_fd{-1};
};
```

---

## 第三步：生成驱动实现文件

根据芯片参数自动生成 `<chip_model>.cpp`，包含：

- `init()` - 芯片初始化与配置
- `probe()` - 芯片探测
- `RunImpl()` - 数据读取循环
- `read_gps_data()` - GPS 数据读取
- `parse_ubx_message()` - UBX 协议解析
- `configure_receiver()` - 接收机配置
- `configure_rtk()` - RTK 配置（若支持）
- `send_rtcm_correction()` - RTCM 校正数据发送（若支持）

---

## 第四步：生成 uORB 消息定义

自动生成 `msg/sensor_gps.msg`（若不存在）：

```
uint64 timestamp                # 时间戳 (microseconds)
uint32 device_id                # 设备 ID
int32 lat                        # 纬度 (1e-7 度)
int32 lon                        # 经度 (1e-7 度)
int32 alt                        # 高度 (mm)
uint16 alt_ellipsoid            # 椭球体高度 (mm)
float32 s_variance_m_s          # 速度标准差 (m/s)
float32 c_variance_rad          # 航向标准差 (rad)
uint8 fix_type                   # 定位类型 (0=无, 1=GPS, 2=DGPS, 3=RTK)
uint8 satellites_used           # 使用的卫星数
float32 hdop                     # 水平精度因子
float32 vdop                     # 垂直精度因子
float32 vel_m_s                 # 速度 (m/s)
float32 cog_rad                 # 航向 (rad)
int32 vel_ned_north             # 北向速度 (mm/s)
int32 vel_ned_east              # 东向速度 (mm/s)
int32 vel_ned_down              # 下向速度 (mm/s)
```

---

## 第五步：生成 MAVLink 流配置

自动生成 `src/modules/mavlink/streams/GPS_RAW_INT.hpp`：

```cpp
class MavlinkStreamGPSRawInt : public MavlinkStream
{
public:
	const char *get_name() const override { return MavlinkStreamGPSRawInt::get_name_static(); }
	static const char *get_name_static() { return "GPS_RAW_INT"; }
	static uint16_t get_id_static() { return MAVLINK_MSG_ID_GPS_RAW_INT; }

	bool send() override
	{
		sensor_gps_s gps;

		if (_gps_sub.update(&gps)) {
			mavlink_gps_raw_int_t msg{};
			msg.time_usec = gps.timestamp;
			msg.lat = gps.lat;
			msg.lon = gps.lon;
			msg.alt = gps.alt;
			msg.eph = (uint16_t)(gps.hdop * 100);
			msg.epv = (uint16_t)(gps.vdop * 100);
			msg.vel = (uint16_t)(gps.vel_m_s * 100);
			msg.cog = (uint16_t)(gps.cog_rad * 5729.58);
			msg.fix_type = gps.fix_type;
			msg.satellites_visible = gps.satellites_used;

			mavlink_msg_gps_raw_int_send(_mavlink->get_channel(), msg.time_usec, msg.fix_type, msg.lat, msg.lon, msg.alt, msg.eph, msg.epv, msg.vel, msg.cog, msg.satellites_visible);
			return true;
		}
		return false;
	}

private:
	uORB::Subscription _gps_sub{ORB_ID(sensor_gps)};
};
```

---

## 第六步：生成 CMakeLists.txt

自动生成 `src/drivers/gps/<chip_model>/CMakeLists.txt`。

---

## 第七步：生成 Kconfig

自动生成 `src/drivers/gps/<chip_model>/Kconfig`。

---

## 第八步：生成单元测试框架

自动生成 `src/drivers/gps/<chip_model>/test/test_<chip_model>.cpp`。

---

## 第九步：生成完整文件清单

输出生成的文件列表。

---

## 参数库扩充指南

若需添加新芯片，编辑 `.claude/skills/px4-gnss-gen/chip_library.json`。

---

## 编码规范

- 禁止浮点运算在驱动层（校准参数除外）
- 禁止动态内存分配
- 禁止阻塞调用
- 使用 WorkQueue 模式
- 数据范围校验后再写 uORB
- 超时检测与健康异常上报
- GPS 数据必须进行有效性检查（卫星数、HDOP/VDOP、定位类型）

---

## 使用示例

### 示例 1：生成 u-blox NEO-M8N UART 驱动

```bash
/px4-gnss-gen NEO-M8N UART
```

**用户输入**：
- 芯片型号：NEO-M8N
- 总线类型：UART
- UART 波特率：38400（默认）
- 功能需求：基础 GPS + 速度 + 航向
- 输出目录：~/px4agent/src/drivers/gps/（默认）

**生成的文件**：
```
src/drivers/gps/neo_m8n/
├── neo_m8n.hpp
├── neo_m8n.cpp
├── CMakeLists.txt
├── Kconfig
└── test/
    └── test_neo_m8n.cpp
msg/sensor_gps.msg
src/modules/mavlink/streams/GPS_RAW_INT.hpp
```

### 示例 2：生成 u-blox ZED-F9P UART RTK 驱动

```bash
/px4-gnss-gen ZED-F9P UART
```

**用户输入**：
- 芯片型号：ZED-F9P
- 总线类型：UART
- UART 波特率：115200（默认）
- 功能需求：基础 GPS + RTK 高精度 + 多频 GNSS
- 输出目录：~/px4agent/src/drivers/gps/（默认）

**生成的文件**：同上，但包含 RTK 配置和 RTCM 校正数据处理

### 示例 3：生成 Septentrio mosaic-X5 Ethernet 驱动

```bash
/px4-gnss-gen mosaic-X5 Ethernet
```

**用户输入**：
- 芯片型号：mosaic-X5
- 总线类型：Ethernet
- 功能需求：工业级 RTK + 抗干扰
- 输出目录：~/px4agent/src/drivers/gps/（默认）

**生成的文件**：同上，但使用 Ethernet 通信

### 示例 4：生成 Emlid Reach M+ UART 驱动

```bash
/px4-gnss-gen Reach-M+ UART
```

**用户输入**：
- 芯片型号：Reach-M+
- 总线类型：UART
- UART 波特率：115200（默认）
- 功能需求：基础 GPS + RTK
- 输出目录：~/px4agent/src/drivers/gps/（默认）

**生成的文件**：同上

### 示例 5：添加新芯片到库

编辑 `.claude/skills/px4-gnss-gen/chip_library.json`，添加新芯片：

```json
{
  "Garmin-GNSS-18x": {
    "manufacturer": "Garmin",
    "bus_types": ["UART"],
    "default_uart_baudrate": 9600,
    "protocol": "NMEA",
    "sample_rate_max": 1,
    "rtk_capable": false,
    "multi_frequency": false,
    "registers": {
      "NMEA_TALKER_ID": "GP"
    }
  }
}
```

下次运行时，新芯片自动可用：

```bash
/px4-gnss-gen Garmin-GNSS-18x UART
```

### 示例 6：生成自定义 GNSS 接收机驱动

```bash
/px4-gnss-gen 自定义接收机 UART
```

**用户输入**：
- 芯片型号：自定义接收机
- 总线类型：UART
- UART 波特率：115200
- 协议类型：NMEA / UBX / 其他
- 功能需求：基础 GPS
- 输出目录：~/px4agent/src/drivers/gps/（默认）

**生成的文件**：同上，使用通用模板
