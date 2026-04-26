---
name: setup-wsl2
version: "1.0.0"
description: 在 Windows 11 上安装 WSL2 + Ubuntu 22.04，并配置适合 PX4 编译的内存参数。
disable-model-invocation: false
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
在 Windows 11 上安装 WSL2 + Ubuntu 22.04：$ARGUMENTS

**仅适用于 Windows 11**。若在 Ubuntu 原生环境中触发此 Skill，直接告知用户"当前为 Linux 环境，跳过 WSL2 安装"并退出。

---

## 第一步：检测 WSL2 状态

```powershell
# [PowerShell 管理员] 检测当前 WSL 版本和已注册的发行版
wsl --status
wsl -l -v
```

**判断逻辑**：
- 输出中含 `Ubuntu-22.04` 且 `VERSION` 列为 `2` → **已完整安装，报告跳过并退出**
- 输出中含 `Ubuntu-22.04` 但 `VERSION` 为 `1` → 跳到第四步（升级为 WSL2）
- 命令报错或列表为空 → 从第二步开始完整安装

---

## 第二步：启用 WSL2 功能

```powershell
# [PowerShell 管理员] 启用 Windows 功能（需管理员权限）
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

执行后**必须重启计算机**。

```powershell
# [PowerShell 管理员] 设置 WSL 默认版本为 2（重启后执行）
wsl --set-default-version 2
```

重启后，WSL 内核会自动更新（Windows 11 自带，无需手动下载）。

---

## 第三步：安装 Ubuntu 22.04

```powershell
# [PowerShell 管理员] 安装 Ubuntu 22.04
wsl --install -d Ubuntu-22.04
```

安装完成后，WSL 会自动打开 Ubuntu 终端，提示**创建用户名和密码**（用于 Linux 账号）。

**重要提示**：
- 用户名建议使用纯小写英文（如 `px4dev`），避免中文或特殊字符
- 密码用于 `sudo` 操作，请牢记

---

## 第四步：升级现有 WSL1 为 WSL2（仅当第一步检测到 VERSION=1 时执行）

```powershell
# [PowerShell 管理员] 将 Ubuntu-22.04 升级为 WSL2
wsl --set-version Ubuntu-22.04 2
```

升级耗时约 2～5 分钟，等待完成后继续。

---

## 第五步：配置 .wslconfig（内存限制）

PX4 编译需要至少 8 GB 内存。在 Windows 侧创建 WSL 全局配置文件：

```powershell
# [PowerShell 任意] 在用户目录创建 .wslconfig
$wslconfig = @"
[wsl2]
memory=12GB
processors=4
swap=4GB
localhostForwarding=true
"@
$wslconfig | Out-File -FilePath "$env:USERPROFILE\.wslconfig" -Encoding utf8
```

**参数说明**：
- `memory=12GB`：分配给 WSL2 的内存上限（建议为物理内存的 50～75%）
- `processors=4`：分配的 CPU 核心数（建议为物理核数的 50%）
- `localhostForwarding=true`：允许 Windows 访问 WSL 内 localhost 服务

修改后重启 WSL：

```powershell
# [PowerShell] 关闭 WSL，使配置生效
wsl --shutdown
# 再次打开 Ubuntu 终端使配置生效
```

---

## 第六步：更新 Ubuntu 包

在 Ubuntu 22.04 终端内执行：

```bash
# [WSL/Linux] 更新包列表和已安装包
sudo apt update && sudo apt upgrade -y
```

---

## 第七步：验证

```powershell
# [PowerShell] 验证安装结果
wsl -l -v
```

**成功标志**：输出中出现：
```
  NAME            STATE           VERSION
* Ubuntu-22.04   Running         2
```

```bash
# [WSL/Linux] 验证基本命令可用
uname -r   # 输出形如 5.15.xx-microsoft-standard-WSL2
lsb_release -a   # 输出 Ubuntu 22.04
```

---

## 常见报错

| 现象 | 原因 | 解决 |
|------|------|------|
| `wsl --install` 卡在 0% | 网络问题 | 挂梯子或切换 DNS：`8.8.8.8` |
| 安装后没弹出 Ubuntu 终端 | 需手动打开 | 搜索"Ubuntu 22.04"打开 |
| `Error code: Wsl/Service/0x800706ba` | WSL 服务未启动 | 在服务管理器中启用 `LxssManager` |
| 内存配置不生效 | `.wslconfig` 编码问题 | 用记事本另存为 UTF-8 无 BOM |
| WSLg 图形不可用 | 驱动版本过旧 | 更新显卡驱动至支持 WSLg 的版本 |
