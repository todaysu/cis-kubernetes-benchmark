# CIS Kubernetes Benchmark v1.12.0 审计脚本

<div align="center">

![Version](https://img.shields.io/badge/version-v1.3.0-blue.svg)
![CIS Benchmark](https://img.shields.io/badge/CIS-v1.12.0-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

**一个完整的 Kubernetes 安全基线审计工具，基于 CIS Kubernetes Benchmark v1.12.0 标准**

[功能特性](#功能特性) • [快速开始](#快速开始) • [输出过滤](#输出过滤) • [三层检查机制](#三层检查机制) • [检查项清单](#检查项清单) • [更新指南](#更新指南)

</div>

---

## 📋 目录

- [功能特性](#功能特性)
- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [三层检查机制](#三层检查机制)
- [检查项清单](#检查项清单)
- [输出说明](#输出说明)
- [更新指南](#更新指南)
- [常见问题](#常见问题)
- [贡献指南](#贡献指南)

---

## ✨ 功能特性

### 核心特性

- ✅ **完整的 CIS 覆盖** - 基于 CIS Kubernetes Benchmark v1.12.0 官方标准实现
- 🎯 **三层检查机制** - L1进程参数、L2配置文件、L3默认值，全面覆盖
- 🎨 **彩色输出** - 清晰的 PASS/FAIL/WARN 状态显示
- 📊 **统计报告** - 自动生成审计结果汇总
- 🔧 **易于扩展** - 模块化设计，方便添加新检查项
- 🌐 **跨平台支持** - 支持 Linux 和 macOS
- 🎛️ **输出过滤** - 灵活过滤 PASS/WARN/FAIL 结果，专注关注问题项

### 增强功能

- 🔍 **Container Runtime 检查** - 支持 Docker、Containerd、CRI-O
- 🛡️ **RBAC 最小权限检查** - 通配符使用、Secret 访问、Pod 创建权限
- 🔐 **Secrets 管理检查** - 环境变量中的 Secret 使用检测
- 🚦 **Pod Security Standards** - 支持新的 PSS（替代已弃用的 PSP）
- 🌐 **Network Policies** - 网络策略配置完整性检查
- 📝 **详细报告** - 每个检查项都标明配置来源（L1/L2/L3）
- 🔕 **安静模式** - 只显示汇总报告，适合自动化脚本

---

## 📜 版本历史

### v1.3.0 (2025-01-14)
- ✨ 新增输出过滤功能
  - `--only-pass`: 只显示 PASS 结果
  - `--only-warn`: 只显示 WARN 结果
  - `--only-fail`: 只显示 FAIL 结果
  - `--only-error`: 只显示 FAIL 和 WARN 结果
  - `--quiet`: 安静模式，只显示汇总报告
  - `--help`: 显示帮助信息
- 🔧 优化命令行参数解析
- 📝 添加完整的帮助文档

### v1.2.0
- 🔍 添加 Container Runtime 检查（Docker、Containerd、CRI-O）
- 🛡️ 增强 RBAC 最小权限检查
- 🔐 添加 Secrets 管理检查
- 🚦 添加 Pod Security Standards 支持
- 🌐 增强 Network Policies 检查

### v1.1.0
- 🎯 实现三层检查框架
- 📊 优化输出格式，显示配置来源层级

### v1.0.0
- 🎉 初始版本
- ✅ 基于 CIS Kubernetes Benchmark v1.12.0 实现

---

## 💻 系统要求

### 操作系统
- Linux (Ubuntu 20.04+, CentOS 7+, RHEL 7+)
- macOS 10.15+

### 软件依赖
- Bash 4.0+
- Kubernetes 1.20+ (被审计的集群)
- kubectl (用于集群级别的检查)
- jq (用于 JSON 解析，可选)

### 权限要求
```bash
# 需要root权限执行
sudo ./cis_kubernetes_benchmark.sh master
sudo ./cis_kubernetes_benchmark.sh worker
```

---

## 🚀 快速开始

### 1. 下载脚本

```bash
# 克隆仓库
git clone https://github.com/yourusername/cis-kubernetes-benchmark.git
cd cis-kubernetes-benchmark

# 或直接下载
wget https://raw.githubusercontent.com/yourusername/cis-kubernetes-benchmark/main/cis_kubernetes_benchmark.sh
chmod +x cis_kubernetes_benchmark.sh
```

### 2. 执行审计

```bash
# 审计 Master 节点（显示所有结果）
sudo ./cis_kubernetes_benchmark.sh master

# 审计 Worker 节点（显示所有结果）
sudo ./cis_kubernetes_benchmark.sh worker

# 只显示失败项
sudo ./cis_kubernetes_benchmark.sh master --only-fail

# 只显示警告项
sudo ./cis_kubernetes_benchmark.sh worker --only-warn

# 安静模式，只显示汇总
sudo ./cis_kubernetes_benchmark.sh master --quiet
```

### 3. 查看结果

脚本执行后会输出：
- 实时的检查结果（PASS/FAIL/WARN）
- 最终的统计汇总报告

```bash
=================================================
Audit Summary
=================================================
[PASS]: 85
[FAIL]: 3
[WARN]: 12
Total Checks: 100
```

---

## 🎛️ 输出过滤

v1.3.0 新增了强大的输出过滤功能，让你专注于关注的问题项。

### 过滤选项

| 选项 | 功能 | 使用场景 |
|------|------|----------|
| `--only-pass` | 只显示 PASS 结果 | 验证合规的配置项 |
| `--only-warn` | 只显示 WARN 结果 | 查看需要审查的配置 |
| `--only-fail` | 只显示 FAIL 结果 | 专注修复失败项 |
| `--only-error` | 只显示 FAIL 和 WARN | 查看所有问题项 |
| `--quiet`, `-q` | 安静模式 | 自动化脚本/CI/CD |
| `--help` | 显示帮助 | 查看使用说明 |

### 使用示例

```bash
# 只看失败项，快速定位问题
sudo ./cis_kubernetes_benchmark.sh master --only-fail

# 输出示例:
# === 输出过滤模式: 只显示 FAIL 结果 ===
#
# [FAIL] 1.2.6: bind-address=0.0.0.0, expected: 127.0.0.1 (L1: process)
# [FAIL] 4.2.1: Container runtime socket permissions are not 660
#
# ========================================
# Audit Summary
# ========================================
# [PASS]: 85
# [FAIL]: 2
# [WARN]: 12
# Total Checks: 99

# 只看警告项，了解潜在风险
sudo ./cis_kubernetes_benchmark.sh worker --only-warn

# 查看所有问题项（失败+警告）
sudo ./cis_kubernetes_benchmark.sh master --only-error

# 安静模式，适合自动化集成
sudo ./cis_kubernetes_benchmark.sh master --quiet
# 只输出汇总报告，不显示每个检查项

# 组合使用示例：定期安全扫描
# 0 2 * * * /path/to/cis_kubernetes_benchmark.sh master --quiet | mail -s "K8S Security Report" admin@example.com
```

### 输出对比

| 模式 | 输出内容 | 适用场景 |
|------|----------|----------|
| 默认模式 | 全部（PASS + FAIL + WARN） | 完整审计 |
| `--only-fail` | 仅 FAIL | 快速修复 |
| `--only-warn` | 仅 WARN | 风险评估 |
| `--only-error` | FAIL + WARN | 安全检查 |
| `--only-pass` | 仅 PASS | 合规验证 |
| `--quiet` | 仅汇总 | 自动化 |

---

## 🎯 三层检查机制

本脚本实现了独特的**三层检查机制**，确保全面覆盖所有配置来源：

### 检查流程图

```
┌─────────────────────────────────────────────────────────────┐
│                    三层检查流程                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ① L1 (Layer 1) - 进程参数检查                              │
│     ├─ 优先级: 最高                                           │
│     ├─ 检查对象: 运行中进程的实际启动参数                     │
│     ├─ 检查方法: ps aux | grep [component]                  │
│     ├─ 结果判定: 如果进程参数存在，直接判定并返回            │
│     └─ 未找到则进入 L2 层检查                                │
│                                                              │
│  ② L2 (Layer 2) - 配置文件检查                              │
│     ├─ 优先级: 中等                                           │
│     ├─ 检查对象: 配置文件中的持久化配置                       │
│     ├─ 检查方法: 读取 YAML/JSON 配置文件                     │
│     ├─ 结果判定: 如果配置文件中存在，直接判定并返回          │
│     └─ 未找到则进入 L3 层检查                                │
│                                                              │
│  ③ L3 (Layer 3) - 默认值检查                                │
│     ├─ 优先级: 最低                                           │
│     ├─ 检查对象: Kubernetes 组件的默认值                     │
│     ├─ 检查方法: 预定义的默认值表                            │
│     └─ 结果判定: 根据默认值判定                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 输出示例

```bash
# L1 层找到配置
[PASS] 1.2.1: anonymous-auth=false (L1: process)

# L2 层找到配置
[PASS] 1.2.6: bindAddress: 127.0.0.1 (L2: config)

# L3 层使用默认值
[PASS] 1.2.5: kubelet-https uses secure default: true (L3: default)

# 所有层都未找到
[WARN] 1.2.10: EventRateLimit not found in process, config, or defaults (NOT_FOUND)
```

### API 使用

```bash
# 基础用法
check_and_print_three_layer <check_id> <component> <param_name> <expected_value> [config_file] [default_value]

# 示例：检查 anonymous-auth 参数
check_and_print_three_layer \
    "1.2.1" \
    "apiserver" \
    "anonymous-auth" \
    "false" \
    "/etc/kubernetes/manifests/kube-apiserver.yaml" \
    "true"
```

---

## 📊 检查项清单

### Master 节点检查

#### Section 1.1 - 控制平面组件配置文件 (21项)

| ID | 检查项 | 描述 |
|----|--------|------|
| 1.1.1 | API Server Pod 规范文件权限 | 确保权限为 644 或更严格 |
| 1.1.2 | API Server Pod 规范文件所有权 | 确保为 root:root |
| 1.1.3 | Controller Manager Pod 规范文件权限 | 确保权限为 644 或更严格 |
| 1.1.4 | Controller Manager Pod 规范文件所有权 | 确保为 root:root |
| 1.1.5 | Scheduler Pod 规范文件权限 | 确保权限为 644 或更严格 |
| 1.1.6 | Scheduler Pod 规范文件所有权 | 确保为 root:root |
| 1.1.7 | etcd Pod 规范文件权限 | 确保权限为 644 或更严格 |
| 1.1.8 | etcd Pod 规范文件所有权 | 确保为 root:root |
| 1.1.9 | 网络配置文件权限 | 确保权限为 644 或更严格 |
| 1.1.10 | 网络配置文件所有权 | 确保为 root:root |
| 1.1.11 | 容器运行时 socket 文件权限 | 确保权限为 660 或更严格 |
| 1.1.12 | 容器运行时 socket 文件所有权 | 确保为 root:root 或 root:<runtime> |
| 1.1.13 | etcd 数据目录权限 | 确保权限为 700 或更严格 |
| 1.1.14 | etcd 数据目录所有权 | 确保为 etcd:etcd |
| 1.1.15 | admin.conf 文件权限 | 确保权限为 644 或更严格 |
| 1.1.16 | admin.conf 文件所有权 | 确保为 root:root |
| 1.1.17 | scheduler.conf 文件权限 | 确保权限为 644 或更严格 |
| 1.1.18 | scheduler.conf 文件所有权 | 确保为 root:root |
| 1.1.19 | controller-manager.conf 文件权限 | 确保权限为 644 或更严格 |
| 1.1.20 | controller-manager.conf 文件所有权 | 确保为 root:root |
| 1.1.21 | PKI 目录和文件所有权 | 确保为 root:root |

#### Section 1.2 - API Server 配置 (34+项)

| ID | 检查项 | 期望值 |
|----|--------|--------|
| 1.2.1 | anonymous-auth | false |
| 1.2.2 | token-auth-file | 未设置 |
| 1.2.3 | --authorization-mode | 非 AlwaysAllow |
| 1.2.4 | kubelet-client-certificate 和 kubelet-client-key | 已设置 |
| 1.2.5 | kubelet-https | true |
| 1.2.6 | bind-address | 127.0.0.1 |
| 1.2.7 | authorization-mode | 包含 Node |
| 1.2.8 | authorization-mode | 包含 RBAC |
| 1.2.9 | enable-admission-plugins | EventRateLimit |
| 1.2.10 | enable-admission-plugins | 非 AlwaysAdmit |
| 1.2.11 | audit-log-path | 已设置 |
| ... | ... | ... |

#### Section 1.3 - Controller Manager 配置 (7项)
#### Section 1.4 - Scheduler 配置 (2项)
#### Section 2 - etcd 配置 (7项)
#### Section 5 - Kubernetes 策略 (15+项)

### Worker 节点检查

#### Section 4.1 - Worker 节点配置文件 (8项)
#### Section 4.2 - Kubelet 配置 (22项)
#### Section 4.3 - Container Runtime 配置 (10项)

---

## 📖 输出说明

### 状态标识

| 状态 | 颜色 | 说明 |
|------|------|------|
| PASS | 🟢 绿色 | 配置符合安全基线要求 |
| FAIL | 🔴 红色 | 配置不符合安全基线要求 |
| WARN | 🟡 黄色 | 配置需要审查或未找到 |
| INFO | 🔵 蓝色 | 信息性输出 |

### 层级标识

| 标识 | 说明 |
|------|------|
| (L1: process) | 从运行时进程参数中找到配置 |
| (L2: config) | 从配置文件中找到配置 |
| (L3: default) | 使用组件默认值 |
| (NOT_FOUND) | 所有层都未找到配置 |

### 示例输出

```bash
=================================================
Section 1.2 - API Server Configuration
=================================================

[PASS] 1.2.1: anonymous-auth=false (L1: process)
[FAIL] 1.2.6: bind-address=0.0.0.0, expected: 127.0.0.1 (L1: process)
[WARN] 1.2.10: EventRateLimit not found in process, config, or defaults (NOT_FOUND)
[PASS] 1.2.5: kubelet-https uses secure default: true (L3: default)

=================================================
Audit Summary
=================================================
[PASS]: 85
[FAIL]: 3
[WARN]: 12
Total Checks: 100
```

---

## 🔄 更新指南

当 CIS 发布新版本 Benchmark 时，按以下步骤更新脚本：

### 更新流程

```bash
# 1. 下载最新版本文档
wget https://www.cisecurity.org/benchmark/kubernetes

# 2. 对比版本差异
diff cis_v1.12.0.pdf cis_v1.13.0.pdf

# 3. 更新脚本版本号
vim cis_kubernetes_benchmark.sh
# 修改: 基于 CIS Kubernetes Benchmark v1.13.0

# 4. 更新检查项
# - 在对应 Section 中添加新检查项
# - 修改已变更的检查项
# - 删除已废弃的检查项

# 5. 测试验证
sudo ./cis_kubernetes_benchmark.sh master
sudo ./cis_kubernetes_benchmark.sh worker

# 6. 更新文档
vim README.md
# 更新版本号、检查项清单等
```

### 添加新检查项模板

```bash
# 在对应的 Section 中添加新检查函数
check_X_Y_Z() {
    local check_id="X.Y.Z"
    local component="apiserver"  # 或其他组件
    local param_name="new-parameter"
    local expected_value="secure-value"
    local config_file="/path/to/config.yaml"
    local default_value="default-value"  # 可选

    check_and_print_three_layer \
        "$check_id" \
        "$component" \
        "$param_name" \
        "$expected_value" \
        "$config_file" \
        "$default_value"
}

# 在对应的 run_section_X_Y_checks 函数末尾调用
check_X_Y_Z
```

### 版本控制

```bash
# 创建新分支
git checkout -b update-to-v1.13.0

# 提交更改
git add cis_kubernetes_benchmark.sh README.md
git commit -m "更新到 CIS Kubernetes Benchmark v1.13.0"

# 推送并创建 PR
git push origin update-to-v1.13.0
```

---

## ❓ 常见问题

### Q1: 为什么某些检查显示 WARN？

**A:** WARN 状态可能由以下原因引起：
- 配置未在进程参数、配置文件和默认值中找到
- 使用了不安全的默认值
- 检查项需要人工审查

### Q2: 如何修复 FAIL 的检查项？

**A:** 根据输出中的层级信息进行修复：
- **L1**: 修改服务启动参数
- **L2**: 修改配置文件
- **L3**: 显式设置参数（不依赖默认值）

### Q3: 脚本可以在非 root 用户下运行吗？

**A:** 某些检查需要 root 权限，建议使用 sudo 运行。

### Q4: 如何导出检查结果？

**A:** 使用重定向将输出保存到文件：

```bash
sudo ./cis_kubernetes_benchmark.sh master 2>&1 | tee master_audit.log
```

### Q5: 支持 Kubernetes 哪些版本？

**A:** 本脚本基于 CIS v1.12.0，适用于 Kubernetes 1.20-1.25 版本。

---

## 🤝 贡献指南

欢迎贡献代码、报告问题或提出改进建议！

### 贡献流程

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 代码规范

- 遵循现有代码风格
- 添加详细的中文注释
- 更新相关文档
- 确保所有检查都有清晰的描述

---

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## 🙏 致谢

- [CIS (Center for Internet Security)](https://www.cisecurity.org/) - 提供 Kubernetes 安全基线标准
- Kubernetes 社区 - 提供优秀的容器编排平台
- 所有贡献者 - 持续改进本项目

---

## 📞 联系方式

- 项目主页: [https://github.com/yourusername/cis-kubernetes-benchmark](https://github.com/yourusername/cis-kubernetes-benchmark)
- 问题反馈: [GitHub Issues](https://github.com/yourusername/cis-kubernetes-benchmark/issues)
- 邮箱: your.email@example.com

---

<div align="center">

**如果这个项目对你有帮助，请给个 ⭐️ Star 支持！**

Made with ❤️ by Kubernetes Security Community

</div>
