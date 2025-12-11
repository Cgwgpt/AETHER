# AETHER Cloud Run 部署经验教训

## 📋 部署过程回顾与问题分析

整个部署过程比较漫长，主要遇到了以下几个核心问题，导致了多次失败和重试：

## 🔍 核心问题分析

### 1. 环境初始化不完整

**问题描述：**
- 最初，项目 AETHER 和其依赖的 `stable-diffusion.cpp` 仓库没有被正确下载和设置
- `stable-diffusion.cpp` 是一个独立的 C++ 仓库，需要被克隆到 AETHER 项目目录中

**影响：**
- 导致 Docker 在构建时找不到必要的 C++ 源码和 `CMakeLists.txt` 文件
- 从而构建失败，出现 "CMakeLists.txt not found" 错误

**解决方案：**
```bash
# 确保子模块正确初始化
git submodule update --init --recursive

# 或者使用预构建的二进制文件（推荐）
# 检查 stable-diffusion.cpp/build/bin/sd 是否存在
```

### 2. 构建环境资源耗尽 (No space left on device)

**问题描述：**
- 这是最核心、最耗时的问题
- 在 Cloud Shell 中直接运行部署脚本，默认使用本地 Docker (`docker build`) 构建镜像
- Cloud Shell 的虚拟机磁盘空间非常有限（通常只有几GB可用）
- `torch` 和 `transformers` 等库体积巨大（通常需要数 GB 的空间）
- Docker 的中间层或缓存写满了磁盘

**影响：**
- 即使尝试了多种 Dockerfile 优化也无法绕开物理限制
- 导致了反复的、长时间的构建失败

**解决方案：**
```bash
# 优先使用 Cloud Build
USE_CLOUD_BUILD=true ./deploy_to_cloud_run_fixed.sh

# 或者清理本地 Docker 空间
docker system prune -a --volumes
docker builder prune -a
```

### 3. 部署脚本存在错误

**问题1：gcloud 命令参数错误**
```bash
# ❌ 错误的命令
gcloud builds submit --tag $IMAGE_URI --dockerfile Dockerfile.fixed .

# ✅ 正确的命令
gcloud builds submit --tag $IMAGE_URI .
# 或者指定配置文件
gcloud builds submit --config cloudbuild.yaml .
```

**问题2：未默认启用 Cloud Build**
- 脚本没有默认启用 Cloud Build
- 导致一直在资源受限的本地环境中挣扎

**影响：**
- 即使找到了正确方向也无法成功执行
- 导致了额外的调试时间

## ⏱️ 耗时较长的原因总结

### 1. 反复的 Docker 构建
- Docker 构建本身就是耗时过程，尤其涉及 C++ 编译和大型 Python 依赖
- 每次失败后的重试都意味着从头开始构建
- 单次构建可能需要 20-30 分钟

### 2. 问题层层递进
- 本次部署的问题是嵌套的："俄罗斯套娃"式问题
- 解决了源码缺失问题后，才暴露出磁盘空间问题
- 尝试解决磁盘空间问题时，又触发了部署脚本的 bug
- 逐层排查耗费了大量时间

### 3. 大型依赖
- PyTorch 和 CUDA 相关的镜像是出了名的庞大
- 下载和解压都需要很长时间
- 网络波动会导致重新下载

## 📚 经验教训 (Lessons Learned)

### 1. 优先使用云端构建服务 ⭐⭐⭐

**原则：**
对于大型、复杂的 Docker 镜像（尤其是包含大型机器学习库或需要编译的），应首选 Google Cloud Build 而不是在 Cloud Shell 等资源受限的环境中本地构建。

**实践：**
```bash
# 在部署脚本中应默认启用
export USE_CLOUD_BUILD=true

# 或者直接使用 Cloud Build
gcloud builds submit --tag gcr.io/PROJECT_ID/aether:latest .
```

**优势：**
- 无磁盘空间限制
- 更强的计算资源
- 并行构建能力
- 自动缓存优化

### 2. 仔细检查并验证部署脚本 ⭐⭐⭐

**原则：**
不要完全信任项目自带的部署脚本。在使用前，应仔细阅读，特别是与核心命令相关的部分。

**实践：**
```bash
# 验证 gcloud 命令
gcloud builds submit --help

# 验证 Docker 命令
docker build --help

# 测试脚本语法
bash -n deploy_script.sh
```

**检查要点：**
- 命令参数是否正确
- 环境变量是否设置
- 文件路径是否存在
- 权限是否足够

### 3. 选择合适的基础镜像 ⭐⭐

**对于 GPU 应用：**
```dockerfile
# ✅ 推荐：使用官方预构建镜像
FROM nvcr.io/nvidia/pytorch:23.10-py3

# ❌ 避免：从头安装 CUDA
FROM ubuntu:22.04
RUN apt-get install cuda-toolkit...
```

**对于 CPU 应用：**
```dockerfile
# ✅ 推荐：使用官方 Python 镜像
FROM python:3.11-slim

# ✅ 或者使用 Ubuntu LTS
FROM ubuntu:22.04
```

**注意事项：**
- 务必在 Docker Hub 或 NGC 官网确认镜像标签存在
- 选择合适的版本（不要总是用 latest）
- 考虑镜像大小和安全性

### 4. 理解项目依赖 ⭐⭐

**实践：**
```bash
# 部署前检查项目结构
ls -la
cat README.md
cat requirements.txt

# 检查子模块
git submodule status
ls -la stable-diffusion.cpp/

# 检查预构建文件
ls -la stable-diffusion.cpp/build/bin/
```

**要点：**
- 阅读项目 README 和文档
- 了解外部依赖和子模块
- 检查预构建文件是否存在
- 理解构建流程

### 5. 使用渐进式部署策略 ⭐⭐

**策略：**
1. **最小可行版本 (MVP)**：先部署最简单的版本
2. **逐步增加功能**：确认基础版本工作后再添加复杂功能
3. **分层验证**：每一层都要验证成功

**实践：**
```bash
# 第一步：部署最简单版本
docker build -f Dockerfile.simple -t test:v1 .

# 第二步：添加更多功能
docker build -f Dockerfile.robust -t test:v2 .

# 第三步：完整功能版本
docker build -f Dockerfile.cloud-run -t test:v3 .
```

### 6. 建立完善的验证机制 ⭐⭐

**部署前验证：**
```bash
# 使用我们创建的验证脚本
./validate_deployment.sh

# 检查 Dockerfile 语法
docker build --dry-run -f Dockerfile .

# 验证环境配置
gcloud config list
docker info
```

**部署后验证：**
```bash
# 检查服务状态
gcloud run services describe SERVICE_NAME --region=REGION

# 查看日志
gcloud run logs tail SERVICE_NAME --region=REGION

# 测试服务
curl -f SERVICE_URL/health || echo "Health check failed"
```

## 🎯 最佳实践总结

### 部署脚本设计原则

1. **默认使用云端构建**
2. **提供多种 Dockerfile 选项**
3. **完善的错误处理和恢复机制**
4. **详细的日志和状态反馈**
5. **自动环境检查和验证**

### 推荐的部署流程

```bash
# 1. 环境验证
./validate_deployment.sh

# 2. 选择合适的部署方式
# 标准部署（自动选择最佳策略）
./deploy_to_cloud_run_fixed.sh

# GPU 部署（生产推荐）
USE_GPU=true ./deploy_to_cloud_run_fixed.sh

# 强制使用 Cloud Build
USE_CLOUD_BUILD=true ./deploy_to_cloud_run_fixed.sh

# 3. 部署后验证
gcloud run logs tail aether --region=us-central1
```

## 🔧 故障排除快速参考

| 问题 | 症状 | 解决方案 |
|------|------|----------|
| 磁盘空间不足 | `No space left on device` | 使用 `USE_CLOUD_BUILD=true` |
| CMakeLists.txt 找不到 | `CMakeLists.txt not found` | 检查子模块或使用预构建二进制 |
| gcloud 命令错误 | `unknown flag --dockerfile` | 移除错误参数，使用标准命令 |
| Dockerfile 语法错误 | `COPY` 指令失败 | 移除 shell 条件逻辑 |
| 权限问题 | `Permission denied` | 重新认证 `gcloud auth login` |

## 📖 相关文档

- [DEPLOY_GUIDE.md](./DEPLOY_GUIDE.md) - 部署指南
- [CLOUD_RUN_TROUBLESHOOTING.md](./CLOUD_RUN_TROUBLESHOOTING.md) - 故障排除
- [validate_deployment.sh](./validate_deployment.sh) - 部署验证脚本

---

**总结：** 这次部署的核心障碍是在资源不足的环境中尝试构建一个过于庞大的 Docker 镜像，并且被一个含有错误的部署脚本所误导。正确的路径是修正脚本，并利用 Cloud Build 在云端完成构建工作。

通过这次经验，我们建立了一套完整的部署解决方案，可以帮助其他开发者避免同样的问题，实现真正的一键部署。