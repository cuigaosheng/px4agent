# 快速启动指南 - 5 分钟上手 PX4Agent

> 从零开始，5 分钟内完成安装和第一个 Skill 触发

---

## 前置条件

- **操作系统**：macOS、Linux 或 Windows 11
- **Git**：已安装
- **AI 工具**：Claude Code、Cursor、或其他支持的平台

---

## 第一步：克隆仓库（1 分钟）

```bash
# 克隆项目
git clone https://github.com/yourusername/px4agent.git
cd px4agent

# 查看目录结构
ls -la
# 应该看到：
# .claude/          ← Skills 目录
# install.sh        ← Linux/macOS 安装脚本
# install.ps1       ← Windows 安装脚本
# README.md         ← 项目文档
```

---

## 第二步：一键安装（2-3 分钟）

### macOS / Linux

```bash
# 给脚本执行权限
chmod +x install.sh

# 一键安装到所有平台
./install.sh --all --global

# 输出示例：
# ✓ Skills 源目录检查通过
# ✓ 创建目录：/Users/xxx/.claude/skills
# ✓ Claude 安装完成
# ✓ Cursor 安装完成
# ...
# ✓ 成功安装：9 个平台
```

### Windows PowerShell（管理员）

```powershell
# 一键安装到所有平台
.\install.ps1 -All -Global

# 输出示例：
# ✓ Skills 源目录检查通过
# ✓ 创建目录：C:\Users\xxx\.claude\skills
# ✓ Claude 安装完成
# ...
# ✓ 成功安装：9 个平台
```

---

## 第三步：验证安装（1-2 分钟）

### 方式 1：启动 Claude Code

```bash
# 在项目目录启动 Claude Code
claude

# 或在你的 AI 工具中打开项目
```

### 方式 2：测试第一个 Skill

在 Claude Code 或其他 AI 工具中输入：

```
帮我启动 PX4 SITL 仿真
```

**预期结果**：
- AI 自动识别并使用 `px4-sim-start` Skill
- 输出仿真启动步骤
- 你可以按照步骤启动 Gazebo 仿真环境

---

## 常见问题

### Q1：安装脚本报错"权限不足"

**macOS/Linux**：
```bash
chmod +x install.sh
./install.sh --all --global
```

**Windows**：
- 右键 PowerShell → "以管理员身份运行"
- 然后执行 `.\install.ps1 -All -Global`

### Q2：安装后 AI 工具没有识别 Skills

**解决方案**：
1. 重启 AI 工具（完全关闭后重新打开）
2. 检查 Skills 目录是否存在：
   - macOS/Linux：`ls ~/.claude/skills/`
   - Windows：`dir %USERPROFILE%\.claude\skills`
3. 确认目录中有 Skill 文件夹（如 `px4-sim-start/`）

### Q3：Windows 软链接创建失败

**原因**：需要管理员权限

**解决方案**：
1. 右键 PowerShell → "以管理员身份运行"
2. 重新执行安装脚本

### Q4：想只安装到某个平台

```bash
# macOS/Linux
./install.sh --claude --cursor

# Windows
.\install.ps1 -Claude -Cursor
```

---

## 下一步

安装完成后，你可以尝试以下 Skill：

### 🚀 新手推荐

| Skill | 命令 | 用途 |
|-------|------|------|
| **环境安装** | `/setup-all` | 一键安装 PX4 完整开发环境 |
| **SITL 仿真** | `/px4-sim-start` | 启动 Gazebo 或 AirSim 仿真 |
| **驱动生成** | `/px4-imu-gen` | 一键生成 IMU 驱动代码 |

### 📚 学习路径

1. **第一天**：`/setup-all` → 安装开发环境
2. **第二天**：`/px4-sim-start` → 启动仿真
3. **第三天**：`/px4-imu-gen` → 生成驱动代码
4. **第四天**：`/px4-e2e-sensor` → 端到端传感器开发

---

## 获取帮助

- **详细安装指南**：[INSTALLATION.md](./INSTALLATION.md)
- **Skill 选择指南**：[SKILL_GUIDE.md](./SKILL_GUIDE.md)
- **项目 README**：[README.md](../README.md)
- **问题反馈**：[GitHub Issues](https://github.com/yourusername/px4agent/issues)

---

## 验证清单

安装完成后，检查以下项目：

- [ ] 克隆了 px4agent 仓库
- [ ] 运行了安装脚本（`install.sh` 或 `install.ps1`）
- [ ] 脚本输出"成功安装：X 个平台"
- [ ] 重启了 AI 工具
- [ ] 在 AI 工具中测试了一个 Skill（如 `/px4-sim-start`）
- [ ] AI 能够识别并执行 Skill

✅ 全部完成？恭喜！你已经准备好开始 PX4 开发了！
