#!/bin/bash

# version-manager.sh - PX4Agent Skill 版本管理系统
# 功能：
#   1. 检查所有 Skill 版本号
#   2. 生成 CHANGELOG
#   3. 验证版本一致性
#   4. 自动更新版本号

set -e

SKILLS_DIR=".claude/skills"
CHANGELOG_FILE="CHANGELOG.md"
VERSION_MANIFEST="version-manifest.json"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# 检查 Skill 目录是否存在
check_skills_dir() {
    if [ ! -d "$SKILLS_DIR" ]; then
        log_error "Skills 目录不存在: $SKILLS_DIR"
        exit 1
    fi
    log_success "Skills 目录检查通过"
}

# 从 SKILL.md 中提取版本号
extract_version() {
    local skill_path=$1
    local skill_md="$skill_path/SKILL.md"

    if [ ! -f "$skill_md" ]; then
        echo "unknown"
        return
    fi

    # 从 frontmatter 中提取 version
    grep -m1 'version:' "$skill_md" | sed 's/.*version: *"\([^"]*\)".*/\1/' || echo "unknown"
}

# 从 SKILL.md 中提取描述
extract_description() {
    local skill_path=$1
    local skill_md="$skill_path/SKILL.md"

    if [ ! -f "$skill_md" ]; then
        echo "No description"
        return
    fi

    # 从 frontmatter 中提取 description
    grep -m1 'description:' "$skill_md" | sed 's/.*description: *"\([^"]*\)".*/\1/' || echo "No description"
}

# 生成版本清单 JSON
generate_version_manifest() {
    log_info "生成版本清单..."

    local manifest_content="{\n  \"generated_at\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\",\n  \"skills\": {\n"

    local first=true
    for skill_dir in "$SKILLS_DIR"/*; do
        if [ -d "$skill_dir" ]; then
            local skill_name=$(basename "$skill_dir")
            local version=$(extract_version "$skill_dir")
            local description=$(extract_description "$skill_dir")

            if [ "$first" = false ]; then
                manifest_content="${manifest_content},\n"
            fi
            first=false

            manifest_content="${manifest_content}    \"$skill_name\": {\n"
            manifest_content="${manifest_content}      \"version\": \"$version\",\n"
            manifest_content="${manifest_content}      \"description\": \"$description\",\n"
            manifest_content="${manifest_content}      \"path\": \"$skill_dir\"\n"
            manifest_content="${manifest_content}    }"
        fi
    done

    manifest_content="${manifest_content}\n  }\n}"

    echo -e "$manifest_content" > "$VERSION_MANIFEST"
    log_success "版本清单已生成: $VERSION_MANIFEST"
}

# 检查版本一致性
check_version_consistency() {
    log_info "检查版本一致性..."

    local inconsistencies=0

    for skill_dir in "$SKILLS_DIR"/*; do
        if [ -d "$skill_dir" ]; then
            local skill_name=$(basename "$skill_dir")
            local version=$(extract_version "$skill_dir")

            # 检查版本格式 (应为 X.Y.Z)
            if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                log_warn "$skill_name: 版本格式不规范 ($version)，应为 X.Y.Z"
                ((inconsistencies++))
            fi
        fi
    done

    if [ $inconsistencies -eq 0 ]; then
        log_success "所有 Skill 版本格式正确"
    else
        log_warn "发现 $inconsistencies 个版本格式问题"
    fi
}

# 生成 CHANGELOG
generate_changelog() {
    log_info "生成 CHANGELOG..."

    local changelog_header="# PX4Agent Skills CHANGELOG

> 所有 Skill 版本变更记录

---

## 版本历史

### 当前版本 ($(date +'%Y-%m-%d'))

"

    echo "$changelog_header" > "$CHANGELOG_FILE"

    # 按层级组织 Skill
    echo "#### Layer 3 - 场景技能" >> "$CHANGELOG_FILE"
    for skill_dir in "$SKILLS_DIR"/px4-e2e-*; do
        if [ -d "$skill_dir" ]; then
            local skill_name=$(basename "$skill_dir")
            local version=$(extract_version "$skill_dir")
            local description=$(extract_description "$skill_dir")
            echo "- **$skill_name** v$version: $description" >> "$CHANGELOG_FILE"
        fi
    done

    echo "" >> "$CHANGELOG_FILE"
    echo "#### Layer 2 - 组件技能" >> "$CHANGELOG_FILE"
    for skill_dir in "$SKILLS_DIR"/px4-*; do
        if [ -d "$skill_dir" ] && [[ ! $(basename "$skill_dir") =~ ^px4-e2e ]]; then
            local skill_name=$(basename "$skill_dir")
            local version=$(extract_version "$skill_dir")
            local description=$(extract_description "$skill_dir")
            echo "- **$skill_name** v$version: $description" >> "$CHANGELOG_FILE"
        fi
    done

    echo "" >> "$CHANGELOG_FILE"
    echo "#### Layer 1 - 基础设施技能" >> "$CHANGELOG_FILE"
    for skill_dir in "$SKILLS_DIR"/{commit,review,handoff,simplify,clean-contract}; do
        if [ -d "$skill_dir" ]; then
            local skill_name=$(basename "$skill_dir")
            local version=$(extract_version "$skill_dir")
            local description=$(extract_description "$skill_dir")
            echo "- **$skill_name** v$version: $description" >> "$CHANGELOG_FILE"
        fi
    done

    echo "" >> "$CHANGELOG_FILE"
    echo "#### Layer 0.5 - 环境安装技能" >> "$CHANGELOG_FILE"
    for skill_dir in "$SKILLS_DIR"/setup-*; do
        if [ -d "$skill_dir" ]; then
            local skill_name=$(basename "$skill_dir")
            local version=$(extract_version "$skill_dir")
            local description=$(extract_description "$skill_dir")
            echo "- **$skill_name** v$version: $description" >> "$CHANGELOG_FILE"
        fi
    done

    log_success "CHANGELOG 已生成: $CHANGELOG_FILE"
}

# 统计 Skill 数量
count_skills() {
    local count=0
    for skill_dir in "$SKILLS_DIR"/*; do
        if [ -d "$skill_dir" ]; then
            ((count++))
        fi
    done
    echo $count
}

# 生成版本报告
generate_version_report() {
    log_info "生成版本报告..."

    local total_skills=$(count_skills)

    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║     PX4Agent Skills 版本报告           ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "生成时间: $(date +'%Y-%m-%d %H:%M:%S')"
    echo "总 Skill 数: $total_skills"
    echo ""

    # 按层级统计
    local layer3_count=$(ls -d "$SKILLS_DIR"/px4-e2e-* 2>/dev/null | wc -l)
    local layer2_count=$(ls -d "$SKILLS_DIR"/px4-* 2>/dev/null | grep -v px4-e2e | wc -l)
    local layer1_count=$(ls -d "$SKILLS_DIR"/{commit,review,handoff,simplify,clean-contract} 2>/dev/null | wc -l)
    local layer05_count=$(ls -d "$SKILLS_DIR"/setup-* 2>/dev/null | wc -l)

    echo "Layer 3 (场景技能):     $layer3_count"
    echo "Layer 2 (组件技能):     $layer2_count"
    echo "Layer 1 (基础设施):     $layer1_count"
    echo "Layer 0.5 (环境安装):   $layer05_count"
    echo ""
}

# 主函数
main() {
    case "${1:-report}" in
        report)
            check_skills_dir
            generate_version_report
            ;;
        manifest)
            check_skills_dir
            generate_version_manifest
            log_success "版本清单已生成"
            ;;
        changelog)
            check_skills_dir
            generate_changelog
            ;;
        check)
            check_skills_dir
            check_version_consistency
            ;;
        all)
            check_skills_dir
            generate_version_report
            generate_version_manifest
            generate_changelog
            check_version_consistency
            log_success "所有版本管理任务已完成"
            ;;
        *)
            echo "用法: $0 {report|manifest|changelog|check|all}"
            echo ""
            echo "命令说明:"
            echo "  report      - 生成版本报告（默认）"
            echo "  manifest    - 生成版本清单 JSON"
            echo "  changelog   - 生成 CHANGELOG.md"
            echo "  check       - 检查版本一致性"
            echo "  all         - 执行所有任务"
            exit 1
            ;;
    esac
}

main "$@"
