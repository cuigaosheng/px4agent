---
name: setup-qgc
version: "1.0.0"
description: 安装 QGroundControl 并配置 WSL2/Linux 到 Windows 的 MAVLink 网络连通。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
安装 QGroundControl 并打通 MAVLink 网络：$ARGUMENTS

---

## 第一步：检测 QGC 安装状态

### Windows 11

```powershell
# [PowerShell] 检测 QGC 是否已安装
$paths = @(
    "$env:LOCALAPPDATA\Programs\QGroundControl\QGroundControl.exe",
    "C:\Program Files\QGroundControl\QGroundControl.exe",
    "$env:ProgramFiles\QGroundControl\QGroundControl.exe"
)
$found = $paths | Where-Object { Test-Path $_ }
if ($found) { Write-Host "QGC 已安装：$found" } else { Write-Host "QGC 未安装" }
```

### Ubuntu Linux

```bash
# [WSL/Linux] 检测 QGC AppImage
ls ~/QGroundControl.AppImage 2>/dev/null && echo "QGC 已安装" || echo "QGC 未安装"
which QGroundControl 2>/dev/null && echo "QGC 全局可用" || true
```

**判断逻辑**：
- QGC 已安装 → 跳到第三步（仅验证网络连通）
- 未安装 → 从第二步开始安装

---

## 第二步：安装 QGroundControl

### Windows 11（推荐）

```
1. 访问 QGC 官方下载页：https://docs.qgroundcontrol.com/master/en/getting_started/download_and_install.html
2. 下载 QGroundControl-installer.exe（v4.4 或最新稳定版）
3. 双击安装，默认路径即可
4. 安装完成后，桌面出现 QGroundControl 快捷方式
```

**注意**：QGC 在 Windows 侧运行，通过 UDP 14550 连接 WSL2 内的 PX4 SITL。

### Ubuntu Linux（AppImage）

```bash
# [WSL/Linux] 下载 QGC AppImage
cd ~
wget https://d176tv9ibo4jno.cloudfront.net/builds/master/QGroundControl.AppImage
chmod +x QGroundControl.AppImage

# 安装 FUSE（AppImage 运行依赖）
sudo apt install -y fuse libfuse2

# 运行（需要图形环境，原生 Ubuntu 或 WSLg）
./QGroundControl.AppImage
```

---

## 第三步：配置 WSL2 网络（Windows 11 + WSL2 必须执行）

WSL2 使用 NAT 网络，QGC（Windows 侧）无法直接访问 WSL2 内的 PX4 SITL。

### 方案 A：Mirrored 网络模式（Windows 11 22H2+ 推荐）

```powershell
# [PowerShell] 在 .wslconfig 中启用镜像网络（Windows 11 22H2+ 支持）
$wslconfig = Get-Content "$env:USERPROFILE\.wslconfig" -Raw
if ($wslconfig -notmatch "networkingMode") {
    Add-Content "$env:USERPROFILE\.wslconfig" "`n[wsl2]`nnetworkingMode=mirrored"
}
```

或手动编辑 `%USERPROFILE%\.wslconfig`，在 `[wsl2]` 节下添加：

```ini
[wsl2]
networkingMode=mirrored
```

然后重启 WSL：

```powershell
wsl --shutdown
```

**Mirrored 模式效果**：WSL2 与 Windows 共享同一 IP，QGC 直接连 `127.0.0.1:14550` 即可，无需额外配置。

### 方案 B：端口转发（Windows 11 旧版本回退方案）

```powershell
# [PowerShell 管理员] 获取 WSL2 当前 IP
$wslIp = (wsl hostname -I).Trim().Split(" ")[0]
Write-Host "WSL2 IP: $wslIp"

# 添加端口转发规则（将 Windows 14550 UDP 转发到 WSL2）
netsh interface portproxy add v4tov4 listenport=14550 listenaddress=0.0.0.0 connectport=14550 connectaddress=$wslIp

# 添加 Windows 防火墙规则
New-NetFirewallRule -DisplayName "PX4 SITL MAVLink" -Direction Inbound -Protocol UDP -LocalPort 14550 -Action Allow

# 验证端口转发规则
netsh interface portproxy show all
```

**注意**：WSL2 的 IP 在每次重启后会变化。如需持久化，可将上述命令写入开机脚本。

---

## 第四步：验证 MAVLink 网络连通

**验证步骤**：

1. 在 WSL/Linux 内启动 PX4 SITL：

```bash
# [WSL/Linux] 启动 SITL（不带 Gazebo，仅测试 MAVLink）
cd ~/PX4-Autopilot
make px4_sitl none_iris
```

2. 在 Windows 侧打开 QGroundControl。

3. QGC 默认监听 UDP 14550，SITL 启动后自动广播心跳。

**成功标志**：
- QGC 左上角出现 **飞机图标**
- 参数面板可加载（`Vehicle Parameters` 有内容）
- QGC 右上角显示 `Connected`

---

## 第五步：配置 QGC 手动添加连接（可选）

若 QGC 未自动连接，手动添加：

```
QGC → Application Settings → Comm Links → Add
  Type: UDP
  Listening Port: 14550
  Target Hosts: （留空，监听所有）
→ OK → Connect
```

---

## 常见报错

| 现象 | 原因 | 解决 |
|------|------|------|
| QGC 无法连接 SITL | WSL2 IP 变化，端口转发失效 | 重新执行方案 B，更新 WSL2 IP |
| QGC 连上但参数加载失败 | MAVLink 带宽不足 | 检查网络延迟，避免 VPN 干扰 |
| SITL 启动但 QGC 无反应 | 防火墙拦截 UDP 14550 | 执行方案 B 的防火墙规则添加 |
| `make px4_sitl none_iris` 失败 | PX4 未编译 | 先执行 `/setup-px4` |
| Mirrored 模式不可用 | Windows 11 版本 < 22H2 | 改用方案 B 端口转发 |
