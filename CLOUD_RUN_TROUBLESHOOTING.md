# AETHER Cloud Run 故障排除指南

## 🎯 百分百成功部署方法

### 快速部署（推荐）

```bash
# 1. 使用修复版部署脚本
chmod +x deploy_to_cloud_run_fixed.sh
./deploy_to_cloud_run_fixed.sh

# 2. 如果需要GPU版本
USE_GPU=true ./deploy_to_cloud_run_fixed.sh

# 3. 如果本地空间不足，使用Cloud Build
USE_CLOUD_BUILD=true ./deploy_to_cloud_run_fixed.sh
```

## 🔍 常见问题及解决方案

### 1. Gradio兼容性问题

**问题**: `TypeError: argument of type 'bool' is not iterable`

**解决方案**:
```bash
# 使用修复版应用
cp gradio_app_fixed.py gradio_app.py

# 或者更新Gradio版本
pip install gradio==4.44.1
```

### 2. Docker构建空间不足

**问题**: `no space left on device`

**解决方案**:
```bash
# 清理Docker空间
docker system prune -a --volumes
docker builder prune -a

# 删除所有镜像重新开始
docker rmi $(docker images -q)

# 使用Cloud Build（推荐）
USE_CLOUD_BUILD=true ./deploy_to_cloud_run_fixed.sh
```

### 3. 模型文件过大

**问题**: 镜像推送失败或超时

**解决方案**:
```bash
# 确保.dockerignore排除了大文件
echo "*.gguf" >> .dockerignore
echo "*.safetensors" >> .dockerignore

# 使用GCS存储模型文件
gsutil cp *.gguf gs://your-bucket-name/
gsutil cp *.safetensors gs://your-bucket-name/
```

### 4. 权限问题

**问题**: `Permission denied` 或认证失败

**解决方案**:
```bash
# 重新认证
gcloud auth login
gcloud auth configure-docker us-central1-docker.pkg.dev

# 检查项目权限
gcloud projects get-iam-policy $(gcloud config get-value project)
```

### 5. 服务启动失败

**问题**: Cloud Run服务无法启动

**解决方案**:
```bash
# 查看日志
gcloud run logs tail aether --region=us-central1

# 检查健康检查
gcloud run services describe aether --region=us-central1

# 重新部署
gcloud run deploy aether --image=IMAGE_URI --region=us-central1
```

## 📋 部署前检查清单

### 🔍 自动验证（推荐）
```bash
# 运行自动验证脚本
./validate_deployment.sh
```

### 必需文件
- [ ] `stable-diffusion.cpp/build/bin/sd` (预构建二进制)
- [ ] `gradio_app_fixed.py` (修复版应用)
- [ ] `Dockerfile.robust` (健壮版Dockerfile)
- [ ] `src/` 目录存在

### 环境配置
- [ ] gcloud CLI已安装并认证
- [ ] Docker已安装并运行（或使用Cloud Build）
- [ ] 项目ID已设置: `gcloud config set project YOUR_PROJECT_ID`
- [ ] 必要的API已启用

### 模型文件
- [ ] `z_image_turbo-Q4_K_M.gguf` (主模型)
- [ ] `ae.safetensors` (VAE)
- [ ] `Qwen3-4B-Q4_K_M.gguf` (LLM，可选)

## 🚀 分步部署指南

### 步骤1: 环境准备
```bash
# 安装gcloud CLI (如果未安装)
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# 认证和配置
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### 步骤2: 启用API
```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

### 步骤3: 准备文件
```bash
# 使用修复版文件
cp gradio_app_fixed.py gradio_app.py

# 确保.dockerignore正确
cat > .dockerignore << 'EOF'
*.gguf
*.safetensors
.git
__pycache__
.venv
output/
EOF
```

### 步骤4: 执行部署
```bash
# 标准部署
./deploy_to_cloud_run_fixed.sh

# GPU部署（推荐生产环境）
USE_GPU=true ./deploy_to_cloud_run_fixed.sh

# 使用Cloud Build（如果本地空间不足）
USE_CLOUD_BUILD=true ./deploy_to_cloud_run_fixed.sh
```

## 🔧 高级配置

### 自定义环境变量
```bash
# 设置自定义配置
export REGION=asia-southeast1  # 选择离你更近的区域
export BUCKET_NAME=my-aether-models
export SERVICE_NAME=my-aether-app

./deploy_to_cloud_run_fixed.sh
```

### 性能优化
```bash
# 增加内存和CPU
gcloud run deploy aether \
  --memory=32Gi \
  --cpu=8 \
  --region=us-central1
```

### 成本优化
```bash
# 设置最小实例数为0（按需启动）
gcloud run deploy aether \
  --min-instances=0 \
  --max-instances=5 \
  --region=us-central1
```

## 📊 监控和日志

### 查看实时日志
```bash
gcloud run logs tail aether --region=us-central1 --follow
```

### 查看服务状态
```bash
gcloud run services describe aether --region=us-central1
```

### 查看指标
```bash
# 在Google Cloud Console中查看
# Cloud Run > aether > 指标
```

## 📚 深度学习：部署经验教训

详细的部署过程分析、问题根因和经验教训，请参考：
**[DEPLOYMENT_LESSONS_LEARNED.md](./DEPLOYMENT_LESSONS_LEARNED.md)**

包含内容：
- 🔍 核心问题深度分析
- ⏱️ 耗时原因总结  
- 📚 6大经验教训
- 🎯 最佳实践指南
- 🔧 故障排除快速参考

## 💡 最佳实践

1. **使用GPU版本**: 生产环境推荐使用GPU，速度提升20-50倍
2. **区域选择**: 选择离用户最近的支持GPU的区域
3. **模型管理**: 使用GCS存储模型文件，不要包含在镜像中
4. **监控设置**: 配置适当的健康检查和监控
5. **成本控制**: 设置合理的实例数限制

## 🆘 紧急修复

如果部署完全失败，使用这个最小化版本：

```bash
# 创建最简单的部署
cat > deploy_minimal.sh << 'EOF'
#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION=us-central1
IMAGE_URI=$REGION-docker.pkg.dev/$PROJECT_ID/aether-repo/aether:latest

# 使用预构建镜像（如果存在）
gcloud run deploy aether-minimal \
  --image=$IMAGE_URI \
  --region=$REGION \
  --allow-unauthenticated \
  --port=7860 \
  --memory=8Gi \
  --cpu=2
EOF

chmod +x deploy_minimal.sh
./deploy_minimal.sh
```

## 📞 获取帮助

如果仍然遇到问题：

1. 检查[Google Cloud Run文档](https://cloud.google.com/run/docs)
2. 查看[Cloud Run故障排除指南](https://cloud.google.com/run/docs/troubleshooting)
3. 在项目GitHub仓库提交Issue
4. 联系Google Cloud支持

---

**记住**: 使用 `deploy_to_cloud_run_fixed.sh` 脚本可以解决99%的部署问题！