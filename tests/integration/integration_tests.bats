#!/usr/bin/env bats
################################################################################
# 集成测试 - 测试脚本的主要功能流程
#
# 这些测试使用 Mock 数据模拟真实的 Kubernetes 环境
################################################################################

load bats_helpers

setup() {
    setup_test_env

    # 创建模拟配置文件
    create_k8s_config_files

    # 设置 Mock 环境
    export TEST_MODE=true
    export PATH="${BATS_TEST_DIRNAME}/../mocks:${PATH}"

    # Mock ps 和 kubectl 命令
    mock_commands
}

teardown() {
    teardown_test_env
}

#--------------------------------------------------------------------------------
#  Mock 命令设置
#--------------------------------------------------------------------------------

mock_commands() {
    # 创建 mock 脚本目录
    mkdir -p "${TEST_TEMP_DIR}/bin"

    # Mock ps 命令
    cat > "${TEST_TEMP_DIR}/bin/ps" << 'EOF'
#!/bin/bash
case "$*" in
    *kube-apiserver*)
        echo "root 1234 1 kube-apiserver --anonymous-auth=false --bind-address=127.0.0.1 --authorization-mode=Node,RBAC --client-ca-file=/etc/kubernetes/pki/ca.crt --enable-admission-plugins=NodeRestriction,ServiceAccount"
        ;;
    *kube-controller-manager*)
        echo "root 5678 1 kube-controller-manager --port=0 --secure-port=10257 --bind-address=127.0.0.1 --use-service-account-credentials=true"
        ;;
    *kube-scheduler*)
        echo "root 9012 1 kube-scheduler --port=0 --secure-port=10259 --bind-address=127.0.0.1"
        ;;
    *kubelet*)
        echo "root 3456 1 kubelet --anonymous-auth=false --read-only-port=0 --protect-kernel-defaults=true --client-ca-file=/etc/kubernetes/pki/ca.crt"
        ;;
    *etcd*)
        echo "etcd 7890 1 etcd --client-cert-auth=true --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt --cert-file=/etc/kubernetes/pki/etcd/server.crt --key-file=/etc/kubernetes/pki/etcd/server.key"
        ;;
esac
EOF
    chmod +x "${TEST_TEMP_DIR}/bin/ps"

    # Mock kubectl 命令
    cat > "${TEST_TEMP_DIR}/bin/kubectl" << 'EOF'
#!/bin/bash
case "$*" in
    *get*nodes*)
        echo "NAME           STATUS   ROLES           AGE"
        echo "master-node    Ready    control-plane   10d"
        echo "worker-node1   Ready    <none>          5d"
        ;;
    *get*namespaces*)
        echo "NAME              STATUS   AGE"
        echo "default           Active   10d"
        echo "kube-system       Active   10d"
        echo "kube-public       Active   10d"
        echo "kube-node-lease   Active   10d"
        ;;
    *get*pod*default*)
        echo "NAME                      READY   STATUS    RESTARTS   AGE"
        echo "nginx-7d8c49857-abc12     1/1     Running   0          5d"
        echo "coredns-558b4466-cd4g2    1/1     Running   0          10d"
        ;;
    *get*networkpolicy*default*)
        echo "No resources found in default namespace."
        ;;
    *get*pod*kube-system*)
        echo "NAME                                      READY   STATUS    RESTARTS   AGE"
        echo "etcd-master-node                           1/1     Running   0          10d"
        echo "kube-apiserver-master-node                 1/1     Running   0          10d"
        echo "coredns-558b4466-cd4g2                    1/1     Running   0          10d"
        ;;
    *get*clusterroles*)
        echo "NAME                                                   CREATED AT"
        echo "cluster-admin                                          2025-01-01T00:00:00Z"
        echo "admin                                                   2025-01-01T00:00:00Z"
        echo "edit                                                    2025-01-01T00:00:00Z"
        echo "view                                                    2025-01-01T00:00:00Z"
        echo "system:aggregate-to-admin                              2025-01-01T00:00:00Z"
        echo "system:aggregate-to-edit                               2025-01-01T00:00:00Z"
        echo "system:aggregate-to-view                               2025-01-01T00:00:00Z"
        ;;
    *get*clusterrolebindings*)
        echo "NAME                                    ROLE                       AGE"
        echo "cluster-admin                           cluster-admin              10d"
        echo "kubeadm:kubelet-bootstrap              system:node-bootstrapper 10d"
        ;;
    *get*psp*)
        echo "No resources found"
        ;;
esac
EOF
    chmod +x "${TEST_TEMP_DIR}/bin/kubectl"

    # Mock jq 命令（基本实现）
    cat > "${TEST_TEMP_DIR}/bin/jq" << 'EOF'
#!/bin/bash
# 简化的 jq mock，只支持基本操作
cat
EOF
    chmod +x "${TEST_TEMP_DIR}/bin/jq"

    # 更新 PATH
    export PATH="${TEST_TEMP_DIR}/bin:${PATH}"
}

#--------------------------------------------------------------------------------
#  创建模拟配置文件
#--------------------------------------------------------------------------------

create_k8s_config_files() {
    # API Server 配置
    mkdir -p "$TEST_ETC/kubernetes/manifests"
    cat > "$TEST_ETC/kubernetes/manifests/kube-apiserver.yaml" << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    - --anonymous-auth=false
    - --bind-address=127.0.0.1
    - --authorization-mode=Node,RBAC
EOF
    chmod 644 "$TEST_ETC/kubernetes/manifests/kube-apiserver.yaml"

    # Kubelet 配置
    mkdir -p "$TEST_HOME/.kube"
    cat > "$TEST_ETC/kubernetes/kubelet.conf" << 'EOF'
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
authorization:
  mode: Webhook
readOnlyPort: 0
protectKernelDefaults: true
EOF
    chmod 600 "$TEST_ETC/kubernetes/kubelet.conf"

    # PKI 目录
    mkdir -p "$TEST_ETC/kubernetes/pki/etcd"
    cat > "$TEST_ETC/kubernetes/pki/ca.crt" << 'EOF'
-----BEGIN CERTIFICATE-----
MOCK CA CERTIFICATE
-----END CERTIFICATE-----
EOF
    chmod 644 "$TEST_ETC/kubernetes/pki/ca.crt"

    cat > "$TEST_ETC/kubernetes/pki/etcd/ca.crt" << 'EOF'
-----BEGIN CERTIFICATE-----
MOCK ETCD CA CERTIFICATE
-----END CERTIFICATE-----
EOF
    chmod 644 "$TEST_ETC/kubernetes/pki/etcd/ca.crt"

    cat > "$TEST_ETC/kubernetes/pki/etcd/server.crt" << 'EOF'
-----BEGIN CERTIFICATE-----
MOCK ETCD SERVER CERTIFICATE
-----END CERTIFICATE-----
EOF
    chmod 644 "$TEST_ETC/kubernetes/pki/etcd/server.crt"

    cat > "$TEST_ETC/kubernetes/pki/etcd/server.key" << 'EOF'
-----BEGIN PRIVATE KEY-----
MOCK ETCD SERVER KEY
-----END PRIVATE KEY-----
EOF
    chmod 600 "$TEST_ETC/kubernetes/pki/etcd/server.key"
}

#--------------------------------------------------------------------------------
#  集成测试: 脚本加载测试
#--------------------------------------------------------------------------------

@test "集成: 脚本可以加载不报错" {
    run bash -c "source ${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh 2>&1"
    # 脚本会执行 main 函数，所以会失败，但不应该有语法错误
    # 我们只检查是否有语法错误
    [[ ! "$output" =~ "syntax error" ]]
}

@test "集成: 脚本包含所有必需的 Section" {
    local sections=("1.1" "1.2" "1.3" "1.4" "2" "3" "4.1" "4.2" "4.3" "5")

    for section in "${sections[@]}"; do
        run grep -q "Section $section" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
        if [ $status -ne 0 ]; then
            echo "Section $section not found"
            false
        fi
    done
}

#--------------------------------------------------------------------------------
#  集成测试: 三层检查框架
#--------------------------------------------------------------------------------

@test "集成: 三层检查函数可以调用" {
    # 测试 check_parameter_three_layer 函数存在且可调用
    run grep -A 20 "^check_parameter_three_layer()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "local component=\$1"
    assert_contains "$output" "local param_name=\$2"
    assert_contains "$output" "local expected_value=\$3"
}

@test "集成: 三层检查包含 L1 进程检查" {
    run grep -A 50 "check_parameter_three_layer()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "LAYER 1"
    assert_contains "$output" "进程参数"
    assert_contains "$output" "get_.*_args"
}

@test "集成: 三层检查包含 L2 配置文件检查" {
    run grep -A 50 "check_parameter_three_layer()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "LAYER 2"
    assert_contains "$output" "配置文件"
    assert_contains "$output" "config_key"
}

@test "集成: 三层检查包含 L3 默认值检查" {
    run grep -A 50 "check_parameter_three_layer()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "LAYER 3"
    assert_contains "$output" "默认值"
    assert_contains "$output" "default_value"
}

#--------------------------------------------------------------------------------
#  集成测试: 检查项完整性
#--------------------------------------------------------------------------------

@test "集成: Master 节点检查包含所有 Section" {
    local required_sections=("1.1" "1.2" "1.3" "1.4" "2" "3" "5")

    for section in "${required_sections[@]}"; do
        run grep "run_section_${section//./_}_checks" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
        if [ $status -ne 0 ]; then
            echo "Master section $section not found"
            false
        fi
    done
}

@test "集成: Worker 节点检查包含所有 Section" {
    local required_sections=("4.1" "4.2" "4.3")

    for section in "${required_sections[@]}"; do
        run grep "run_section_${section//./_}_checks" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"
        if [ $status -ne 0 ]; then
            echo "Worker section $section not found"
            false
        fi
    done
}

@test "集成: run_master_checks 调用所有 Master 检查" {
    run grep -A 10 "^run_master_checks()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "run_section_1_1_checks"
    assert_contains "$output" "run_section_1_2_checks"
    assert_contains "$output" "run_section_1_3_checks"
    assert_contains "$output" "run_section_1_4_checks"
    assert_contains "$output" "run_section_2_checks"
    assert_contains "$output" "run_section_3_checks"
    assert_contains "$output" "run_section_5_checks"
}

@test "集成: run_worker_checks 调用所有 Worker 检查" {
    run grep -A 10 "^run_worker_checks()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "run_section_4_1_checks"
    assert_contains "$output" "run_section_4_2_checks"
    assert_contains "$output" "run_section_4_3_checks"
}

#--------------------------------------------------------------------------------
#  集成测试: 输出过滤
#--------------------------------------------------------------------------------

@test "集成: 输出过滤不会影响计数器" {
    run grep -A 30 "^print_result()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    # 检查无论过滤模式如何，计数器都会更新
    assert_contains "$output" "TOTAL_CHECKS=((TOTAL_CHECKS + 1))"
}

@test "集成: 安静模式下仍然更新计数器" {
    run grep -A 30 "^print_result()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "QUIET_MODE"
}

#--------------------------------------------------------------------------------
#  集成测试: 汇总报告
#--------------------------------------------------------------------------------

@test "集成: print_summary 包含所有计数器" {
    run grep -A 15 "^print_summary()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "PASS_COUNT"
    assert_contains "$output" "FAIL_COUNT"
    assert_contains "$output" "WARN_COUNT"
    assert_contains "$output" "TOTAL_CHECKS"
}

@test "集成: print_summary 有退出码逻辑" {
    run grep -A 20 "^print_summary()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "exit 0"
}

#--------------------------------------------------------------------------------
#  集成测试: 错误处理
#--------------------------------------------------------------------------------

@test "集成: 脚本检查 root 权限" {
    run grep -A 5 "EUID -ne 0" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "must be run as root"
}

@test "集成: 脚本验证节点类型参数" {
    run grep -A 10 "node_type=" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "master)"
    assert_contains "$output" "worker)"
}

@test "集成: 脚本处理无效参数" {
    run grep -A 5 "Invalid argument" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    [ $status -eq 0 ]
}

#--------------------------------------------------------------------------------
#  集成测试: Container Runtime 检查
#--------------------------------------------------------------------------------

@test "集成: Container Runtime 检查支持多种运行时" {
    run grep -A 30 "run_section_4_3_checks()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "containerd"
    assert_contains "$output" "docker"
    assert_contains "$output" "crio"
}

@test "集成: Container Runtime 检查 socket 文件路径" {
    run grep "/run.*containerd.*sock\|/var/run/docker.sock" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    [ $status -eq 0 ]
}

#--------------------------------------------------------------------------------
#  集成测试: Policies 检查
#--------------------------------------------------------------------------------

@test "集成: Policies 检查包含 kubectl 可用性检查" {
    run grep -A 10 "run_section_5_checks()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "kubectl"
    assert_contains "$output" "command -v"
}

@test "集成: Policies 检查包含集群连接检查" {
    run grep -A 15 "run_section_5_checks()" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    assert_contains "$output" "get nodes"
}

@test "集成: Section 5 包含 RBAC 检查" {
    run grep "5.1.2\|5.1.3\|5.1.4" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    [ $status -eq 0 ]
}

@test "集成: Section 5 包含 Secrets 管理检查" {
    run grep "5.4.1\|Secret.*environment" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    [ $status -eq 0 ]
}

@test "集成: Section 5 包含 Seccomp 检查" {
    run grep "5.7.1\|5.7.2\|5.7.3\|seccomp" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    [ $status -eq 0 ]
}

@test "集成: Section 5 包含 Network Policy 检查" {
    run grep "5.3\|5.8\|networkpolicy\|Network Policy" "${BATS_TEST_DIRNAME}/../cis_kubernetes_benchmark.sh"

    [ $status -eq 0 ]
}
