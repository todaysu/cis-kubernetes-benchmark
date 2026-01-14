# 🚀 GitHub 上传指南

## 📋 上传前准备

### 步骤 1: 创建 GitHub Personal Access Token (访问令牌)

GitHub 已不再支持密码认证，需要使用 Personal Access Token。

#### 创建 Token 步骤：

1. **登录 GitHub**
   - 访问：https://github.com
   - 使用你的账号登录

2. **进入 Settings**
   - 点击右上角头像 → Settings

3. **创建 Token**
   - 左侧菜单最下方 → Developer settings
   - Personal access tokens → Tokens (classic)
   - Generate new token → Generate new token (classic)

4. **配置 Token**
   ```
   Name: cis-kubernetes-benchmark
   Expiration: 90 days (或根据需求选择)
   Scopes: 勾选以下权限
     ☑ repo (完整仓库访问权限)
     ☑ workflow (如果需要 GitHub Actions)
   ```

5. **保存 Token**
   - 点击 Generate token
   - ⚠️ **重要**: 立即复制 Token，它只会显示一次！
   - 保存到安全的地方

---

### 步骤 2: 在 GitHub 创建新仓库

1. 访问：https://github.com/new
2. 填写仓库信息：
   ```
   Repository name: cis-kubernetes-benchmark
   Description: CIS Kubernetes Benchmark v1.12.0 审计脚本 - 三层检查机制
   ☑ Public (公开) 或 ☐ Private (私有)
   ☐ 不要勾选 "Add a README file" (我们已有)
   ☐ 不要勾选其他选项
   ```
3. 点击 Create repository

---

### 步骤 3: 上传代码到 GitHub

在终端执行以下命令：

```bash
# 进入项目目录
cd /Users/suyingjie/cis-kubernetes-benchmark

# 添加远程仓库 (使用你的用户名替换 YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/cis-kubernetes-benchmark.git

# 推送到 GitHub (会提示输入用户名和 Token)
git push -u origin main
```

#### 认证提示：
```
Username: YOUR_USERNAME (你的 GitHub 用户名)
Password: ghp_xxxxxxxxxxxxxxxxxxxxxx (粘贴刚才创建的 Token)
```

---

### 步骤 4: 验证上传

访问你的仓库：
```
https://github.com/YOUR_USERNAME/cis-kubernetes-benchmark
```

确认以下文件已上传：
- ✅ cis_kubernetes_benchmark.sh
- ✅ README.md
- ✅ LICENSE
- ✅ .gitignore

---

## 🔧 常见问题

### Q1: 提示 "Authentication failed"
**A:** 检查以下几点：
1. Token 是否正确复制（包含 ghp_ 前缀）
2. Token 是否有 repo 权限
3. 仓库名称是否正确

### Q2: 提示 "Repository not found"
**A:**
1. 确认仓库已创建
2. 检查仓库名称拼写
3. 检查你是否有权限访问该仓库

### Q3: 想要使用 SSH 而不是 HTTPS
**A:**
```bash
# 生成 SSH 密钥
ssh-keygen -t ed25519 -C "595705712@qq.com"

# 添加到 GitHub
cat ~/.ssh/id_ed25519.pub
# 复制内容到 GitHub Settings → SSH and GPG keys → New SSH key

# 使用 SSH URL
git remote set-url origin git@github.com:YOUR_USERNAME/cis-kubernetes-benchmark.git
git push -u origin main
```

---

## 📝 后续维护

### 更新代码流程

```bash
# 1. 修改文件
vim cis_kubernetes_benchmark.sh

# 2. 查看变更
git status
git diff

# 3. 提交变更
git add .
git commit -m "更新说明"

# 4. 推送到 GitHub
git push
```

### 创建 Releases

1. 在 GitHub 仓库页面
2. 点击右侧 → Releases
3. Draft a new release
4. 填写版本号和发布说明
5. 点击 Publish release

---

## ⚠️ 安全建议

1. **永远不要**在代码中硬编码 Token 或密码
2. **定期更换** Personal Access Token
3. **使用不同 Token** 用于不同项目
4. **启用** GitHub 双因素认证 (2FA)
5. **定期审查** 授权的第三方应用

---

需要帮助？请查看：
- GitHub 官方文档: https://docs.github.com
- Git 官方文档: https://git-scm.com/docs
