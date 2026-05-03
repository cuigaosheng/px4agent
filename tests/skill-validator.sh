#!/bin/bash

# skill-validator.sh - PX4Agent Skill 自动化验证框架
# 功能：
#   1. 验证 SKILL.md 格式和 frontmatter
#   2. 检查步骤完整性
#   3. 验证代码示例语法
#   4. 检查编码规范合规性

set -e

SKILLS_DIR=".claude/skills"
TESTS_DIR="tests"
REPORT_FILE="$TESTS_DIR/validation-report.txt"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 统计变量
TOTAL_SKILLS=0
PASSED_SKILLS=0
FAILED_SKILLS=0
WARNINGS=0

# 日志函数
log_info() {
    echo -e "${BLUE}ℹ${NC} $1" | tee -a "$REPORT_FILE"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$REPORT_FILE"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$REPORT_FILE"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$REPORT_FILE"
}

# 初始化报告文件
init_report() {
    mkdir -p "$TESTS_DIR"
    > "$REPORT_FILE"
    echo "PX4Agent Skill 验证报告" >> "$REPORT_FILE"
    echo "生成时间: $(date +'%Y-%m-%d %H:%M:%S')" >> "$REPORT_FILE"
    echo "========================================" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# 验证 frontmatter 格式
validate_frontmatter() {
    local skill_md=$1
    local skill_name=$(basename $(dirname "$skill_md"))

    if ! grep -q "^---$" "$skill_md"; then
        log_error "$skill_name: 缺少 frontmatter 分隔符 (---)"
        return 1
    fi

    # 检查必需字段
    local required_fields=("name" "version" "description" "disable-model-invocation" "allowed-tools")
    for field in "${required_fields[@]}"; do
        if ! grep -q "^$field:" "$skill_md"; then
            log_error "$skill_name: 缺少必需字段 ($field)"
            return 1
        fi
    done

    # 验证版本格式
    local version=$(grep "^version:" "$skill_md" | sed 's/.*version: *"\([^"]*\)".*/\1/')
    if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_warn "$skill_name: 版本格式不规范 ($version)，应为 X.Y.Z"
        return 1
    fi

    return 0
}

# 验证步骤完整性
validate_steps() {
    local skill_md=$1
    local skill_name=$(basename $(dirname "$skill_md"))

    # 提取 frontmatter 后的内容
    local content=$(sed -n '/^---$/,$ p' "$skill_md" | tail -n +2)

    # 检查是否有步骤标题
    if ! echo "$content" | grep -q "^## "; then
        log_warn "$skill_name: 没有找到步骤标题 (## Step ...)"
        return 1
    fi

    # 检查步骤编号连续性
    local step_numbers=$(echo "$content" | grep "^## Step" | sed 's/.*Step \([0-9]*\).*/\1/' | sort -n)
    local expected=1
    for num in $step_numbers; do
        if [ "$num" -ne "$expected" ]; then
            log_warn "$skill_name: 步骤编号不连续 (期望 $expected，得到 $num)"
            return 1
        fi
        ((expected++))
    done

    return 0
}

# 检查代码块完整性
validate_code_blocks() {
    local skill_md=$1
    local skill_name=$(basename $(dirname "$skill_md"))

    # 检查代码块是否有开始和结束标记
    local open_blocks=$(grep -c "^\`\`\`" "$skill_md" || true)
    if [ $((open_blocks % 2)) -ne 0 ]; then
        log_warn "$skill_name: 代码块标记不匹配 (开始/结束数不相等)"
        return 1
    fi

    return 0
}

# 检查编码规范合规性
validate_coding_standards() {
    local skill_md=$1
    local skill_name=$(basename $(dirname "$skill_md"))

    # 检查是否包含禁止的模式
    local violations=0

    # 检查动态内存分配
    if grep -q "new \|delete \|malloc\|free" "$skill_md"; then
        log_warn "$skill_name: 代码示例中包含动态内存分配 (new/delete/malloc/free)"
        ((violations++))
    fi

    # 检查 printf
    if grep -q "printf" "$skill_md"; then
        log_warn "$skill_name: 代码示例中包含 printf，应使用 PX4_DEBUG/INFO/WARN/ERR"
        ((violations++))
    fi

    # 检查 sleep/usleep
    if grep -q "sleep\|usleep" "$skill_md"; then
        log_warn "$skill_name: 代码示例中包含阻塞调用 (sleep/usleep)，应使用 ScheduleDelayed()"
        ((violations++))
    fi

    # 检查 mutex lock
    if grep -q "mutex\|lock" "$skill_md"; then
        log_warn "$skill_name: 代码示例中包含 mutex lock，应使用 ScheduledWorkItem"
        ((violations++))
    fi

    if [ $violations -gt 0 ]; then
        return 1
    fi

    return 0
}

# 验证单个 Skill
validate_skill() {
    local skill_dir=$1
    local skill_name=$(basename "$skill_dir")
    local skill_md="$skill_dir/SKILL.md"

    ((TOTAL_SKILLS++))

    if [ ! -f "$skill_md" ]; then
        log_error "$skill_name: 缺少 SKILL.md 文件"
        ((FAILED_SKILLS++))
        return 1
    fi

    log_info "验证 $skill_name..."

    local failed=0

    # 运行所有验证
    validate_frontmatter "$skill_md" || ((failed++))
    validate_steps "$skill_md" || ((failed++))
    validate_code_blocks "$skill_md" || ((failed++))
    validate_coding_standards "$skill_md" || ((failed++))

    if [ $failed -eq 0 ]; then
        log_success "$skill_name 验证通过"
        ((PASSED_SKILLS++))
        return 0
    else
        log_error "$skill_name 验证失败 ($failed 个问题)"
        ((FAILED_SKILLS++))
        return 1
    fi
}

# 验证所有 Skill
validate_all_skills() {
    log_info "开始验证所有 Skill..."
    echo "" >> "$REPORT_FILE"

    for skill_dir in "$SKILLS_DIR"/*; do
        if [ -d "$skill_dir" ]; then
            validate_skill "$skill_dir"
        fi
    done
}

# 生成验证报告
generate_report() {
    echo "" >> "$REPORT_FILE"
    echo "========================================" >> "$REPORT_FILE"
    echo "验证摘要" >> "$REPORT_FILE"
    echo "========================================" >> "$REPORT_FILE"
    echo "总 Skill 数:     $TOTAL_SKILLS" >> "$REPORT_FILE"
    echo "通过验证:        $PASSED_SKILLS" >> "$REPORT_FILE"
    echo "验证失败:        $FAILED_SKILLS" >> "$REPORT_FILE"
    echo "警告数:          $WARNINGS" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    if [ $FAILED_SKILLS -eq 0 ]; then
        echo "✓ 所有 Skill 验证通过" >> "$REPORT_FILE"
        log_success "所有 Skill 验证通过"
        return 0
    else
        echo "✗ 有 $FAILED_SKILLS 个 Skill 验证失败" >> "$REPORT_FILE"
        log_error "有 $FAILED_SKILLS 个 Skill 验证失败"
        return 1
    fi
}

# 主函数
main() {
    init_report
    validate_all_skills
    generate_report

    echo ""
    echo "验证报告已保存到: $REPORT_FILE"
    echo ""

    if [ $FAILED_SKILLS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
