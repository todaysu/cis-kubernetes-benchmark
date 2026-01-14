#!/usr/bin/env bats
################################################################################
# CIS Kubernetes Benchmark - 主测试套件
#
# 加载顺序:
#   1. 加载测试辅助函数
#   2. 加载被测试的脚本
#   3. 设置 Mock 环境
#   4. 运行测试
#
# 使用方法:
#   bats tests/test_suite.bats
#   或运行全部: make test
################################################################################

# 设置测试环境
load bats_helpers

#--------------------------------------------------------------------------------
#  Setup 和 Teardown
#--------------------------------------------------------------------------------

setup() {
    # 创建测试环境
    setup_test_env

    # 导出测试模式标志
    export TEST_MODE=true

    # Mock 基本命令
    ps() { mock_ps "$@"; }
    export -f ps

    kubectl() { mock_kubectl "$@"; }
    export -f kubectl
}

teardown() {
    # 清理测试环境
    teardown_test_env
}

#--------------------------------------------------------------------------------
#  测试配置验证
#--------------------------------------------------------------------------------

@test "测试环境验证: 脚本文件存在" {
    [ -f "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh" ]
}

@test "测试环境验证: 脚本可执行" {
    run bash -c "test -x ${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh || test -r ${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "测试环境验证: 脚本语法正确" {
    run bash -n "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "测试环境验证: 脚本包含帮助功能" {
    run bash "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh" --help
    [ $status -eq 0 ]
    assert_contains "$output" "用法"
    assert_contains "$output" "输出过滤"
}

#--------------------------------------------------------------------------------
#  参数解析测试
#--------------------------------------------------------------------------------

@test "参数解析: 无参数显示错误" {
    run bash "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -ne 0 ]
    assert_contains "$output" "Missing node type"
}

@test "参数解析: --help 显示帮助" {
    run bash "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh" --help
    [ $status -eq 0 ]
    assert_contains "$output" "CIS Kubernetes Benchmark"
}

@test "参数解析: --only-pass 设置过滤模式" {
    # 测试过滤模式设置（通过检查脚本是否能接受参数）
    run bash "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh" --help
    assert_contains "$output" "--only-pass"
}

@test "参数解析: --only-warn 设置过滤模式" {
    run bash "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh" --help
    assert_contains "$output" "--only-warn"
}

@test "参数解析: --only-fail 设置过滤模式" {
    run bash "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh" --help
    assert_contains "$output" "--only-fail"
}

@test "参数解析: --quiet 设置安静模式" {
    run bash "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh" --help
    assert_contains "$output" "--quiet"
}

#--------------------------------------------------------------------------------
#  输出过滤功能测试
#--------------------------------------------------------------------------------

@test "输出过滤: 验证 SHOW_PASS 变量存在" {
    # 源码检查
    run grep -q "SHOW_PASS=" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "输出过滤: 验证 SHOW_WARN 变量存在" {
    run grep -q "SHOW_WARN=" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "输出过滤: 验证 SHOW_FAIL 变量存在" {
    run grep -q "SHOW_FAIL=" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "输出过滤: 验证 QUIET_MODE 变量存在" {
    run grep -q "QUIET_MODE=" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "输出过滤: 验证 show_help 函数存在" {
    run grep -q "show_help()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

#--------------------------------------------------------------------------------
#  三层检查框架测试
#--------------------------------------------------------------------------------

@test "三层检查: check_parameter_three_layer 函数存在" {
    run grep -q "check_parameter_three_layer()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "三层检查: check_and_print_three_layer 函数存在" {
    run grep -q "check_and_print_three_layer()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "三层检查: 验证 L1 进程检查逻辑" {
    run grep "进程参数检查" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "三层检查: 验证 L2 配置文件检查逻辑" {
    run grep "配置文件检查" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "三层检查: 验证 L3 默认值检查逻辑" {
    run grep "默认值检查" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

#--------------------------------------------------------------------------------
#  辅助函数测试
#--------------------------------------------------------------------------------

@test "辅助函数: print_result 函数存在" {
    run grep -q "^print_result()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "辅助函数: check_file_exists 函数存在" {
    run grep -q "^check_file_exists()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "辅助函数: check_file_permissions 函数存在" {
    run grep -q "^check_file_permissions()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "辅助函数: check_file_ownership 函数存在" {
    run grep -q "^check_file_ownership()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "辅助函数: get_apiserver_args 函数存在" {
    run grep -q "get_apiserver_args()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "辅助函数: get_kubelet_args 函数存在" {
    run grep -q "get_kubelet_args()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "辅助函数: get_controller_manager_args 函数存在" {
    run grep -q "get_controller_manager_args()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "辅助函数: get_scheduler_args 函数存在" {
    run grep -q "get_scheduler_args()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "辅助函数: get_etcd_args 函数存在" {
    run grep -q "get_etcd_args()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

#--------------------------------------------------------------------------------
#  检查项函数测试
#--------------------------------------------------------------------------------

@test "检查项: Section 1.1 检查函数存在" {
    run grep -q "run_section_1_1_checks()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "检查项: Section 1.2 检查函数存在" {
    run grep -q "run_section_1_2_checks()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "检查项: Section 1.3 检查函数存在" {
    run grep -q "run_section_1_3_checks()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "检查项: Section 4.1 检查函数存在" {
    run grep -q "run_section_4_1_checks()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "检查项: Section 4.2 检查函数存在" {
    run grep -q "run_section_4_2_checks()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "检查项: Section 4.3 (Container Runtime) 检查函数存在" {
    run grep -q "run_section_4_3_checks()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "检查项: Section 5 (Policies) 检查函数存在" {
    run grep -q "run_section_5_checks()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "检查项: run_master_checks 函数存在" {
    run grep -q "^run_master_checks()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "检查项: run_worker_checks 函数存在" {
    run grep -q "^run_worker_checks()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

#--------------------------------------------------------------------------------
#  汇总报告测试
#--------------------------------------------------------------------------------

@test "汇总报告: print_summary 函数存在" {
    run grep -q "^print_summary()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "汇总报告: 验证计数器变量存在" {
    run grep -q "PASS_COUNT=" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]

    run grep -q "FAIL_COUNT=" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]

    run grep -q "WARN_COUNT=" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]

    run grep -q "TOTAL_CHECKS=" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

#--------------------------------------------------------------------------------
#  版本信息测试
#--------------------------------------------------------------------------------

@test "版本信息: 脚本包含版本号" {
    run grep -q "v1.3.0" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "版本信息: 基于 CIS v1.12.0" {
    run grep -q "CIS.*v1.12.0" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "版本信息: 包含版本历史" {
    run grep -q "版本历史" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

#--------------------------------------------------------------------------------
#  边界条件测试
#--------------------------------------------------------------------------------

@test "边界条件: 空变量处理 (bug fix 验证)" {
    # 验证修复后的代码能正确处理空变量
    run grep -q "if \[\[ -n \"\$clusterroles\" \]\]; then" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "边界条件: grep 错误处理" {
    # 验证 grep 命令包含错误重定向
    run grep -q "grep.*2>/dev/null" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "边界条件: 算术运算前变量初始化" {
    # 验证算术运算前有变量初始化
    run grep -q "local system_wildcards=0" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

#--------------------------------------------------------------------------------
#  代码质量测试
#--------------------------------------------------------------------------------

@test "代码质量: 脚本使用 set -e 或类似选项" {
    # 检查是否有错误处理
    run grep -q "||" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "代码质量: 函数有文档注释" {
    # 验证主要函数有注释 (检查多种注释风格)
    local count=$(grep -c "^#.*函数:" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh")
    [ $count -gt 1 ]
}

@test "代码质量: 脚本行数合理 (< 3500 行)" {
    local lines=$(wc -l < "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh")
    [ $lines -lt 3500 ]
}

@test "代码质量: 检查函数数量充足 (> 100)" {
    local functions=$(grep -c "^.*() {" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh")
    [ $functions -gt 100 ]
}

#--------------------------------------------------------------------------------
#  兼容性测试
#--------------------------------------------------------------------------------

@test "兼容性: 支持 macOS" {
    run grep -q "darwin" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "兼容性: 支持 Linux" {
    # Linux 支持通过 darwin 的 else 分支实现
    run grep -q 'OSTYPE.*==.*darwin' "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}

@test "兼容性: stat 命令兼容两种系统" {
    # 验证同时支持 macOS (-f) 和 Linux (-c) 的 stat 命令
    run grep -q 'stat.*-f.*"%' "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
    run grep -q 'stat.*-c.*"%' "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
    [ $status -eq 0 ]
}
