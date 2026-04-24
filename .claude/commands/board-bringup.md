在 PX4 中添加自定义飞控硬件（Board Bring-up）：$ARGUMENTS

请严格按以下步骤执行，**每步完成后汇报进度并等待用户确认再继续**。

## 项目路径
- PX4 源码：`C:/Users/cuiga/droneyee_px4v1.15.0`（WSL 内：`~/droneyee_px4v1.15.0`）
- Board 目录：`boards/<vendor>/<board>/`
- NuttX 配置：`boards/<vendor>/<board>/nuttx-config/`
- 驱动目录：`src/drivers/`
- 平台定义：`platforms/nuttx/`

---

## 第一步：确认需求

询问用户：
1. **硬件基础**：
   - 基于哪款 MCU（STM32F7 / STM32H7 / STM32F4）
   - 参考哪款官方板（Pixhawk 4 / 6C / Cube Orange）
   - 主要差异（更换传感器 / 增减接口 / 自定义 IO）
2. **差异化配置**：
   - 传感器变更（IMU / 气压计 / 磁力计）
   - 接口变更（UART 数量 / SPI 总线 / I2C 总线 / CAN 口）
   - 特殊硬件（自定义 ADC / 光流 / 激光雷达接口）
3. **工作量评估**：
   - 最小改动（继承参考板，修改引脚/传感器）
   - 全新设计（全部从头定义）

---

## 第二步：理解 PX4 Board 目录结构

```
boards/<vendor>/<board>/
├── CMakeLists.txt          # 编译配置（驱动使能、模块选择）
├── default.cmake           # 编译目标 make px4_<board>_default
├── board_config.h          # 引脚定义（SPI/I2C/UART/GPIO）
├── init/                   # 启动脚本（rcS 机型选择）
│   └── rc.board_defaults   # Board 级参数默认值
├── nuttx-config/           # NuttX 内核配置
│   ├── nsh/                # 正常运行配置
│   │   ├── defconfig       # menuconfig 导出的配置
│   │   └── Make.defs
│   └── bootloader/         # Bootloader 配置
├── src/                    # Board 专用驱动（可选）
└── module.yaml             # Board 级参数定义
```

---

## 第三步：基于参考板创建新 Board

### 3a 复制参考板目录

```bash
cd ~/droneyee_px4v1.15.0

# 以 Pixhawk 4（px4_fmu-v5）为参考板
# 创建自定义 board：vendor=droneyee, board=v1
cp -r boards/px4/fmu-v5 boards/droneyee/v1

# 重命名关键文件
cd boards/droneyee/v1
mv px4fmu-v5_default.cmake droneyee_v1_default.cmake
```

### 3b 修改 CMakeLists.txt

```cmake
# boards/droneyee/v1/CMakeLists.txt
px4_add_board(
    PLATFORM nuttx
    VENDOR droneyee
    MODEL v1
    LABEL default
    TOOLCHAIN arm-none-eabi
    ARCHITECTURE cortex-m7        # MCU 核心（F7/H7→m7，F4→m4）
    ROMFSROOT px4fmu_common       # 使用通用 ROMFS

    # ── 驱动使能（选择本板支持的驱动）──
    DRIVERS
        adc/board_adc
        barometer/ms5611            # 更换气压计：改为 bmp388
        imu/bmi088                  # 主 IMU
        imu/icm42688p               # 备 IMU（若有）
        magnetometer/ist8310        # 磁力计
        gps
        pwm_out
        uavcan                      # 若有 CAN 口

    # ── 模块使能 ──
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
        land_detector

    # ── 系统命令 ──
    SYSTEMCMDS
        param
        reboot
        top
        ver
        listener
)
```

---

## 第四步：修改引脚定义（board_config.h）

```c
/* boards/droneyee/v1/board_config.h */
#pragma once

#include <px4_platform_common/px4_config.h>

/* ── SPI 总线定义 ──
 * SPI1：IMU（高速，板载）
 * SPI2：传感器备用
 */
#define PX4_SPI_BUS_SENSORS     1
#define PX4_SPI_BUS_BARO        2

/* ── SPI 片选引脚 ──
 * 格式：PX4_MK_GPIO(端口, 引脚编号)
 */
#define PX4_SPIDEV_ICM42688     PX4_MK_GPIO(GPIO_PORTA, 4)   // PA4
#define PX4_SPIDEV_BMI088_GYRO  PX4_MK_GPIO(GPIO_PORTB, 0)   // PB0
#define PX4_SPIDEV_BMI088_ACC   PX4_MK_GPIO(GPIO_PORTB, 1)   // PB1
#define PX4_SPIDEV_MS5611       PX4_MK_GPIO(GPIO_PORTC, 2)   // PC2

/* ── I2C 总线定义 ──
 * I2C1：外部传感器（GPS、罗盘）
 * I2C2：内部传感器
 */
#define PX4_I2C_BUS_EXPANSION   1
#define PX4_I2C_BUS_ONBOARD     2

/* ── UART 分配 ──
 * UART1：GPS（115200）
 * UART2：遥控器（SBUS/CRSF）
 * UART3：数传（MAVLink）
 * UART4：外部 MAVLink 或调试
 */
#define GPS_DEFAULT_UART_PORT   "/dev/ttyS0"    // UART1
#define RC_SERIAL_PORT          "/dev/ttyS1"    // UART2（SBUS）
#define MAVLINK_UART_PORT       "/dev/ttyS2"    // UART3

/* ── CAN 接口 ──*/
#define HW_CAN1_GPIO            GPIO_CAN1_TX | GPIO_CAN1_RX

/* ── ADC 通道 ──
 * ADC1_IN10：电池电压
 * ADC1_IN11：电池电流
 */
#define ADC_BATTERY_VOLTAGE_CHANNEL    10
#define ADC_BATTERY_CURRENT_CHANNEL    11

/* ── LED ──*/
#define BOARD_HAS_LED           1
#define GPIO_nLED_RED           (GPIO_OUTPUT | GPIO_PORTD | GPIO_PIN15)
#define GPIO_nLED_GREEN         (GPIO_OUTPUT | GPIO_PORTD | GPIO_PIN13)
#define GPIO_nLED_BLUE          (GPIO_OUTPUT | GPIO_PORTD | GPIO_PIN14)

/* ── 安全开关 ──*/
#define SAFETY_SWITCH_GPIO      (GPIO_INPUT | GPIO_PORTC | GPIO_PIN5)

/* ── 电机输出 PWM ──
 * TIM1：MAIN 输出（4路）
 * TIM4：AUX 输出（4路）
 */
#define DIRECT_PWM_OUTPUT_CHANNELS  8
```

---

## 第五步：配置 NuttX（nuttx-config/nsh/defconfig）

主要关注以下配置项（使用 `make <board> menuconfig` 图形化修改）：

```bash
# WSL 内执行
cd ~/droneyee_px4v1.15.0
make droneyee_v1_default menuconfig
```

**关键配置项**：

```ini
# ── 时钟频率（根据 MCU 型号）──
CONFIG_STM32H7_HSE_FREQUENCY=16000000   # 外部晶振频率（Hz）
CONFIG_STM32H7_SYSCLK_FREQUENCY=480000000  # 系统时钟 480MHz（H7）

# ── UART 使能 ──
CONFIG_STM32H7_USART1=y    # GPS
CONFIG_STM32H7_USART2=y    # RC
CONFIG_STM32H7_USART3=y    # MAVLink

# ── SPI 使能 ──
CONFIG_STM32H7_SPI1=y
CONFIG_STM32H7_SPI2=y

# ── I2C 使能 ──
CONFIG_STM32H7_I2C1=y
CONFIG_STM32H7_I2C2=y

# ── CAN（FDCAN）──
CONFIG_STM32H7_FDCAN1=y

# ── DMA 使能（高速传感器必须）──
CONFIG_STM32H7_DMA1=y
CONFIG_STM32H7_DMA2=y

# ── 文件系统 ──
CONFIG_FS_FAT=y            # SD 卡（日志存储）
CONFIG_MMCSD_SPI=y         # SPI 接 SD 卡（或 SDIO）
```

---

## 第六步：编写启动脚本（Board 默认参数）

```bash
# boards/droneyee/v1/init/rc.board_defaults
#!/bin/sh
# Board 级默认参数（覆盖 PX4 通用默认值）

# 电池配置
param set BAT_N_CELLS 4        # 4S 电池
param set BAT_V_CHARGED 4.20   # 单体满电压

# 传感器配置（根据实际硬件）
param set SENS_IMU_AUTOCAL 1   # 自动 IMU 校准
param set CAL_GYRO0_ID 1376264 # 陀螺仪 0 ID（实际值在首次启动后获取）

# 执行器配置
param set PWM_MAIN_MIN 1000
param set PWM_MAIN_MAX 2000
param set PWM_MAIN_DISARM 900

# 机架（四旋翼 X 型）
param set SYS_AUTOSTART 4001
```

---

## 第七步：编译与烧录

```bash
# WSL 内编译
cd ~/droneyee_px4v1.15.0

# 首次编译（生成所有构建文件）
make droneyee_v1_default

# 编译并烧录（飞控通过 USB 连接）
make droneyee_v1_default upload

# 烧录 Bootloader（若飞控是全新 MCU，先烧录 Bootloader）
make droneyee_v1_bootloader
make droneyee_v1_bootloader upload
```

---

## 第八步：首次上电验证检查清单

### 8a 基础系统验证

```bash
# 在 QGC MAVLink Console 或串口终端执行

# 1. 确认固件版本和 Board 信息
ver all
# 输出应包含：droneyee_v1，固件版本，编译时间

# 2. 查看所有检测到的传感器
sensors status
# 应显示 IMU、气压计、磁力计等

# 3. 验证 IMU 数据
listener sensor_accel_fifo    # 加速度计
listener sensor_gyro_fifo     # 陀螺仪
# 加速度计静止时 Z 轴应约为 9.8 m/s²，X/Y 约为 0

# 4. 验证气压计
listener sensor_baro
# 气压值应符合当地大气压（约 101325 Pa 海平面）

# 5. 验证磁力计
listener sensor_mag
# 应有数据输出，方向与实际一致
```

### 8b 通信接口验证

```bash
# GPS（若已连接）
listener vehicle_gps_position
# 应有卫星数量和定位数据

# MAVLink 链路
mavlink status
# 应显示连接的通道和 stream

# CAN 总线（若有设备）
uavcan status
# 应显示在线节点
```

### 8c 执行器验证（拆除螺旋桨）

```bash
# 查看 PWM 输出配置
pwm info
# 确认通道数量和频率

# 解锁并测试电机
commander arm --force    # 强制解锁（仅调试）
actuator_test set -m 1 -v 0.2 -t 1
actuator_test set -m 2 -v 0.2 -t 1
commander disarm
```

### 8d 传感器校准

```bash
# 在 QGC 中执行（Vehicle Setup → Sensors）
# 1. 陀螺仪校准（静置 5 秒）
# 2. 加速度计校准（6 面校准）
# 3. 磁力计校准（旋转校准）
# 4. 地平线校准（调整安装水平）

# 校准后验证
listener estimator_sensor_bias    # 检查校准偏差值
```

---

## 常见问题排查

| 现象 | 原因 | 解决 |
|------|------|------|
| 编译报 `No such board` | CMakeLists.txt 路径错误 | 检查 `boards/<vendor>/<model>/` 目录名 |
| 传感器无法识别 | SPI/I2C 引脚定义错误 | 用示波器验证总线信号，检查 board_config.h |
| IMU 数据全为零 | 片选引脚未使能 | 检查 `PX4_SPIDEV_*` GPIO 定义 |
| UART 无数据 | NuttX 未使能对应 UART | `make menuconfig` 检查 UART 配置 |
| 上传失败 | Bootloader 版本不匹配 | 先烧录匹配的 Bootloader |
| 系统时钟异常 | 外部晶振频率配置错误 | 确认 `CONFIG_STM32H7_HSE_FREQUENCY` |
| SD 卡无法挂载 | SDIO/SPI SD 配置不对 | 检查 `CONFIG_MMCSD_*` NuttX 配置 |

---

## 编码规范（Board 开发）
- 引脚定义必须在 `board_config.h` 中集中管理，禁止在驱动中硬编码引脚
- 新增驱动在 `CMakeLists.txt` 的 `DRIVERS` 列表中注册，不得直接修改驱动源码
- Board 默认参数在 `rc.board_defaults` 定义，不得修改通用 `rcS`
- `defconfig` 修改必须通过 `menuconfig` 导出，禁止手动编辑 defconfig 文件
- 所有 Board 级参数必须在 `module.yaml` 中定义范围和单位
- 首次上电前必须完成 8 项验证检查清单，不得跳过传感器校准
