# PX4Agent Skill 测试框架

> 自动化验证 Skill 格式、编码规范和完整性

---

## 快速开始

### macOS / Linux

```bash
# 给脚本执行权限
chmod +x skill-validator.sh

# 运行验证
./skill-validator.sh

# 查看报告
cat validation-report.txt
```

### Windows PowerShell

```powershell
# 运行验证
.\skill-validator.ps1

# 查看报告
Get-Content validation-report.txt
```

---

## 验证内容

### 1. Frontmatter 格式验证

检查每个 `SKILL.md` 是否包含必需的 frontmatter 字段：

- `name` - Skill 名称
- `version` - 版本号（格式：X.Y.Z）
- `description` - 一句话描述
- `disable-model-invocation` - 是否禁用模型调用
- `allowed-tools` - 允许的工具列表

### 2. 步骤完整性验证

- 检查是否有步骤标题（`## Step N`）
- 验证步骤编号连续性（1, 2, 3, ...）
- 确保没有跳过的步骤

### 3. 代码块完整性验证

- 检查代码块标记是否匹配（开始和结束数相等）
- 确保没有未闭合的代码块

### 4. 编码规范合规性验证

检查代码示例是否违反 PX4 编码规范：

- ❌ 禁止动态内存分配（`new` / `delete` / `malloc` / `free`）
- ❌ 禁止 `printf`（应使用 `PX4_DEBUG` / `PX4_INFO` / `PX4_WARN` / `PX4_ERR`）
- ❌ 禁止阻塞调用（`sleep` / `usleep`，应使用 `ScheduleDelayed()`）
- ❌ 禁止 `mutex lock`（应使用 `ScheduledWorkItem`）

---

## 验证报告

验证完成后，报告保存到 `validation-report.txt`，包含：

```
PX4Agent Skill 验证报告
生成时间: 2026-05-03 10:30:45
========================================

ℹ 验证 px4-e2e-sensor...
✓ px4-e2e-sensor 验证通过
ℹ 验证 px4-e2e-avoidance...
✓ px4-e2e-avoidance 验证通过
...

========================================
验证摘要
========================================
总 Skill 数:     48
通过验证:        48
验证失败:        0
警告数:          0

✓ 所有 Skill 验证通过
```

---

## 版本管理

### 生成版本报告

```bash
# macOS/Linux
./version-manager.sh report

# Windows PowerShell
.\version-manager.ps1 -Command report
```

### 生成版本清单 JSON

```bash
# macOS/Linux
./version-manager.sh manifest

# Windows PowerShell
.\version-manager.ps1 -Command manifest
```

输出文件：`version-manifest.json`

```json
{
  "generated_at": "2026-05-03T10:30:45Z",
  "skills": {
    "px4-e2e-sensor": {
      "version": "1.0.0",
      "description": "传感器端到端全链路开发",
      "path": "./.claude/skills/px4-e2e-sensor"
    },
    ...
  }
}
```

### 生成 CHANGELOG

```bash
# macOS/Linux
./version-manager.sh changelog

# Windows PowerShell
.\version-manager.ps1 -Command changelog
```

输出文件：`CHANGELOG.md`

### 检查版本一致性

```bash
# macOS/Linux
./version-manager.sh check

# Windows PowerShell
.\version-manager.ps1 -Command check
```

### 执行所有任务

```bash
# macOS/Linux
./version-manager.sh all

# Windows PowerShell
.\version-manager.ps1 -Command all
```

---

## CI/CD 集成

### GitHub Actions

项目已配置 `.github/workflows/validate-skills.yml`，在以下情况自动运行：

- **Push 到 main 或 develop 分支**
- **Pull Request 到 main 或 develop 分支**
- **修改 `.claude/skills/` 目录下的文件**

### 工作流程

1. **Skill 验证** - 运行 `skill-validator.sh`
2. **版本清单生成** - 运行 `version-manager.sh manifest`
3. **CHANGELOG 生成** - 运行 `version-manager.sh changelog`
4. **版本一致性检查** - 运行 `version-manager.sh check`
5. **安装脚本验证** - 检查 `install.sh` 语法
6. **文档验证** - 检查 Markdown 格式和链接
7. **安装测试** - 验证 Skill 目录结构
8. **报告生成** - 生成版本报告

### 查看 CI/CD 结果

1. 在 GitHub 上打开 Pull Request
2. 查看 "Checks" 标签
3. 点击 "Validate Skills" 工作流
4. 查看详细日志和生成的报告

---

## 常见问题

### Q1：验证失败，如何修复？

查看 `validation-report.txt` 中的错误信息，按照提示修复对应的 `SKILL.md` 文件。

常见问题：
- **版本格式不规范** - 应为 `X.Y.Z` 格式（如 `1.0.0`）
- **步骤编号不连续** - 检查 `## Step N` 是否连续
- **代码块不匹配** - 检查 ` ``` ` 是否成对出现
- **编码规范违反** - 检查代码示例是否包含禁止的模式

### Q2：如何添加新 Skill？

1. 在 `.claude/skills/<skill-name>/` 目录下创建 `SKILL.md`
2. 添加必需的 frontmatter 字段
3. 编写步骤（`## Step 1`, `## Step 2`, ...）
4. 运行验证：`./skill-validator.sh`
5. 确保验证通过后提交

### Q3：如何更新 Skill 版本？

1. 修改 `SKILL.md` 中的 `version` 字段
2. 运行 `./version-manager.sh changelog` 生成新的 CHANGELOG
3. 提交改动

### Q4：CI/CD 失败，如何调试？

1. 在本地运行 `./skill-validator.sh` 和 `./version-manager.sh all`
2. 查看输出中的错误信息
3. 修复问题后重新提交

---

## 脚本参考

### skill-validator.sh / skill-validator.ps1

验证所有 Skill 的格式和编码规范。

**输出**：
- 控制台：彩色输出，显示验证进度和结果
- 文件：`tests/validation-report.txt`

**退出码**：
- `0` - 所有 Skill 验证通过
- `1` - 有 Skill 验证失败

### version-manager.sh / version-manager.ps1

管理 Skill 版本号和生成相关报告。

**命令**：
- `report` - 生成版本报告（默认）
- `manifest` - 生成版本清单 JSON
- `changelog` - 生成 CHANGELOG.md
- `check` - 检查版本一致性
- `all` - 执行所有任务

---

## 最佳实践

1. **本地验证** - 在提交前运行 `./skill-validator.sh` 和 `./version-manager.sh all`
2. **版本管理** - 每次修改 Skill 时更新版本号
3. **CHANGELOG** - 定期生成 CHANGELOG 以跟踪变更
4. **CI/CD 检查** - 确保 GitHub Actions 工作流通过
5. **文档更新** - 修改 Skill 时同步更新 README 和文档

---

## 获取帮助

- **快速启动**：[QUICK_START.md](../docs/QUICK_START.md)
- **详细安装**：[INSTALLATION.md](../docs/INSTALLATION.md)
- **Skill 选择**：[SKILL_GUIDE.md](../docs/SKILL_GUIDE.md)
- **项目 README**：[README.md](../README.md)
