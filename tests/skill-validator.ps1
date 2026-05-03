# skill-validator.ps1 - PX4Agent Skill 自动化验证框架 (Windows PowerShell)
# 功能：
#   1. 验证 SKILL.md 格式和 frontmatter
#   2. 检查步骤完整性
#   3. 验证代码示例语法
#   4. 检查编码规范合规性

param(
    [string]$SkillsDir = ".\.claude\skills",
    [string]$TestsDir = ".\tests",
    [string]$ReportFile = "$TestsDir\validation-report.txt"
)

# 颜色定义
$Colors = @{
    Info    = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
}

# 统计变量
$TotalSkills = 0
$PassedSkills = 0
$FailedSkills = 0
$Warnings = 0

# 日志函数
function Write-Log {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"

    switch ($Type) {
        "Info"    { Write-Host "ℹ $Message" -ForegroundColor $Colors.Info }
        "Success" { Write-Host "✓ $Message" -ForegroundColor $Colors.Success }
        "Warning" { Write-Host "⚠ $Message" -ForegroundColor $Colors.Warning; $script:Warnings++ }
        "Error"   { Write-Host "✗ $Message" -ForegroundColor $Colors.Error }
    }

    Add-Content -Path $ReportFile -Value $logMessage
}

# 初始化报告文件
function Initialize-Report {
    if (-not (Test-Path $TestsDir)) {
        New-Item -ItemType Directory -Path $TestsDir -Force | Out-Null
    }

    $reportHeader = @"
PX4Agent Skill 验证报告
生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
========================================

"@

    Set-Content -Path $ReportFile -Value $reportHeader
    Write-Log "报告文件已初始化: $ReportFile" "Info"
}

# 验证 frontmatter 格式
function Test-Frontmatter {
    param([string]$SkillMd, [string]$SkillName)

    $content = Get-Content -Path $SkillMd -Raw

    # 检查 frontmatter 分隔符
    if ($content -notmatch "^---") {
        Write-Log "$SkillName: 缺少 frontmatter 分隔符 (---)" "Error"
        return $false
    }

    # 检查必需字段
    $requiredFields = @("name", "version", "description", "disable-model-invocation", "allowed-tools")
    foreach ($field in $requiredFields) {
        if ($content -notmatch "^$field:") {
            Write-Log "$SkillName: 缺少必需字段 ($field)" "Error"
            return $false
        }
    }

    # 验证版本格式
    if ($content -match 'version:\s*"([^"]+)"') {
        $version = $matches[1]
        if ($version -notmatch '^\d+\.\d+\.\d+$') {
            Write-Log "$SkillName: 版本格式不规范 ($version)，应为 X.Y.Z" "Warning"
            return $false
        }
    }

    return $true
}

# 验证步骤完整性
function Test-Steps {
    param([string]$SkillMd, [string]$SkillName)

    $content = Get-Content -Path $SkillMd -Raw

    # 检查是否有步骤标题
    if ($content -notmatch "^## Step") {
        Write-Log "$SkillName: 没有找到步骤标题 (## Step ...)" "Warning"
        return $false
    }

    # 检查步骤编号连续性
    $stepMatches = [regex]::Matches($content, "^## Step (\d+)", [System.Text.RegularExpressions.RegexOptions]::Multiline)
    $expected = 1
    foreach ($match in $stepMatches) {
        $stepNum = [int]$match.Groups[1].Value
        if ($stepNum -ne $expected) {
            Write-Log "$SkillName: 步骤编号不连续 (期望 $expected，得到 $stepNum)" "Warning"
            return $false
        }
        $expected++
    }

    return $true
}

# 检查代码块完整性
function Test-CodeBlocks {
    param([string]$SkillMd, [string]$SkillName)

    $content = Get-Content -Path $SkillMd -Raw
    $codeBlockCount = ([regex]::Matches($content, "```")).Count

    if ($codeBlockCount % 2 -ne 0) {
        Write-Log "$SkillName: 代码块标记不匹配 (开始/结束数不相等)" "Warning"
        return $false
    }

    return $true
}

# 检查编码规范合规性
function Test-CodingStandards {
    param([string]$SkillMd, [string]$SkillName)

    $content = Get-Content -Path $SkillMd -Raw
    $violations = 0

    # 检查动态内存分配
    if ($content -match "(new |delete |malloc|free)") {
        Write-Log "$SkillName: 代码示例中包含动态内存分配 (new/delete/malloc/free)" "Warning"
        $violations++
    }

    # 检查 printf
    if ($content -match "printf") {
        Write-Log "$SkillName: 代码示例中包含 printf，应使用 PX4_DEBUG/INFO/WARN/ERR" "Warning"
        $violations++
    }

    # 检查 sleep/usleep
    if ($content -match "(sleep|usleep)") {
        Write-Log "$SkillName: 代码示例中包含阻塞调用 (sleep/usleep)，应使用 ScheduleDelayed()" "Warning"
        $violations++
    }

    # 检查 mutex lock
    if ($content -match "(mutex|lock)") {
        Write-Log "$SkillName: 代码示例中包含 mutex lock，应使用 ScheduledWorkItem" "Warning"
        $violations++
    }

    return ($violations -eq 0)
}

# 验证单个 Skill
function Test-Skill {
    param([string]$SkillDir)

    $skillName = Split-Path -Leaf $SkillDir
    $skillMd = Join-Path $SkillDir "SKILL.md"

    $script:TotalSkills++

    if (-not (Test-Path $skillMd)) {
        Write-Log "$skillName: 缺少 SKILL.md 文件" "Error"
        $script:FailedSkills++
        return $false
    }

    Write-Log "验证 $skillName..." "Info"

    $failed = 0

    # 运行所有验证
    if (-not (Test-Frontmatter $skillMd $skillName)) { $failed++ }
    if (-not (Test-Steps $skillMd $skillName)) { $failed++ }
    if (-not (Test-CodeBlocks $skillMd $skillName)) { $failed++ }
    if (-not (Test-CodingStandards $skillMd $skillName)) { $failed++ }

    if ($failed -eq 0) {
        Write-Log "$skillName 验证通过" "Success"
        $script:PassedSkills++
        return $true
    } else {
        Write-Log "$skillName 验证失败 ($failed 个问题)" "Error"
        $script:FailedSkills++
        return $false
    }
}

# 验证所有 Skill
function Test-AllSkills {
    Write-Log "开始验证所有 Skill..." "Info"
    Write-Log "" "Info"

    if (-not (Test-Path $SkillsDir)) {
        Write-Log "Skills 目录不存在: $SkillsDir" "Error"
        return $false
    }

    $skillDirs = Get-ChildItem -Path $SkillsDir -Directory
    foreach ($skillDir in $skillDirs) {
        Test-Skill $skillDir.FullName | Out-Null
    }

    return $true
}

# 生成验证报告
function Generate-Report {
    $summary = @"

========================================
验证摘要
========================================
总 Skill 数:     $TotalSkills
通过验证:        $PassedSkills
验证失败:        $FailedSkills
警告数:          $Warnings

"@

    Add-Content -Path $ReportFile -Value $summary

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "验证摘要" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "总 Skill 数:     $TotalSkills"
    Write-Host "通过验证:        $PassedSkills" -ForegroundColor Green
    Write-Host "验证失败:        $FailedSkills" -ForegroundColor $(if ($FailedSkills -eq 0) { "Green" } else { "Red" })
    Write-Host "警告数:          $Warnings" -ForegroundColor $(if ($Warnings -eq 0) { "Green" } else { "Yellow" })
    Write-Host ""

    if ($FailedSkills -eq 0) {
        Write-Log "✓ 所有 Skill 验证通过" "Success"
        return $true
    } else {
        Write-Log "✗ 有 $FailedSkills 个 Skill 验证失败" "Error"
        return $false
    }
}

# 主函数
function Main {
    Initialize-Report
    Test-AllSkills | Out-Null
    $result = Generate-Report

    Write-Host ""
    Write-Host "验证报告已保存到: $ReportFile" -ForegroundColor Cyan
    Write-Host ""

    if ($result) {
        exit 0
    } else {
        exit 1
    }
}

Main
