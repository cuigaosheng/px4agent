---
name: setup-px4
version: "1.0.0"
description: 在 WSL2/Ubuntu 22.04 上安装 PX4 工具链并编译 SITL 目标（Windows 和 Linux 通用）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
安装 PX4 工具链并编译 SITL：$ARGUMENTS

适用于 WSL2 内的 Ubuntu 22.04 或原生 Ubuntu 22.04。以下所有命令均在 **WSL/Linux 终端**中执行。

---

## 第一步：检测已有组件

```bash
# [WSL/Linux] 检测工具链
echo "--- 基础工具 ---"
which git cmake ninja python3 pip3 2>/dev/null || echo "部分工具缺失"

echo "--- 交叉编译器 ---"
arm-none-eabi-gcc --version 2>/dev/null | head -1 || echo "arm-none-eabi-gcc 未安装"

echo "--- PX4 源码 ---"
ls ~/PX4-Autopilot/CMakeLists.txt 2>/dev/null && echo "源码已存在" || echo "源码未下载"

echo "--- 已有编译产物 ---"
ls ~/PX4-Autopilot/build/px4_sitl_default/bin/px4 2>/dev/null && echo "SITL 已编译" || echo "SITL 未编译"
```

**判断逻辑**：
- SITL 已编译（`build/px4_sitl_default/bin/px4` 存在）→ **直接报告跳过，退出**
- 源码已存在但未编译 → 跳到第三步（安装工具链后编译）
- 源码和工具链均缺失 → 从第二步开始完整安装

---

## 第二步：安装系统依赖

```bash
# [WSL/Linux] 安装编译 PX4 所需的系统包
sudo apt update
sudo apt install -y \
    git curl wget python3 python3-pip python3-venv \
    cmake ninja-build build-essential \
    gcc-multilib g++-multilib \
    libssl-dev libusb-1.0-0-dev \
    pkg-config zip unzip \
    ccache

# 安装 ARM 交叉编译器（飞控固件编译用）
sudo apt install -y gcc-arm-none-eabi binutils-arm-none-eabi
```

---

## 第三步：克隆 PX4 源码

```bash
# [WSL/Linux] 克隆 PX4 v1.15.0（已确认适用版本）
cd ~
git clone https://github.com/PX4/PX4-Autopilot.git --branch v1.15.0 --depth 1
cd PX4-Autopilot
git submodule update --init --recursive
```

**网络慢时替代方案**：

```bash
# 使用国内镜像（若 GitHub 访问慢）
git clone https://gitee.com/PX4/PX4-Autopilot.git --branch v1.15.0 --depth 1
```

克隆含子模块约需 10～30 分钟，根据网速不同。

---

## 第四步：运行 PX4 官方环境安装脚本

```bash
# [WSL/Linux] 运行官方依赖安装脚本（自动安装 Python 包、udev 规则等）
cd ~/PX4-Autopilot
bash ./Tools/setup/ubuntu.sh --no-nuttx
```

**重要**：脚本执行完成后，会提示将当前用户加入 `dialout` 组。**必须重新登录终端**（关闭并重开 WSL 窗口）使组权限生效：

```bash
# 重新登录后验证
groups | grep dialout  # 应输出包含 dialout
```

---

## 第五步：安装 Python 依赖

```bash
# [WSL/Linux] 安装 PX4 Python 工具依赖
cd ~/PX4-Autopilot
pip3 install --user -r Tools/setup/requirements.txt
```

---

## 第六步：编译 SITL 目标

```bash
# [WSL/Linux] 仅编译，不启动仿真（首次编译约需 15～30 分钟）
cd ~/PX4-Autopilot
DONT_RUN=1 make px4_sitl gazebo
```

**编译参数说明**：
- `DONT_RUN=1`：只编译不运行，避免在无显示器的环境中挂起
- `px4_sitl`：SITL 飞控固件目标
- `gazebo`：生成 Gazebo SITL 支持文件

加速编译（多核）：

```bash
# 使用 8 线程并行编译
DONT_RUN=1 make px4_sitl gazebo -j8
```

---

## 第七步：验证

```bash
# [WSL/Linux] 验证编译产物存在
ls ~/PX4-Autopilot/build/px4_sitl_default/bin/px4
ls ~/PX4-Autopilot/build/px4_sitl_default/etc/

# 验证基本运行（无 Gazebo，仅打印版本）
cd ~/PX4-Autopilot
./build/px4_sitl_default/bin/px4 --version
```

**成功标志**：
- `build/px4_sitl_default/bin/px4` 文件存在
- `px4 --version` 输出 `PX4 Autopilot v1.15.x`

---

## 常见报错

| 现象 | 原因 | 解决 |
|------|------|------|
| `ninja: build stopped: subcommand failed` | 编译错误 | 看上方具体报错行，通常是依赖缺失 |
| `ModuleNotFoundError: No module named 'xxx'` | Python 包缺失 | `pip3 install --user <module>` |
| `arm-none-eabi-gcc: command not found` | 交叉编译器未安装 | `sudo apt install gcc-arm-none-eabi` |
| 编译中途卡住不动 | 内存不足 | 增大 `.wslconfig` 中的 `memory` 值 |
| `git submodule update` 超时 | 网络问题 | 挂梯子或改用 gitee 镜像 |
| `make: gazebo: No such target` | 未安装 Gazebo | 先执行 `/setup-gazebo` |
