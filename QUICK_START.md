# 🚀 AETHER 快速开始指南

## 30秒部署到 Cloud Run

### 前置条件
- Google Cloud 项目（已启用计费）
- gcloud CLI 已安装并认证

### 一键部署

```bash
# 1. 克隆仓库
git clone https://github.com/Cgwgpt/AETHER.git
cd AETHER

# 2. 验证环境（可选但推荐）
./validate_deployment.sh

# 3. 一键部署
./deploy_to_cloud_run_fixed.sh
```

### GPU 版本（推荐生产环境）

```bash
# GPU 版本 - 速度提升 20-50 倍
USE_GPU=true ./deploy_to_cloud_run_fixed.sh
```

### 如果遇到问题

```bash
# 使用 Cloud Build（解决磁盘空间问题）
USE_CLOUD_BUILD=true ./deploy_to_cloud_run_fixed.sh

# 查看详细故障排除
cat CLOUD_RUN_TROUBLESHOOTING.md

# 了解部署经验教训
cat DEPLOYMENT_LESSONS_LEARNED.md
```

## 🎯 部署成功后

访问返回的 URL，你将看到 AETHER 的 Web 界面。

### 特性
- ⚡ 8步快速生成
- 🎨 多种分辨率支持
- 🔧 Flash Attention 优化
- 🖥️ Metal/CUDA 加速

### 成本估算
- **存储**: ~$0.16/月 (模型文件)
- **CPU 版本**: ~$0.10/小时 使用时间
- **GPU 版本**: ~$1.00/小时 使用时间

## 📚 更多文档

- [完整部署指南](./DEPLOY_GUIDE.md)
- [故障排除](./CLOUD_RUN_TROUBLESHOOTING.md)  
- [部署经验教训](./DEPLOYMENT_LESSONS_LEARNED.md)
- [中文文档](./docs/cloud_run_zh.md)