#!/bin/bash

# PX4Agent 一键安装脚本 (macOS/Linux)
# 支持多平台安装：Claude Code、Cursor、TRAE、Copilot、Antigravity、OpenCode、Windsurf、Gemini CLI、Codex

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SOURCE="$SCRIPT_DIR/.claude/skills"

# 平台定义
declare -A PLATFORMS=(
    [claude]="$HOME/.claude/skills"
    [cursor]="$HOME/.cursor/skills"
    [trae]="$HOME/.trae/skills"
    [copilot]="$HOME/.copilot/skills"
    [antigravity]="$HOME/.gemini/antigravity/skills"
    [opencode]="$HOME/.config/opencode/skill"
    [windsurf]="$HOME/.codeium/windsurf/skills"
    [gemini]="$HOME/.gemini/skills"
    [codex]="$HOME/.codex/skills"
)

# 软链接平台（指向 Claude）
declare -A SYMLINK_PLATFORMS=(
    [windsurf]="$HOME/.codeium/windsurf/skills"
    [gemini]="$HOME/.gemini/skills"
    [codex]="$HOME/.codex/skills"
)

# 打印帮助信息
print_help() {
    cat << EOF
PX4Agent 一键安装脚本

用法：
    ./install.sh [选项]

选项：
    --all                   安装到所有平台（默认）
    --global                全局安装（推荐）
    --project               项目级安装
    --claude                仅安装到 Claude Code
    --cursor                仅安装到 Cursor
    --trae                  仅安装到 TRAE
    --copilot               仅安装到 GitHub Copilot
    --antigravity           仅安装到 Google Antigravity
    --opencode              仅安装到 OpenCode
    --windsurf              仅安装到 Windsurf
    --gemini                仅安装到 Gemini CLI
    --codex                 仅安装到 OpenAI Codex
    --help                  显示此帮助信息

示例：
    ./install.sh --all --global          # 一键安装到所有平台（全局）
    ./install.sh --claude --cursor       # 仅安装到 Claude 和 Cursor
    ./install.sh --project               # 项目级安装

EOF
}

# 打印消息
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 检查源目录
check_source() {
    if [ ! -d "$SKILLS_SOURCE" ]; then
        print_error "Skills 源目录不存在：$SKILLS_SOURCE"
        exit 1
    fi
    print_success "Skills 源目录检查通过"
}

# 创建目标目录
create_target_dir() {
    local target_dir="$1"
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
        print_success "创建目录：$target_dir"
    fi
}

# 复制 Skills（原生平台）
install_native() {
    local platform="$1"
    local target_dir="${PLATFORMS[$platform]}"

    print_info "安装到 $platform：$target_dir"

    create_target_dir "$target_dir"

    # 备份现有 Skills（如果存在）
    if [ -d "$target_dir" ] && [ "$(ls -A "$target_dir")" ]; then
        local backup_dir="${target_dir}.backup.$(date +%Y%m%d_%H%M%S)"
        print_warning "检测到现有 Skills，备份到：$backup_dir"
        cp -r "$target_dir" "$backup_dir"
    fi

    # 复制 Skills
    cp -r "$SKILLS_SOURCE"/* "$target_dir/"
    print_success "$platform 安装完成"
}

# 创建软链接（软链接平台）
install_symlink() {
    local platform="$1"
    local target_dir="${SYMLINK_PLATFORMS[$platform]}"
    local claude_dir="${PLATFORMS[claude]}"

    print_info "为 $platform 创建软链接：$target_dir → $claude_dir"

    # 创建父目录
    mkdir -p "$(dirname "$target_dir")"

    # 删除现有软链接或目录
    if [ -L "$target_dir" ]; then
        rm "$target_dir"
        print_warning "删除现有软链接"
    elif [ -d "$target_dir" ]; then
        local backup_dir="${target_dir}.backup.$(date +%Y%m%d_%H%M%S)"
        print_warning "检测到现有目录，备份到：$backup_dir"
        mv "$target_dir" "$backup_dir"
    fi

    # 创建软链接
    ln -s "$claude_dir" "$target_dir"
    print_success "$platform 软链接创建完成"
}

# 验证安装
verify_installation() {
    local platform="$1"
    local target_dir="${PLATFORMS[$platform]}"

    if [ -d "$target_dir" ] && [ "$(ls -A "$target_dir")" ]; then
        local skill_count=$(find "$target_dir" -maxdepth 1 -type d | wc -l)
        print_success "$platform 验证通过（$skill_count 个 Skill）"
        return 0
    else
        print_error "$platform 验证失败"
        return 1
    fi
}

# 主函数
main() {
    local install_mode="all"
    local scope="global"
    local platforms_to_install=()

    # 解析参数
    if [ $# -eq 0 ]; then
        platforms_to_install=("${!PLATFORMS[@]}")
    else
        while [ $# -gt 0 ]; do
            case "$1" in
                --all)
                    platforms_to_install=("${!PLATFORMS[@]}")
                    ;;
                --global)
                    scope="global"
                    ;;
                --project)
                    scope="project"
                    ;;
                --claude|--cursor|--trae|--copilot|--antigravity|--opencode|--windsurf|--gemini|--codex)
                    platforms_to_install+=("${1#--}")
                    ;;
                --help)
                    print_help
                    exit 0
                    ;;
                *)
                    print_error "未知选项：$1"
                    print_help
                    exit 1
                    ;;
            esac
            shift
        done
    fi

    # 如果没有指定平台，默认安装到所有平台
    if [ ${#platforms_to_install[@]} -eq 0 ]; then
        platforms_to_install=("${!PLATFORMS[@]}")
    fi

    # 打印安装信息
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  PX4Agent 一键安装脚本                 ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    print_info "安装范围：$scope"
    print_info "目标平台：${platforms_to_install[*]}"
    echo ""

    # 检查源目录
    check_source
    echo ""

    # 安装到各平台
    local success_count=0
    local fail_count=0

    for platform in "${platforms_to_install[@]}"; do
        echo ""

        # 检查平台是否为软链接平台
        if [[ " ${!SYMLINK_PLATFORMS[@]} " =~ " ${platform} " ]]; then
            # 先确保 Claude 已安装
            if [ ! -d "${PLATFORMS[claude]}" ] || [ -z "$(ls -A "${PLATFORMS[claude]}")" ]; then
                print_warning "Claude 平台未安装，先安装 Claude"
                install_native "claude"
            fi
            install_symlink "$platform"
        else
            install_native "$platform"
        fi

        # 验证安装
        if verify_installation "$platform"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done

    # 打印总结
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  安装完成                              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    print_success "成功安装：$success_count 个平台"
    if [ $fail_count -gt 0 ]; then
        print_error "安装失败：$fail_count 个平台"
    fi

    echo ""
    print_info "下一步："
    echo "  1. 在你的 AI 工具中重启或重新加载 Skills"
    echo "  2. 尝试触发一个 Skill，例如："
    echo "     /px4-sim-start"
    echo "     /px4-imu-gen"
    echo "     /setup-all"
    echo ""

    if [ $fail_count -gt 0 ]; then
        exit 1
    fi
}

# 运行主函数
main "$@"
