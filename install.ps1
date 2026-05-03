# PX4Agent 一键安装脚本 (Windows PowerShell)
# 支持多平台安装：Claude Code、Cursor、TRAE、Copilot、Antigravity、OpenCode、Windsurf、Gemini CLI、Codex

param(
    [switch]$All = $false,
    [switch]$Global = $false,
    [switch]$Project = $false,
    [switch]$Claude = $false,
    [switch]$Cursor = $false,
    [switch]$TRAE = $false,
    [switch]$Copilot = $false,
    [switch]$Antigravity = $false,
    [switch]$OpenCode = $false,
    [switch]$Windsurf = $false,
    [switch]$Gemini = $false,
    [switch]$Codex = $false,
    [switch]$Help = $false
)

# 颜色定义
$Colors = @{
    Info    = 'Cyan'
    Success = 'Green'
    Error   = 'Red'
    Warning = 'Yellow'
}

# 脚本目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsSource = Join-Path $ScriptDir ".claude\skills"

# 平台定义
$Platforms = @{
    claude      = "$env:USERPROFILE\.claude\skills"
    cursor      = "$env:USERPROFILE\.cursor\skills"
    trae        = "$env:USERPROFILE\.trae\skills"
    copilot     = "$env:USERPROFILE\.copilot\skills"
    antigravity = "$env:USERPROFILE\.gemini\antigravity\skills"
    opencode    = "$env:USERPROFILE\.config\opencode\skill"
    windsurf    = "$env:USERPROFILE\.codeium\windsurf\skills"
    gemini      = "$env:USERPROFILE\.gemini\skills"
    codex       = "$env:USERPROFILE\.codex\skills"
}

# 软链接平台
$SymlinkPlatforms = @{
    windsurf = "$env:USERPROFILE\.codeium\windsurf\skills"
    gemini   = "$env:USERPROFILE\.gemini\skills"
    codex    = "$env:USERPROFILE\.codex\skills"
}

# 打印帮助信息
function Print-Help {
    Write-Host @"
PX4Agent 一键安装脚本 (Windows PowerShell)

用法：
    .\install.ps1 [选项]

选项：
    -All                    安装到所有平台（默认）
    -Global                 全局安装（推荐）
    -Project                项目级安装
    -Claude                 仅安装到 Claude Code
    -Cursor                 仅安装到 Cursor
    -TRAE                   仅安装到 TRAE
    -Copilot                仅安装到 GitHub Copilot
    -Antigravity            仅安装到 Google Antigravity
    -OpenCode               仅安装到 OpenCode
    -Windsurf               仅安装到 Windsurf
    -Gemini                 仅安装到 Gemini CLI
    -Codex                  仅安装到 OpenAI Codex
    -Help                   显示此帮助信息

示例：
    .\install.ps1 -All -Global          # 一键安装到所有平台（全局）
    .\install.ps1 -Claude -Cursor       # 仅安装到 Claude 和 Cursor
    .\install.ps1 -Project              # 项目级安装

注意：
    需要管理员权限运行此脚本（用于创建软链接）

"@
}

# 打印消息
function Print-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor $Colors.Info
}

function Print-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $Colors.Success
}

function Print-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $Colors.Error
}

function Print-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $Colors.Warning
}

# 检查管理员权限
function Check-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Print-Error "需要管理员权限运行此脚本"
        exit 1
    }
}

# 检查源目录
function Check-Source {
    if (-not (Test-Path $SkillsSource)) {
        Print-Error "Skills 源目录不存在：$SkillsSource"
        exit 1
    }
    Print-Success "Skills 源目录检查通过"
}

# 创建目标目录
function Create-TargetDir {
    param([string]$TargetDir)
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
        Print-Success "创建目录：$TargetDir"
    }
}

# 复制 Skills（原生平台）
function Install-Native {
    param([string]$Platform)
    $TargetDir = $Platforms[$Platform]

    Print-Info "安装到 $Platform：$TargetDir"

    Create-TargetDir $TargetDir

    # 备份现有 Skills
    if ((Test-Path $TargetDir) -and ((Get-ChildItem $TargetDir -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)) {
        $BackupDir = "$TargetDir.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Print-Warning "检测到现有 Skills，备份到：$BackupDir"
        Copy-Item -Path $TargetDir -Destination $BackupDir -Recurse -Force
    }

    # 复制 Skills
    Copy-Item -Path "$SkillsSource\*" -Destination $TargetDir -Recurse -Force
    Print-Success "$Platform 安装完成"
}

# 创建软链接（软链接平台）
function Install-Symlink {
    param([string]$Platform)
    $TargetDir = $SymlinkPlatforms[$Platform]
    $ClaudeDir = $Platforms['claude']

    Print-Info "为 $Platform 创建软链接：$TargetDir → $ClaudeDir"

    # 创建父目录
    $ParentDir = Split-Path -Parent $TargetDir
    Create-TargetDir $ParentDir

    # 删除现有软链接或目录
    if (Test-Path $TargetDir) {
        if ((Get-Item $TargetDir).LinkType -eq "SymbolicLink") {
            Remove-Item $TargetDir -Force
            Print-Warning "删除现有软链接"
        } else {
            $BackupDir = "$TargetDir.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Print-Warning "检测到现有目录，备份到：$BackupDir"
            Move-Item -Path $TargetDir -Destination $BackupDir -Force
        }
    }

    # 创建软链接
    New-Item -ItemType SymbolicLink -Path $TargetDir -Target $ClaudeDir -Force | Out-Null
    Print-Success "$Platform 软链接创建完成"
}

# 验证安装
function Verify-Installation {
    param([string]$Platform)
    $TargetDir = $Platforms[$Platform]

    if ((Test-Path $TargetDir) -and ((Get-ChildItem $TargetDir -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)) {
        $SkillCount = (Get-ChildItem $TargetDir -Directory | Measure-Object).Count
        Print-Success "$Platform 验证通过（$SkillCount 个 Skill）"
        return $true
    } else {
        Print-Error "$Platform 验证失败"
        return $false
    }
}

# 主函数
function Main {
    # 检查管理员权限
    Check-Admin

    # 解析参数
    $PlatformsToInstall = @()

    if ($Help) {
        Print-Help
        exit 0
    }

    if ($All -or ($Claude -eq $false -and $Cursor -eq $false -and $TRAE -eq $false -and $Copilot -eq $false -and $Antigravity -eq $false -and $OpenCode -eq $false -and $Windsurf -eq $false -and $Gemini -eq $false -and $Codex -eq $false)) {
        $PlatformsToInstall = $Platforms.Keys
    } else {
        if ($Claude) { $PlatformsToInstall += 'claude' }
        if ($Cursor) { $PlatformsToInstall += 'cursor' }
        if ($TRAE) { $PlatformsToInstall += 'trae' }
        if ($Copilot) { $PlatformsToInstall += 'copilot' }
        if ($Antigravity) { $PlatformsToInstall += 'antigravity' }
        if ($OpenCode) { $PlatformsToInstall += 'opencode' }
        if ($Windsurf) { $PlatformsToInstall += 'windsurf' }
        if ($Gemini) { $PlatformsToInstall += 'gemini' }
        if ($Codex) { $PlatformsToInstall += 'codex' }
    }

    # 打印安装信息
    Write-Host ""
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor $Colors.Info
    Write-Host "║  PX4Agent 一键安装脚本                 ║" -ForegroundColor $Colors.Info
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor $Colors.Info
    Write-Host ""

    Print-Info "目标平台：$($PlatformsToInstall -join ', ')"
    Write-Host ""

    # 检查源目录
    Check-Source
    Write-Host ""

    # 安装到各平台
    $SuccessCount = 0
    $FailCount = 0

    foreach ($Platform in $PlatformsToInstall) {
        Write-Host ""

        # 检查平台是否为软链接平台
        if ($SymlinkPlatforms.ContainsKey($Platform)) {
            # 先确保 Claude 已安装
            if (-not (Test-Path $Platforms['claude']) -or ((Get-ChildItem $Platforms['claude'] -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0)) {
                Print-Warning "Claude 平台未安装，先安装 Claude"
                Install-Native 'claude'
            }
            Install-Symlink $Platform
        } else {
            Install-Native $Platform
        }

        # 验证安装
        if (Verify-Installation $Platform) {
            $SuccessCount++
        } else {
            $FailCount++
        }
    }

    # 打印总结
    Write-Host ""
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor $Colors.Info
    Write-Host "║  安装完成                              ║" -ForegroundColor $Colors.Info
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor $Colors.Info
    Write-Host ""

    Print-Success "成功安装：$SuccessCount 个平台"
    if ($FailCount -gt 0) {
        Print-Error "安装失败：$FailCount 个平台"
    }

    Write-Host ""
    Print-Info "下一步："
    Write-Host "  1. 在你的 AI 工具中重启或重新加载 Skills"
    Write-Host "  2. 尝试触发一个 Skill，例如："
    Write-Host "     /px4-sim-start"
    Write-Host "     /px4-imu-gen"
    Write-Host "     /setup-all"
    Write-Host ""

    if ($FailCount -gt 0) {
        exit 1
    }
}

# 运行主函数
Main
