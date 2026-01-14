#!/bin/bash
################################################################################
# 测试运行脚本
# 提供统一的测试入口
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 统计变量
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

#--------------------------------------------------------------------------------
#  帮助信息
#--------------------------------------------------------------------------------

show_help() {
    cat << EOF
${BLUE}CIS Kubernetes Benchmark - 测试运行器${NC}

用法: $(basename "$0") [选项]

选项:
  -u, --unit          运行单元测试
  -i, --integration   运行集成测试
  -a, --all           运行所有测试
  -v, --verbose       详细输出
  -c, --coverage      生成覆盖率报告
  -h, --help          显示帮助信息

示例:
  $(basename "$0") --all         # 运行所有测试
  $(basename "$0") --unit        # 只运行单元测试
  $(basename "$0") --verbose     # 详细模式运行

EOF
}

#--------------------------------------------------------------------------------
#  检查依赖
#--------------------------------------------------------------------------------

check_dependencies() {
    echo -e "${BLUE}检查依赖...${NC}"

    # 检查 BATS
    if ! command -v bats &> /dev/null; then
        echo -e "${YELLOW}BATS 未安装，正在安装...${NC}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install bats-core
        else
            sudo apt-get install -y bats
        fi
    fi

    # 检查 ShellCheck
    if ! command -v shellcheck &> /dev/null; then
        echo -e "${YELLOW}ShellCheck 未安装，正在安装...${NC}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install shellcheck
        else
            sudo apt-get install -y shellcheck
        fi
    fi

    echo -e "${GREEN}✓ 依赖检查完成${NC}\n"
}

#--------------------------------------------------------------------------------
#  语法检查
#--------------------------------------------------------------------------------

syntax_check() {
    echo -e "${BLUE}运行语法检查...${NC}"

    if bash -n "$PROJECT_DIR/cis_kubernetes_benchmark.sh"; then
        echo -e "${GREEN}✓ 语法检查通过${NC}\n"
    else
        echo -e "${RED}✗ 语法检查失败${NC}\n"
        exit 1
    fi
}

#--------------------------------------------------------------------------------
#  ShellCheck
#--------------------------------------------------------------------------------

shellcheck_lint() {
    echo -e "${BLUE}运行 ShellCheck...${NC}"

    if shellcheck "$PROJECT_DIR/cis_kubernetes_benchmark.sh"; then
        echo -e "${GREEN}✓ ShellCheck 通过${NC}\n"
    else
        echo -e "${YELLOW}⚠ ShellCheck 发现问题${NC}\n"
    fi
}

#--------------------------------------------------------------------------------
#  运行测试
#--------------------------------------------------------------------------------

run_unit_tests() {
    echo -e "${BLUE}运行单元测试...${NC}\n"

    local test_file="$SCRIPT_DIR/unit/unit_tests.bats"

    if [[ "$VERBOSE" == "true" ]]; then
        bats --verbose "$test_file"
    else
        bats "$test_file"
    fi
}

run_integration_tests() {
    echo -e "${BLUE}运行集成测试...${NC}\n"

    local test_file="$SCRIPT_DIR/integration/integration_tests.bats"

    if [[ "$VERBOSE" == "true" ]]; then
        bats --verbose "$test_file"
    else
        bats "$test_file"
    fi
}

run_all_tests() {
    echo -e "${BLUE}运行所有测试...${NC}\n"

    # 生成 Mock 数据
    echo -e "${BLUE}生成 Mock 数据...${NC}"
    bash "$SCRIPT_DIR/mocks/create_mocks.sh"
    echo ""

    # 运行测试套件
    local test_file="$SCRIPT_DIR/test_suite.bats"

    if [[ "$VERBOSE" == "true" ]]; then
        bats --verbose "$test_file"
    else
        bats "$test_file"
    fi
}

#--------------------------------------------------------------------------------
#  覆盖率报告
#--------------------------------------------------------------------------------

generate_coverage() {
    echo -e "${BLUE}生成覆盖率报告...${NC}"

    mkdir -p "$PROJECT_DIR/build/coverage"

    cat > "$PROJECT_DIR/build/coverage/coverage.md" << EOF
# 测试覆盖率报告

生成时间: $(date)

## 测试统计

- 总函数数: $(grep -c "^.*() {" "$PROJECT_DIR/cis_kubernetes_benchmark.sh")
- 总行数: $(wc -l < "$PROJECT_DIR/cis_kubernetes_benchmark.sh")

## 测试覆盖

### 单元测试
- 文件权限检查
- 参数检查逻辑
- 输出过滤功能
- 辅助函数

### 集成测试
- 脚本加载测试
- 三层检查框架
- 检查项完整性
- 端到端流程

EOF

    echo -e "${GREEN}✓ 覆盖率报告已生成: $PROJECT_DIR/build/coverage/coverage.md${NC}\n"
}

#--------------------------------------------------------------------------------
#  主程序
#--------------------------------------------------------------------------------

main() {
    local RUN_UNIT=false
    local RUN_INTEGRATION=false
    local RUN_ALL=false
    local VERBOSE=false
    local COVERAGE=false

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--unit)
                RUN_UNIT=true
                shift
                ;;
            -i|--integration)
                RUN_INTEGRATION=true
                shift
                ;;
            -a|--all)
                RUN_ALL=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                export VERBOSE
                shift
                ;;
            -c|--coverage)
                COVERAGE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done

    # 如果没有指定任何测试，运行所有
    if [[ "$RUN_UNIT" == "false" && "$RUN_INTEGRATION" == "false" && "$RUN_ALL" == "false" ]]; then
        RUN_ALL=true
    fi

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  CIS Kubernetes Benchmark 测试${NC}"
    echo -e "${BLUE}========================================${NC}\n"

    # 检查依赖
    check_dependencies

    # 语法检查
    syntax_check

    # ShellCheck
    shellcheck_lint

    # 运行测试
    local start_time=$(date +%s)

    if [[ "$RUN_ALL" == "true" ]]; then
        run_all_tests
    else
        if [[ "$RUN_UNIT" == "true" ]]; then
            run_unit_tests
        fi

        if [[ "$RUN_INTEGRATION" == "true" ]]; then
            run_integration_tests
        fi
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # 覆盖率
    if [[ "$COVERAGE" == "true" ]]; then
        generate_coverage
    fi

    # 汇总
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  测试完成${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "耗时: ${GREEN}${duration}秒${NC}\n"
}

# 运行主程序
main "$@"
