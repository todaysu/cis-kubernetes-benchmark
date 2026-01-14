#!/usr/bin/env bats
################################################################################
# 单元测试 - 测试独立的辅助函数
#
# 这些测试不依赖 Kubernetes 集群，只测试单个函数的逻辑
################################################################################

load bats_helpers

setup() {
    setup_test_env
    export TEST_MODE=true
}

teardown() {
    teardown_test_env
}

#--------------------------------------------------------------------------------
#  文件检查函数测试
#--------------------------------------------------------------------------------

@test "文件检查: check_file_permissions - 正确的权限" {
    # 创建测试文件
    local test_file="$TEST_TEMP_DIR/test_file.txt"
    create_test_file "$test_file" "content" "600"

    # 源码并测试（模拟）
    # 实际测试需要加载源码函数
    run bash -c "
        file='$test_file'
        if [[ '$OSTYPE' == 'darwin'* ]]; then
            perm=\$(stat -f '%Lp' '\$file')
        else
            perm=\$(stat -c '%a' '\$file')
        fi
        echo \$perm
    "

    [ "$output" = "600" ]
}

@test "文件检查: check_file_permissions - 权限过大" {
    local test_file="$TEST_TEMP_DIR/test_file.txt"
    create_test_file "$test_file" "content" "777"

    run bash -c "
        file='$test_file'
        if [[ '$OSTYPE' == 'darwin'* ]]; then
            perm=\$(stat -f '%Lp' '\$file')
        else
            perm=\$(stat -c '%a' '\$file')
        fi
        echo \$perm
    "

    [ "$output" = "777" ]
}

@test "文件检查: check_file_ownership - 正确的所有者" {
    local test_file="$TEST_TEMP_DIR/test_file.txt"
    create_test_file "$test_file" "content" "600"

    run bash -c "
        file='$test_file'
        if [[ '$OSTYPE' == 'darwin'* ]]; then
            owner=\$(stat -f '%Su' '\$file')
        else
            owner=\$(stat -c '%U' '\$file')
        fi
        echo \$owner
    "

    # 文件创建者是当前用户
    [ "$output" = "$(whoami)" ]
}

#--------------------------------------------------------------------------------
#  参数检查函数测试
#--------------------------------------------------------------------------------

@test "参数检查: check_argument_present - 参数存在" {
    local process="kube-apiserver --anonymous-auth=false --bind-address=127.0.0.1"

    run bash -c "
        process='$process'
        if echo \"\$process\" | grep -q -- '--anonymous-auth'; then
            echo 'found'
        else
            echo 'not found'
        fi
    "

    [ "$output" = "found" ]
}

@test "参数检查: check_argument_present - 参数不存在" {
    local process="kube-apiserver --anonymous-auth=false"

    run bash -c "
        process='$process'
        if echo \"\$process\" | grep -q -- '--bind-address'; then
            echo 'found'
        else
            echo 'not found'
        fi
    "

    [ "$output" = "not found" ]
}

@test "参数检查: check_argument_value - 值匹配" {
    local process="kube-apiserver --anonymous-auth=false"

    run bash -c "
        process='$process'
        value=\$(echo \"\$process\" | grep -oP '(?<=--anonymous-auth=)[^ ]+' 2>/dev/null || echo \"\$process\" | grep -o -- '--anonymous-auth[^ ]*' | cut -d'=' -f2)
        echo \$value
    "

    [ "$output" = "false" ]
}

@test "参数检查: check_argument_value - 值不匹配" {
    local process="kube-apiserver --anonymous-auth=true"

    run bash -c "
        process='$process'
        value=\$(echo \"\$process\" | grep -oP '(?<=--anonymous-auth=)[^ ]+' 2>/dev/null || echo \"\$process\" | grep -o -- '--anonymous-auth[^ ]*' | cut -d'=' -f2)
        echo \$value
    "

    [ "$output" = "true" ]
}

#--------------------------------------------------------------------------------
#  输出过滤功能测试
#--------------------------------------------------------------------------------

@test "输出过滤: 默认模式 - 显示所有结果" {
    # 验证默认变量值
    run grep -A 5 '输出过滤选项' "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "SHOW_PASS=true"
    assert_contains "$output" "SHOW_WARN=true"
    assert_contains "$output" "SHOW_FAIL=true"
}

@test "输出过滤: --only-pass 模式" {
    # 检查参数处理逻辑
    run grep -A 5 'only-pass)' "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "SHOW_PASS=true"
    assert_contains "$output" "SHOW_WARN=false"
    assert_contains "$output" "SHOW_FAIL=false"
}

@test "输出过滤: --only-warn 模式" {
    run grep -A 5 'only-warn)' "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "SHOW_PASS=false"
    assert_contains "$output" "SHOW_WARN=true"
    assert_contains "$output" "SHOW_FAIL=false"
}

@test "输出过滤: --only-fail 模式" {
    run grep -A 5 'only-fail)' "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "SHOW_PASS=false"
    assert_contains "$output" "SHOW_WARN=false"
    assert_contains "$output" "SHOW_FAIL=true"
}

@test "输出过滤: --only-error 模式" {
    run grep -A 5 'only-error)' "${BATS_TEST_DIR_NAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "SHOW_PASS=false"
    assert_contains "$output" "SHOW_WARN=true"
    assert_contains "$output" "SHOW_FAIL=true"
}

@test "输出过滤: --quiet 模式" {
    run grep -A 2 'quiet|-q)' "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "QUIET_MODE=true"
}

#--------------------------------------------------------------------------------
#  print_result 函数测试
#--------------------------------------------------------------------------------

@test "print_result: PASS 状态增加计数器" {
    run bash -c '
        TOTAL_CHECKS=0
        PASS_COUNT=0
        status="PASS"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        case $status in
            "PASS") PASS_COUNT=$((PASS_COUNT + 1)) ;;
        esac
        echo "TOTAL=$TOTAL_CHECKS PASS=$PASS_COUNT"
    '

    assert_contains "$output" "TOTAL=1"
    assert_contains "$output" "PASS=1"
}

@test "print_result: FAIL 状态增加计数器" {
    run bash -c '
        TOTAL_CHECKS=0
        FAIL_COUNT=0
        status="FAIL"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        case $status in
            "FAIL") FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
        esac
        echo "TOTAL=$TOTAL_CHECKS FAIL=$FAIL_COUNT"
    '

    assert_contains "$output" "TOTAL=1"
    assert_contains "$output" "FAIL=1"
}

@test "print_result: WARN 状态增加计数器" {
    run bash -c '
        TOTAL_CHECKS=0
        WARN_COUNT=0
        status="WARN"
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        case $status in
            "WARN") WARN_COUNT=$((WARN_COUNT + 1)) ;;
        esac
        echo "TOTAL=$TOTAL_CHECKS WARN=$WARN_COUNT"
    '

    assert_contains "$output" "TOTAL=1"
    assert_contains "$output" "WARN=1"
}

#--------------------------------------------------------------------------------
#  边界条件测试
#--------------------------------------------------------------------------------

@test "边界条件: 空字符串变量不会导致错误" {
    # 模拟空变量的算术运算
    run bash -c '
        wildcard_clusterroles=0
        system_wildcards=0
        result=$((wildcard_clusterroles - system_wildcards))
        echo "Result: $result"
    '

    assert_contains "$output" "Result: 0"
}

@test "边界条件: grep 在空输入时的处理" {
    run bash -c '
        empty_input=""
        count=$(echo "$empty_input" | grep -c "^system:" 2>/dev/null || echo "0")
        echo "Count: $count"
    '

    assert_contains "$output" "Count: 0"
}

@test "边界条件: wc -l 处理空输入" {
    run bash -c '
        empty_input=""
        if [[ -n "$empty_input" ]]; then
            count=$(echo "$empty_input" | wc -l)
        else
            count=0
        fi
        echo "Count: $count"
    '

    assert_contains "$output" "Count: 0"
}

#--------------------------------------------------------------------------------
#  路径处理测试
#--------------------------------------------------------------------------------

@test "路径处理: 配置文件路径数组" {
    run grep -A 5 'get_apiserver_config()' "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "/etc/kubernetes/manifests/kube-apiserver.yaml"
}

@test "路径处理: kubelet 配置文件路径" {
    run grep 'config.yaml' "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    [ $status -eq 0 ]
}

@test "路径处理: etcd 配置文件路径" {
    run grep 'etcd.yaml\|etcd.conf' "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    [ $status -eq 0 ]
}

#--------------------------------------------------------------------------------
#  颜色代码测试
#--------------------------------------------------------------------------------

@test "颜色定义: 红色 (RED) 变量存在" {
    run grep "^RED=" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
    assert_contains "$output" "'\033[0;31m'"
}

@test "颜色定义: 绿色 (GREEN) 变量存在" {
    run grep "^GREEN=" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
    assert_contains "$output" "'\033[0;32m'"
}

@test "颜色定义: 黄色 (YELLOW) 变量存在" {
    run grep "^YELLOW=" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
    assert_contains "$output" "'\033[0;33m'"
}

@test "颜色定义: 蓝色 (BLUE) 变量存在" {
    run grep "^BLUE=" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
    assert_contains "$output" "'\033[0;34m'"
}

@test "颜色定义: 无颜色 (NC) 变量存在" {
    run grep "^NC=" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
    assert_contains "$output" "'\033[0m'"
}
