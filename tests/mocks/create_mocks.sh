#!/bin/bash
################################################################################
# Mock 数据生成脚本
# 用于生成测试所需的模拟 Kubernetes 配置和进程数据
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MOCK_DIR="$PROJECT_DIR/tests/mocks"

#--------------------------------------------------------------------------------
#  Mock 进程数据
#--------------------------------------------------------------------------------

create_mock_process_data() {
    mkdir -p "$MOCK_DIR/processes"

    # API Server 进程 - 合规配置
    cat > "$MOCK_DIR/processes/apiserver_compliant.txt" << 'EOF'
root 1234 1 kube-apiserver --anonymous-auth=false --bind-address=127.0.0.1 --authorization-mode=Node,RBAC --enable-admission-plugins=NodeRestriction,ServiceAccount --client-ca-file=/etc/kubernetes/pki/ca.crt --enable-bootstrap-token-auth=true --token-auth-file=
EOF

    # API Server 进程 - 不合规配置
    cat > "$MOCK_DIR/processes/apiserver_noncompliant.txt" << 'EOF'
root 1234 1 kube-apiserver --anonymous-auth=true --bind-address=0.0.0.0 --authorization-mode=AlwaysAllow
EOF

    # Kubelet 进程 - 合规配置
    cat > "$MOCK_DIR/processes/kubelet_compliant.txt" << 'EOF'
root 3456 1 kubelet --anonymous-auth=false --read-only-port=0 --protect-kernel-defaults=true --client-ca-file=/etc/kubernetes/pki/ca.crt --authorization-mode=Webhook
EOF

    # Kubelet 进程 - 不合规配置
    cat > "$MOCK_DIR/processes/kubelet_noncompliant.txt" << 'EOF'
root 3456 1 kubelet --anonymous-auth=true --read-only-port=10255 --protect-kernel-defaults=false
EOF

    # Controller Manager 进程
    cat > "$MOCK_DIR/processes/controller_manager.txt" << 'EOF'
root 5678 1 kube-controller-manager --port=0 --secure-port=10257 --bind-address=127.0.0.1 --use-service-account-credentials=true --allocate-node-cidrs=true --authentication-kubeconfig=/etc/kubernetes/controller-manager.conf --authorization-kubeconfig=/etc/kubernetes/controller-manager.conf
EOF

    # Scheduler 进程
    cat > "$MOCK_DIR/processes/scheduler.txt" << 'EOF'
root 9012 1 kube-scheduler --port=0 --secure-port=10259 --bind-address=127.0.0.1 --authentication-kubeconfig=/etc/kubernetes/scheduler.conf --authorization-kubeconfig=/etc/kubernetes/scheduler.conf
EOF

    # etcd 进程
    cat > "$MOCK_DIR/processes/etcd.txt" << 'EOF'
etcd 7890 1 etcd --name=master-node --data-dir=/var/lib/etcd --listen-client-urls=https://127.0.0.1:2379 --advertise-client-urls=https://127.0.0.1:2379 --client-cert-auth=true --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt --cert-file=/etc/kubernetes/pki/etcd/server.crt --key-file=/etc/kubernetes/pki/etcd/server.key --peer-client-cert-auth=true --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt --peer-key-file=/etc/kubernetes/pki/etcd/peer.key
EOF
}

#--------------------------------------------------------------------------------
#  Mock kubectl 输出
#--------------------------------------------------------------------------------

create_mock_kubectl_data() {
    mkdir -p "$MOCK_DIR/kubectl"

    # kubectl get nodes
    cat > "$MOCK_DIR/kubectl/get_nodes.txt" << 'EOF'
NAME           STATUS   ROLES           AGE   VERSION
master-node    Ready    control-plane   10d   v1.25.0
worker-node1   Ready    <none>          5d    v1.25.0
worker-node2   Ready    <none>          3d    v1.25.0
EOF

    # kubectl get namespaces
    cat > "$MOCK_DIR/kubectl/get_namespaces.txt" << 'EOF'
NAME              STATUS   AGE
default           Active   10d
kube-system       Active   10d
kube-public       Active   10d
kube-node-lease   Active   10d
EOF

    # kubectl get pods -A
    cat > "$MOCK_DIR/kubectl/get_pods_all.txt" << 'EOF'
NAMESPACE       NAME                                      READY   STATUS    RESTARTS   AGE
default         nginx-7d8c49857-abc12                     1/1     Running   0          5d
kube-system     etcd-master-node                          1/1     Running   0          10d
kube-system     kube-apiserver-master-node                1/1     Running   0          10d
kube-system     kube-controller-manager-master-node       1/1     Running   0          10d
kube-system     kube-scheduler-master-node                1/1     Running   0          10d
kube-system     coredns-558b4466-cd4g2                    1/1     Running   0          10d
EOF

    # kubectl get clusterroles
    cat > "$MOCK_DIR/kubectl/get_clusterroles.txt" << 'EOF'
NAME                                                   CREATED AT
admin                                                  2025-01-01T00:00:00Z
cluster-admin                                          2025-01-01T00:00:00Z
edit                                                   2025-01-01T00:00:00Z
view                                                   2025-01-01T00:00:00Z
system:aggregate-to-admin                             2025-01-01T00:00:00Z
system:aggregate-to-edit                              2025-01-01T00:00:00Z
system:aggregate-to-view                              2025-01-01T00:00:00Z
system:controller:attachdetach-controller              2025-01-01T00:00:00Z
system:controller:clusterrole-aggregation-controller   2025-01-01T00:00:00Z
EOF

    # kubectl get clusterrolebindings
    cat > "$MOCK_DIR/kubectl/get_clusterrolebindings.txt" << 'EOF'
NAME                                    ROLE                      AGE
cluster-admin                           cluster-admin              10d
kubeadm:kubelet-bootstrap              system:node-bootstrapper  10d
kubeadm:node-autoapprove-bootstrap    system:node-bootstrapper  10d
kubeadm:node-autoapprove-certificate-rotation   system:node-bootstrapper  10d
EOF

    # kubectl get networkpolicies -A
    cat > "$MOCK_DIR/kubectl/get_networkpolicies.txt" << 'EOF'
NAMESPACE   NAME        POD-SELECTOR   AGE
production  deny-all    <none>          5d
EOF

    # kubectl get pods -n default -o json
    cat > "$MOCK_DIR/kubectl/get_pods_default.json" << 'EOF'
{
  "apiVersion": "v1",
  "items": [
    {
      "metadata": {
        "name": "nginx-7d8c49857-abc12",
        "namespace": "default"
      },
      "spec": {
        "containers": [
          {
            "name": "nginx",
            "image": "nginx:1.21"
          }
        ]
      }
    }
  ]
}
EOF
}

#--------------------------------------------------------------------------------
#  Mock 配置文件
#--------------------------------------------------------------------------------

create_mock_config_files() {
    mkdir -p "$MOCK_DIR/configs"

    # kube-apiserver.yaml (合规)
    cat > "$MOCK_DIR/configs/apiserver_compliant.yaml" << 'EOF'
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
    - --enable-admission-plugins=NodeRestriction,ServiceAccount
    volumeMounts:
    - name: k8s-certs
      mountPath: /etc/kubernetes/pki
  volumes:
  - name: k8s-certs
    hostPath:
      path: /etc/kubernetes/pki
EOF

    # kube-apiserver.yaml (不合规)
    cat > "$MOCK_DIR/configs/apiserver_noncompliant.yaml" << 'EOF'
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
    - --anonymous-auth=true
    - --bind-address=0.0.0.0
    - --authorization-mode=AlwaysAllow
EOF

    # kubelet config.yaml (合规)
    cat > "$MOCK_DIR/configs/kubelet_compliant.yaml" << 'EOF'
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
readOnlyPort: 0
protectKernelDefaults: true
tlsCertFile: /etc/kubernetes/pki/kubelet.crt
tlsPrivateKeyFile: /etc/kubernetes/pki/kubelet.key
clusterDNS:
- 10.96.0.10
clusterDomain: cluster.local
cgroupDriver: systemd
EOF

    # kubelet config.yaml (不合规)
    cat > "$MOCK_DIR/configs/kubelet_noncompliant.yaml" << 'EOF'
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: true
authorization:
  mode: AlwaysAllow
readOnlyPort: 10255
protectKernelDefaults: false
EOF

    # etcd.conf (合规)
    cat > "$MOCK_DIR/configs/etcd_compliant.conf" << 'EOF'
# [Member]
ETCD_NAME=master-node
ETCD_DATA_DIR=/var/lib/etcd
ETCD_LISTEN_CLIENT_URLS=https://127.0.0.1:2379
ETCD_ADVERTISE_CLIENT_URLS=https://127.0.0.1:2379

# [Clustering]
ETCD_INITIAL_CLUSTER=master-node=https://127.0.0.1:2380
ETCD_INITIAL_CLUSTER_STATE=existing

# [Security]
ETCD_CERT_FILE=/etc/kubernetes/pki/etcd/server.crt
ETCD_KEY_FILE=/etc/kubernetes/pki/etcd/server.key
ETCD_CLIENT_CERT_AUTH=true
ETCD_TRUSTED_CA_FILE=/etc/kubernetes/pki/etcd/ca.crt
ETCD_AUTO_TLS=false

# [Peer]
ETCD_PEER_CERT_FILE=/etc/kubernetes/pki/etcd/peer.crt
ETCD_PEER_KEY_FILE=/etc/kubernetes/pki/etcd/peer.key
ETCD_PEER_CLIENT_CERT_AUTH=true
ETCD_PEER_TRUSTED_CA_FILE=/etc/kubernetes/pki/etcd/ca.crt
EOF
}

#--------------------------------------------------------------------------------
#  Mock 文件系统
#--------------------------------------------------------------------------------

create_mock_filesystem() {
    mkdir -p "$MOCK_DIR/filesystem"

    # 创建脚本中用到的各种文件路径
    local paths=(
        "/etc/kubernetes/manifests/kube-apiserver.yaml:644:root:root"
        "/etc/kubernetes/manifests/kube-controller-manager.yaml:644:root:root"
        "/etc/kubernetes/manifests/kube-scheduler.yaml:644:root:root"
        "/etc/kubernetes/manifests/etcd.yaml:644:root:root"
        "/etc/kubernetes/admin.conf:640:root:root"
        "/etc/kubernetes/controller-manager.conf:640:root:root"
        "/etc/kubernetes/scheduler.conf:640:root:root"
        "/var/lib/kubelet/config.yaml:644:root:root"
        "/etc/systemd/system/kubelet.service.d/10-kubeadm.conf:644:root:root"
        "/run/containerd/containerd.sock:660:root:root"
        "/var/run/docker.sock:660:root:root"
        "/etc/kubernetes/pki/ca.crt:644:root:root"
        "/etc/kubernetes/pki/etcd/ca.crt:644:root:root"
        "/etc/kubernetes/pki/etcd/server.crt:600:root:root"
        "/etc/kubernetes/pki/etcd/server.key:600:root:root"
        "/var/lib/etcd:700:etcd:etcd"
    )

    for path_spec in "${paths[@]}"; do
        IFS=':' read -r path perm user group <<< "$path_spec"
        local full_path="$MOCK_DIR/filesystem$path"
        mkdir -p "$(dirname "$full_path")"
        echo "mock content" > "$full_path"
        chmod "$perm" "$full_path"
    done
}

#--------------------------------------------------------------------------------
#  测试场景数据
#--------------------------------------------------------------------------------

create_test_scenarios() {
    mkdir -p "$MOCK_DIR/scenarios"

    # 场景1: 完全合规的集群
    cat > "$MOCK_DIR/scenarios/compliant_cluster.sh" << 'EOF'
#!/bin/bash
# 完全合规的 Kubernetes 集群场景
# 所有检查都应该 PASS

export MOCK_SCENARIO="compliant"
export MOCK_APISERVER_ARGS="--anonymous-auth=false --bind-address=127.0.0.1 --authorization-mode=Node,RBAC"
export MOCK_KUBELET_ARGS="--anonymous-auth=false --read-only-port=0 --protect-kernel-defaults=true"
EOF

    # 场景2: 不合规的集群
    cat > "$MOCK_DIR/scenarios/noncompliant_cluster.sh" << 'EOF'
#!/bin/bash
# 不合规的 Kubernetes 集群场景
# 大部分检查应该 FAIL

export MOCK_SCENARIO="noncompliant"
export MOCK_APISERVER_ARGS="--anonymous-auth=true --bind-address=0.0.0.0 --authorization-mode=AlwaysAllow"
export MOCK_KUBELET_ARGS="--anonymous-auth=true --read-only-port=10255"
EOF

    # 场景3: 部分合规的集群
    cat > "$MOCK_DIR/scenarios/partially_compliant_cluster.sh" << 'EOF'
#!/bin/bash
# 部分合规的 Kubernetes 集群场景
# 混合 PASS, FAIL, WARN 结果

export MOCK_SCENARIO="partially_compliant"
export MOCK_APISERVER_ARGS="--anonymous-auth=false --bind-address=0.0.0.0 --authorization-mode=Node,RBAC"
export MOCK_KUBELET_ARGS="--anonymous-auth=false --read-only-port=0"
EOF
}

#--------------------------------------------------------------------------------
#  执行创建
#--------------------------------------------------------------------------------

main() {
    echo "Creating mock data for testing..."
    echo ""

    echo "1. Creating mock process data..."
    create_mock_process_data

    echo "2. Creating mock kubectl data..."
    create_mock_kubectl_data

    echo "3. Creating mock config files..."
    create_mock_config_files

    echo "4. Creating mock filesystem..."
    create_mock_filesystem

    echo "5. Creating test scenarios..."
    create_test_scenarios

    echo ""
    echo "Mock data created successfully!"
    echo "Location: $MOCK_DIR"
    echo ""
    echo "Directory structure:"
    tree "$MOCK_DIR" 2>/dev/null || find "$MOCK_DIR" -type d | sort
}

# 执行主函数
main "$@"
