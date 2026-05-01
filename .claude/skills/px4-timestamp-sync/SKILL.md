---
name: px4-timestamp-sync
version: "1.0.0"
description: PX4 精准时间戳处理与同步 - 实现多传感器时间戳对齐、同步机制、精度验证和时间戳校准。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

PX4 精准时间戳处理与同步：$ARGUMENTS

实现 PX4 中的精准时间戳处理、多传感器同步、时间戳校准和精度验证。

---

## 时间戳处理的核心概念

### 1. PX4 时间戳系统

PX4 使用 **微秒级精度** 的单调时钟：

```cpp
// 获取当前时间戳（微秒）
uint64_t timestamp = hrt_absolute_time();

// 时间戳精度：1 微秒 (1 µs)
// 范围：0 ~ 2^64 微秒 ≈ 584,942 年
```

### 2. 时间戳来源

| 来源 | 精度 | 用途 |
|------|------|------|
| **hrt_absolute_time()** | 1 µs | 驱动层、传感器读取 |
| **系统时钟** | 1 ms | 应用层、日志 |
| **GPS 时间** | 1 ns | 高精度定位 |
| **PPS 信号** | 1 ns | 硬件同步 |

### 3. 时间戳同步问题

**常见问题**：
- 传感器读取延迟不一致
- 多传感器时间戳偏差
- 时间戳回溯（时间倒流）
- 时间戳跳变（时间跳跃）

---

## 第一步：时间戳同步机制设计

### 1.1 传感器时间戳对齐

**问题**：不同传感器的读取时间不同

```cpp
// ❌ 错误做法：直接使用读取时的时间戳
sensor_accel_s accel;
accel.timestamp = hrt_absolute_time();  // 读取时间
read_accel_data(accel.x, accel.y, accel.z);  // 实际测量时间更早

// ✅ 正确做法：使用测量时间戳
sensor_accel_s accel;
read_accel_data(accel.x, accel.y, accel.z);
accel.timestamp = hrt_absolute_time();  // 读取完成时间
// 或者从硬件获取测量时间戳
```

### 1.2 多传感器时间戳同步

**方案 A：中央时间戳同步器**

```cpp
class TimestampSynchronizer {
public:
    // 注册传感器
    void register_sensor(const char *name, uint32_t expected_rate_hz);

    // 获取同步时间戳
    uint64_t get_synchronized_timestamp(const char *sensor_name);

    // 更新传感器时间戳
    void update_sensor_timestamp(const char *sensor_name, uint64_t timestamp);

private:
    struct SensorTimestamp {
        uint64_t last_timestamp;
        uint64_t expected_interval_us;
        int64_t offset_us;  // 与系统时间的偏差
        uint32_t missed_samples;
    };

    std::map<std::string, SensorTimestamp> _sensors;
};
```

**方案 B：硬件同步（PPS 信号）**

```cpp
// 使用 GPS PPS 信号同步所有传感器
class PPSSynchronizer {
public:
    void on_pps_signal(uint64_t pps_timestamp);
    uint64_t get_pps_aligned_timestamp();

private:
    uint64_t _last_pps_timestamp;
    uint64_t _pps_interval_us;  // 通常 1,000,000 µs (1 秒)
};
```

---

## 第二步：时间戳校准

### 2.1 时间戳偏差检测

```cpp
class TimestampCalibrator {
public:
    // 检测时间戳偏差
    int64_t detect_offset(const char *sensor_name, uint64_t expected_timestamp, uint64_t actual_timestamp);

    // 计算平均偏差
    int64_t get_average_offset(const char *sensor_name);

    // 应用校准
    uint64_t apply_calibration(const char *sensor_name, uint64_t raw_timestamp);

private:
    struct CalibrationData {
        std::vector<int64_t> offsets;  // 历史偏差
        int64_t average_offset;
        int64_t max_offset;
        int64_t min_offset;
    };

    std::map<std::string, CalibrationData> _calibrations;
};
```

### 2.2 时间戳精度验证

```cpp
class TimestampValidator {
public:
    // 检查时间戳有效性
    bool is_valid_timestamp(uint64_t timestamp, uint64_t last_timestamp);

    // 检查时间戳连续性
    bool check_continuity(uint64_t timestamp, uint64_t expected_interval_us);

    // 检查时间戳单调性
    bool check_monotonicity(uint64_t timestamp, uint64_t last_timestamp);

private:
    static constexpr uint64_t MAX_TIMESTAMP_JUMP = 1000000;  // 1 秒
    static constexpr uint64_t MAX_TIMESTAMP_BACKWARD = 1000;  // 1 ms
};
```

---

## 第三步：实现时间戳同步驱动

### 3.1 驱动头文件

```cpp
#pragma once

#include <px4_platform_common/px4_config.h>
#include <px4_platform_common/module.h>
#include <px4_platform_common/px4_work_queue/ScheduledWorkItem.hpp>
#include <drivers/drv_hrt.h>
#include <uORB/Subscription.hpp>
#include <uORB/Publication.hpp>
#include <uORB/topics/sensor_accel.h>
#include <uORB/topics/sensor_gyro.h>
#include <uORB/topics/sensor_mag.h>
#include <uORB/topics/sensor_baro.h>

using namespace time_literals;

class TimestampSyncModule : public px4::ScheduledWorkItem {
public:
    TimestampSyncModule();
    virtual ~TimestampSyncModule();

    static int task_spawn(int argc, char *argv[]);
    static int custom_command(int argc, char *argv[]);
    static int print_usage(const char *reason = nullptr);

    virtual int init();
    void print_status();

protected:
    virtual void RunImpl();

private:
    // 订阅传感器数据
    uORB::Subscription _accel_sub{ORB_ID(sensor_accel)};
    uORB::Subscription _gyro_sub{ORB_ID(sensor_gyro)};
    uORB::Subscription _mag_sub{ORB_ID(sensor_mag)};
    uORB::Subscription _baro_sub{ORB_ID(sensor_baro)};

    // 时间戳同步数据
    struct SensorTimestampData {
        uint64_t last_timestamp;
        uint64_t expected_interval_us;
        int64_t offset_us;
        uint32_t sample_count;
        uint32_t missed_samples;
    };

    SensorTimestampData _accel_ts{};
    SensorTimestampData _gyro_ts{};
    SensorTimestampData _mag_ts{};
    SensorTimestampData _baro_ts{};

    // 时间戳验证
    bool validate_timestamp(uint64_t timestamp, uint64_t last_timestamp, uint64_t expected_interval_us);

    // 时间戳校准
    int64_t calibrate_timestamp(const char *sensor_name, uint64_t timestamp);

    // 性能计数
    perf_counter_t _sync_perf{perf_alloc(PC_ELAPSED, "timestamp_sync")};
    perf_counter_t _timestamp_errors{perf_alloc(PC_COUNT, "timestamp_errors")};
};
```

### 3.2 驱动实现

```cpp
#include "timestamp_sync.hpp"

TimestampSyncModule::TimestampSyncModule()
    : ScheduledWorkItem(MODULE_NAME, px4::wq_configurations::hp_default) {
}

TimestampSyncModule::~TimestampSyncModule() {
    perf_free(_sync_perf);
    perf_free(_timestamp_errors);
}

int TimestampSyncModule::init() {
    // 初始化传感器预期采样率
    _accel_ts.expected_interval_us = 1000000 / 1000;  // 1000 Hz
    _gyro_ts.expected_interval_us = 1000000 / 1000;   // 1000 Hz
    _mag_ts.expected_interval_us = 1000000 / 50;      // 50 Hz
    _baro_ts.expected_interval_us = 1000000 / 50;     // 50 Hz

    ScheduleOnInterval(10_ms);  // 100 Hz 检查
    return PX4_OK;
}

void TimestampSyncModule::RunImpl() {
    perf_begin(_sync_perf);

    // 检查加速度计时间戳
    sensor_accel_s accel;
    if (_accel_sub.update(&accel)) {
        if (!validate_timestamp(accel.timestamp, _accel_ts.last_timestamp, _accel_ts.expected_interval_us)) {
            perf_count(_timestamp_errors);
            PX4_WARN("Accel timestamp error: %llu (expected interval: %llu)",
                     accel.timestamp - _accel_ts.last_timestamp, _accel_ts.expected_interval_us);
        }
        _accel_ts.last_timestamp = accel.timestamp;
        _accel_ts.sample_count++;
    }

    // 检查陀螺仪时间戳
    sensor_gyro_s gyro;
    if (_gyro_sub.update(&gyro)) {
        if (!validate_timestamp(gyro.timestamp, _gyro_ts.last_timestamp, _gyro_ts.expected_interval_us)) {
            perf_count(_timestamp_errors);
        }
        _gyro_ts.last_timestamp = gyro.timestamp;
        _gyro_ts.sample_count++;
    }

    // 检查磁力计时间戳
    sensor_mag_s mag;
    if (_mag_sub.update(&mag)) {
        if (!validate_timestamp(mag.timestamp, _mag_ts.last_timestamp, _mag_ts.expected_interval_us)) {
            perf_count(_timestamp_errors);
        }
        _mag_ts.last_timestamp = mag.timestamp;
        _mag_ts.sample_count++;
    }

    // 检查气压计时间戳
    sensor_baro_s baro;
    if (_baro_sub.update(&baro)) {
        if (!validate_timestamp(baro.timestamp, _baro_ts.last_timestamp, _baro_ts.expected_interval_us)) {
            perf_count(_timestamp_errors);
        }
        _baro_ts.last_timestamp = baro.timestamp;
        _baro_ts.sample_count++;
    }

    perf_end(_sync_perf);
}

bool TimestampSyncModule::validate_timestamp(uint64_t timestamp, uint64_t last_timestamp, uint64_t expected_interval_us) {
    // 检查时间戳单调性（不能倒流）
    if (timestamp < last_timestamp) {
        PX4_ERR("Timestamp went backward: %llu -> %llu", last_timestamp, timestamp);
        return false;
    }

    // 检查时间戳跳变
    if (last_timestamp > 0) {
        uint64_t actual_interval = timestamp - last_timestamp;
        uint64_t tolerance = expected_interval_us / 2;  // ±50% 容差

        if (actual_interval < (expected_interval_us - tolerance) ||
            actual_interval > (expected_interval_us + tolerance)) {
            PX4_WARN("Timestamp interval out of range: %llu (expected: %llu ± %llu)",
                     actual_interval, expected_interval_us, tolerance);
            return false;
        }
    }

    return true;
}

void TimestampSyncModule::print_status() {
    PX4_INFO("Timestamp Sync Status:");
    PX4_INFO("  Accel samples: %u, errors: %u", _accel_ts.sample_count, _accel_ts.missed_samples);
    PX4_INFO("  Gyro samples: %u, errors: %u", _gyro_ts.sample_count, _gyro_ts.missed_samples);
    PX4_INFO("  Mag samples: %u, errors: %u", _mag_ts.sample_count, _mag_ts.missed_samples);
    PX4_INFO("  Baro samples: %u, errors: %u", _baro_ts.sample_count, _baro_ts.missed_samples);
    perf_print_counter(_sync_perf);
    perf_print_counter(_timestamp_errors);
}
```

---

## 第四步：时间戳精度验证

### 4.1 时间戳精度测试

```cpp
class TimestampPrecisionTest {
public:
    // 测试时间戳精度
    void test_timestamp_precision() {
        uint64_t t1 = hrt_absolute_time();
        uint64_t t2 = hrt_absolute_time();

        // 应该至少相差 1 µs
        assert(t2 >= t1);
        PX4_INFO("Timestamp precision: %llu µs", t2 - t1);
    }

    // 测试时间戳单调性
    void test_timestamp_monotonicity() {
        uint64_t last_ts = 0;
        for (int i = 0; i < 1000; i++) {
            uint64_t ts = hrt_absolute_time();
            assert(ts >= last_ts);  // 时间戳必须单调递增
            last_ts = ts;
        }
        PX4_INFO("Timestamp monotonicity: OK");
    }

    // 测试时间戳稳定性
    void test_timestamp_stability() {
        std::vector<uint64_t> intervals;
        uint64_t last_ts = hrt_absolute_time();

        for (int i = 0; i < 100; i++) {
            uint64_t ts = hrt_absolute_time();
            intervals.push_back(ts - last_ts);
            last_ts = ts;
        }

        // 计算标准差
        double mean = 0;
        for (auto interval : intervals) {
            mean += interval;
        }
        mean /= intervals.size();

        double variance = 0;
        for (auto interval : intervals) {
            variance += (interval - mean) * (interval - mean);
        }
        variance /= intervals.size();

        double stddev = sqrt(variance);
        PX4_INFO("Timestamp stability: mean=%.2f µs, stddev=%.2f µs", mean, stddev);
    }
};
```

---

## 第五步：时间戳同步最佳实践

### 5.1 驱动层时间戳处理

```cpp
// ✅ 正确做法
void sensor_driver::RunImpl() {
    // 1. 记录读取开始时间
    uint64_t read_start = hrt_absolute_time();

    // 2. 读取传感器数据
    int16_t raw_x, raw_y, raw_z;
    read_sensor_data(raw_x, raw_y, raw_z);

    // 3. 记录读取完成时间（更准确）
    uint64_t read_end = hrt_absolute_time();

    // 4. 使用读取完成时间作为时间戳
    sensor_accel_s accel{};
    accel.timestamp = read_end;
    accel.x = raw_x / 1000.0f;
    accel.y = raw_y / 1000.0f;
    accel.z = raw_z / 1000.0f;

    // 5. 发布数据
    _accel_pub.publish(accel);
}
```

### 5.2 多传感器同步

```cpp
// ✅ 多传感器时间戳对齐
class MultiSensorSync {
public:
    void sync_sensors() {
        // 获取所有传感器的最新数据
        sensor_accel_s accel;
        sensor_gyro_s gyro;
        sensor_mag_s mag;

        _accel_sub.copy(&accel);
        _gyro_sub.copy(&gyro);
        _mag_sub.copy(&mag);

        // 计算时间戳偏差
        uint64_t accel_ts = accel.timestamp;
        uint64_t gyro_ts = gyro.timestamp;
        uint64_t mag_ts = mag.timestamp;

        // 使用最新的时间戳作为参考
        uint64_t ref_ts = std::max({accel_ts, gyro_ts, mag_ts});

        // 计算每个传感器的延迟
        int64_t accel_delay = ref_ts - accel_ts;
        int64_t gyro_delay = ref_ts - gyro_ts;
        int64_t mag_delay = ref_ts - mag_ts;

        PX4_DEBUG("Sensor delays: accel=%lld µs, gyro=%lld µs, mag=%lld µs",
                  accel_delay, gyro_delay, mag_delay);
    }
};
```

### 5.3 时间戳日志记录

```cpp
// ✅ 时间戳日志记录
void log_with_timestamp(const char *message, uint64_t timestamp) {
    // 计算时间戳距离启动的时间
    static uint64_t start_time = hrt_absolute_time();
    uint64_t elapsed = timestamp - start_time;

    // 转换为秒和毫秒
    uint32_t seconds = elapsed / 1000000;
    uint32_t milliseconds = (elapsed % 1000000) / 1000;

    PX4_INFO("[%u.%03u] %s", seconds, milliseconds, message);
}
```

---

## 第六步：时间戳同步诊断

### 6.1 诊断命令

```bash
# 启动时间戳同步模块
timestamp_sync start

# 查看时间戳同步状态
timestamp_sync status

# 打印时间戳统计信息
timestamp_sync stats

# 验证时间戳精度
timestamp_sync test_precision

# 验证时间戳单调性
timestamp_sync test_monotonicity

# 验证时间戳稳定性
timestamp_sync test_stability
```

### 6.2 时间戳错误排查

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| 时间戳倒流 | 硬件时钟异常 | 检查系统时钟、重启飞控 |
| 时间戳跳变 | 中断延迟过长 | 优化中断处理、提高优先级 |
| 时间戳偏差大 | 传感器读取延迟不一致 | 使用硬件同步（PPS）、校准偏差 |
| 时间戳缺失 | 传感器数据丢失 | 检查总线连接、增加缓冲区 |

---

## 使用示例

### 示例 1：启动时间戳同步

```bash
# 启动时间戳同步模块
timestamp_sync start

# 查看状态
timestamp_sync status

# 输出示例：
# Timestamp Sync Status:
#   Accel samples: 1000, errors: 0
#   Gyro samples: 1000, errors: 0
#   Mag samples: 200, errors: 0
#   Baro samples: 200, errors: 0
```

### 示例 2：验证时间戳精度

```bash
# 运行精度测试
timestamp_sync test_precision

# 输出示例：
# Timestamp precision: 1 µs
# Timestamp monotonicity: OK
# Timestamp stability: mean=1.05 µs, stddev=0.23 µs
```

### 示例 3：诊断时间戳问题

```bash
# 如果发现时间戳错误
# 1. 检查传感器连接
# 2. 验证时间戳精度
# 3. 查看时间戳统计
timestamp_sync stats

# 4. 如果需要校准，运行校准程序
timestamp_sync calibrate
```

---

## 编码规范

- 禁止在驱动层使用系统时钟，只用 `hrt_absolute_time()`
- 时间戳必须在数据读取完成后立即记录
- 时间戳必须进行单调性检查
- 时间戳偏差必须进行校准和验证
- 时间戳错误必须进行日志记录和统计
