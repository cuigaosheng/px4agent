---
name: px4-board-bringup
version: "1.0.0"
description: 在 PX4 中添加自定义飞控硬件（板级支持、引脚、NuttX、驱动、校准）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
在 PX4 中添加自定义飞控硬件（Board Bring-up）：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 源码：`~/px4agent`
- Board 目录：`boards/<vendor>/<board>/`
- NuttX 配置：`boards/<vendor>/<board>/nuttx-config/`
- 驱动目录：`src/drivers/`
- 平台定义：`platforms/nuttx/`

---

## 第一步：确认需求

询问用户：
1. **硬件基础**：基于哪款 MCU（STM32F7/H7/F4）、参考哪款官方板、主要差异
2. **差异化配置**：传感器变更 / 接口变更 / 特殊硬件
3. **工作量评估**：最小改动（继承参考板）/ 全新设计

---

## 第二步：理解 PX4 Board 目录结构

```
boards/<vendor>/<board>/
├── CMakeLists.txt          # 编译配置（驱动使能、模块选择）
├── default.cmake           # 编译目标 make px4_<board>_default
├── board_config.h          # 引脚定义（SPI/I2C/UART/GPIO）
├── init/
│   └── rc.board_defaults   # Board 级参数默认值
├── nuttx-config/
│   ├── nsh/
│   │   ├── defconfig       # menuconfig 导出的配置
│   │   └── Make.defs
│   └── bootloader/
└── module.yaml             # Board 级参数定义
```

---

## 第三步：基于参考板创建新 Board

```bash
cd ~/px4agent
cp -r boards/px4/fmu-v5 boards/px4agent/v1
cd boards/px4agent/v1
mv px4fmu-v5_default.cmake px4agent_v1_default.cmake
```

修改 `CMakeLists.txt`：
```cmake
px4_add_board(
    PLATFORM nuttx
    VENDOR px4agent
    MODEL v1
    LABEL default
    TOOLCHAIN arm-none-eabi
    ARCHITECTURE cortex-m7
    ROMFSROOT px4fmu_common
    DRIVERS
        imu/icm42688p
        barometer/bmp388
        magnetometer/ist8310
        gps
        pwm_out
    MODULES
        ekf2
        mc_att_control
        mc_rate_control
        mc_pos_control
        commander
        navigator
        mavlink
        sensors
        control_allocator
)
```

---

## 第四步：修改引脚定义（board_config.h）

```c
#pragma once
#include <px4_platform_common/px4_config.h>

#define PX4_SPI_BUS_SENSORS     1
#define PX4_SPIDEV_ICM42688     PX4_MK_GPIO(GPIO_PORTA, 4)
#define PX4_I2C_BUS_EXPANSION   1
#define GPS_DEFAULT_UART_PORT   "/dev/ttyS0"
#define ADC_BATTERY_VOLTAGE_CHANNEL    10
#define ADC_BATTERY_CURRENT_CHANNEL    11
#define DIRECT_PWM_OUTPUT_CHANNELS  8
```

---

## 第五步：配置 NuttX

```bash
cd ~/px4agent
make px4agent_v1_default menuconfig
```

关键配置项（STM32H7 示例）：
```ini
CONFIG_STM32H7_HSE_FREQUENCY=16000000
CONFIG_STM32H7_SYSCLK_FREQUENCY=480000000
CONFIG_STM32H7_USART1=y
CONFIG_STM32H7_SPI1=y
CONFIG_STM32H7_I2C1=y
CONFIG_STM32H7_FDCAN1=y
CONFIG_FS_FAT=y
```

---

## 第六步：编写启动脚本

```bash
# boards/px4agent/v1/init/rc.board_defaults
param set BAT_N_CELLS 4
param set PWM_MAIN_MIN 1000
param set PWM_MAIN_MAX 2000
param set SYS_AUTOSTART 4001
```

---

## 第七步：编译与烧录

```bash
cd ~/px4agent
make px4agent_v1_default
make px4agent_v1_default upload
```

---

## 第八步：首次上电验证检查清单

```bash
ver all                       # 确认固件版本和 Board 信息
sensors status                # 查看所有检测到的传感器
listener sensor_accel_fifo    # 加速度计（静止时 Z ≈ 9.8）
listener sensor_gyro_fifo     # 陀螺仪
listener sensor_baro          # 气压计
listener vehicle_gps_position # GPS
mavlink status                # MAVLink 链路
pwm info                      # PWM 输出配置
```

---

## 编码规范（Board 开发）
- 引脚定义必须在 `board_config.h` 中集中管理，禁止在驱动中硬编码引脚
- 新增驱动在 `CMakeLists.txt` 的 `DRIVERS` 列表中注册
- Board 默认参数在 `rc.board_defaults` 定义，不得修改通用 `rcS`
- `defconfig` 修改必须通过 `menuconfig` 导出，禁止手动编辑
- 首次上电前必须完成 8 项验证检查清单，不得跳过传感器校准
