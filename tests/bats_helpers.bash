#!/bin/bash
################################################################################
# BATS 测试辅助函数
# 用于提供 Mock 功能和测试工具
################################################################################

#--------------------------------------------------------------------------------
#  Mock 函数: 模拟命令输出
#--------------------------------------------------------------------------------

# Mock ps 命令输出
mock_ps() {
    local component=$1
    case "$component" in
        apiserver)
            echo "kube-apiserver --anonymous-auth=false --bind-address=127.0.0.1 --authorization-mode=Node,RBAC"
            ;;
        controller-manager)
            echo "kube-controller-manager --port=0 --secure-port=10257 --bind-address=127.0.0.1"
            ;;
        scheduler)
            echo "kube-scheduler --port=0 --secure-port=10259 --bind-address=127.0.0.1"
            ;;
        kubelet)
            echo "kubelet --anonymous-auth=false --read-only-port=0 --protect-kernel-defaults=true"
            ;;
        etcd)
            echo "etcd --client-cert-auth=true --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Mock kubectl 命令输出
mock_kubectl() {
    local args="$@"
    if [[ "$args" =~ "get nodes" ]]; then
        echo "NAME           STATUS   ROLES           AGE"
        echo "master-node    Ready    control-plane   10d"
        echo "worker-node1   Ready    <none>          5d"
        echo "worker-node2   Ready    <none>          3d"
    elif [[ "$args" =~ "get namespaces" ]]; then
        echo "default"
        echo "kube-system"
        echo "kube-public"
    elif [[ "$args" =~ "get networkpolicy" ]]; then
        # 返回空，表示没有 network policy
        return 0
    elif [[ "$args" =~ "get clusterroles" ]]; then
        echo "NAME"
        echo "cluster-admin"
        echo "admin"
        echo "edit"
        echo "view"
    elif [[ "$args" =~ "get clusterrolebindings" ]]; then
        echo "NAME"
        echo "cluster-admin-binding"
    elif [[ "$args" =~ "get psp" ]]; then
        # PSP 已废弃
        return 0
    else
        return 0
    fi
}

# Mock stat 命令输出 (macOS)
mock_stat_macos() {
    local file=$1
    local perms=$2
    local user=$3
    local group=$4

    case "$OSTYPE" in
        darwin*)
            echo "$perms"
            echo "$user"
            echo "$group"
            ;;
        *)
            echo "$perms"
            echo "$user"
            echo "$group"
            ;;
    esac
}

# Mock 文件存在检查
mock_file_exists() {
    local file=$1
    case "$file" in
        "/etc/kubernetes/manifests/kube-apiserver.yaml"|""/var/lib/kubelet/config.yaml"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

#--------------------------------------------------------------------------------
#  测试辅助函数
#--------------------------------------------------------------------------------

# 创建临时测试文件
create_test_file() {
    local file=$1
    local content=$2
    local perms=${3:-"644"}

    mkdir -p "$(dirname "$file")"
    echo "$content" > "$file"
    chmod "$perms" "$file"
}

# 创建临时测试目录
setup_test_env() {
    export TEST_TEMP_DIR=$(mktemp -d)
    export TEST_HOME="$TEST_TEMP_DIR/home"
    export TEST_ETC="$TEST_TEMP_DIR/etc"

    mkdir -p "$TEST_HOME"
    mkdir -p "$TEST_ETC/kubernetes"
    mkdir -p "$TEST_ETC/kubernetes/manifests"
    mkdir -p "$TEST_ETC/kubernetes/pki"
}

# 清理测试环境
teardown_test_env() {
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    unset TEST_TEMP_DIR
    unset TEST_HOME
    unset TEST_ETC
}

#--------------------------------------------------------------------------------
#  断言函数
#--------------------------------------------------------------------------------

# 断言包含
assert_contains() {
    local haystack="$1"
    local needle="$2"
    [[ "$haystack" == *"$needle"* ]] || {
        echo "Expected '$haystack' to contain '$needle'"
        return 1
    }
}

# 断言相等
assert_equals() {
    local expected="$1"
    local actual="$2"
    [[ "$expected" == "$actual" ]] || {
        echo "Expected '$expected', got '$actual'"
        return 1
    }
}

# 断言匹配正则
assert_match() {
    local string="$1"
    local pattern="$2"
    [[ "$string" =~ $pattern ]] || {
        echo "Expected '$string' to match '$pattern'"
        return 1
    }
}

# 断言命令成功
assert_success() {
    local status=$1
    local output=${2:-}
    [[ $status -eq 0 ]] || {
        echo "Command failed with status $status"
        [[ -n "$output" ]] && echo "Output: $output"
        return 1
    }
}

# 断言命令失败
assert_failure() {
    local status=$1
    [[ $status -ne 0 ]] || {
        echo "Expected command to fail, but it succeeded"
        return 1
    }
}

#--------------------------------------------------------------------------------
#  导出函数
#--------------------------------------------------------------------------------
export -f mock_ps mock_kubectl mock_stat_macos mock_file_exists
export -f create_test_file setup_test_env teardown_test_env
export -f assert_contains assert_equals assert_match assert_success assert_failure
