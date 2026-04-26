---
name: setup-gazebo
version: "1.0.0"
description: 安装 Gazebo Classic 11 并验证 PX4 SITL 图形仿真可用（WSL2 WSLg 或原生 Linux）。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
安装 Gazebo Classic 11 并验证 SITL 连通：$ARGUMENTS

以下所有命令均在 **WSL/Linux 终端**中执行。Windows 11 用户使用 WSLg 作为图形显示后端，无需额外配置 X Server。

---

## 第一步：检测 Gazebo 状态

```bash
# [WSL/Linux] 检测 Gazebo 是否已安装
echo "--- Gazebo 命令 ---"
which gazebo 2>/dev/null && gazebo --version 2>/dev/null | head -1 || echo "Gazebo 未安装"

echo "--- libgazebo11 开发库 ---"
dpkg -l libgazebo11-dev 2>/dev/null | grep -q "^ii" && echo "libgazebo11-dev 已安装" || echo "libgazebo11-dev 未安装"

echo "--- 图形显示环境 ---"
echo "DISPLAY=$DISPLAY"
echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
```

**判断逻辑**：
- `gazebo --version` 输出 `Gazebo 11.x.x` 且 `libgazebo11-dev` 已安装 → **报告跳过，退出**
- 部分安装 → 执行第三步补全
- 完全未安装 → 从第二步开始

---

## 第二步：添加 Gazebo apt 源

```bash
# [WSL/Linux] 添加 OSRF（Open Robotics）官方 apt 源
sudo sh -c 'echo "deb http://packages.osrfoundation.org/gazebo/ubuntu-stable `lsb_release -cs` main" > /etc/apt/sources.list.d/gazebo-stable.list'
wget -qO - https://packages.osrfoundation.org/gazebo.key | sudo apt-key add -
sudo apt update
```

**网络慢时替代**（使用国内镜像）：

```bash
# 直接跳过 OSRF 源，使用 Ubuntu 22.04 系统源里的 Gazebo 11
sudo apt update
# Ubuntu 22.04 自带的 Gazebo 11 版本可直接安装
```

---

## 第三步：安装 Gazebo Classic 11

```bash
# [WSL/Linux] 安装 Gazebo 11 完整包
sudo apt install -y gazebo11 libgazebo11-dev gazebo11-plugin-base

# 安装 PX4 仿真需要的额外插件
sudo apt install -y \
    ros-independent-gz-common \
    libgazebo-dev \
    libprotobuf-dev \
    libprotoc-dev \
    protobuf-compiler
```

**若上述 ROS-independent 包不存在，使用最小安装**：

```bash
sudo apt install -y gazebo11 libgazebo11-dev
```

---

## 第四步：配置图形显示（Windows 11 WSLg 验证）

```bash
# [WSL/Linux] 验证 WSLg 图形转发
echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
echo "DISPLAY=$DISPLAY"

# 测试图形显示（应打开一个空白 Gazebo 窗口）
timeout 5 gazebo --version 2>&1
```

**Windows 11 + WSLg**：
- `$WAYLAND_DISPLAY` 应为 `wayland-0`，`$DISPLAY` 应为 `:0`
- 无需额外安装 VcXsrv 或 X410，WSLg 内置图形转发

**原生 Ubuntu**：
- 确认 `$DISPLAY` 有值（如 `:0`）即可

若 WSLg 不可用（旧版 Windows 11）：

```bash
# 手动安装 VcXsrv（Windows 侧），然后在 WSL 中设置：
export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0
# 将此行加入 ~/.bashrc
```

---

## 第五步：设置环境变量

```bash
# [WSL/Linux] 将 Gazebo 环境变量加入 ~/.bashrc
cat >> ~/.bashrc << 'EOF'

# Gazebo Classic 11 环境
source /usr/share/gazebo/setup.sh
export GAZEBO_PLUGIN_PATH=$GAZEBO_PLUGIN_PATH:~/PX4-Autopilot/build/px4_sitl_default/build_gazebo-classic
export GAZEBO_MODEL_PATH=$GAZEBO_MODEL_PATH:~/PX4-Autopilot/Tools/simulation/gazebo-classic/sitl_gazebo-classic/models
EOF

source ~/.bashrc
```

---

## 第六步：验证

```bash
# [WSL/Linux] 验证 Gazebo 版本
gazebo --version
# 期望输出：Gazebo multi-robot simulator, version 11.x.x

# 验证库文件
dpkg -l libgazebo11-dev | grep "^ii"
# 期望输出：ii  libgazebo11-dev  11.x.x  ...

# 完整验证：启动 PX4 SITL + Gazebo（需要已安装 PX4）
# cd ~/PX4-Autopilot && make px4_sitl gazebo
# 成功标志：Gazebo 窗口打开，出现 iris 四旋翼模型
```

**成功标志**：
- `gazebo --version` 输出 `version 11.x.x`
- 启动 `make px4_sitl gazebo` 后 Gazebo 窗口出现

---

## 常见报错

| 现象 | 原因 | 解决 |
|------|------|------|
| `gazebo: command not found` | 安装未完成 | 重新执行第三步 |
| Gazebo 窗口黑屏或不出现 | WSLg 未就绪 | 关闭终端重新打开；或更新 Windows 11 |
| `libgazebo.so: cannot open` | 环境变量未加载 | `source /usr/share/gazebo/setup.sh` |
| `make px4_sitl gazebo` 报插件错 | GAZEBO_PLUGIN_PATH 未设置 | 重新 `source ~/.bashrc` 后再 make |
| DISPLAY 未设置 | 非桌面环境 | 确认 WSLg 已启用或手动设置 DISPLAY |
