# AETHER Cloud Run 快速部署指南

## 🎯 百分百成功部署方法（推荐）

### 使用修复版脚本（解决所有已知问题）

```bash
# 1. 使用修复版部署脚本（自动选择最佳构建方式）
chmod +x deploy_to_cloud_run_fixed.sh
./deploy_to_cloud_run_fixed.sh

# 2. GPU版本（推荐生产环境，速度提升20-50倍）
USE_GPU=true ./deploy_to_cloud_run_fixed.sh

# 3. 如果本地空间不足，使用Cloud Build
USE_CLOUD_BUILD=true ./deploy_to_cloud_run_fixed.sh
```

### ✨ 最新修复（v2.0）

- **🔧 解决CMakeLists.txt问题**: 自动检测预构建二进制文件
- **⚡ 智能构建选择**: 优先使用轻量级Dockerfile.simple
- **🛠️ 完整构建备选**: 如需重新编译使用Dockerfile.cloud-run
- **✅ 构建验证**: 内置测试脚本确保环境正确

## 解决 Docker 构建空间不足问题

### 方案 1: 本地构建（推荐）

```bash
# 1. 清理 Docker 空间
docker system prune -a --volumes
docker builder prune -a

# 2. 使用优化的部署脚本
./deploy_to_cloud_run.sh
```

### 方案 2: 使用 Cloud Build（如果本地空间仍不足）

```bash
# 设置环境变量使用 Cloud Build
export USE_CLOUD_BUILD=true
./deploy_to_cloud_run.sh
```

### 方案 3: 手动上传模型文件

如果模型文件太大，可以先单独上传：

```bash
# 1. 创建存储桶
export BUCKET_NAME=your-bucket-name
gcloud storage buckets create gs://$BUCKET_NAME --location=us-central1

# 2. 上传模型文件
gcloud storage cp *.gguf gs://$BUCKET_NAME/
gcloud storage cp *.safetensors gs://$BUCKET_NAME/

# 3. 构建不包含模型的镜像
docker build --platform linux/amd64 -f Dockerfile.optimized -t your-image .
```

## 部署选项

### CPU 部署（成本低）
```bash
./deploy_to_cloud_run.sh
```

### GPU 部署（高性能）
```bash
export USE_GPU=true
./deploy_to_cloud_run.sh
```

## 环境变量配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `REGION` | us-central1 | Cloud Run 区域 |
| `BUCKET_NAME` | z-image-models-{timestamp} | GCS 存储桶名称 |
| `USE_GPU` | false | 是否使用 GPU |
| `USE_CLOUD_BUILD` | false | 是否使用 Cloud Build |

## 故障排除

### 🔥 常见问题快速修复

#### Gradio兼容性错误
```bash
# 使用修复版应用
cp gradio_app_fixed.py gradio_app.py
```

#### Docker空间不足
```bash
# 清理Docker空间
docker system prune -a --volumes
docker builder prune -a

# 使用Cloud Build
USE_CLOUD_BUILD=true ./deploy_to_cloud_run_fixed.sh
```

#### 模型文件过大
```bash
# 确保.dockerignore正确配置
echo "*.gguf" >> .dockerignore
echo "*.safetensors" >> .dockerignore
```

#### 权限问题
```bash
# 重新认证
gcloud auth login
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### 详细故障排除
查看完整的故障排除指南: `CLOUD_RUN_TROUBLESHOOTING.md`

## 成本估算

- **存储**: ~$0.16/月 (8GB 模型文件)
- **CPU 版本**: ~$0.10/小时 使用时间
- **GPU 版本**: ~$1.00/小时 使用时间

GPU 版本生成速度比 CPU 快 20-50 倍，适合生产使用。