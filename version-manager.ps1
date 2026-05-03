# version-manager.ps1 - PX4Agent Skill 版本管理系统 (Windows PowerShell)
# 功能：
#   1. 检查所有 Skill 版本号
#   2. 生成 CHANGELOG
#   3. 验证版本一致性
#   4. 自动更新版本号

param(
    [ValidateSet("report", "manifest", "changelog", "check", "all")]
    [string]$Command = "report",
    [string]$SkillsDir = ".\.claude\skills",
    [string]$ChangelogFile = "CHANGELOG.md",
    [string]$ManifestFile = "version-manifest.json"
)

# 颜色定义
$Colors = @{
    Info    = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
}

# 日志函数
function Write-Log {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )

    switch ($Type) {
        "Info"    { Write-Host "ℹ $Message" -ForegroundColor $Colors.Info }
        "Success" { Write-Host "✓ $Message" -ForegroundColor $Colors.Success }
        "Warning" { Write-Host "⚠ $Message" -ForegroundColor $Colors.Warning }
        "Error"   { Write-Host "✗ $Message" -ForegroundColor $Colors.Error }
    }
}

# 检查 Skill 目录是否存在
function Test-SkillsDir {
    if (-not (Test-Path $SkillsDir)) {
        Write-Log "Skills 目录不存在: $SkillsDir" "Error"
        exit 1
    }
    Write-Log "Skills 目录检查通过" "Success"
}

# 从 SKILL.md 中提取版本号
function Get-SkillVersion {
    param([string]$SkillPath)

    $skillMd = Join-Path $SkillPath "SKILL.md"

    if (-not (Test-Path $skillMd)) {
        return "unknown"
    }

    $content = Get-Content -Path $skillMd -Raw
    if ($content -match 'version:\s*"([^"]+)"') {
        return $matches[1]
    }

    return "unknown"
}

# 从 SKILL.md 中提取描述
function Get-SkillDescription {
    param([string]$SkillPath)

    $skillMd = Join-Path $SkillPath "SKILL.md"

    if (-not (Test-Path $skillMd)) {
        return "No description"
    }

    $content = Get-Content -Path $skillMd -Raw
    if ($content -match 'description:\s*"([^"]+)"') {
        return $matches[1]
    }

    return "No description"
}

# 生成版本清单 JSON
function New-VersionManifest {
    Write-Log "生成版本清单..." "Info"

    $manifest = @{
        generated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        skills       = @{}
    }

    $skillDirs = Get-ChildItem -Path $SkillsDir -Directory
    foreach ($skillDir in $skillDirs) {
        $skillName = $skillDir.Name
        $version = Get-SkillVersion $skillDir.FullName
        $description = Get-SkillDescription $skillDir.FullName

        $manifest.skills[$skillName] = @{
            version     = $version
            description = $description
            path        = $skillDir.FullName
        }
    }

    $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $ManifestFile
    Write-Log "版本清单已生成: $ManifestFile" "Success"
}

# 检查版本一致性
function Test-VersionConsistency {
    Write-Log "检查版本一致性..." "Info"

    $inconsistencies = 0
    $skillDirs = Get-ChildItem -Path $SkillsDir -Directory

    foreach ($skillDir in $skillDirs) {
        $skillName = $skillDir.Name
        $version = Get-SkillVersion $skillDir.FullName

        # 检查版本格式 (应为 X.Y.Z)
        if ($version -notmatch '^\d+\.\d+\.\d+$') {
            Write-Log "$skillName`: 版本格式不规范 ($version)，应为 X.Y.Z" "Warning"
            $inconsistencies++
        }
    }

    if ($inconsistencies -eq 0) {
        Write-Log "所有 Skill 版本格式正确" "Success"
    } else {
        Write-Log "发现 $inconsistencies 个版本格式问题" "Warning"
    }
}

# 生成 CHANGELOG
function New-Changelog {
    Write-Log "生成 CHANGELOG..." "Info"

    $changelog = @"
# PX4Agent Skills CHANGELOG

> 所有 Skill 版本变更记录

---

## 版本历史

### 当前版本 ($(Get-Date -Format 'yyyy-MM-dd'))

#### Layer 3 - 场景技能

"@

    # Layer 3 - 场景技能
    $layer3Skills = Get-ChildItem -Path $SkillsDir -Directory | Where-Object { $_.Name -match "^px4-e2e-" }
    foreach ($skill in $layer3Skills) {
        $version = Get-SkillVersion $skill.FullName
        $description = Get-SkillDescription $skill.FullName
        $changelog += "- **$($skill.Name)** v$version`: $description`n"
    }

    $changelog += "`n#### Layer 2 - 组件技能`n`n"

    # Layer 2 - 组件技能
    $layer2Skills = Get-ChildItem -Path $SkillsDir -Directory | Where-Object { $_.Name -match "^px4-" -and $_.Name -notmatch "^px4-e2e-" }
    foreach ($skill in $layer2Skills) {
        $version = Get-SkillVersion $skill.FullName
        $description = Get-SkillDescription $skill.FullName
        $changelog += "- **$($skill.Name)** v$version`: $description`n"
    }

    $changelog += "`n#### Layer 1 - 基础设施技能`n`n"

    # Layer 1 - 基础设施技能
    $layer1Names = @("commit", "review", "handoff", "simplify", "clean-contract")
    foreach ($name in $layer1Names) {
        $skillPath = Join-Path $SkillsDir $name
        if (Test-Path $skillPath) {
            $version = Get-SkillVersion $skillPath
            $description = Get-SkillDescription $skillPath
            $changelog += "- **$name** v$version`: $description`n"
        }
    }

    $changelog += "`n#### Layer 0.5 - 环境安装技能`n`n"

    # Layer 0.5 - 环境安装技能
    $layer05Skills = Get-ChildItem -Path $SkillsDir -Directory | Where-Object { $_.Name -match "^setup-" }
    foreach ($skill in $layer05Skills) {
        $version = Get-SkillVersion $skill.FullName
        $description = Get-SkillDescription $skill.FullName
        $changelog += "- **$($skill.Name)** v$version`: $description`n"
    }

    Set-Content -Path $ChangelogFile -Value $changelog
    Write-Log "CHANGELOG 已生成: $ChangelogFile" "Success"
}

# 统计 Skill 数量
function Get-SkillCount {
    $skillDirs = Get-ChildItem -Path $SkillsDir -Directory
    return $skillDirs.Count
}

# 生成版本报告
function Show-VersionReport {
    Write-Log "生成版本报告..." "Info"

    $totalSkills = Get-SkillCount

    Write-Host ""
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     PX4Agent Skills 版本报告           ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "总 Skill 数: $totalSkills"
    Write-Host ""

    # 按层级统计
    $layer3Count = (Get-ChildItem -Path $SkillsDir -Directory | Where-Object { $_.Name -match "^px4-e2e-" }).Count
    $layer2Count = (Get-ChildItem -Path $SkillsDir -Directory | Where-Object { $_.Name -match "^px4-" -and $_.Name -notmatch "^px4-e2e-" }).Count
    $layer1Count = (Get-ChildItem -Path $SkillsDir -Directory | Where-Object { $_.Name -in @("commit", "review", "handoff", "simplify", "clean-contract") }).Count
    $layer05Count = (Get-ChildItem -Path $SkillsDir -Directory | Where-Object { $_.Name -match "^setup-" }).Count

    Write-Host "Layer 3 (场景技能):     $layer3Count"
    Write-Host "Layer 2 (组件技能):     $layer2Count"
    Write-Host "Layer 1 (基础设施):     $layer1Count"
    Write-Host "Layer 0.5 (环境安装):   $layer05Count"
    Write-Host ""
}

# 主函数
function Main {
    switch ($Command) {
        "report" {
            Test-SkillsDir
            Show-VersionReport
        }
        "manifest" {
            Test-SkillsDir
            New-VersionManifest
        }
        "changelog" {
            Test-SkillsDir
            New-Changelog
        }
        "check" {
            Test-SkillsDir
            Test-VersionConsistency
        }
        "all" {
            Test-SkillsDir
            Show-VersionReport
            New-VersionManifest
            New-Changelog
            Test-VersionConsistency
            Write-Log "所有版本管理任务已完成" "Success"
        }
        default {
            Write-Log "未知命令: $Command" "Error"
            Write-Host ""
            Write-Host "用法: .\version-manager.ps1 -Command {report|manifest|changelog|check|all}"
            Write-Host ""
            Write-Host "命令说明:"
            Write-Host "  report      - 生成版本报告（默认）"
            Write-Host "  manifest    - 生成版本清单 JSON"
            Write-Host "  changelog   - 生成 CHANGELOG.md"
            Write-Host "  check       - 检查版本一致性"
            Write-Host "  all         - 执行所有任务"
            exit 1
        }
    }
}

Main
