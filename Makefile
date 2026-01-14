.PHONY: help test test-unit test-integration test-all lint clean install-deps coverage

# 默认目标
.DEFAULT_GOAL := help

# 颜色定义
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
NC     := \033[0m

# 目录
SCRIPT_DIR    := $(shell pwd)
TEST_DIR      := $(SCRIPT_DIR)/tests
BUILD_DIR     := $(SCRIPT_DIR)/build
COVERAGE_DIR  := $(BUILD_DIR)/coverage

################################################################################

##@ Helpers

help: ## 显示帮助信息
	@echo "$(BLUE)CIS Kubernetes Benchmark - Makefile$(NC)"
	@echo ""
	@echo "$(GREEN)可用命令:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

################################################################################

##@ 开发环境

install-deps: ## 安装测试依赖
	@echo "$(BLUE)安装测试依赖...$(NC)"
	@if command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get update && sudo apt-get install -y bats shellcheck; \
	elif command -v brew >/dev/null 2>&1; then \
		brew install bats-shellcheck; \
	else \
		echo "$(YELLOW)请手动安装 BATS 和 ShellCheck$(NC)"; \
		echo "  Ubuntu/Debian: sudo apt-get install bats shellcheck"; \
		echo "  macOS: brew install bats shellcheck"; \
	fi

setup: install-deps ## 设置开发环境
	@echo "$(BLUE)设置开发环境...$(NC)"
	@chmod +x cis_kubernetes_benchmark.sh
	@chmod +x tests/mocks/create_mocks.sh
	@mkdir -p $(BUILD_DIR) $(COVERAGE_DIR)
	@echo "$(GREEN)开发环境设置完成!$(NC)"

################################################################################

##@ 代码检查

lint: ## 运行 ShellCheck 检查
	@echo "$(BLUE)运行 ShellCheck...$(NC)"
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x cis_kubernetes_benchmark.sh; \
		echo "$(GREEN)ShellCheck 检查通过!$(NC)"; \
	else \
		echo "$(YELLOW)ShellCheck 未安装，跳过检查$(NC)"; \
	fi

syntax: ## 检查脚本语法
	@echo "$(BLUE)检查脚本语法...$(NC)"
	@bash -n cis_kubernetes_benchmark.sh
	@echo "$(GREEN)语法检查通过!$(NC)"

check: lint syntax ## 运行所有检查

################################################################################

##@ 测试

test-unit: ## 运行单元测试
	@echo "$(BLUE)运行单元测试...$(NC)"
	@if command -v bats >/dev/null 2>&1; then \
		bats $(TEST_DIR)/unit/unit_tests.bats; \
	else \
		echo "$(YELLOW)BATS 未安装，尝试使用 bash 直接运行...$(NC)"; \
		bash $(TEST_DIR)/unit/unit_tests.bats; \
	fi

test-integration: ## 运行集成测试
	@echo "$(BLUE)运行集成测试...$(NC)"
	@if command -v bats >/dev/null 2>&1; then \
		bats $(TEST_DIR)/integration/integration_tests.bats; \
	else \
		bash $(TEST_DIR)/integration/integration_tests.bats; \
	fi

test-all: ## 运行所有测试
	@echo "$(BLUE)运行所有测试...$(NC)"
	@$(MAKE) -s test-unit
	@echo ""
	@$(MAKE) -s test-integration

test: test-unit ## 运行测试（单元测试）

test-verbose: ## 详细模式运行测试
	@echo "$(BLUE)详细模式运行测试...$(NC)"
	@if command -v bats >/dev/null 2>&1; then \
		bats --verbose $(TEST_DIR)/unit/unit_tests.bats; \
	else \
		bash $(TEST_DIR)/unit/unit_tests.bats; \
	fi

test-watch: ## 监视模式运行测试（需要 entr 或类似工具）
	@echo "$(BLUE)监视模式运行测试...$(NC)"
	@if command -v entr >/dev/null 2>&1; then \
		find $(TEST_DIR) cis_kubernetes_benchmark.sh | entr -cr make test; \
	else \
		echo "$(YELLOW)entr 未安装，无法使用监视模式$(NC)"; \
		echo "安装: brew install entr"; \
	fi

################################################################################

##@ Mock 数据

mocks: ## 生成测试用 Mock 数据
	@echo "$(BLUE)生成 Mock 数据...$(NC)"
	@bash $(TEST_DIR)/mocks/create_mocks.sh
	@echo "$(GREEN)Mock 数据生成完成!$(NC)"

mocks-clean: ## 清理 Mock 数据
	@echo "$(BLUE)清理 Mock 数据...$(NC)"
	@rm -rf $(TEST_DIR)/mocks/filesystem
	@rm -rf $(TEST_DIR)/mocks/processes
	@rm -rf $(TEST_DIR)/mocks/kubectl
	@rm -rf $(TEST_DIR)/mocks/configs
	@echo "$(GREEN)Mock 数据已清理!$(NC)"

################################################################################

##@ 覆盖率

coverage: ## 生成测试覆盖率报告
	@echo "$(BLUE)生成测试覆盖率...$(NC)"
	@mkdir -p $(COVERAGE_DIR)
	@echo "# 测试覆盖率报告" > $(COVERAGE_DIR)/coverage.md
	@echo "" >> $(COVERAGE_DIR)/coverage.md
	@echo "生成时间: $$(date)" >> $(COVERAGE_DIR)/coverage.md
	@echo "" >> $(COVERAGE_DIR)/coverage.md
	@bash -c 'grep -c "^.*() {" cis_kubernetes_benchmark.sh' >> $(COVERAGE_DIR)/coverage.md
	@echo "$(GREEN)覆盖率报告已生成: $(COVERAGE_DIR)/coverage.md$(NC)"

################################################################################

##@ 清理

clean: ## 清理构建文件
	@echo "$(BLUE)清理构建文件...$(NC)"
	@rm -rf $(BUILD_DIR)
	@rm -rf $(TEST_DIR)/mocks/filesystem
	@find . -type f -name "*.pyc" -delete
	@find . -type f -name "__pycache__" -delete
	@echo "$(GREEN)清理完成!$(NC)"

distclean: clean ## 深度清理
	@echo "$(BLUE)深度清理...$(NC)"
	@rm -rf $(BUILD_DIR)
	@rm -rf $(TEST_DIR)/mocks/filesystem
	@rm -rf $(TEST_DIR)/mocks/processes
	@rm -rf $(TEST_DIR)/mocks/kubectl
	@rm -rf $(TEST_DIR)/mocks/configs
	@echo "$(GREEN)深度清理完成!$(NC)"

################################################################################

##@ 快速命令

quick-test: syntax test ## 快速测试（语法 + 单元测试）

ci: check test-all ## 模拟 CI 流程（检查 + 测试）
	@echo "$(GREEN)CI 流程完成!$(NC)"

################################################################################

##@ 文档

docs: ## 生成文档
	@echo "$(BLUE)生成文档...$(NC)"
	@mkdir -p $(BUILD_DIR)/docs
	@echo "# CIS Kubernetes Benchmark 文档" > $(BUILD_DIR)/docs/README.md
	@echo "" >> $(BUILD_DIR)/docs/README.md
	@echo "生成时间: $$(date)" >> $(BUILD_DIR)/docs/README.md
	@echo "$(GREEN)文档已生成: $(BUILD_DIR)/docs/README.md$(NC)"

################################################################################

##@ 发布

release: check test-all docs ## 发布前检查
	@echo "$(BLUE)发布检查...$(NC)"
	@echo "$(GREEN)所有检查通过，可以发布!$(NC)"
	@echo "$(YELLOW)别忘了更新版本号和 CHANGELOG$(NC)"

tag: ## 创建 Git 标签
	@if [ -z "$(VERSION)" ]; then \
		echo "$(YELLOW)用法: make tag VERSION=v1.3.1$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)创建标签 $(VERSION)...$(NC)"
	@git tag -a $(VERSION) -m "Release $(VERSION)"
	@git push origin $(VERSION)
	@echo "$(GREEN)标签 $(VERSION) 已创建并推送!$(NC)"

################################################################################

##@ 杂项

version: ## 显示版本信息
	@echo "$(BLUE)CIS Kubernetes Benchmark$(NC)"
	@echo "$(GREEN)版本: $$(grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' cis_kubernetes_benchmark.sh | head -1)$(NC)"
	@echo "基于 CIS Kubernetes Benchmark v1.12.0"

info: ## 显示项目信息
	@echo "$(BLUE)项目信息:$(NC)"
	@echo "  脚本: cis_kubernetes_benchmark.sh"
	@echo "  版本: $$(grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' cis_kubernetes_benchmark.sh | head -1)"
	@echo "  位置: $(SCRIPT_DIR)"
	@echo "  测试: $(TEST_DIR)"
	@echo "  构建: $(BUILD_DIR)"

tree: ## 显示项目结构
	@echo "$(BLUE)项目结构:$(NC)"
	@tree -L 2 -I 'node_modules|.git' || find . -maxdepth 2 -type d | grep -v "\.git" | sort
