# 测试框架文档

## 📋 目录

- [测试概述](#测试概述)
- [快速开始](#快速开始)
- [测试类型](#测试类型)
- [Mock 数据](#mock-数据)
- [CI/CD 集成](#cicd-集成)
- [编写测试](#编写测试)

---

## 🧪 测试概述

本测试框架使用 **BATS (Bash Automated Testing System)** 来测试 CIS Kubernetes Benchmark 审计脚本。

### 测试层次

```
tests/
├── unit/              # 单元测试 - 测试独立函数
├── integration/       # 集成测试 - 测试功能流程
├── mocks/             # Mock 数据生成器
├── fixtures/          # 静态测试数据
└── bats_helpers.bash  # 测试辅助函数
```

---

## 🚀 快速开始

### 安装依赖

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y bats shellcheck
```

#### macOS
```bash
brew install bats shellcheck
```

### 运行测试

#### 使用 Makefile（推荐）
```bash
# 运行所有测试
make test

# 只运行单元测试
make test-unit

# 只运行集成测试
make test-integration

# 详细模式
make test-verbose

# 完整检查（lint + test）
make ci
```

#### 直接使用 BATS
```bash
# 运行所有测试
bats tests/test_suite.bats

# 运行单元测试
bats tests/unit/unit_tests.bats

# 运行集成测试
bats tests/integration/integration_tests.bats
```

---

## 📊 测试类型

### 1. 单元测试 (Unit Tests)

**位置**: `tests/unit/unit_tests.bats`

**测试内容**:
- 文件检查函数（权限、所有权）
- 参数检查函数
- 输出过滤逻辑
- print_result 函数
- 颜色定义

**特点**:
- 不依赖外部服务
- 执行快速（< 1秒）
- 覆盖基础功能

**示例**:
```bash
# 运行单元测试
make test-unit

# 或使用 BATS
bats tests/unit/unit_tests.bats
```

### 2. 集成测试 (Integration Tests)

**位置**: `tests/integration/integration_tests.bats`

**测试内容**:
- 脚本加载和初始化
- 三层检查框架
- 完整的 Section 调用
- Mock 环境下的端到端测试

**特点**:
- 使用 Mock 数据
- 测试组件交互
- 模拟真实场景

**示例**:
```bash
# 运行集成测试
make test-integration

# 或使用 BATS
bats tests/integration/integration_tests.bats
```

### 3. 端到端测试 (E2E Tests)

**说明**: 需要真实的 Kubernetes 环境（Kind/Minikube）

**测试内容**:
- 在真实集群中运行脚本
- 验证实际输出
- 性能测试

**运行方式**:
```bash
# 1. 启动 Kind 集群
kind create cluster

# 2. 运行脚本
sudo ./cis_kubernetes_benchmark.sh master

# 3. 检查结果
echo $?  # 应该为 0（如果使用 --quiet）
```

---

## 🎭 Mock 数据

### 生成 Mock 数据

```bash
# 生成所有 Mock 数据
make mocks

# 或直接运行脚本
bash tests/mocks/create_mocks.sh
```

### Mock 数据结构

```
tests/mocks/
├── processes/          # Mock 进程输出
│   ├── apiserver_compliant.txt
│   ├── kubelet_compliant.txt
│   └── ...
├── kubectl/            # Mock kubectl 输出
│   ├── get_nodes.txt
│   ├── get_namespaces.txt
│   └── ...
├── configs/            # Mock 配置文件
│   ├── apiserver_compliant.yaml
│   ├── kubelet_compliant.yaml
│   └── ...
├── filesystem/         # Mock 文件系统
│   ├── etc/kubernetes/
│   ├── var/lib/kubelet/
│   └── ...
└── scenarios/          # 测试场景
    ├── compliant_cluster.sh
    ├── noncompliant_cluster.sh
    └── partially_compliant_cluster.sh
```

### 使用 Mock 数据

在测试中引用 Mock 数据：

```bash
@test "测试使用 Mock 进程数据" {
    # 读取 Mock 数据
    local mock_data="${BATS_TEST_DIRNAME}/../mocks/processes/apiserver_compliant.txt"

    # 使用 Mock 数据
    run cat "$mock_data"

    # 验证
    assert_contains "$output" "--anonymous-auth=false"
}
```

---

## 🔄 CI/CD 集成

### GitHub Actions

**配置文件**: `.github/workflows/ci.yml`

**工作流程**:
1. **代码质量检查** - ShellCheck + 语法检查
2. **单元测试** - 独立函数测试
3. **集成测试** - Mock 环境测试
4. **安全扫描** - Trivy 漏洞扫描
5. **性能测试** - 脚本大小、函数数量
6. **测试报告** - 生成汇总报告

**触发条件**:
- Push 到 main/develop 分支
- Pull Request
- 手动触发

### 本地 CI 模拟

```bash
# 模拟完整 CI 流程
make ci

# 这包括：
# 1. make lint      # ShellCheck 检查
# 2. make syntax    # 语法检查
# 3. make test-all  # 所有测试
```

---

## ✍️ 编写测试

### BATS 测试模板

```bash
#!/usr/bin/env bats
################################################################################
# 测试描述
################################################################################

load bats_helpers

setup() {
    # 每个测试前执行
    setup_test_env
}

teardown() {
    # 每个测试后执行
    teardown_test_env
}

@test "测试名称" {
    # Arrange - 准备测试数据
    local test_data="some value"

    # Act - 执行被测试的功能
    run bash -c "echo '$test_data'"

    # Assert - 验证结果
    [ $status -eq 0 ]
    assert_contains "$output" "some value"
}
```

### 常用断言

```bash
# 断言包含
assert_contains "$output" "expected text"

# 断言相等
assert_equals "expected" "$actual"

# 断言匹配正则
assert_match "$string" "regex_pattern"

# 断言命令成功
assert_success $status

# 断言命令失败
assert_failure $status

# 直接断言
[ $status -eq 0 ]
[ "$output" == "expected" ]
[[ "$output" =~ pattern ]]
```

### 最佳实践

1. **测试命名要清晰**
   ```bash
   @test "文件检查: check_file_permissions - 正确的权限" {
   ```

2. **使用 setup/teardown**
   ```bash
   setup() {
       # 准备测试环境
   }

   teardown() {
       # 清理测试环境
   }
   ```

3. **隔离测试**
   - 每个测试应该独立
   - 不依赖其他测试的执行顺序

4. **使用辅助函数**
   ```bash
   # 使用 bats_helpers.bash 中的辅助函数
   create_test_file "$path" "content" "600"
   setup_test_env
   teardown_test_env
   ```

5. **Mock 外部依赖**
   ```bash
   # Mock ps 命令
   ps() { mock_ps "$@"; }
   export -f ps
   ```

---

## 📈 测试覆盖率

### 查看覆盖率

```bash
# 生成覆盖率报告
make coverage

# 查看报告
cat build/coverage/coverage.md
```

### 提高覆盖率

1. **识别未测试的代码**
   ```bash
   # 查找没有测试的函数
   grep "^.*() {" cis_kubernetes_benchmark.sh | wc -l
   ```

2. **为边缘情况添加测试**
   ```bash
   @test "边界条件: 空变量处理" {
       # 测试空输入
   }
   ```

3. **添加错误处理测试**
   ```bash
   @test "错误处理: 文件不存在时的行为" {
       # 测试错误场景
   }
   ```

---

## 🐛 调试测试

### 启用详细输出

```bash
# BATS 详细模式
bats --verbose tests/unit/unit_tests.bats

# 打印变量
bats --trace tests/unit/unit_tests.bats
```

### 调试单个测试

```bash
# 只运行一个测试
bats --filter "测试名称" tests/unit/unit_tests.bats
```

### 调试辅助

```bash
# 在测试中打印调试信息
@test "测试名称" {
    echo "DEBUG: variable value = $variable" >&3
}
```

---

## 📚 相关资源

- [BATS 官方文档](https://bats-core.readthedocs.io/)
- [ShellCheck 文档](https://www.shellcheck.net/)
- [CIS Benchmark 官方](https://www.cisecurity.org/benchmark/kubernetes)

---

## 🤝 贡献指南

### 添加新测试

1. 在对应的目录创建测试文件
2. 使用现有的辅助函数和 Mock 数据
3. 确保测试独立且快速
4. 运行 `make ci` 验证
5. 提交 PR

### 测试命名规范

- 单元测试: `unit/<feature>_tests.bats`
- 集成测试: `integration/<feature>_tests.bats`
- 文件名使用小写和下划线

### 代码审查检查清单

- [ ] 所有测试通过
- [ ] ShellCheck 无警告
- [ ] 语法检查通过
- [ ] 新功能有对应的测试
- [ ] Mock 数据完整
