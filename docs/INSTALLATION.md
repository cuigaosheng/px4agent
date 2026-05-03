# 详细安装指南

> 支持所有 9 种平台的完整安装说明

---

## 目录

- [系统要求](#系统要求)
- [安装方式](#安装方式)
- [平台特定说明](#平台特定说明)
- [故障排查](#故障排查)
- [常见问题](#常见问题)

---

## 系统要求

### 最低要求

| 项目 | 要求 |
|------|------|
| **操作系统** | macOS 10.15+、Linux (Ubuntu 20.04+)、Windows 11 |
| **Git** | 2.20+ |
| **磁盘空间** | 100 MB（仅 Skills 文件） |
| **网络** | 互联网连接（用于克隆仓库） |

### 可选要求

| 项目 | 用途 |
|------|------|
| **PX4 工具链** | 编译 PX4 固件（可通过 `/setup-px4` 自动安装） |
| **Gazebo** | SITL 仿真（可通过 `/setup-gazebo` 自动安装） |
| **ROS2** | 高级集成（可通过 `/setup-ros2` 自动安装） |

---

## 安装方式

### 方式 1：一键全局安装（推荐）

**优点**：
- 一条命令完成所有平台安装
- 自动创建软链接，更新一处全部同步
- 节省磁盘空间

**步骤**：

#### macOS / Linux

```bash
# 1. 克隆仓库
git clone https://github.com/yourusername/px4agent.git
cd px4agent

# 2. 给脚本执行权限
chmod +x install.sh

# 3. 一键安装
./install.sh --all --global
```

#### Windows PowerShell

```powershell
# 1. 克隆仓库
git clone https://github.com/yourusername/px4agent.git
cd px4agent

# 2. 以管理员身份运行 PowerShell

# 3. 一键安装
.\install.ps1 -All -Global
```

### 方式 2：选择性安装

**适用场景**：只需要在特定平台使用

```bash
# macOS/Linux：仅安装到 Claude 和 Cursor
./install.sh --claude --cursor

# Windows：仅安装到 Claude 和 Cursor
.\install.ps1 -Claude -Cursor
```

### 方式 3：项目级安装

**适用场景**：多个项目，不想污染全局目录

```bash
# macOS/Linux
./install.sh --project

# Windows
.\install.ps1 -Project
```

### 方式 4：手动安装

**适用场景**：脚本不兼容或需要自定义

```bash
# 1. 找到你的 AI 工具的 Skills 目录
# 例如 Claude Code：~/.claude/skills/

# 2. 复制 .claude/skills/* 到目标目录
cp -r .claude/skills/* ~/.claude/skills/

# 3. 重启 AI 工具
```

---

## 平台特定说明

### Claude Code

**目录**：`~/.claude/skills/`

**安装**：
```bash
./install.sh --claude --global
```

**验证**：
```bash
ls ~/.claude/skills/
# 应该看到 48 个 Skill 目录
```

**重启**：
```bash
# 关闭 Claude Code，重新打开
claude
```

---

### Cursor

**目录**：`~/.cursor/skills/`

**安装**：
```bash
./install.sh --cursor --global
```

**验证**：
```bash
ls ~/.cursor/skills/
```

**重启**：
- 关闭 Cursor，重新打开

---

### TRAE

**目录**：`~/.trae/skills/`

**安装**：
```bash
./install.sh --trae --global
```

**验证**：
```bash
ls ~/.trae/skills/
```

---

### GitHub Copilot

**目录**：`~/.copilot/skills/`

**安装**：
```bash
./install.sh --copilot --global
```

**验证**：
```bash
ls ~/.copilot/skills/
```

**重启**：
- 在 VS Code 中重新加载窗口（Cmd+Shift+P → Reload Window）

---

### Google Antigravity

**目录**：`~/.gemini/antigravity/skills/`

**安装**：
```bash
./install.sh --antigravity --global
```

**验证**：
```bash
ls ~/.gemini/antigravity/skills/
```

---

### OpenCode

**目录**：`~/.config/opencode/skill/`

**安装**：
```bash
./install.sh --opencode --global
```

**验证**：
```bash
ls ~/.config/opencode/skill/
```

---

### Windsurf（软链接）

**目录**：`~/.codeium/windsurf/skills/` → `~/.claude/skills/`

**安装**：
```bash
./install.sh --windsurf --global
```

**特点**：
- 自动创建软链接指向 Claude 目录
- 更新 Claude 目录，Windsurf 自动同步
- 节省磁盘空间

**验证**：
```bash
ls -la ~/.codeium/windsurf/skills/
# 应该看到 -> ~/.claude/skills
```

---

### Gemini CLI（软链接）

**目录**：`~/.gemini/skills/` → `~/.claude/skills/`

**安装**：
```bash
./install.sh --gemini --global
```

**验证**：
```bash
ls -la ~/.gemini/skills/
```

---

### OpenAI Codex（软链接）

**目录**：`~/.codex/skills/` → `~/.claude/skills/`

**安装**：
```bash
./install.sh --codex --global
```

**验证**：
```bash
ls -la ~/.codex/skills/
```

---

## 故障排查

### 问题 1：脚本权限不足

**症状**：`Permission denied: ./install.sh`

**解决方案**：
```bash
chmod +x install.sh
./install.sh --all --global
```

### 问题 2：Windows 软链接失败

**症状**：`Access Denied` 或 `You do not have sufficient privilege`

**解决方案**：
1. 右键 PowerShell → "以管理员身份运行"
2. 重新执行脚本

### 问题 3：安装后 AI 工具没有识别 Skills

**症状**：在 AI 工具中输入 `/px4-sim-start` 没有反应

**解决方案**：
1. **完全重启 AI 工具**（不是最小化，是完全关闭）
2. 检查 Skills 目录是否存在：
   ```bash
   ls ~/.claude/skills/
   ```
3. 确认目录中有 Skill 文件夹：
   ```bash
   ls ~/.claude/skills/ | head -5
   # 应该看到：
   # px4-e2e-avoidance
   # px4-e2e-control
   # ...
   ```

### 问题 4：软链接创建失败

**症状**：`Cannot create symbolic link`

**原因**：
- Windows：需要管理员权限
- macOS/Linux：目标目录已存在且不为空

**解决方案**：
```bash
# 备份现有目录
mv ~/.codeium/windsurf/skills ~/.codeium/windsurf/skills.backup

# 重新运行安装脚本
./install.sh --windsurf --global
```

### 问题 5：磁盘空间不足

**症状**：`No space left on device`

**解决方案**：
1. 使用软链接方式（只占用一份空间）
2. 或删除其他不需要的 Skills 目录

---

## 常见问题

### Q1：我可以在多个平台上同时使用 Skills 吗？

**A**：可以。安装脚本会自动在所有指定平台上安装 Skills。

### Q2：更新 Skills 需要重新安装吗？

**A**：不需要。只需 `git pull` 更新仓库，然后重新运行安装脚本即可。

### Q3：我可以自定义 Skills 目录位置吗？

**A**：可以，但需要手动复制文件。建议使用默认位置以保持兼容性。

### Q4：卸载 Skills 怎么做？

**A**：
```bash
# 删除 Skills 目录
rm -rf ~/.claude/skills/

# 或使用卸载脚本（如果存在）
./uninstall.sh
```

### Q5：我想只在某个项目中使用 Skills

**A**：使用项目级安装：
```bash
./install.sh --project
```

这会在项目目录中创建 `.claude/skills/` 副本。

### Q6：软链接和复制有什么区别？

**软链接**：
- 占用空间少（只有链接本身）
- 更新一处全部同步
- 需要管理员权限（Windows）

**复制**：
- 占用空间多（每个平台一份）
- 更新需要重新安装
- 不需要特殊权限

---

## 验证安装

### 快速验证

```bash
# 检查 Claude 目录
ls ~/.claude/skills/ | wc -l
# 应该输出 48（48 个 Skill）

# 检查某个 Skill
ls ~/.claude/skills/px4-sim-start/
# 应该看到 SKILL.md 和 px4-sim-start.zip
```

### 完整验证

在 Claude Code 中运行：

```
列出所有可用的 Skill
```

**预期结果**：AI 应该能够列出所有 48 个 Skill。

---

## 获取帮助

- **快速启动**：[QUICK_START.md](./QUICK_START.md)
- **Skill 选择**：[SKILL_GUIDE.md](./SKILL_GUIDE.md)
- **问题反馈**：[GitHub Issues](https://github.com/yourusername/px4agent/issues)
