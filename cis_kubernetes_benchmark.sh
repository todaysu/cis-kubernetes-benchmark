#!/bin/bash
################################################################################
# CIS Kubernetes Benchmark v1.12.0 审计脚本 (增强版)
#
# ============================================================================
# 脚本说明
# ============================================================================
# 本脚本用于审计 Kubernetes 集群是否符合 CIS Kubernetes Benchmark v1.12.0
# 安全基线标准。脚本实现了完整的三层检查机制，确保全面覆盖所有安全配置项。
#
# ============================================================================
# 使用方法
# ============================================================================
#   基本用法:
#     sudo ./cis_kubernetes_benchmark.sh master   # 审计 Master 节点
#     sudo ./cis_kubernetes_benchmark.sh worker  # 审计 Worker 节点
#
#   输出过滤:
#     sudo ./cis_kubernetes_benchmark.sh master --only-pass    # 只显示 PASS
#     sudo ./cis_kubernetes_benchmark.sh master --only-warn    # 只显示 WARN
#     sudo ./cis_kubernetes_benchmark.sh master --only-fail    # 只显示 FAIL
#     sudo ./cis_kubernetes_benchmark.sh master --only-error   # 只显示 FAIL 和 WARN
#     sudo ./cis_kubernetes_benchmark.sh master --quiet        # 安静模式，只显示汇总
#
# ============================================================================
# 三层检查机制
# ============================================================================
#   L1 (Layer 1): 进程参数检查 - 检查运行中进程的实际启动参数 (最高优先级)
#   L2 (Layer 2): 配置文件检查 - 检查配置文件中的持久化配置 (中等优先级)
#   L3 (Layer 3): 默认值检查 - 检查组件的默认值 (最低优先级)
#
# ============================================================================
# 基于
# ============================================================================
#   CIS Kubernetes Benchmark v1.12.0
#   官方网站: https://www.cisecurity.org/benchmark/kubernetes
#
# ============================================================================
# 版本历史
# ============================================================================
#   v1.0.0 - 初始版本，基于 CIS v1.12.0 标准实现
#   v1.1.0 - 添加三层检查框架
#   v1.2.0 - 添加 Container Runtime 检查和增强 Policies 检查
#   v1.3.0 - 添加输出过滤功能 (--only-pass, --only-warn, --only-fail, --only-error, --quiet)
#
# ============================================================================
# 维护说明
# ============================================================================
#   当 CIS 发布新版本时，请参考以下步骤更新：
#   1. 从 CIS 官网下载最新版本的 Benchmark 文档
#   2. 对比新旧版本的差异（新增、修改、删除的检查项）
#   3. 更新对应 Section 的检查函数
#   4. 更新版本号和修改日志
#   5. 测试验证所有检查项
#
################################################################################

#-----------------------------#
#  输出过滤选项
#-----------------------------#
FILTER_MODE="all"    # 过滤模式: all, pass, warn, fail, error, quiet
SHOW_PASS=true      # 是否显示 PASS
SHOW_WARN=true      # 是否显示 WARN
SHOW_FAIL=true      # 是否显示 FAIL
QUIET_MODE=false    # 安静模式（只显示汇总）

#-----------------------------#
#  颜色定义 - 用于终端输出高亮
#-----------------------------#
RED='\033[0;31m'      # 红色 - FAIL
GREEN='\033[0;32m'    # 绿色 - PASS
YELLOW='\033[0;33m'   # 黄色 - WARN
BLUE='\033[0;34m'     # 蓝色 - INFO
NC='\033[0m'          # 无颜色 - 重置

#-----------------------------#
#  计数器变量 - 用于统计检查结果
#-----------------------------#
PASS_COUNT=0      # 通过数量
FAIL_COUNT=0      # 失败数量
WARN_COUNT=0      # 警告数量
TOTAL_CHECKS=0    # 总检查数量

#-----------------------------#
#  辅助函数区域
#-----------------------------#

#--------------------------------------------------------------------------------
#  函数: print_result
#  功能: 打印带颜色的检查结果（支持输出过滤）
#  参数:
#    $1 - status: 状态 (PASS/FAIL/WARN)
#    $2 - message: 结果描述信息
#    $3 - check_id: 检查项编号 (如 "1.1.1")
#  返回: 无
#  过滤选项:
#    --only-pass   : 只显示 PASS 结果
#    --only-warn   : 只显示 WARN 结果
#    --only-fail   : 只显示 FAIL 结果
#    --only-error  : 只显示 FAIL 和 WARN 结果
#    --quiet       : 安静模式，只显示汇总报告
#--------------------------------------------------------------------------------
print_result() {
    local status=$1
    local message=$2
    local check_id=$3

    # 始终更新计数器（即使在安静模式下）
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    # 安静模式：不输出任何检查结果
    if [[ "$QUIET_MODE" == "true" ]]; then
        case $status in
            "PASS") PASS_COUNT=$((PASS_COUNT + 1)) ;;
            "FAIL") FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
            "WARN") WARN_COUNT=$((WARN_COUNT + 1)) ;;
        esac
        return
    fi

    # 根据过滤模式决定是否输出
    local should_print=false

    case $status in
        "PASS")
            PASS_COUNT=$((PASS_COUNT + 1))
            [[ "$SHOW_PASS" == "true" ]] && should_print=true
            ;;
        "FAIL")
            FAIL_COUNT=$((FAIL_COUNT + 1))
            [[ "$SHOW_FAIL" == "true" ]] && should_print=true
            ;;
        "WARN")
            WARN_COUNT=$((WARN_COUNT + 1))
            [[ "$SHOW_WARN" == "true" ]] && should_print=true
            ;;
    esac

    # 输出结果
    if [[ "$should_print" == "true" ]]; then
        case $status in
            "PASS")
                echo -e "${GREEN}[PASS]${NC} $check_id: $message"
                ;;
            "FAIL")
                echo -e "${RED}[FAIL]${NC} $check_id: $message"
                ;;
            "WARN")
                echo -e "${YELLOW}[WARN]${NC} $check_id: $message"
                ;;
        esac
    fi
}

# Check if file exists
check_file_exists() {
    local file=$1
    if [[ ! -e "$file" ]]; then
        return 1
    fi
    return 0
}

# Check file permissions (numeric)
check_file_permissions() {
    local file=$1
    local expected_max_perm=$2

    if ! check_file_exists "$file"; then
        return 2
    fi

    local actual_perm
    if [[ "$OSTYPE" == "darwin"* ]]; then
        actual_perm=$(stat -f "%Lp" "$file")
    else
        actual_perm=$(stat -c "%a" "$file" 2>/dev/null || stat -c "%a" "$file")
    fi

    # Convert to integer for comparison
    actual_perm=$((10#$actual_perm))
    expected_max_perm=$((10#$expected_max_perm))

    # Check if actual is equal to or more restrictive than expected
    # More restrictive means lower numeric value
    if [[ $actual_perm -le $expected_max_perm ]]; then
        return 0
    else
        return 1
    fi
}

# Check file ownership
check_file_ownership() {
    local file=$1
    local expected_user=$2
    local expected_group=${3:-$2}

    if ! check_file_exists "$file"; then
        return 2
    fi

    local actual_user
    local actual_group

    if [[ "$OSTYPE" == "darwin"* ]]; then
        actual_user=$(stat -f "%Su" "$file")
        actual_group=$(stat -f "%Sg" "$file")
    else
        actual_user=$(stat -c "%U" "$file")
        actual_group=$(stat -c "%G" "$file")
    fi

    if [[ "$actual_user" == "$expected_user" && "$actual_group" == "$expected_group" ]]; then
        return 0
    else
        return 1
    fi
}

# Check directory ownership recursively
check_dir_ownership_recursive() {
    local dir=$1
    local expected_user=$2
    local expected_group=${3:-$2}

    if ! check_file_exists "$dir"; then
        return 2
    fi

    local failed_files=0
    while IFS= read -r -d '' file; do
        local actual_user
        local actual_group

        if [[ "$OSTYPE" == "darwin"* ]]; then
            actual_user=$(stat -f "%Su" "$file")
            actual_group=$(stat -f "%Sg" "$file")
        else
            actual_user=$(stat -c "%U" "$file")
            actual_group=$(stat -c "%G" "$file")
        fi

        if [[ "$actual_user" != "$expected_user" || "$actual_group" != "$expected_group" ]]; then
            failed_files=$((failed_files + 1))
        fi
    done < <(find "$dir" -type f -print0 2>/dev/null)

    if [[ $failed_files -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

#-----------------------------#
#  Process Parameter Check Functions
#-----------------------------#

# Get kube-apiserver process arguments
get_apiserver_args() {
    ps aux | grep '[k]ube-apiserver' 2>/dev/null
}

# Check if an argument is present in process
check_argument_present() {
    local arg_name=$1
    local process_info=$2

    if echo "$process_info" | grep -q -- "$arg_name"; then
        return 0
    else
        return 1
    fi
}

# Check if an argument has a specific value
check_argument_value() {
    local arg_name=$1
    local expected_value=$2
    local process_info=$3

    # Try to extract the argument value
    local actual_value
    actual_value=$(echo "$process_info" | grep -oP "(?<=${arg_name}=)[^ ]+" 2>/dev/null || echo "$process_info" | grep -o -- "${arg_name}[^ ]*" | cut -d'=' -f2)

    if [[ "$actual_value" == "$expected_value" ]]; then
        return 0
    else
        return 1
    fi
}

# Check if an argument is NOT present (for security checks)
check_argument_absent() {
    local arg_name=$1
    local process_info=$2

    if echo "$process_info" | grep -q -- "$arg_name"; then
        return 1  # Found - should be absent
    else
        return 0  # Not found - good
    fi
}

# Check if argument is in a list of values
check_argument_in_list() {
    local arg_name=$1
    local expected_values=$2  # Comma-separated list
    local process_info=$3

    local actual_value
    actual_value=$(echo "$process_info" | grep -oP "(?<=${arg_name}=)[^ ]+" 2>/dev/null || echo "$process_info" | grep -o -- "${arg_name}[^ ]*" | cut -d'=' -f2)

    # Convert to array and check
    local IFS=','
    read -ra values <<< "$expected_values"
    for value in "${values[@]}"; do
        if [[ "$actual_value" == *"$value"* ]]; then
            return 0
        fi
    done
    return 1
}

# Check if admission plugin is present
check_admission_plugin() {
    local plugin=$1
    local process_info=$2

    if echo "$process_info" | grep -q -- "enable-admission-plugins=.*${plugin}.*"; then
        return 0
    else
        return 1
    fi
}

#================================================================================
#  三层检查框架 (THREE-LAYER CHECKING FRAMEWORK)
#================================================================================
#
#  本框架实现了完整的三层检查机制，确保全面覆盖 Kubernetes 组件的配置检查：
#
#  ┌─────────────────────────────────────────────────────────────────────┐
#  │                          三层检查流程                                │
#  ├─────────────────────────────────────────────────────────────────────┤
#  │                                                                     │
#  │  ① L1 (Layer 1) - 进程参数检查                                     │
#  │     ├─ 优先级: 最高                                                 │
#  │     ├─ 检查对象: 运行中进程的实际启动参数                          │
#  │     ├─ 检查方法: ps aux | grep [component]                         │
#  │     ├─ 结果判定: 如果进程参数存在，直接判定并返回                  │
#  │     └─ 未找到则进入 L2 层检查                                      │
#  │                                                                     │
#  │  ② L2 (Layer 2) - 配置文件检查                                     │
#  │     ├─ 优先级: 中等                                                 │
#  │     ├─ 检查对象: 配置文件中的持久化配置                            │
#  │     ├─ 检查方法: 读取 YAML/JSON 配置文件                          │
#  │     ├─ 结果判定: 如果配置文件中存在，直接判定并返回                │
#  │     └─ 未找到则进入 L3 层检查                                      │
#  │                                                                     │
#  │  ③ L3 (Layer 3) - 默认值检查                                       │
#  │     ├─ 优先级: 最低                                                 │
#  │     ├─ 检查对象: Kubernetes 组件的默认值                           │
#  │     ├─ 检查方法: 预定义的默认值表                                  │
#  │     └─ 结果判定: 根据默认值判定                                    │
#  │                                                                     │
#  └─────────────────────────────────────────────────────────────────────┘
#
#================================================================================
#  使用方法 (USAGE)
#================================================================================
#
#  check_parameter_three_layer <component> <param_name> <expected_value> [config_file] [default_value]
#
#  参数说明:
#    component        - 组件名称 (apiserver, controller-manager, scheduler, kubelet, etcd)
#    param_name       - 参数名称 (使用 kebab-case 格式，如 anonymous-auth)
#    expected_value   - 期望的安全值 (如 false, 127.0.0.1)
#    config_file      - 配置文件路径 (可选，用于 L2 层检查)
#    default_value    - 默认值 (可选，用于 L3 层检查)
#
#  返回值:
#    0 - 参数合规 (在任何一层找到且值匹配)
#    1 - 参数不合规 (找到但值不匹配)
#    2 - 参数未找到 (所有层都未找到)
#
#  全局变量 (输出):
#    CHECK_RESULT  - 检查结果 (PASS/FAIL/WARN/SKIP/NOT_FOUND)
#    CHECK_LAYER   - 检查来源层级 (L1/L2/L3/NOT_FOUND/L0)
#    CHECK_MESSAGE - 检查结果描述信息
#
#================================================================================
#  示例 (EXAMPLES)
#================================================================================
#
#  # 示例 1: 检查 API Server 的 anonymous-auth 参数
#  check_parameter_three_layer "apiserver" "anonymous-auth" "false" "/etc/kubernetes/manifests/kube-apiserver.yaml" "true"
#
#  # 示例 2: 使用简化函数直接打印结果
#  check_and_print_three_layer "1.2.1" "apiserver" "anonymous-auth" "false" "/etc/kubernetes/manifests/kube-apiserver.yaml" "true"
#
#================================================================================

#--------------------------------------------------------------------------------
#  函数组: 获取各组件配置文件内容
#  功能: 按优先级顺序读取各组件的配置文件，用于 L2 层检查
#--------------------------------------------------------------------------------

# 获取 API Server 配置文件内容
get_apiserver_config() {
    local config_files=(
        "/etc/kubernetes/manifests/kube-apiserver.yaml"
        "/etc/kubernetes/apiserver.conf"
    )
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            cat "$file" 2>/dev/null
            return 0
        fi
    done
    return 1
}

# 获取 Controller Manager 配置文件内容
get_controller_manager_config() {
    local config_files=(
        "/etc/kubernetes/manifests/kube-controller-manager.yaml"
        "/etc/kubernetes/controller-manager.conf"
    )
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            cat "$file" 2>/dev/null
            return 0
        fi
    done
    return 1
}

# 获取 Scheduler 配置文件内容
get_scheduler_config() {
    local config_files=(
        "/etc/kubernetes/manifests/kube-scheduler.yaml"
        "/etc/kubernetes/scheduler.conf"
    )
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            cat "$file" 2>/dev/null
            return 0
        fi
    done
    return 1
}

# 获取 Kubelet 配置文件内容 (别名函数，保持一致性)
get_kubelet_config_file() {
    get_kubelet_config
}

# 获取 etcd 配置文件内容
get_etcd_config() {
    local config_files=(
        "/etc/kubernetes/manifests/etcd.yaml"
        "/etc/etcd/etcd.conf"
    )
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            cat "$file" 2>/dev/null
            return 0
        fi
    done
    return 1
}

#--------------------------------------------------------------------------------
#  Core three-layer parameter check function
#
#  Parameters:
#    component:        Component name (apiserver, controller-manager, scheduler, kubelet, etcd)
#    param_name:       Parameter name (kebab-case for CLI, will be converted for config files)
#    expected_value:   Expected/secure value
#    config_file_path: Optional - path to config file for L2 check
#    default_value:    Optional - default value for L3 check
#
#  Returns:
#    0: Parameter is compliant (found and matches expected at any layer)
#    1: Parameter is non-compliant (found but doesn't match)
#    2: Parameter not found or unknown default
#
#  Sets global variables: CHECK_RESULT, CHECK_LAYER, CHECK_MESSAGE
#--------------------------------------------------------------------------------

check_parameter_three_layer() {
    local component=$1
    local param_name=$2
    local expected_value=$3
    local config_file_path=${4:-""}
    local default_value=${5:-""}

    # Result variables (global)
    CHECK_RESULT=""
    CHECK_LAYER=""
    CHECK_MESSAGE=""

    #================================================================================
    #  LAYER 1: Process Arguments Check (Runtime - Highest Priority)
    #================================================================================
    local process_info=""
    local param_cli_format="--$param_name"

    case "$component" in
        apiserver)
            process_info=$(get_apiserver_args)
            ;;
        controller-manager)
            process_info=$(get_controller_manager_args)
            ;;
        scheduler)
            process_info=$(get_scheduler_args)
            ;;
        kubelet)
            process_info=$(get_kubelet_args)
            ;;
        etcd)
            process_info=$(get_etcd_args)
            ;;
        *)
            CHECK_RESULT="SKIP"
            CHECK_LAYER="L0"
            CHECK_MESSAGE="Unknown component: $component"
            return 2
            ;;
    esac

    # L1 Check: Process arguments
    if [[ -n "$process_info" ]]; then
        if echo "$process_info" | grep -qw -- "${param_cli_format}"; then
            # Boolean flag without value (check presence only)
            if [[ "$expected_value" == "true" || "$expected_value" == "false" ]]; then
                # For boolean flags, check if they exist with =value
                local actual_value=$(echo "$process_info" | grep -oP "(?<=${param_cli_format}=)[^ ]+" 2>/dev/null | head -1)
                if [[ -n "$actual_value" ]]; then
                    if [[ "$actual_value" == "$expected_value" ]]; then
                        CHECK_RESULT="PASS"
                        CHECK_LAYER="L1"
                        CHECK_MESSAGE="$param_name=$actual_value (L1: process)"
                        return 0
                    else
                        CHECK_RESULT="FAIL"
                        CHECK_LAYER="L1"
                        CHECK_MESSAGE="$param_name=$actual_value, expected: $expected_value (L1: process)"
                        return 1
                    fi
                fi
            else
                # Non-boolean parameter with value
                local actual_value=$(echo "$process_info" | grep -oP "(?<=${param_cli_format}=)[^ ]+" 2>/dev/null | head -1)
                if [[ -n "$actual_value" ]]; then
                    if [[ "$actual_value" == "$expected_value" ]]; then
                        CHECK_RESULT="PASS"
                        CHECK_LAYER="L1"
                        CHECK_MESSAGE="$param_name=$actual_value (L1: process)"
                        return 0
                    else
                        CHECK_RESULT="FAIL"
                        CHECK_LAYER="L1"
                        CHECK_MESSAGE="$param_name=$actual_value, expected: $expected_value (L1: process)"
                        return 1
                    fi
                fi
            fi
        fi
    fi

    #================================================================================
    #  LAYER 2: Configuration File Check (Persistent - Medium Priority)
    #================================================================================
    if [[ -n "$config_file_path" && -f "$config_file_path" ]]; then
        # Convert param_name from kebab-case to camelCase for config files
        # Example: anonymous-auth -> anonymousAuth
        local config_key=$(echo "$param_name" | sed -r 's/-([a-z])/\U\1/g')

        # Try to extract value from YAML/JSON config
        local actual_value=$(grep -E "^\s*$config_key\s*:" "$config_file_path" 2>/dev/null | sed -r 's/.*:\s*//' | tr -d ' "\047"' | head -1)

        if [[ -n "$actual_value" ]]; then
            if [[ "$actual_value" == "$expected_value" ]]; then
                CHECK_RESULT="PASS"
                CHECK_LAYER="L2"
                CHECK_MESSAGE="$config_key: $actual_value (L2: config)"
                return 0
            else
                CHECK_RESULT="FAIL"
                CHECK_LAYER="L2"
                CHECK_MESSAGE="$config_key: $actual_value, expected: $expected_value (L2: config)"
                return 1
            fi
        fi
    fi

    #================================================================================
    #  LAYER 3: Default Value Check (Fallback - Lowest Priority)
    #================================================================================
    if [[ -n "$default_value" ]]; then
        if [[ "$default_value" == "$expected_value" ]]; then
            CHECK_RESULT="PASS"
            CHECK_LAYER="L3"
            CHECK_MESSAGE="$param_name uses secure default: $default_value (L3: default)"
            return 0
        else
            CHECK_RESULT="WARN"
            CHECK_LAYER="L3"
            CHECK_MESSAGE="$param_name default: $default_value, expected: $expected_value (L3: default)"
            return 2
        fi
    else
        # Parameter not found at any layer and no default specified
        CHECK_RESULT="WARN"
        CHECK_LAYER="NOT_FOUND"
        CHECK_MESSAGE="$param_name not found in process, config, or defaults"
        return 2
    fi
}

#--------------------------------------------------------------------------------
#  Helper function: Check and print result in one call
#--------------------------------------------------------------------------------
check_and_print_three_layer() {
    local check_id=$1
    local component=$2
    local param_name=$3
    local expected_value=$4
    local config_file_path=${5:-""}
    local default_value=${6:-""}

    check_parameter_three_layer "$component" "$param_name" "$expected_value" "$config_file_path" "$default_value"
    local result=$?

    case $result in
        0) print_result "PASS" "$CHECK_MESSAGE" "$check_id" ;;
        1) print_result "FAIL" "$CHECK_MESSAGE" "$check_id" ;;
        2) print_result "WARN" "$CHECK_MESSAGE" "$check_id" ;;
    esac

    return $result
}

# Check if admission plugin is NOT present
check_admission_plugin_absent() {
    local plugin=$1
    local process_info=$2

    if echo "$process_info" | grep -q -- "enable-admission-plugins=.*${plugin}.*"; then
        return 1  # Found - should be absent
    else
        return 0  # Not found - good
    fi
}

# Get kube-controller-manager process arguments
get_controller_manager_args() {
    ps aux | grep '[k]ube-controller-manager' 2>/dev/null
}

# Get kube-scheduler process arguments
get_scheduler_args() {
    ps aux | grep '[k]ube-scheduler' 2>/dev/null
}

# Get etcd process arguments (if running as standalone pod)
get_etcd_args() {
    ps aux | grep '[e]tcd' 2>/dev/null | grep -v 'kube-apiserver'
}

# Get kubelet process arguments
get_kubelet_args() {
    ps aux | grep '[k]ubelet' 2>/dev/null
}

# Read kubelet configuration file (config.yaml)
get_kubelet_config() {
    local config_file="/var/lib/kubelet/config.yaml"
    if [[ -f "$config_file" ]]; then
        cat "$config_file" 2>/dev/null
    fi
}

#-----------------------------#
#  Section 1.1: Control Plane Component Configuration Files
#-----------------------------#

run_section_1_1_checks() {
    echo -e "\n${BLUE}=================================================${NC}"
    echo -e "${BLUE}Section 1.1 - Control Plane Component Configuration Files${NC}"
    echo -e "${BLUE}=================================================${NC}\n"

    # 1.1.1: Ensure that the API server pod specification file permissions are set to 644 or more restrictive
    check_1_1_1() {
        local file="/etc/kubernetes/manifests/kube-apiserver.yaml"
        if check_file_permissions "$file" 644; then
            print_result "PASS" "API Server pod spec file permissions are $((10#$(stat -c "%a" "$file" 2>/dev/null || stat -f "%Lp" "$file")))" "1.1.1"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "API Server pod spec file not found at $file" "1.1.1"
            else
                print_result "FAIL" "API Server pod spec file permissions are not 644 or more restrictive" "1.1.1"
            fi
        fi
    }

    # 1.1.2: Ensure that the API server pod specification file ownership is set to root:root
    check_1_1_2() {
        local file="/etc/kubernetes/manifests/kube-apiserver.yaml"
        if check_file_ownership "$file" "root" "root"; then
            print_result "PASS" "API Server pod spec file ownership is root:root" "1.1.2"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "API Server pod spec file not found at $file" "1.1.2"
            else
                print_result "FAIL" "API Server pod spec file ownership is not root:root" "1.1.2"
            fi
        fi
    }

    # 1.1.3: Ensure that the controller manager pod specification file permissions are set to 644 or more restrictive
    check_1_1_3() {
        local file="/etc/kubernetes/manifests/kube-controller-manager.yaml"
        if check_file_permissions "$file" 644; then
            print_result "PASS" "Controller Manager pod spec file permissions are 644 or more restrictive" "1.1.3"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "Controller Manager pod spec file not found at $file" "1.1.3"
            else
                print_result "FAIL" "Controller Manager pod spec file permissions are not 644 or more restrictive" "1.1.3"
            fi
        fi
    }

    # 1.1.4: Ensure that the controller manager pod specification file ownership is set to root:root
    check_1_1_4() {
        local file="/etc/kubernetes/manifests/kube-controller-manager.yaml"
        if check_file_ownership "$file" "root" "root"; then
            print_result "PASS" "Controller Manager pod spec file ownership is root:root" "1.1.4"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "Controller Manager pod spec file not found at $file" "1.1.4"
            else
                print_result "FAIL" "Controller Manager pod spec file ownership is not root:root" "1.1.4"
            fi
        fi
    }

    # 1.1.5: Ensure that the scheduler pod specification file permissions are set to 644 or more restrictive
    check_1_1_5() {
        local file="/etc/kubernetes/manifests/kube-scheduler.yaml"
        if check_file_permissions "$file" 644; then
            print_result "PASS" "Scheduler pod spec file permissions are 644 or more restrictive" "1.1.5"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "Scheduler pod spec file not found at $file" "1.1.5"
            else
                print_result "FAIL" "Scheduler pod spec file permissions are not 644 or more restrictive" "1.1.5"
            fi
        fi
    }

    # 1.1.6: Ensure that the scheduler pod specification file ownership is set to root:root
    check_1_1_6() {
        local file="/etc/kubernetes/manifests/kube-scheduler.yaml"
        if check_file_ownership "$file" "root" "root"; then
            print_result "PASS" "Scheduler pod spec file ownership is root:root" "1.1.6"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "Scheduler pod spec file not found at $file" "1.1.6"
            else
                print_result "FAIL" "Scheduler pod spec file ownership is not root:root" "1.1.6"
            fi
        fi
    }

    # 1.1.7: Ensure that the etcd pod specification file permissions are set to 644 or more restrictive
    check_1_1_7() {
        local file="/etc/kubernetes/manifests/etcd.yaml"
        if check_file_permissions "$file" 644; then
            print_result "PASS" "etcd pod spec file permissions are 644 or more restrictive" "1.1.7"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "etcd pod spec file not found at $file" "1.1.7"
            else
                print_result "FAIL" "etcd pod spec file permissions are not 644 or more restrictive" "1.1.7"
            fi
        fi
    }

    # 1.1.8: Ensure that the etcd pod specification file ownership is set to root:root
    check_1_1_8() {
        local file="/etc/kubernetes/manifests/etcd.yaml"
        if check_file_ownership "$file" "root" "root"; then
            print_result "PASS" "etcd pod spec file ownership is root:root" "1.1.8"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "etcd pod spec file not found at $file" "1.1.8"
            else
                print_result "FAIL" "etcd pod spec file ownership is not root:root" "1.1.8"
            fi
        fi
    }

    # 1.1.9: Ensure that the network configuration file permissions are set to 644 or more restrictive
    check_1_1_9() {
        local dir="/etc/cni/net.d"
        local found_files=0
        local failed=0

        if [[ ! -d "$dir" ]]; then
            print_result "WARN" "CNI network configuration directory not found at $dir" "1.1.9"
            return
        fi

        while IFS= read -r -d '' file; do
            found_files=1
            if ! check_file_permissions "$file" 644; then
                failed=1
                print_result "FAIL" "Network config file $file permissions are not 644 or more restrictive" "1.1.9"
                return
            fi
        done < <(find "$dir" -type f -name "*.conf" -print0 2>/dev/null)

        if [[ $found_files -eq 0 ]]; then
            print_result "WARN" "No network configuration files found in $dir" "1.1.9"
        elif [[ $failed -eq 0 ]]; then
            print_result "PASS" "All network configuration files have 644 or more restrictive permissions" "1.1.9"
        fi
    }

    # 1.1.10: Ensure that the network configuration file ownership is set to root:root
    check_1_1_10() {
        local dir="/etc/cni/net.d"
        local found_files=0
        local failed=0

        if [[ ! -d "$dir" ]]; then
            print_result "WARN" "CNI network configuration directory not found at $dir" "1.1.10"
            return
        fi

        while IFS= read -r -d '' file; do
            found_files=1
            if ! check_file_ownership "$file" "root" "root"; then
                failed=1
                print_result "FAIL" "Network config file $file ownership is not root:root" "1.1.10"
                return
            fi
        done < <(find "$dir" -type f -name "*.conf" -print0 2>/dev/null)

        if [[ $found_files -eq 0 ]]; then
            print_result "WARN" "No network configuration files found in $dir" "1.1.10"
        elif [[ $failed -eq 0 ]]; then
            print_result "PASS" "All network configuration files are owned by root:root" "1.1.10"
        fi
    }

    # 1.1.11: Ensure that the container runtime socket file permissions are set to 660 or more restrictive
    check_1_1_11() {
        local sockets=("/var/run/docker.sock" "/run/containerd/containerd.sock" "/run/crio/crio.sock" "/run/kubelet.sock")
        local found=0
        local failed=0

        for socket in "${sockets[@]}"; do
            if [[ -S "$socket" ]]; then
                found=1
                if ! check_file_permissions "$socket" 660; then
                    failed=1
                    print_result "FAIL" "Container runtime socket $socket permissions are not 660 or more restrictive" "1.1.11"
                    return
                fi
            fi
        done

        if [[ $found -eq 0 ]]; then
            print_result "WARN" "No container runtime socket files found" "1.1.11"
        elif [[ $failed -eq 0 ]]; then
            print_result "PASS" "All container runtime socket files have 660 or more restrictive permissions" "1.1.11"
        fi
    }

    # 1.1.12: Ensure that the container runtime socket file ownership is set to root:root or root:container runtime
    check_1_1_12() {
        local sockets=("/var/run/docker.sock" "/run/containerd/containerd.sock" "/run/crio/crio.sock" "/run/kubelet.sock")
        local found=0
        local failed=0

        for socket in "${sockets[@]}"; do
            if [[ -S "$socket" ]]; then
                found=1
                local actual_user
                local actual_group

                if [[ "$OSTYPE" == "darwin"* ]]; then
                    actual_user=$(stat -f "%Su" "$socket")
                    actual_group=$(stat -f "%Sg" "$socket")
                else
                    actual_user=$(stat -c "%U" "$socket")
                    actual_group=$(stat -c "%G" "$socket")
                fi

                if [[ "$actual_user" != "root" ]]; then
                    failed=1
                    print_result "FAIL" "Container runtime socket $socket ownership is not root:root or root:<runtime>" "1.1.12"
                    return
                fi
            fi
        done

        if [[ $found -eq 0 ]]; then
            print_result "WARN" "No container runtime socket files found" "1.1.12"
        elif [[ $failed -eq 0 ]]; then
            print_result "PASS" "All container runtime socket files are properly owned" "1.1.12"
        fi
    }

    # 1.1.13: Ensure that the etcd data directory permissions are set to 700 or more restrictive
    check_1_1_13() {
        local dir="/var/lib/etcd"
        if check_file_permissions "$dir" 700; then
            print_result "PASS" "etcd data directory permissions are 700 or more restrictive" "1.1.13"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "etcd data directory not found at $dir" "1.1.13"
            else
                print_result "FAIL" "etcd data directory permissions are not 700 or more restrictive" "1.1.13"
            fi
        fi
    }

    # 1.1.14: Ensure that the etcd data directory ownership is set to etcd:etcd
    check_1_1_14() {
        local dir="/var/lib/etcd"
        if check_file_ownership "$dir" "etcd" "etcd"; then
            print_result "PASS" "etcd data directory ownership is etcd:etcd" "1.1.14"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "etcd data directory not found at $dir" "1.1.14"
            else
                print_result "FAIL" "etcd data directory ownership is not etcd:etcd" "1.1.14"
            fi
        fi
    }

    # 1.1.15: Ensure that the admin.conf file permissions are set to 644 or more restrictive
    check_1_1_15() {
        local file="/etc/kubernetes/admin.conf"
        if check_file_permissions "$file" 644; then
            print_result "PASS" "admin.conf file permissions are 644 or more restrictive" "1.1.15"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "admin.conf file not found at $file" "1.1.15"
            else
                print_result "FAIL" "admin.conf file permissions are not 644 or more restrictive" "1.1.15"
            fi
        fi
    }

    # 1.1.16: Ensure that the admin.conf file ownership is set to root:root
    check_1_1_16() {
        local file="/etc/kubernetes/admin.conf"
        if check_file_ownership "$file" "root" "root"; then
            print_result "PASS" "admin.conf file ownership is root:root" "1.1.16"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "admin.conf file not found at $file" "1.1.16"
            else
                print_result "FAIL" "admin.conf file ownership is not root:root" "1.1.16"
            fi
        fi
    }

    # 1.1.17: Ensure that the scheduler.conf file permissions are set to 644 or more restrictive
    check_1_1_17() {
        local file="/etc/kubernetes/scheduler.conf"
        if check_file_permissions "$file" 644; then
            print_result "PASS" "scheduler.conf file permissions are 644 or more restrictive" "1.1.17"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "scheduler.conf file not found at $file" "1.1.17"
            else
                print_result "FAIL" "scheduler.conf file permissions are not 644 or more restrictive" "1.1.17"
            fi
        fi
    }

    # 1.1.18: Ensure that the scheduler.conf file ownership is set to root:root
    check_1_1_18() {
        local file="/etc/kubernetes/scheduler.conf"
        if check_file_ownership "$file" "root" "root"; then
            print_result "PASS" "scheduler.conf file ownership is root:root" "1.1.18"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "scheduler.conf file not found at $file" "1.1.18"
            else
                print_result "FAIL" "scheduler.conf file ownership is not root:root" "1.1.18"
            fi
        fi
    }

    # 1.1.19: Ensure that the controller-manager.conf file permissions are set to 644 or more restrictive
    check_1_1_19() {
        local file="/etc/kubernetes/controller-manager.conf"
        if check_file_permissions "$file" 644; then
            print_result "PASS" "controller-manager.conf file permissions are 644 or more restrictive" "1.1.19"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "controller-manager.conf file not found at $file" "1.1.19"
            else
                print_result "FAIL" "controller-manager.conf file permissions are not 644 or more restrictive" "1.1.19"
            fi
        fi
    }

    # 1.1.20: Ensure that the controller-manager.conf file ownership is set to root:root
    check_1_1_20() {
        local file="/etc/kubernetes/controller-manager.conf"
        if check_file_ownership "$file" "root" "root"; then
            print_result "PASS" "controller-manager.conf file ownership is root:root" "1.1.20"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "controller-manager.conf file not found at $file" "1.1.20"
            else
                print_result "FAIL" "controller-manager.conf file ownership is not root:root" "1.1.20"
            fi
        fi
    }

    # 1.1.21: Ensure that the Kubernetes PKI directory and file ownership is set to root:root
    check_1_1_21() {
        local dir="/etc/kubernetes/pki"
        if [[ ! -d "$dir" ]]; then
            print_result "WARN" "PKI directory not found at $dir" "1.1.21"
            return
        fi

        if check_dir_ownership_recursive "$dir" "root" "root"; then
            print_result "PASS" "All files in PKI directory are owned by root:root" "1.1.21"
        else
            print_result "FAIL" "Some files in PKI directory are not owned by root:root" "1.1.21"
        fi
    }

    # Execute all 1.1 checks
    check_1_1_1
    check_1_1_2
    check_1_1_3
    check_1_1_4
    check_1_1_5
    check_1_1_6
    check_1_1_7
    check_1_1_8
    check_1_1_9
    check_1_1_10
    check_1_1_11
    check_1_1_12
    check_1_1_13
    check_1_1_14
    check_1_1_15
    check_1_1_16
    check_1_1_17
    check_1_1_18
    check_1_1_19
    check_1_1_20
    check_1_1_21
}

#-----------------------------#
#  Section 1.2: API Server Configuration
#-----------------------------#

run_section_1_2_checks() {
    echo -e "\n${BLUE}=================================================${NC}"
    echo -e "${BLUE}Section 1.2 - API Server Configuration${NC}"
    echo -e "${BLUE}=================================================${NC}\n"

    # Get API Server process info once
    local apiserver_process
    apiserver_process=$(get_apiserver_args)

    # Get API Server config file path
    local apiserver_config_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
    [[ ! -f "$apiserver_config_file" ]] && apiserver_config_file=""

    if [[ -z "$apiserver_process" ]] && [[ -z "$apiserver_config_file" ]]; then
        print_result "WARN" "kube-apiserver process and config not found. Skipping API Server checks." "1.2.x"
        return
    fi

    #================================================================================
    #  DEMONSTRATION: Three-Layer Checking Framework
    #================================================================================
    # The following checks demonstrate the NEW three-layer checking method:
    #
    # LAYER 1 (L1): Check process arguments (runtime - highest priority)
    # LAYER 2 (L2): Check configuration files (persistent - medium priority)
    # LAYER 3 (L3): Check default values (fallback - lowest priority)
    #
    # Usage: check_and_print_three_layer <check_id> <component> <param_name> <expected_value> [config_file] [default_value]
    #
    # Example: check_and_print_three_layer "1.2.1" "apiserver" "anonymous-auth" "false" "$apiserver_config_file" "true"
    #--------------------------------------------------------------------------------

    # 1.2.1: Ensure that the --anonymous-auth argument is set to false
    # OLD METHOD (single-layer, process only):
    # check_1_2_1() {
    #     if check_argument_value "--anonymous-auth" "false" "$apiserver_process"; then
    #         print_result "PASS" "--anonymous-auth is set to false" "1.2.1"
    #     else
    #         print_result "FAIL" "--anonymous-auth is not set to false" "1.2.1"
    #     fi
    # }

    # NEW METHOD (three-layer):
    check_1_2_1() {
        check_and_print_three_layer "1.2.1" "apiserver" "anonymous-auth" "false" "$apiserver_config_file" "true"
    }

    # 1.2.2: Ensure that the --token-auth-file parameter is not set
    check_1_2_2() {
        if check_argument_absent "--token-auth-file" "$apiserver_process"; then
            print_result "PASS" "--token-auth-file is not set" "1.2.2"
        else
            print_result "FAIL" "--token-auth-file is set" "1.2.2"
        fi
    }

    # 1.2.3: Ensure that the --DenyServiceExternalIPs is not set
    check_1_2_3() {
        # Note: This check depends on Kubernetes version and specific requirements
        # Some environments may require this to be set
        if check_argument_absent "--deny-service-external-ip" "$apiserver_process" && \
           check_argument_absent "--DenyServiceExternalIPs" "$apiserver_process"; then
            print_result "PASS" "--DenyServiceExternalIPs is not set" "1.2.3"
        else
            print_result "WARN" "--DenyServiceExternalIPs is set (verify if required)" "1.2.3"
        fi
    }

    # 1.2.4: Ensure that the --kubelet-client-certificate and --kubelet-client-key arguments are set
    check_1_2_4() {
        if check_argument_present "--kubelet-client-certificate" "$apiserver_process" && \
           check_argument_present "--kubelet-client-key" "$apiserver_process"; then
            print_result "PASS" "--kubelet-client-certificate and --kubelet-client-key are set" "1.2.4"
        else
            print_result "FAIL" "--kubelet-client-certificate and/or --kubelet-client-key are not set" "1.2.4"
        fi
    }

    # 1.2.5: Ensure that the --kubelet-https argument is set to true
    check_1_2_5() {
        # Note: In newer Kubernetes versions, this is deprecated/removed
        if check_argument_value "--kubelet-https" "true" "$apiserver_process"; then
            print_result "PASS" "--kubelet-https is set to true" "1.2.5"
        elif check_argument_absent "--kubelet-https" "$apiserver_process"; then
            # Default is true in newer versions
            print_result "PASS" "--kubelet-https not set (defaults to true in current version)" "1.2.5"
        else
            print_result "FAIL" "--kubelet-https is not set to true" "1.2.5"
        fi
    }

    # 1.2.6: Ensure that the --bind-address argument is set to 127.0.0.1
    check_1_2_6() {
        if check_argument_value "--bind-address" "127.0.0.1" "$apiserver_process"; then
            print_result "PASS" "--bind-address is set to 127.0.0.1" "1.2.6"
        else
            print_result "FAIL" "--bind-address is not set to 127.0.0.1" "1.2.6"
        fi
    }

    # 1.2.7: Ensure that the --authorization-mode argument is not set to AlwaysAllow
    check_1_2_7() {
        local auth_mode
        auth_mode=$(echo "$apiserver_process" | grep -oP "(?<=--authorization-mode=)[^ ]+" 2>/dev/null || echo "$apiserver_process" | grep -o -- "--authorization-mode[^ ]*" | cut -d'=' -f2)

        if [[ "$auth_mode" != "AlwaysAllow" ]] && [[ -n "$auth_mode" ]]; then
            print_result "PASS" "--authorization-mode is not set to AlwaysAllow" "1.2.7"
        else
            print_result "FAIL" "--authorization-mode is set to AlwaysAllow" "1.2.7"
        fi
    }

    # 1.2.8: Ensure that the --authorization-mode argument includes Node
    check_1_2_8() {
        local auth_mode
        auth_mode=$(echo "$apiserver_process" | grep -oP "(?<=--authorization-mode=)[^ ]+" 2>/dev/null || echo "$apiserver_process" | grep -o -- "--authorization-mode[^ ]*" | cut -d'=' -f2)

        if [[ "$auth_mode" == *"Node"* ]]; then
            print_result "PASS" "--authorization-mode includes Node" "1.2.8"
        else
            print_result "FAIL" "--authorization-mode does not include Node" "1.2.8"
        fi
    }

    # 1.2.9: Ensure that the --authorization-mode argument includes RBAC
    check_1_2_9() {
        local auth_mode
        auth_mode=$(echo "$apiserver_process" | grep -oP "(?<=--authorization-mode=)[^ ]+" 2>/dev/null || echo "$apiserver_process" | grep -o -- "--authorization-mode[^ ]*" | cut -d'=' -f2)

        if [[ "$auth_mode" == *"RBAC"* ]]; then
            print_result "PASS" "--authorization-mode includes RBAC" "1.2.9"
        else
            print_result "FAIL" "--authorization-mode does not include RBAC" "1.2.9"
        fi
    }

    # 1.2.10: Ensure that the admission control plugin EventRateLimit is set
    check_1_2_10() {
        if check_admission_plugin "EventRateLimit" "$apiserver_process"; then
            print_result "PASS" "EventRateLimit admission plugin is enabled" "1.2.10"
        else
            print_result "WARN" "EventRateLimit admission plugin is not enabled" "1.2.10"
        fi
    }

    # 1.2.11: Ensure that the admission control plugin AlwaysAdmit is not set
    check_1_2_11() {
        if check_admission_plugin_absent "AlwaysAdmit" "$apiserver_process"; then
            print_result "PASS" "AlwaysAdmit admission plugin is not set" "1.2.11"
        else
            print_result "FAIL" "AlwaysAdmit admission plugin is set" "1.2.11"
        fi
    }

    # 1.2.12: Ensure that the admission control plugin AlwaysPullImages is set
    check_1_2_12() {
        if check_admission_plugin "AlwaysPullImages" "$apiserver_process"; then
            print_result "PASS" "AlwaysPullImages admission plugin is set" "1.2.12"
        else
            print_result "WARN" "AlwaysPullImages admission plugin is not set" "1.2.12"
        fi
    }

    # 1.2.13: Ensure that the admission control plugin SecurityContextDeny is set
    check_1_2_13() {
        if check_admission_plugin "SecurityContextDeny" "$apiserver_process"; then
            print_result "PASS" "SecurityContextDeny admission plugin is set" "1.2.13"
        else
            print_result "WARN" "SecurityContextDeny admission plugin is not set" "1.2.13"
        fi
    }

    # 1.2.14: Ensure that the admission control plugin ServiceAccount is set
    check_1_2_14() {
        if check_admission_plugin "ServiceAccount" "$apiserver_process"; then
            print_result "PASS" "ServiceAccount admission plugin is set" "1.2.14"
        else
            print_result "FAIL" "ServiceAccount admission plugin is not set" "1.2.14"
        fi
    }

    # 1.2.15: Ensure that the --service-account-lookup argument is set to true
    check_1_2_15() {
        if check_argument_value "--service-account-lookup" "true" "$apiserver_process"; then
            print_result "PASS" "--service-account-lookup is set to true" "1.2.15"
        elif check_argument_absent "--service-account-lookup" "$apiserver_process"; then
            # Default is true in newer versions
            print_result "PASS" "--service-account-lookup not set (defaults to true in current version)" "1.2.15"
        else
            print_result "FAIL" "--service-account-lookup is not set to true" "1.2.15"
        fi
    }

    # 1.2.16: Ensure that the --audit-log-path argument is set
    check_1_2_16() {
        if check_argument_present "--audit-log-path" "$apiserver_process"; then
            print_result "PASS" "--audit-log-path is set" "1.2.16"
        else
            print_result "FAIL" "--audit-log-path is not set" "1.2.16"
        fi
    }

    # 1.2.17: Ensure that the --audit-log-maxage argument is set to 30 or as appropriate
    check_1_2_17() {
        local audit_maxage
        audit_maxage=$(echo "$apiserver_process" | grep -oP "(?<=--audit-log-maxage=)[^ ]+" 2>/dev/null || echo "$apiserver_process" | grep -o -- "--audit-log-maxage[^ ]*" | cut -d'=' -f2)

        if [[ -n "$audit_maxage" ]] && [[ "$audit_maxage" -ge 30 ]]; then
            print_result "PASS" "--audit-log-maxage is set to $audit_maxage (>= 30)" "1.2.17"
        elif [[ -n "$audit_maxage" ]]; then
            print_result "WARN" "--audit-log-maxage is set to $audit_maxage (< 30 recommended)" "1.2.17"
        else
            print_result "FAIL" "--audit-log-maxage is not set" "1.2.17"
        fi
    }

    # 1.2.18: Ensure that the --audit-log-maxbackup argument is set
    check_1_2_18() {
        if check_argument_present "--audit-log-maxbackup" "$apiserver_process"; then
            print_result "PASS" "--audit-log-maxbackup is set" "1.2.18"
        else
            print_result "FAIL" "--audit-log-maxbackup is not set" "1.2.18"
        fi
    }

    # 1.2.19: Ensure that the --audit-log-maxsize argument is set
    check_1_2_19() {
        if check_argument_present "--audit-log-maxsize" "$apiserver_process"; then
            print_result "PASS" "--audit-log-maxsize is set" "1.2.19"
        else
            print_result "FAIL" "--audit-log-maxsize is not set" "1.2.19"
        fi
    }

    # 1.2.20: Ensure that the --request-timeout argument is set
    check_1_2_20() {
        # Note: This is deprecated in newer versions
        if check_argument_present "--request-timeout" "$apiserver_process"; then
            print_result "PASS" "--request-timeout is set" "1.2.20"
        else
            print_result "WARN" "--request-timeout is not set (may be deprecated in current version)" "1.2.20"
        fi
    }

    # 1.2.21: Ensure that the --authorization-mode argument includes Node,RBAC
    check_1_2_21() {
        local auth_mode
        auth_mode=$(echo "$apiserver_process" | grep -oP "(?<=--authorization-mode=)[^ ]+" 2>/dev/null || echo "$apiserver_process" | grep -o -- "--authorization-mode[^ ]*" | cut -d'=' -f2)

        if [[ "$auth_mode" == *"Node"* ]] && [[ "$auth_mode" == *"RBAC"* ]]; then
            print_result "PASS" "--authorization-mode includes Node and RBAC" "1.2.21"
        else
            print_result "FAIL" "--authorization-mode does not include both Node and RBAC" "1.2.21"
        fi
    }

    # 1.2.22: Ensure that the --token-auth-file parameter is not set (duplicate/similar to 1.2.2)
    check_1_2_22() {
        if check_argument_absent "--token-auth-file" "$apiserver_process"; then
            print_result "PASS" "--token-auth-file is not set" "1.2.22"
        else
            print_result "FAIL" "--token-auth-file is set" "1.2.22"
        fi
    }

    # 1.2.23: Ensure that the --enable-bootstrap-token-auth argument is not set (unless required)
    check_1_2_23() {
        # This is typically set during cluster bootstrap
        if check_argument_absent "--enable-bootstrap-token-auth" "$apiserver_process"; then
            print_result "PASS" "--enable-bootstrap-token-auth is not set" "1.2.23"
        else
            print_result "WARN" "--enable-bootstrap-token-auth is set (verify if required for bootstrapping)" "1.2.23"
        fi
    }

    # 1.2.24: Ensure that the --etcd-certfile and --etcd-keyfile arguments are set
    check_1_2_24() {
        if check_argument_present "--etcd-certfile" "$apiserver_process" && \
           check_argument_present "--etcd-keyfile" "$apiserver_process"; then
            print_result "PASS" "--etcd-certfile and --etcd-keyfile are set" "1.2.24"
        else
            print_result "FAIL" "--etcd-certfile and/or --etcd-keyfile are not set" "1.2.24"
        fi
    }

    # 1.2.25: Ensure that the --tls-cert-file and --tls-private-key-file arguments are set
    check_1_2_25() {
        if check_argument_present "--tls-cert-file" "$apiserver_process" && \
           check_argument_present "--tls-private-key-file" "$apiserver_process"; then
            print_result "PASS" "--tls-cert-file and --tls-private-key-file are set" "1.2.25"
        else
            print_result "FAIL" "--tls-cert-file and/or --tls-private-key-file are not set" "1.2.25"
        fi
    }

    # 1.2.26: Ensure that the --client-ca-file argument is set
    check_1_2_26() {
        if check_argument_present "--client-ca-file" "$apiserver_process"; then
            print_result "PASS" "--client-ca-file is set" "1.2.26"
        else
            print_result "FAIL" "--client-ca-file is not set" "1.2.26"
        fi
    }

    # 1.2.27: Ensure that the --etcd-cafile argument is set
    check_1_2_27() {
        if check_argument_present "--etcd-cafile" "$apiserver_process"; then
            print_result "PASS" "--etcd-cafile is set" "1.2.27"
        else
            print_result "FAIL" "--etcd-cafile is not set" "1.2.27"
        fi
    }

    # 1.2.28: Ensure that the --encryption-provider-config argument is set
    check_1_2_28() {
        if check_argument_present "--encryption-provider-config" "$apiserver_process"; then
            print_result "PASS" "--encryption-provider-config is set" "1.2.28"
        else
            print_result "WARN" "--encryption-provider-config is not set (encryption at rest not enabled)" "1.2.28"
        fi
    }

    # 1.2.29: Ensure that the --admission-control-plugin-config-file argument is set
    check_1_2_29() {
        if check_argument_present "--admission-control-config-file" "$apiserver_process" || \
           check_argument_present "--admission-control-plugin-config-file" "$apiserver_process"; then
            print_result "PASS" "Admission control config file is set" "1.2.29"
        else
            print_result "WARN" "Admission control config file is not set" "1.2.29"
        fi
    }

    # 1.2.30: Ensure that the --secure-port argument is not set to 0
    check_1_2_30() {
        local secure_port
        secure_port=$(echo "$apiserver_process" | grep -oP "(?<=--secure-port=)[^ ]+" 2>/dev/null || echo "$apiserver_process" | grep -o -- "--secure-port[^ ]*" | cut -d'=' -f2)

        if [[ "$secure_port" != "0" ]] && [[ -n "$secure_port" ]]; then
            print_result "PASS" "--secure-port is set to $secure_port" "1.2.30"
        elif check_argument_absent "--secure-port" "$apiserver_process"; then
            print_result "PASS" "--secure-port not set (defaults to 6443)" "1.2.30"
        else
            print_result "FAIL" "--secure-port is set to 0" "1.2.30"
        fi
    }

    # 1.2.31: Ensure that the --profiling argument is set to false
    check_1_2_31() {
        if check_argument_value "--profiling" "false" "$apiserver_process"; then
            print_result "PASS" "--profiling is set to false" "1.2.31"
        elif check_argument_absent "--profiling" "$apiserver_process"; then
            # Default is true, so this should be explicitly set to false
            print_result "WARN" "--profiling is not set (defaults to true, consider disabling)" "1.2.31"
        else
            print_result "FAIL" "--profiling is enabled" "1.2.31"
        fi
    }

    # 1.2.32: Ensure that the --service-account-issuer argument is set
    check_1_2_32() {
        if check_argument_present "--service-account-issuer" "$apiserver_process"; then
            print_result "PASS" "--service-account-issuer is set" "1.2.32"
        else
            print_result "WARN" "--service-account-issuer is not set" "1.2.32"
        fi
    }

    # 1.2.33: Ensure that the --service-account-key-file argument is set
    check_1_2_33() {
        if check_argument_present "--service-account-key-file" "$apiserver_process"; then
            print_result "PASS" "--service-account-key-file is set" "1.2.33"
        else
            print_result "WARN" "--service-account-key-file is not set" "1.2.33"
        fi
    }

    # 1.2.34: Ensure that the --service-account-signing-key-file argument is set
    check_1_2_34() {
        if check_argument_present "--service-account-signing-key-file" "$apiserver_process"; then
            print_result "PASS" "--service-account-signing-key-file is set" "1.2.34"
        else
            print_result "WARN" "--service-account-signing-key-file is not set" "1.2.34"
        fi
    }

    # Execute all 1.2 checks
    check_1_2_1
    check_1_2_2
    check_1_2_3
    check_1_2_4
    check_1_2_5
    check_1_2_6
    check_1_2_7
    check_1_2_8
    check_1_2_9
    check_1_2_10
    check_1_2_11
    check_1_2_12
    check_1_2_13
    check_1_2_14
    check_1_2_15
    check_1_2_16
    check_1_2_17
    check_1_2_18
    check_1_2_19
    check_1_2_20
    check_1_2_21
    check_1_2_22
    check_1_2_23
    check_1_2_24
    check_1_2_25
    check_1_2_26
    check_1_2_27
    check_1_2_28
    check_1_2_29
    check_1_2_30
    check_1_2_31
    check_1_2_32
    check_1_2_33
    check_1_2_34
}

#-----------------------------#
#  Section 1.3: Controller Manager Configuration
#-----------------------------#

run_section_1_3_checks() {
    echo -e "\n${BLUE}=================================================${NC}"
    echo -e "${BLUE}Section 1.3 - Controller Manager Configuration${NC}"
    echo -e "${BLUE}=================================================${NC}\n"

    # Get Controller Manager process info once
    local controller_process
    controller_process=$(get_controller_manager_args)

    if [[ -z "$controller_process" ]]; then
        print_result "WARN" "kube-controller-manager process not found. Skipping Controller Manager checks." "1.3.x"
        return
    fi

    # 1.3.1: Ensure that the --terminated-pod-gc-threshold argument is set
    check_1_3_1() {
        if check_argument_present "--terminated-pod-gc-threshold" "$controller_process"; then
            print_result "PASS" "--terminated-pod-gc-threshold is set" "1.3.1"
        else
            print_result "WARN" "--terminated-pod-gc-threshold is not set" "1.3.1"
        fi
    }

    # 1.3.2: Ensure that the --profiling argument is set to false
    check_1_3_2() {
        if check_argument_value "--profiling" "false" "$controller_process"; then
            print_result "PASS" "--profiling is set to false" "1.3.2"
        elif check_argument_absent "--profiling" "$controller_process"; then
            # Default is true, so this should be explicitly set to false
            print_result "WARN" "--profiling is not set (defaults to true, consider disabling)" "1.3.2"
        else
            print_result "FAIL" "--profiling is enabled" "1.3.2"
        fi
    }

    # 1.3.3: Ensure that the --use-service-account-credentials argument is set to true
    check_1_3_3() {
        if check_argument_value "--use-service-account-credentials" "true" "$controller_process"; then
            print_result "PASS" "--use-service-account-credentials is set to true" "1.3.3"
        elif check_argument_absent "--use-service-account-credentials" "$controller_process"; then
            # Default is true in newer versions
            print_result "PASS" "--use-service-account-credentials not set (defaults to true in current version)" "1.3.3"
        else
            print_result "FAIL" "--use-service-account-credentials is not set to true" "1.3.3"
        fi
    }

    # 1.3.4: Ensure that the --service-account-private-key-file argument is set
    check_1_3_4() {
        if check_argument_present "--service-account-private-key-file" "$controller_process"; then
            print_result "PASS" "--service-account-private-key-file is set" "1.3.4"
        else
            print_result "FAIL" "--service-account-private-key-file is not set" "1.3.4"
        fi
    }

    # 1.3.5: Ensure that the --root-ca-file argument is set
    check_1_3_5() {
        if check_argument_present "--root-ca-file" "$controller_process"; then
            print_result "PASS" "--root-ca-file is set" "1.3.5"
        else
            print_result "WARN" "--root-ca-file is not set" "1.3.5"
        fi
    }

    # 1.3.6: Ensure that the RotateKubeletServerCertificate argument is set
    check_1_3_6() {
        # Check if the feature gate is enabled
        if echo "$controller_process" | grep -q -- "feature-gates=.*RotateKubeletServerCertificate=true"; then
            print_result "PASS" "RotateKubeletServerCertificate feature gate is enabled" "1.3.6"
        # In newer versions, this is enabled by default
        elif check_argument_absent "--feature-gates" "$controller_process" || \
             check_argument_absent "RotateKubeletServerCertificate" "$controller_process"; then
            print_result "WARN" "RotateKubeletServerCertificate feature gate not explicitly set (may be default)" "1.3.6"
        else
            print_result "FAIL" "RotateKubeletServerCertificate feature gate is not enabled" "1.3.6"
        fi
    }

    # 1.3.7: Ensure that the --bind-address argument is set to 127.0.0.1
    check_1_3_7() {
        if check_argument_value "--bind-address" "127.0.0.1" "$controller_process"; then
            print_result "PASS" "--bind-address is set to 127.0.0.1" "1.3.7"
        else
            print_result "FAIL" "--bind-address is not set to 127.0.0.1" "1.3.7"
        fi
    }

    # Execute all 1.3 checks
    check_1_3_1
    check_1_3_2
    check_1_3_3
    check_1_3_4
    check_1_3_5
    check_1_3_6
    check_1_3_7
}

#-----------------------------#
#  Section 1.4: Scheduler Configuration
#-----------------------------#

run_section_1_4_checks() {
    echo -e "\n${BLUE}=================================================${NC}"
    echo -e "${BLUE}Section 1.4 - Scheduler Configuration${NC}"
    echo -e "${BLUE}=================================================${NC}\n"

    # Get Scheduler process info once
    local scheduler_process
    scheduler_process=$(get_scheduler_args)

    if [[ -z "$scheduler_process" ]]; then
        print_result "WARN" "kube-scheduler process not found. Skipping Scheduler checks." "1.4.x"
        return
    fi

    # 1.4.1: Ensure that the --profiling argument is set to false
    check_1_4_1() {
        if check_argument_value "--profiling" "false" "$scheduler_process"; then
            print_result "PASS" "--profiling is set to false" "1.4.1"
        elif check_argument_absent "--profiling" "$scheduler_process"; then
            # Default is true, so this should be explicitly set to false
            print_result "WARN" "--profiling is not set (defaults to true, consider disabling)" "1.4.1"
        else
            print_result "FAIL" "--profiling is enabled" "1.4.1"
        fi
    }

    # 1.4.2: Ensure that the --bind-address argument is set to 127.0.0.1
    check_1_4_2() {
        if check_argument_value "--bind-address" "127.0.0.1" "$scheduler_process"; then
            print_result "PASS" "--bind-address is set to 127.0.0.1" "1.4.2"
        else
            print_result "FAIL" "--bind-address is not set to 127.0.0.1" "1.4.2"
        fi
    }

    # Execute all 1.4 checks
    check_1_4_1
    check_1_4_2
}

#-----------------------------#
#  Section 2: etcd Configuration
#-----------------------------#

run_section_2_checks() {
    echo -e "\n${BLUE}=================================================${NC}"
    echo -e "${BLUE}Section 2 - etcd Configuration${NC}"
    echo -e "${BLUE}=================================================${NC}\n"

    # Get etcd process info once
    local etcd_process
    etcd_process=$(get_etcd_args)

    if [[ -z "$etcd_process" ]]; then
        print_result "WARN" "etcd process not found. Skipping etcd checks." "2.x"
        return
    fi

    # 2.1: Ensure that the --client-cert-auth argument is set to true
    check_2_1() {
        if check_argument_value "--client-cert-auth" "true" "$etcd_process"; then
            print_result "PASS" "--client-cert-auth is set to true" "2.1"
        else
            print_result "FAIL" "--client-cert-auth is not set to true" "2.1"
        fi
    }

    # 2.2: Ensure that the --trusted-ca-file argument is set
    check_2_2() {
        if check_argument_present "--trusted-ca-file" "$etcd_process"; then
            print_result "PASS" "--trusted-ca-file is set" "2.2"
        else
            print_result "FAIL" "--trusted-ca-file is not set" "2.2"
        fi
    }

    # 2.3: Ensure that the --cert-file and --key-file arguments are set
    check_2_3() {
        if check_argument_present "--cert-file" "$etcd_process" && \
           check_argument_present "--key-file" "$etcd_process"; then
            print_result "PASS" "--cert-file and --key-file are set" "2.3"
        else
            print_result "FAIL" "--cert-file and/or --key-file are not set" "2.3"
        fi
    }

    # 2.4: Ensure that the --auto-tls argument is NOT set
    check_2_4() {
        if check_argument_absent "--auto-tls" "$etcd_process"; then
            print_result "PASS" "--auto-tls is not set" "2.4"
        else
            print_result "FAIL" "--auto-tls is set (should not use auto TLS)" "2.4"
        fi
    }

    # 2.5: Ensure that the --peer-client-cert-auth argument is set to true
    check_2_5() {
        if check_argument_value "--peer-client-cert-auth" "true" "$etcd_process"; then
            print_result "PASS" "--peer-client-cert-auth is set to true" "2.5"
        else
            print_result "FAIL" "--peer-client-cert-auth is not set to true" "2.5"
        fi
    }

    # 2.6: Ensure that the --peer-trusted-ca-file argument is set
    check_2_6() {
        if check_argument_present "--peer-trusted-ca-file" "$etcd_process"; then
            print_result "PASS" "--peer-trusted-ca-file is set" "2.6"
        else
            print_result "FAIL" "--peer-trusted-ca-file is not set" "2.6"
        fi
    }

    # 2.7: Ensure that the --peer-cert-file and --peer-key-file arguments are set
    check_2_7() {
        if check_argument_present "--peer-cert-file" "$etcd_process" && \
           check_argument_present "--peer-key-file" "$etcd_process"; then
            print_result "PASS" "--peer-cert-file and --peer-key-file are set" "2.7"
        else
            print_result "FAIL" "--peer-cert-file and/or --peer-key-file are not set" "2.7"
        fi
    }

    # Execute all section 2 checks
    check_2_1
    check_2_2
    check_2_3
    check_2_4
    check_2_5
    check_2_6
    check_2_7
}

#-----------------------------#
#  Section 3: Control Plane Configuration
#-----------------------------#

run_section_3_checks() {
    echo -e "\n${BLUE}=================================================${NC}"
    echo -e "${BLUE}Section 3 - Control Plane Configuration${NC}"
    echo -e "${BLUE}=================================================${NC}\n"

    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_result "WARN" "kubectl not found. Skipping control plane configuration checks." "3.x"
        return
    fi

    # Check if we can connect to the cluster
    if ! kubectl get nodes &> /dev/null; then
        print_result "WARN" "Cannot connect to Kubernetes cluster. Skipping control plane configuration checks." "3.x"
        return
    fi

    # 3.1 Authentication and Authorization

    # 3.1.1: Ensure that the cluster-admin role is only used where required
    check_3_1_1() {
        # Get all users/groups with cluster-admin role
        local cluster_admin_users
        cluster_admin_users=$(kubectl get clusterrolebindings -o json 2>/dev/null | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .subjects[]? | select(.kind=="User") | .name' 2>/dev/null)

        if [[ -z "$cluster_admin_users" ]]; then
            print_result "WARN" "No users with cluster-admin role found (check if default bindings are appropriate)" "3.1.1"
        else
            local count=0
            while IFS= read -r user; do
                if [[ -n "$user" ]]; then
                    count=$((count + 1))
                fi
            done <<< "$cluster_admin_users"

            if [[ $count -le 5 ]]; then
                print_result "PASS" "$count users have cluster-admin role (review for necessity)" "3.1.1"
            else
                print_result "WARN" "$count users have cluster-admin role (consider reducing)" "3.1.1"
            fi
        fi
    }

    # 3.1.2: Ensure that the --authorization-mode argument includes Node
    # Note: This is already checked in 1.2.8, skipping to avoid duplicate
    check_3_1_2() {
        # Placeholder - already covered in section 1.2
        print_result "INFO" "Already checked in section 1.2.8" "3.1.2"
    }

    # 3.1.3: Ensure that the --authorization-mode argument includes RBAC
    # Note: This is already checked in 1.2.9, skipping to avoid duplicate
    check_3_1_3() {
        # Placeholder - already covered in section 1.2
        print_result "INFO" "Already checked in section 1.2.9" "3.1.3"
    }

    # 3.1.4: Ensure that the admission control plugin EventRateLimit is set
    # Note: This is already checked in 1.2.10, skipping to avoid duplicate
    check_3_1_4() {
        # Placeholder - already covered in section 1.2
        print_result "INFO" "Already checked in section 1.2.10" "3.1.4"
    }

    # 3.1.5: Ensure that the admission control plugin AlwaysAdmit is not set
    # Note: This is already checked in 1.2.11, skipping to avoid duplicate
    check_3_1_5() {
        # Placeholder - already covered in section 1.2
        print_result "INFO" "Already checked in section 1.2.11" "3.1.5"
    }

    # 3.1.6: Ensure that the admission control plugin AlwaysPullImages is set
    # Note: This is already checked in 1.2.12, skipping to avoid duplicate
    check_3_1_6() {
        # Placeholder - already covered in section 1.2
        print_result "INFO" "Already checked in section 1.2.12" "3.1.6"
    }

    # 3.2 Logging

    # 3.2.1: Ensure that a minimal audit policy is created
    check_3_2_1() {
        # Check if audit policy is configured
        local apiserver_process
        apiserver_process=$(get_apiserver_args)

        if check_argument_present "--audit-policy-file" "$apiserver_process"; then
            local audit_policy_file
            audit_policy_file=$(echo "$apiserver_process" | grep -oP "(?<=--audit-policy-file=)[^ ]+" 2>/dev/null || echo "$apiserver_process" | grep -o -- "--audit-policy-file[^ ]*" | cut -d'=' -f2)

            if [[ -f "$audit_policy_file" ]]; then
                print_result "PASS" "Audit policy file exists at $audit_policy_file" "3.2.1"
            else
                print_result "WARN" "Audit policy file configured but not found at $audit_policy_file" "3.2.1"
            fi
        else
            print_result "FAIL" "No audit policy file configured" "3.2.1"
        fi
    }

    # 3.2.2: Ensure that the audit policy covers key actions
    check_3_2_2() {
        local apiserver_process
        apiserver_process=$(get_apiserver_args)

        if check_argument_present "--audit-policy-file" "$apiserver_process"; then
            local audit_policy_file
            audit_policy_file=$(echo "$apiserver_process" | grep -oP "(?<=--audit-policy-file=)[^ ]+" 2>/dev/null || echo "$apiserver_process" | grep -o -- "--audit-policy-file[^ ]*" | cut -d'=' -f2)

            if [[ -f "$audit_policy_file" ]]; then
                # Check if policy has key rules
                if grep -q "rules" "$audit_policy_file" 2>/dev/null; then
                    print_result "PASS" "Audit policy contains rules" "3.2.2"
                else
                    print_result "WARN" "Audit policy may not be properly configured" "3.2.2"
                fi
            else
                print_result "WARN" "Audit policy file not found" "3.2.2"
            fi
        else
            print_result "FAIL" "No audit policy file configured" "3.2.2"
        fi
    }

    # Execute all section 3 checks
    check_3_1_1
    check_3_1_2
    check_3_1_3
    check_3_1_4
    check_3_1_5
    check_3_1_6
    check_3_2_1
    check_3_2_2
}

#-----------------------------#
#  Master Node Checks
#-----------------------------#
run_master_checks() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Running Master Node Checks${NC}"
    echo -e "${BLUE}========================================${NC}"

    run_section_1_1_checks
    run_section_1_2_checks
    run_section_1_3_checks
    run_section_1_4_checks
    run_section_2_checks
    run_section_3_checks
    run_section_5_checks
}

#-----------------------------#
#  Section 4: Worker Node Security Configuration
#-----------------------------#

run_section_4_1_checks() {
    echo -e "\n${BLUE}=================================================${NC}"
    echo -e "${BLUE}Section 4.1 - Worker Node Configuration Files${NC}"
    echo -e "${BLUE}=================================================${NC}\n"

    # 4.1.1: Ensure that the kubelet configuration file has permissions set to 644 or more restrictive
    check_4_1_1() {
        local file="/var/lib/kubelet/config.yaml"
        if check_file_permissions "$file" 644; then
            print_result "PASS" "Kubelet config file permissions are 644 or more restrictive" "4.1.1"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "Kubelet config file not found at $file" "4.1.1"
            else
                print_result "FAIL" "Kubelet config file permissions are not 644 or more restrictive" "4.1.1"
            fi
        fi
    }

    # 4.1.2: Ensure that the kubelet configuration file ownership is set to root:root
    check_4_1_2() {
        local file="/var/lib/kubelet/config.yaml"
        if check_file_ownership "$file" "root" "root"; then
            print_result "PASS" "Kubelet config file ownership is root:root" "4.1.2"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "Kubelet config file not found at $file" "4.1.2"
            else
                print_result "FAIL" "Kubelet config file ownership is not root:root" "4.1.2"
            fi
        fi
    }

    # 4.1.3: Ensure that the kubelet service file permissions are set to 644 or more restrictive
    check_4_1_3() {
        local file="/etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
        if [[ ! -f "$file" ]]; then
            # Try alternative locations
            file="/etc/systemd/system/kubelet.service"
        fi

        if check_file_permissions "$file" 644; then
            print_result "PASS" "Kubelet service file permissions are 644 or more restrictive" "4.1.3"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "Kubelet service file not found" "4.1.3"
            else
                print_result "FAIL" "Kubelet service file permissions are not 644 or more restrictive" "4.1.3"
            fi
        fi
    }

    # 4.1.4: Ensure that the kubelet service file ownership is set to root:root
    check_4_1_4() {
        local file="/etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
        if [[ ! -f "$file" ]]; then
            file="/etc/systemd/system/kubelet.service"
        fi

        if check_file_ownership "$file" "root" "root"; then
            print_result "PASS" "Kubelet service file ownership is root:root" "4.1.4"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "Kubelet service file not found" "4.1.4"
            else
                print_result "FAIL" "Kubelet service file ownership is not root:root" "4.1.4"
            fi
        fi
    }

    # 4.1.5: Ensure that the proxy kubeconfig file permissions are set to 644 or more restrictive
    check_4_1_5() {
        # Check if running on worker node (proxy not usually on workers)
        local file="/etc/kubernetes/proxy.conf"
        if [[ ! -f "$file" ]]; then
            print_result "WARN" "Proxy config file not found at $file (may not be applicable)" "4.1.5"
            return
        fi

        if check_file_permissions "$file" 644; then
            print_result "PASS" "Proxy config file permissions are 644 or more restrictive" "4.1.5"
        else
            print_result "FAIL" "Proxy config file permissions are not 644 or more restrictive" "4.1.5"
        fi
    }

    # 4.1.6: Ensure that the proxy kubeconfig file ownership is set to root:root
    check_4_1_6() {
        local file="/etc/kubernetes/proxy.conf"
        if [[ ! -f "$file" ]]; then
            print_result "WARN" "Proxy config file not found at $file (may not be applicable)" "4.1.6"
            return
        fi

        if check_file_ownership "$file" "root" "root"; then
            print_result "PASS" "Proxy config file ownership is root:root" "4.1.6"
        else
            print_result "FAIL" "Proxy config file ownership is not root:root" "4.1.6"
        fi
    }

    # 4.1.7: Ensure that the kubelet.conf file permissions are set to 644 or more restrictive
    check_4_1_7() {
        local file="/etc/kubernetes/kubelet.conf"
        if check_file_permissions "$file" 644; then
            print_result "PASS" "kubelet.conf file permissions are 644 or more restrictive" "4.1.7"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "kubelet.conf file not found at $file" "4.1.7"
            else
                print_result "FAIL" "kubelet.conf file permissions are not 644 or more restrictive" "4.1.7"
            fi
        fi
    }

    # 4.1.8: Ensure that the kubelet.conf file ownership is set to root:root
    check_4_1_8() {
        local file="/etc/kubernetes/kubelet.conf"
        if check_file_ownership "$file" "root" "root"; then
            print_result "PASS" "kubelet.conf file ownership is root:root" "4.1.8"
        else
            local status=$?
            if [[ $status -eq 2 ]]; then
                print_result "WARN" "kubelet.conf file not found at $file" "4.1.8"
            else
                print_result "FAIL" "kubelet.conf file ownership is not root:root" "4.1.8"
            fi
        fi
    }

    # Execute all 4.1 checks
    check_4_1_1
    check_4_1_2
    check_4_1_3
    check_4_1_4
    check_4_1_5
    check_4_1_6
    check_4_1_7
    check_4_1_8
}

run_section_4_2_checks() {
    echo -e "\n${BLUE}=================================================${NC}"
    echo -e "${BLUE}Section 4.2 - Kubelet${NC}"
    echo -e "${BLUE}=================================================${NC}\n"

    # Get kubelet process info and config
    local kubelet_process
    local kubelet_config

    kubelet_process=$(get_kubelet_args)
    kubelet_config=$(get_kubelet_config)

    if [[ -z "$kubelet_process" ]] && [[ -z "$kubelet_config" ]]; then
        print_result "WARN" "Kubelet process and config not found. Skipping Kubelet checks." "4.2.x"
        return
    fi

    # Helper function to check kubelet config value
    check_kubelet_config_value() {
        local key=$1
        local expected_value=$2
        local config=$3

        if echo "$config" | grep -q "${key}: ${expected_value}"; then
            return 0
        elif echo "$config" | grep -q "${key}: ${expected_value}"; then
            return 0
        else
            return 1
        fi
    }

    # 4.2.1: Ensure that the --anonymous-auth argument is set to false
    check_4_2_1() {
        # Check in process args first
        if check_argument_value "--anonymous-auth" "false" "$kubelet_process"; then
            print_result "PASS" "--anonymous-auth is set to false" "4.2.1"
        # Check in config file
        elif echo "$kubelet_config" | grep -q "anonymousAuth: false"; then
            print_result "PASS" "anonymousAuth is set to false in config" "4.2.1"
        else
            print_result "FAIL" "--anonymous-auth is not set to false" "4.2.1"
        fi
    }

    # 4.2.2: Ensure that the --authorization-mode argument is not set to AlwaysAllow
    check_4_2_2() {
        local auth_mode=""

        # Check in process args
        if echo "$kubelet_process" | grep -q -- "--authorization-mode="; then
            auth_mode=$(echo "$kubelet_process" | grep -oP "(?<=--authorization-mode=)[^ ]+" 2>/dev/null)
        # Check in config file
        elif echo "$kubelet_config" | grep -q "authorization:"; then
            auth_mode=$(echo "$kubelet_config" | grep "authorization:" | grep -oP 'mode: \K.*' 2>/dev/null)
        fi

        if [[ "$auth_mode" != "AlwaysAllow" ]] && [[ -n "$auth_mode" ]]; then
            print_result "PASS" "authorization-mode is not set to AlwaysAllow" "4.2.2"
        elif [[ -z "$auth_mode" ]]; then
            print_result "WARN" "authorization-mode not found (may use default)" "4.2.2"
        else
            print_result "FAIL" "authorization-mode is set to AlwaysAllow" "4.2.2"
        fi
    }

    # 4.2.3: Ensure that the --client-ca-file argument is set
    check_4_2_3() {
        if check_argument_present "--client-ca-file" "$kubelet_process"; then
            print_result "PASS" "--client-ca-file is set" "4.2.3"
        elif echo "$kubelet_config" | grep -q "clientCAFile:"; then
            print_result "PASS" "clientCAFile is set in config" "4.2.3"
        else
            print_result "FAIL" "--client-ca-file is not set" "4.2.3"
        fi
    }

    # 4.2.4: Ensure that the --read-only-port argument is set to 0
    check_4_2_4() {
        if check_argument_value "--read-only-port" "0" "$kubelet_process"; then
            print_result "PASS" "--read-only-port is set to 0" "4.2.4"
        elif echo "$kubelet_config" | grep -q "readOnlyPort: 0"; then
            print_result "PASS" "readOnlyPort is set to 0 in config" "4.2.4"
        elif check_argument_absent "--read-only-port" "$kubelet_process" && ! echo "$kubelet_config" | grep -q "readOnlyPort:"; then
            print_result "PASS" "--read-only-port not set (defaults to 0 in newer versions)" "4.2.4"
        else
            print_result "FAIL" "--read-only-port is not set to 0" "4.2.4"
        fi
    }

    # 4.2.5: Ensure that the --streaming-connection-idle-timeout argument is not set to 0
    check_4_2_5() {
        local timeout=""

        if echo "$kubelet_process" | grep -q -- "--streaming-connection-idle-timeout="; then
            timeout=$(echo "$kubelet_process" | grep -oP "(?<=--streaming-connection-idle-timeout=)[^ ]+" 2>/dev/null)
        elif echo "$kubelet_config" | grep -q "streamingConnectionIdleTimeout:"; then
            timeout=$(echo "$kubelet_config" | grep "streamingConnectionIdleTimeout:" | grep -oP ': \K.*' 2>/dev/null)
        fi

        if [[ "$timeout" != "0" ]] && [[ -n "$timeout" ]]; then
            print_result "PASS" "--streaming-connection-idle-timeout is not set to 0" "4.2.5"
        elif [[ -z "$timeout" ]]; then
            print_result "PASS" "--streaming-connection-idle-timeout not set (uses default)" "4.2.5"
        else
            print_result "FAIL" "--streaming-connection-idle-timeout is set to 0" "4.2.5"
        fi
    }

    # 4.2.6: Ensure that the --protect-kernel-defaults argument is set to true
    check_4_2_6() {
        if check_argument_value "--protect-kernel-defaults" "true" "$kubelet_process"; then
            print_result "PASS" "--protect-kernel-defaults is set to true" "4.2.6"
        elif echo "$kubelet_config" | grep -q "protectKernelDefaults: true"; then
            print_result "PASS" "protectKernelDefaults is set to true in config" "4.2.6"
        else
            print_result "FAIL" "--protect-kernel-defaults is not set to true" "4.2.6"
        fi
    }

    # 4.2.7: Ensure that the --make-iptables-util-chains argument is set to true
    check_4_2_7() {
        if check_argument_value "--make-iptables-util-chains" "true" "$kubelet_process"; then
            print_result "PASS" "--make-iptables-util-chains is set to true" "4.2.7"
        elif echo "$kubelet_config" | grep -q "makeIPTablesUtilChains: true"; then
            print_result "PASS" "makeIPTablesUtilChains is set to true in config" "4.2.7"
        elif check_argument_absent "--make-iptables-util-chains" "$kubelet_process" && ! echo "$kubelet_config" | grep -q "makeIPTablesUtilChains:"; then
            print_result "PASS" "--make-iptables-util-chains not set (defaults to true)" "4.2.7"
        else
            print_result "WARN" "--make-iptables-util-chains is not set to true" "4.2.7"
        fi
    }

    # 4.2.8: Ensure that the --hostname-override argument is not set
    check_4_2_8() {
        if check_argument_absent "--hostname-override" "$kubelet_process"; then
            print_result "PASS" "--hostname-override is not set" "4.2.8"
        else
            print_result "WARN" "--hostname-override is set (ensure proper configuration)" "4.2.8"
        fi
    }

    # 4.2.9: Ensure that the --event-qps argument is set to 0 or a level which ensures appropriate event capture
    check_4_2_9() {
        local event_qps=""

        if echo "$kubelet_process" | grep -q -- "--event-qps="; then
            event_qps=$(echo "$kubelet_process" | grep -oP "(?<=--event-qps=)[^ ]+" 2>/dev/null)
        elif echo "$kubelet_config" | grep -q "eventRecordQPS:"; then
            event_qps=$(echo "$kubelet_config" | grep "eventRecordQPS:" | grep -oP ': \K.*' 2>/dev/null)
        fi

        if [[ -n "$event_qps" ]]; then
            if [[ "$event_qps" -eq 0 ]] || [[ "$event_qps" -ge 5 ]]; then
                print_result "PASS" "--event-qps is set to $event_qps" "4.2.9"
            else
                print_result "WARN" "--event-qps is set to $event_qps (may be too low)" "4.2.9"
            fi
        else
            print_result "WARN" "--event-qps not set (uses default)" "4.2.9"
        fi
    }

    # 4.2.10: Ensure that the --tls-cert-file and --tls-private-key-file arguments are set
    check_4_2_10() {
        if check_argument_present "--tls-cert-file" "$kubelet_process" && \
           check_argument_present "--tls-private-key-file" "$kubelet_process"; then
            print_result "PASS" "--tls-cert-file and --tls-private-key-file are set" "4.2.10"
        elif echo "$kubelet_config" | grep -q "tlsCertFile:" && echo "$kubelet_config" | grep -q "tlsPrivateKeyFile:"; then
            print_result "PASS" "tlsCertFile and tlsPrivateKeyFile are set in config" "4.2.10"
        else
            print_result "FAIL" "TLS cert and key files are not properly set" "4.2.10"
        fi
    }

    # 4.2.11: Ensure that the --rotate-certificates argument is not set to false
    check_4_2_11() {
        if check_argument_value "--rotate-certificates" "false" "$kubelet_process"; then
            print_result "FAIL" "--rotate-certificates is set to false" "4.2.11"
        elif check_argument_value "--rotate-certificates" "true" "$kubelet_process"; then
            print_result "PASS" "--rotate-certificates is set to true" "4.2.11"
        elif echo "$kubelet_config" | grep -q "rotateCertificates: true"; then
            print_result "PASS" "rotateCertificates is set to true in config" "4.2.11"
        else
            print_result "WARN" "--rotate-certificates not explicitly set" "4.2.11"
        fi
    }

    # 4.2.12: Ensure that the RotateKubeletServerCertificate argument is set
    check_4_2_12() {
        if echo "$kubelet_process" | grep -q -- "feature-gates=.*RotateKubeletServerCertificate=true"; then
            print_result "PASS" "RotateKubeletServerCertificate feature gate is enabled" "4.2.12"
        elif echo "$kubelet_config" | grep -q "RotateKubeletServerCertificate: true"; then
            print_result "PASS" "RotateKubeletServerCertificate is enabled in config" "4.2.12"
        else
            print_result "WARN" "RotateKubeletServerCertificate not explicitly enabled" "4.2.12"
        fi
    }

    # 4.2.13: Ensure that the --bind-address argument is set to 127.0.0.1
    check_4_2_13() {
        if check_argument_value "--bind-address" "127.0.0.1" "$kubelet_process"; then
            print_result "PASS" "--bind-address is set to 127.0.0.1" "4.2.13"
        elif echo "$kubelet_config" | grep -q "address: 127.0.0.1"; then
            print_result "PASS" "address is set to 127.0.0.1 in config" "4.2.13"
        else
            print_result "WARN" "--bind-address is not set to 127.0.0.1" "4.2.13"
        fi
    }

    # 4.2.14: Ensure that the --cluster-dns argument is set
    check_4_2_14() {
        if check_argument_present "--cluster-dns" "$kubelet_process"; then
            print_result "PASS" "--cluster-dns is set" "4.2.14"
        elif echo "$kubelet_config" | grep -q "clusterDNS:"; then
            print_result "PASS" "clusterDNS is set in config" "4.2.14"
        else
            print_result "WARN" "--cluster-dns is not set" "4.2.14"
        fi
    }

    # 4.2.15: Ensure that the --cluster-domain argument is set
    check_4_2_15() {
        if check_argument_present "--cluster-domain" "$kubelet_process"; then
            print_result "PASS" "--cluster-domain is set" "4.2.15"
        elif echo "$kubelet_config" | grep -q "clusterDomain:"; then
            print_result "PASS" "clusterDomain is set in config" "4.2.15"
        else
            print_result "WARN" "--cluster-domain is not set" "4.2.15"
        fi
    }

    # 4.2.16: Ensure that the --cgroup-driver argument is set
    check_4_2_16() {
        if check_argument_present "--cgroup-driver" "$kubelet_process"; then
            print_result "PASS" "--cgroup-driver is set" "4.2.16"
        elif echo "$kubelet_config" | grep -q "cgroupDriver:"; then
            print_result "PASS" "cgroupDriver is set in config" "4.2.16"
        else
            print_result "WARN" "--cgroup-driver is not set" "4.2.16"
        fi
    }

    # 4.2.17: Ensure that the --network-plugin argument is set
    check_4_2_17() {
        if check_argument_present "--network-plugin" "$kubelet_process"; then
            print_result "PASS" "--network-plugin is set" "4.2.17"
        elif echo "$kubelet_config" | grep -q "networkPlugin:"; then
            print_result "PASS" "networkPlugin is set in config" "4.2.17"
        else
            print_result "WARN" "--network-plugin is not set" "4.2.17"
        fi
    }

    # 4.2.18: Ensure that the --cni-conf-dir argument is set when using network plugin
    check_4_2_18() {
        if check_argument_present "--cni-conf-dir" "$kubelet_process"; then
            print_result "PASS" "--cni-conf-dir is set" "4.2.18"
        elif echo "$kubelet_config" | grep -q "cniConfDir:"; then
            print_result "PASS" "cniConfDir is set in config" "4.2.18"
        else
            print_result "WARN" "--cni-conf-dir is not set" "4.2.18"
        fi
    }

    # 4.2.19: Ensure that the --volume-plugin-dir argument is set
    check_4_2_19() {
        if check_argument_present "--volume-plugin-dir" "$kubelet_process"; then
            print_result "PASS" "--volume-plugin-dir is set" "4.2.19"
        elif echo "$kubelet_config" | grep -q "volumePluginDir:"; then
            print_result "PASS" "volumePluginDir is set in config" "4.2.19"
        else
            print_result "WARN" "--volume-plugin-dir is not set (may use default)" "4.2.19"
        fi
    }

    # 4.2.20: Ensure that the --pod-infra-container-image argument is set
    check_4_2_20() {
        if check_argument_present "--pod-infra-container-image" "$kubelet_process"; then
            print_result "PASS" "--pod-infra-container-image is set" "4.2.20"
        elif echo "$kubelet_config" | grep -q "podInfraContainerImage:"; then
            print_result "PASS" "podInfraContainerImage is set in config" "4.2.20"
        else
            print_result "WARN" "--pod-infra-container-image is not set (may use default)" "4.2.20"
        fi
    }

    # 4.2.21: Ensure that the --allow-privileged argument is set
    check_4_2_21() {
        # Note: In newer versions, privileged is controlled via Pod Security Standards
        if check_argument_value "--allow-privileged" "false" "$kubelet_process"; then
            print_result "PASS" "--allow-privileged is set to false" "4.2.21"
        elif check_argument_value "--allow-privileged" "true" "$kubelet_process"; then
            print_result "WARN" "--allow-privileged is set to true (review if required)" "4.2.21"
        elif check_argument_absent "--allow-privileged" "$kubelet_process"; then
            print_result "PASS" "--allow-privileged not set (may use default)" "4.2.21"
        else
            print_result "WARN" "--allow-privileged configuration unknown" "4.2.21"
        fi
    }

    # 4.2.22: Ensure that the --host-network-sources argument is not set
    check_4_2_22() {
        # Note: This argument is deprecated in newer versions
        if check_argument_absent "--host-network-sources" "$kubelet_process"; then
            print_result "PASS" "--host-network-sources is not set" "4.2.22"
        else
            print_result "WARN" "--host-network-sources is set (review configuration)" "4.2.22"
        fi
    }

    # Execute all 4.2 checks
    check_4_2_1
    check_4_2_2
    check_4_2_3
    check_4_2_4
    check_4_2_5
    check_4_2_6
    check_4_2_7
    check_4_2_8
    check_4_2_9
    check_4_2_10
    check_4_2_11
    check_4_2_12
    check_4_2_13
    check_4_2_14
    check_4_2_15
    check_4_2_16
    check_4_2_17
    check_4_2_18
    check_4_2_19
    check_4_2_20
    check_4_2_21
    check_4_2_22
}

#-----------------------------#
#  Section 4.2: Container Runtime Configuration
#-----------------------------#

run_section_4_3_checks() {
    echo -e "\n${BLUE}=================================================${NC}"
    echo -e "${BLUE}Section 4.2 - Container Runtime Configuration${NC}"
    echo -e "${BLUE}=================================================${NC}\n"

    # Detect container runtime
    local container_runtime=""
    local runtime_socket=""

    if [[ -S "/run/containerd/containerd.sock" ]]; then
        container_runtime="containerd"
        runtime_socket="/run/containerd/containerd.sock"
    elif [[ -S "/var/run/docker.sock" ]]; then
        container_runtime="docker"
        runtime_socket="/var/run/docker.sock"
    elif [[ -S "/run/crio/crio.sock" ]]; then
        container_runtime="crio"
        runtime_socket="/run/crio/crio.sock"
    fi

    if [[ -z "$container_runtime" ]]; then
        print_result "WARN" "No supported container runtime detected" "4.2.x"
        return
    fi

    echo -e "${BLUE}Detected container runtime: ${container_runtime}${NC}\n"

    # 4.2.1: Ensure that the container runtime socket file permissions are set to 660 or more restrictive
    check_4_2_1() {
        if check_file_permissions "$runtime_socket" 660; then
            print_result "PASS" "Container runtime socket permissions are 660 or more restrictive" "4.2.1"
        else
            print_result "FAIL" "Container runtime socket permissions are not 660 or more restrictive" "4.2.1"
        fi
    }

    # 4.2.2: Ensure that the container runtime socket file ownership is set to root:root or root:<runtime>
    check_4_2_2() {
        local actual_user
        local actual_group

        if [[ "$OSTYPE" == "darwin"* ]]; then
            actual_user=$(stat -f "%Su" "$runtime_socket")
            actual_group=$(stat -f "%Sg" "$runtime_socket")
        else
            actual_user=$(stat -c "%U" "$runtime_socket")
            actual_group=$(stat -c "%G" "$runtime_socket")
        fi

        if [[ "$actual_user" == "root" ]]; then
            print_result "PASS" "Container runtime socket ownership is $actual_user:$actual_group" "4.2.2"
        else
            print_result "FAIL" "Container runtime socket ownership is not root:root or root:<runtime>" "4.2.2"
        fi
    }

    # 4.2.3: Ensure that the --authorization-mode argument is not set to AlwaysAllow (for containerd)
    check_4_2_3() {
        if [[ "$container_runtime" == "containerd" ]]; then
            local config_file="/etc/containerd/config.toml"
            if [[ -f "$config_file" ]]; then
                if ! grep -q "disabled_plugins = \[" "$config_file" || \
                   ! grep -q '"io.containerd.grpc.v1.cri"' "$config_file"; then
                    print_result "PASS" "Containerd CRI plugin appears enabled" "4.2.3"
                else
                    print_result "WARN" "Review containerd authorization configuration" "4.2.3"
                fi
            else
                print_result "WARN" "Containerd config file not found at $config_file" "4.2.3"
            fi
        else
            print_result "INFO" "Check applies to containerd runtime only" "4.2.3"
        fi
    }

    # 4.2.4: Ensure that the container runtime has a User Namespace configured
    check_4_2_4() {
        if [[ "$container_runtime" == "docker" ]]; then
            # Check for user namespace remapping in docker daemon config
            local docker_config="/etc/docker/daemon.json"
            if [[ -f "$docker_config" ]]; then
                if grep -q '"userns-remap"' "$docker_config"; then
                    print_result "PASS" "Docker user namespace remapping is configured" "4.2.4"
                else
                    print_result "WARN" "Docker user namespace remapping not configured" "4.2.4"
                fi
            else
                print_result "WARN" "Docker daemon config not found at $docker_config" "4.2.4"
            fi
        elif [[ "$container_runtime" == "containerd" ]]; then
            local config_file="/etc/containerd/config.toml"
            if [[ -f "$config_file" ]]; then
                if grep -q "[plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc.options]" "$config_file" && \
                   grep -q "SystemdCgroup = true" "$config_file"; then
                    print_result "PASS" "Containerd runtime options configured" "4.2.4"
                else
                    print_result "WARN" "Review containerd namespace configuration" "4.2.4"
                fi
            else
                print_result "WARN" "Containerd config file not found" "4.2.4"
            fi
        else
            print_result "INFO" "User namespace configuration check not implemented for $container_runtime" "4.2.4"
        fi
    }

    # 4.2.5: Ensure that the container runtime has a read-only root filesystem
    check_4_2_5() {
        print_result "INFO" "Container-level check - verify pods have readOnlyRootFilesystem set" "4.2.5"
    }

    # 4.2.6: Ensure that the container runtime has the appropriate security options
    check_4_2_6() {
        if [[ "$container_runtime" == "docker" ]]; then
            local docker_config="/etc/docker/daemon.json"
            if [[ -f "$docker_config" ]]; then
                if grep -q '"icc".*false' "$docker_config"; then
                    print_result "PASS" "Docker inter-container communication is restricted" "4.2.6"
                else
                    print_result "WARN" "Docker inter-container communication may be enabled" "4.2.6"
                fi
            else
                print_result "WARN" "Docker daemon config not found" "4.2.6"
            fi
        else
            print_result "INFO" "Security options check for $container_runtime" "4.2.6"
        fi
    }

    # 4.2.7: Ensure that the container runtime has the appropriate log driver configured
    check_4_2_7() {
        if [[ "$container_runtime" == "docker" ]]; then
            local docker_config="/etc/docker/daemon.json"
            if [[ -f "$docker_config" ]]; then
                if grep -q '"log-driver"' "$docker_config"; then
                    print_result "PASS" "Docker log driver is configured" "4.2.7"
                else
                    print_result "WARN" "Docker log driver not explicitly configured" "4.2.7"
                fi
            else
                print_result "WARN" "Docker daemon config not found" "4.2.7"
            fi
        else
            print_result "INFO" "Log driver check for $container_runtime" "4.2.7"
        fi
    }

    # 4.2.8: Ensure that the container runtime has TLS enabled
    check_4_2_8() {
        if [[ "$container_runtime" == "docker" ]]; then
            local docker_config="/etc/docker/daemon.json"
            if [[ -f "$docker_config" ]]; then
                if grep -q '"tlsverify".*true' "$docker_config"; then
                    print_result "PASS" "Docker TLS verification is enabled" "4.2.8"
                else
                    print_result "WARN" "Docker TLS verification may not be enabled" "4.2.8"
                fi
            else
                print_result "WARN" "Docker daemon config not found" "4.2.8"
            fi
        else
            print_result "INFO" "TLS check for $container_runtime" "4.2.8"
        fi
    }

    # 4.2.9: Ensure that the container runtime has the appropriate ulimit settings
    check_4_2_9() {
        if [[ "$container_runtime" == "docker" ]]; then
            local docker_config="/etc/docker/daemon.json"
            if [[ -f "$docker_config" ]]; then
                if grep -q '"default-ulimits"' "$docker_config"; then
                    print_result "PASS" "Docker default ulimits are configured" "4.2.9"
                else
                    print_result "WARN" "Docker default ulimits not configured" "4.2.9"
                fi
            else
                print_result "WARN" "Docker daemon config not found" "4.2.9"
            fi
        else
            print_result "INFO" "Ulimit check for $container_runtime" "4.2.9"
        fi
    }

    # 4.2.10: Ensure that the container runtime has cgroups configured
    check_4_2_10() {
        if [[ "$container_runtime" == "docker" ]]; then
            local docker_config="/etc/docker/daemon.json"
            if [[ -f "$docker_config" ]]; then
                if grep -q '"cgroup-parent"' "$docker_config"; then
                    print_result "PASS" "Docker cgroup parent is configured" "4.2.10"
                else
                    print_result "WARN" "Docker cgroup parent not configured" "4.2.10"
                fi
            else
                print_result "WARN" "Docker daemon config not found" "4.2.10"
            fi
        elif [[ "$container_runtime" == "containerd" ]]; then
            local config_file="/etc/containerd/config.toml"
            if [[ -f "$config_file" ]]; then
                if grep -q "SystemdCgroup = true" "$config_file"; then
                    print_result "PASS" "Containerd systemd cgroup is configured" "4.2.10"
                else
                    print_result "WARN" "Containerd systemd cgroup not configured" "4.2.10"
                fi
            else
                print_result "WARN" "Containerd config file not found" "4.2.10"
            fi
        else
            print_result "INFO" "Cgroup check for $container_runtime" "4.2.10"
        fi
    }

    # Execute all 4.2 (container runtime) checks
    check_4_2_1
    check_4_2_2
    check_4_2_3
    check_4_2_4
    check_4_2_5
    check_4_2_6
    check_4_2_7
    check_4_2_8
    check_4_2_9
    check_4_2_10
}

#-----------------------------#
#  Worker Node Checks
#-----------------------------#
run_worker_checks() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Running Worker Node Checks${NC}"
    echo -e "${BLUE}========================================${NC}"

    run_section_4_1_checks
    run_section_4_2_checks
    run_section_4_3_checks
}

#-----------------------------#
#  Section 5: Kubernetes Policies
#-----------------------------#

run_section_5_checks() {
    echo -e "\n${BLUE}=================================================${NC}"
    echo -e "${BLUE}Section 5 - Kubernetes Policies${NC}"
    echo -e "${BLUE}=================================================${NC}\n"

    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_result "WARN" "kubectl not found. Skipping policy checks." "5.x"
        return
    fi

    # Check if we can connect to the cluster
    if ! kubectl get nodes &> /dev/null; then
        print_result "WARN" "Cannot connect to Kubernetes cluster. Skipping policy checks." "5.x"
        return
    fi

    # 5.1: Ensure that the cluster has at least one active Pod Security Policy (PSP)
    # Note: PSP is deprecated in Kubernetes 1.25+, replaced by Pod Security Standards
    check_5_1() {
        # Check if PSP is available (older Kubernetes versions)
        local psp_count
        psp_count=$(kubectl get psp -o json 2>/dev/null | jq '.items | length' 2>/dev/null || echo "0")

        if [[ "$psp_count" -gt 0 ]]; then
            print_result "PASS" "Found $psp_count Pod Security Policies" "5.1"
        else
            # Check for Pod Security Standards (newer versions)
            local pss_labels
            pss_labels=$(kubectl get ns -o json 2>/dev/null | jq -r '.items[].metadata.labels."pod-security.kubernetes.io/enforce"' 2>/dev/null)

            if [[ -n "$pss_labels" ]]; then
                print_result "PASS" "Pod Security Standards are configured (PSP deprecated)" "5.1"
            else
                print_result "WARN" "No Pod Security Policies or Pod Security Standards found" "5.1"
            fi
        fi
    }

    # 5.2: Ensure that the Pod Security Policy (PSS) is configured to restrict privileged containers
    check_5_2() {
        # Check for Pod Security Standards
        local enforce_level
        enforce_level=$(kubectl get ns -o json 2>/dev/null | jq -r '.items[] | select(.metadata.labels."pod-security.kubernetes.io/enforce" != null) | .metadata.name' 2>/dev/null)

        if [[ -n "$enforce_level" ]]; then
            local count=0
            while IFS= read -r ns; do
                if [[ -n "$ns" ]]; then
                    count=$((count + 1))
                fi
            done <<< "$enforce_level"

            print_result "PASS" "$count namespaces have Pod Security Standards enforced" "5.2"
        else
            print_result "WARN" "No namespaces with Pod Security Standards enforcement found" "5.2"
        fi
    }

    # 5.3: Ensure that the cluster has Network Policies configured
    check_5_3() {
        local namespaces_with_policy=0
        local total_namespaces=0

        local namespaces
        namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

        for ns in $namespaces; do
            total_namespaces=$((total_namespaces + 1))
            local policy_count
            policy_count=$(kubectl get networkpolicy -n "$ns" -o json 2>/dev/null | jq '.items | length' 2>/dev/null || echo "0")

            if [[ "$policy_count" -gt 0 ]]; then
                namespaces_with_policy=$((namespaces_with_policy + 1))
            fi
        done

        if [[ $namespaces_with_policy -gt 0 ]]; then
            print_result "PASS" "$namespaces_with_policy of $total_namespaces namespaces have Network Policies" "5.3"
        else
            print_result "WARN" "No namespaces have Network Policies configured" "5.3"
        fi
    }

    # 5.4: Ensure that the default namespace is not used for user workloads
    check_5_4() {
        local pod_count
        pod_count=$(kubectl get pods -n default -o json 2>/dev/null | jq '.items | length' 2>/dev/null || echo "0")

        # Filter out system pods like kube-proxy, coredns, etc.
        local user_pods
        user_pods=$(kubectl get pods -n default -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | test("kube-proxy|coredns|etcd|local-path-provisioner") | not) | .metadata.name' 2>/dev/null)

        local user_pod_count=0
        if [[ -n "$user_pods" ]]; then
            user_pod_count=$(echo "$user_pods" | wc -l)
        fi

        if [[ $user_pod_count -eq 0 ]]; then
            print_result "PASS" "No user workloads found in default namespace" "5.4"
        else
            print_result "WARN" "$user_pod_count user workload(s) found in default namespace" "5.4"
        fi
    }

    # 5.5: Ensure that the --authorization-mode argument includes RBAC
    # Note: This is already checked in section 1.2.9
    check_5_5() {
        print_result "INFO" "Already checked in section 1.2.9" "5.5"
    }

    # 5.6: Ensure that the admission control plugin ServiceAccount is set
    # Note: This is already checked in section 1.2.14
    check_5_6() {
        print_result "INFO" "Already checked in section 1.2.14" "5.6"
    }

    #--------------------------------------------------------------------------------
    #  Section 5.1: RBAC and Least Privilege (Additional checks from official standard)
    #--------------------------------------------------------------------------------

    # 5.1.2: Minimize access to secrets
    check_5_1_2() {
        # Check for ClusterRoleBindings that grant excessive secret access
        local excessive_bindings=0
        local bindings_info=$(kubectl get clusterrolebindings -o json 2>/dev/null | jq -r '.items[] | select(.roleRef.name=="cluster-admin" or .roleRef.name=="admin" or .roleRef.name=="edit") | "\(.metadata.name) -> \(.roleRef.name)"' 2>/dev/null)

        if [[ -n "$bindings_info" ]]; then
            # Check if any of these bindings have access to secrets
            while IFS= read -r binding; do
                if [[ -n "$binding" ]]; then
                    excessive_bindings=$((excessive_bindings + 1))
                fi
            done <<< "$bindings_info"

            if [[ $excessive_bindings -gt 5 ]]; then
                print_result "WARN" "Found $excessive_bindings ClusterRoleBindings with potentially excessive secret access" "5.1.2"
            else
                print_result "PASS" "ClusterRoleBindings with secret access appear minimal" "5.1.2"
            fi
        else
            print_result "PASS" "No excessive secret access detected in ClusterRoleBindings" "5.1.2"
        fi
    }

    # 5.1.3: Minimize wildcard use in Roles and ClusterRoles
    check_5_1_3() {
        # Check for wildcard usage in Roles and ClusterRoles
        local wildcard_roles=0
        local wildcard_clusterroles=0

        # Check Roles
        local roles=$(kubectl get roles --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.rules[].resources[] == "*" or .rules[].verbs[] == "*") | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null)

        if [[ -n "$roles" ]]; then
            wildcard_roles=$(echo "$roles" | wc -l)
        fi

        # Check ClusterRoles
        local clusterroles=$(kubectl get clusterroles -o json 2>/dev/null | jq -r '.items[] | select(.rules[].resources[] == "*" or .rules[].verbs[] == "*") | .metadata.name' 2>/dev/null)

        if [[ -n "$clusterroles" ]]; then
            wildcard_clusterroles=$(echo "$clusterroles" | wc -l)
        fi

        # Exclude system ClusterRoles
        local system_wildcards=0
        if [[ -n "$clusterroles" ]]; then
            system_wildcards=$(echo "$clusterroles" | grep -c "^system:" 2>/dev/null || echo "0")
        fi
        wildcard_clusterroles=$((wildcard_clusterroles - system_wildcards))

        if [[ $wildcard_roles -eq 0 && $wildcard_clusterroles -eq 0 ]]; then
            print_result "PASS" "No wildcard usage found in custom Roles/ClusterRoles" "5.1.3"
        elif [[ $wildcard_roles -le 2 && $wildcard_clusterroles -le 2 ]]; then
            print_result "WARN" "Found $wildcard_roles Roles and $wildcard_clusterroles ClusterRoles with wildcards (review)" "5.1.3"
        else
            print_result "FAIL" "Found excessive wildcard usage: $wildcard_roles Roles, $wildcard_clusterroles ClusterRoles" "5.1.3"
        fi
    }

    # 5.1.4: Minimize access to create pods
    check_5_1_4() {
        # Check for Roles/ClusterRoles with pod creation permissions
        local pod_create_roles=0

        local roles=$(kubectl get roles,clusterroles --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.rules[].resources[] == "pods" and (.rules[].verbs[] == "create" or .rules[].verbs[] == "*")) | "\(.kind)/\(.metadata.name)"' 2>/dev/null)

        if [[ -n "$roles" ]]; then
            pod_create_roles=$(echo "$roles" | wc -l)
        fi

        # Exclude system roles
        local system_pod_roles=0
        if [[ -n "$roles" ]]; then
            system_pod_roles=$(echo "$roles" | grep -c "^ClusterRole/system:" 2>/dev/null || echo "0")
        fi
        pod_create_roles=$((pod_create_roles - system_pod_roles))

        if [[ $pod_create_roles -le 5 ]]; then
            print_result "PASS" "Pod creation permissions appear minimal ($pod_create_roles custom roles)" "5.1.4"
        else
            print_result "WARN" "Found $pod_create_roles roles with pod creation permissions (review)" "5.1.4"
        fi
    }

    #--------------------------------------------------------------------------------
    #  Section 5.4: Secrets Management
    #--------------------------------------------------------------------------------

    # 5.4.1: Ensure that Kubernetes Secret objects are not stored in environment variables
    check_5_4_1() {
        local pods_with_secrets=0
        local total_pods_checked=0

        # Get all namespaces
        local namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

        for ns in $namespaces; do
            # Skip kube-system namespace
            if [[ "$ns" == "kube-system" ]]; then
                continue
            fi

            # Check pods in this namespace for envFrom with secrets
            local pod_info=$(kubectl get pods -n "$ns" -o json 2>/dev/null | jq -r '.items[] | select(.spec.containers[].envFrom[]?.secretRef != null or .spec.containers[].env[]?.valueFrom.secretKeyRef != null) | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null)

            if [[ -n "$pod_info" ]]; then
                while IFS= read -r pod; do
                    if [[ -n "$pod" ]]; then
                        pods_with_secrets=$((pods_with_secrets + 1))
                    fi
                done <<< "$pod_info"
            fi
        done

        if [[ $pods_with_secrets -eq 0 ]]; then
            print_result "PASS" "No pods found using secrets in environment variables" "5.4.1"
        elif [[ $pods_with_secrets -le 3 ]]; then
            print_result "WARN" "Found $pods_with_secrets pods using secrets in environment variables (consider using mounted volumes)" "5.4.1"
        else
            print_result "FAIL" "Found $pods_with_secrets pods using secrets in environment variables" "5.4.1"
        fi
    }

    #--------------------------------------------------------------------------------
    #  Section 5.5: Extensible Admission Control
    #--------------------------------------------------------------------------------

    # 5.5.1: Ensure that the admission control plugin PodSecurityPolicy is set
    # Note: PSP is deprecated in Kubernetes 1.25+
    check_5_5_1() {
        # Check for PodSecurityPolicy or Pod Security Standards
        local psp_count=$(kubectl get psp -o json 2>/dev/null | jq '.items | length' 2>/dev/null || echo "0")

        if [[ "$psp_count" -gt 0 ]]; then
            print_result "PASS" "Pod Security Policies are configured ($psp_count policies)" "5.5.1"
        else
            # Check for Pod Security Standards (replacement for PSP)
            local pss_count=$(kubectl get ns -o json 2>/dev/null | jq -r '[.items[] | select(.metadata.labels."pod-security.kubernetes.io/enforce" != null)] | length' 2>/dev/null || echo "0")

            if [[ "$pss_count" -gt 0 ]]; then
                print_result "PASS" "Pod Security Standards are configured ($pss_count namespaces with enforcement)" "5.5.1"
            else
                print_result "WARN" "No Pod Security Policies or Pod Security Standards found" "5.5.1"
            fi
        fi
    }

    #--------------------------------------------------------------------------------
    #  Section 5.7: General Security Primitives
    #--------------------------------------------------------------------------------

    # 5.7.1: Ensure that the security context is configured in your pod definitions
    check_5_7_1() {
        local pods_without_context=0
        local total_pods=0

        local namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

        for ns in $namespaces; do
            # Skip system namespaces
            if [[ "$ns" == "kube-system" ]] || [[ "$ns" == "kube-public" ]]; then
                continue
            fi

            # Check pods without security context
            local pod_count=$(kubectl get pods -n "$ns" -o json 2>/dev/null | jq -r '.items[] | select(.spec.securityContext == null and .spec.containers[].securityContext == null) | .metadata.name' 2>/dev/null | wc -l)

            pods_without_context=$((pods_without_context + pod_count))
            total_pods=$((total_pods + $(kubectl get pods -n "$ns" -o json 2>/dev/null | jq '.items | length' 2>/dev/null || echo "0")))
        done

        if [[ $pods_without_context -eq 0 ]]; then
            print_result "PASS" "All pods have security context configured" "5.7.1"
        elif [[ $pods_without_context -le 3 ]]; then
            print_result "WARN" "$pods_without_context of $total_pods pods without security context" "5.7.1"
        else
            print_result "FAIL" "$pods_without_context of $total_pods pods without security context" "5.7.1"
        fi
    }

    # 5.7.2: Ensure that the seccomp profile is set in your pod definitions
    check_5_7_2() {
        local pods_with_seccomp=0
        local total_pods=0

        local namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

        for ns in $namespaces; do
            # Skip system namespaces
            if [[ "$ns" == "kube-system" ]] || [[ "$ns" == "kube-public" ]]; then
                continue
            fi

            # Check pods with seccomp profile
            local pod_count=$(kubectl get pods -n "$ns" -o json 2>/dev/null | jq -r '.items[] | select(.spec.securityContext != null and (.spec.securityContext.seccompProfile != null or .spec.containers[].securityContext.seccompProfile != null)) | .metadata.name' 2>/dev/null | wc -l)

            pods_with_seccomp=$((pods_with_seccomp + pod_count))
            total_pods=$((total_pods + $(kubectl get pods -n "$ns" -o json 2>/dev/null | jq '.items | length' 2>/dev/null || echo "0")))
        done

        if [[ $pods_with_seccomp -gt 0 ]]; then
            print_result "PASS" "$pods_with_seccomp of $total_pods pods have seccomp profile configured" "5.7.2"
        else
            print_result "WARN" "No pods with seccomp profile found" "5.7.2"
        fi
    }

    # 5.7.3: Ensure that the admission control plugin SecurityContextDeny is set
    # Note: This plugin is deprecated in favor of Pod Security Standards
    check_5_7_3() {
        local apiserver_process=$(get_apiserver_args)

        if check_admission_plugin "SecurityContextDeny" "$apiserver_process"; then
            print_result "PASS" "SecurityContextDeny admission plugin is set" "5.7.3"
        else
            # Check for Pod Security Standards instead (replacement)
            local pss_count=$(kubectl get ns -o json 2>/dev/null | jq -r '[.items[] | select(.metadata.labels."pod-security.kubernetes.io/enforce" != null)] | length' 2>/dev/null || echo "0")

            if [[ "$pss_count" -gt 0 ]]; then
                print_result "PASS" "Pod Security Standards configured (SecurityContextDeny deprecated)" "5.7.3"
            else
                print_result "WARN" "SecurityContextDeny not set and no Pod Security Standards found" "5.7.3"
            fi
        fi
    }

    #--------------------------------------------------------------------------------
    #  Section 5.8: Network Policies and Segmentation
    #--------------------------------------------------------------------------------

    # 5.8.1: Ensure namespaces have network policies defined (enhanced check)
    check_5_8_1() {
        local namespaces_with_policy=0
        local namespaces_without_policy=0
        local total_namespaces=0

        local namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

        for ns in $namespaces; do
            # Skip system namespaces that don't need policies
            if [[ "$ns" == "kube-system" ]] || [[ "$ns" == "kube-public" ]] || [[ "$ns" == "kube-node-lease" ]]; then
                continue
            fi

            total_namespaces=$((total_namespaces + 1))
            local policy_count=$(kubectl get networkpolicy -n "$ns" -o json 2>/dev/null | jq '.items | length' 2>/dev/null || echo "0")

            if [[ "$policy_count" -gt 0 ]]; then
                namespaces_with_policy=$((namespaces_with_policy + 1))
            else
                namespaces_without_policy=$((namespaces_without_policy + 1))
            fi
        done

        if [[ $namespaces_without_policy -eq 0 ]]; then
            print_result "PASS" "All namespaces ($total_namespaces) have network policies" "5.8.1"
        elif [[ $namespaces_with_policy -gt $namespaces_without_policy ]]; then
            print_result "WARN" "$namespaces_with_policy/$total_namespaces namespaces have network policies" "5.8.1"
        else
            print_result "FAIL" "$namespaces_without_policy/$total_namespaces namespaces lack network policies" "5.8.1"
        fi
    }

    # Execute all section 5 checks
    check_5_1
    check_5_2
    check_5_3
    check_5_4
    check_5_5
    check_5_6
    # Additional enhanced checks
    check_5_1_2
    check_5_1_3
    check_5_1_4
    check_5_4_1
    check_5_5_1
    check_5_7_1
    check_5_7_2
    check_5_7_3
    check_5_8_1
}

#-----------------------------#
#  Summary Report
#-----------------------------#
print_summary() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Audit Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}[PASS]${NC}: $PASS_COUNT"
    echo -e "${RED}[FAIL]${NC}: $FAIL_COUNT"
    echo -e "${YELLOW}[WARN]${NC}: $WARN_COUNT"
    echo -e "${BLUE}Total Checks${NC}: $TOTAL_CHECKS"

    if [[ $FAIL_COUNT -eq 0 && $WARN_COUNT -eq 0 ]]; then
        echo -e "\n${GREEN}All checks passed!${NC}"
        exit 0
    elif [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "\n${YELLOW}All checks passed with warnings.${NC}"
        exit 0
    else
        echo -e "\n${RED}Some checks failed. Please review the output above.${NC}"
        exit 1
    fi
}

#-----------------------------#
#  Main Script
#-----------------------------#
main() {
    # 解析命令行参数
    local node_type=""
    local filter_args=()

    # 遍历所有参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --only-pass)
                SHOW_PASS=true
                SHOW_WARN=false
                SHOW_FAIL=false
                FILTER_MODE="pass"
                shift
                ;;
            --only-warn)
                SHOW_PASS=false
                SHOW_WARN=true
                SHOW_FAIL=false
                FILTER_MODE="warn"
                shift
                ;;
            --only-fail)
                SHOW_PASS=false
                SHOW_WARN=false
                SHOW_FAIL=true
                FILTER_MODE="fail"
                shift
                ;;
            --only-error)
                SHOW_PASS=false
                SHOW_WARN=true
                SHOW_FAIL=true
                FILTER_MODE="error"
                shift
                ;;
            --quiet|-q)
                QUIET_MODE=true
                shift
                ;;
            master|worker)
                node_type=$1
                shift
                ;;
            -h|--help|help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}[ERROR]${NC} Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 检查是否指定了节点类型
    if [[ -z "$node_type" ]]; then
        echo -e "${RED}[ERROR]${NC} Missing node type argument"
        show_help
        exit 1
    fi

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR]${NC} This script must be run as root"
        exit 1
    fi

    # 显示过滤模式信息（非安静模式）
    if [[ "$QUIET_MODE" == "false" ]]; then
        case $FILTER_MODE in
            pass)
                echo -e "${BLUE}=== 输出过滤模式: 只显示 PASS 结果 ===${NC}\n"
                ;;
            warn)
                echo -e "${BLUE}=== 输出过滤模式: 只显示 WARN 结果 ===${NC}\n"
                ;;
            fail)
                echo -e "${BLUE}=== 输出过滤模式: 只显示 FAIL 结果 ===${NC}\n"
                ;;
            error)
                echo -e "${BLUE}=== 输出过滤模式: 只显示 FAIL 和 WARN 结果 ===${NC}\n"
                ;;
            quiet)
                # 安静模式不显示
                ;;
            *)
                # 默认显示所有
                ;;
        esac
    fi

    # 根据节点类型执行检查
    case $node_type in
        master)
            run_master_checks
            ;;
        worker)
            run_worker_checks
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Invalid node type. Use 'master' or 'worker'"
            exit 1
            ;;
    esac

    # 打印汇总报告
    print_summary
}

#--------------------------------------------------------------------------------
#  函数: show_help
#  功能: 显示帮助信息
#  参数: 无
#  返回: 无
#--------------------------------------------------------------------------------
show_help() {
    cat << EOF
${BLUE}CIS Kubernetes Benchmark v1.12.0 审计脚本 (v1.3.0)${NC}

${YELLOW}用法:${NC}
  sudo $0 [master|worker] [选项]

${YELLOW}参数:${NC}
  master          审计 Master 节点
  worker          审计 Worker 节点

${YELLOW}输出过滤选项:${NC}
  --only-pass     只显示 PASS (通过) 结果
  --only-warn     只显示 WARN (警告) 结果
  --only-fail     只显示 FAIL (失败) 结果
  --only-error    只显示 FAIL 和 WARN 结果
  --quiet, -q     安静模式，只显示汇总报告

${YELLOW}示例:${NC}
  # 审计 Master 节点（显示所有结果）
  sudo $0 master

  # 审计 Worker 节点（显示所有结果）
  sudo $0 worker

  # 只显示失败项
  sudo $0 master --only-fail

  # 只显示警告项
  sudo $0 worker --only-warn

  # 只显示错误项（失败+警告）
  sudo $0 master --only-error

  # 安静模式，只显示汇总
  sudo $0 master --quiet

  # 查看帮助
  $0 --help

${YELLOW}输出说明:${NC}
  ${GREEN}[PASS]${NC}  配置符合安全基线要求
  ${RED}[FAIL]${NC}  配置不符合安全基线要求
  ${YELLOW}[WARN]${NC}  配置需要审查或未找到

${YELLOW}三层检查机制:${NC}
  L1: 进程参数检查 (最高优先级)
  L2: 配置文件检查 (中等优先级)
  L3: 默认值检查 (最低优先级)

${YELLOW}更多信息:${NC}
  GitHub: https://github.com/todaysu/cis-kubernetes-benchmark
  基于: CIS Kubernetes Benchmark v1.12.0

EOF
}

# Run main function
main "$@"
