# AETHER Cloud Run 快速部署指南

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

### 1. Docker 空间不足
```bash
# 查看空间使用
docker system df

# 清理所有未使用的资源
docker system prune -a --volumes

# 删除所有镜像重新开始
docker rmi $(docker images -q)
```

### 2. 模型文件太大
- 确保 `.dockerignore` 排除了 `*.gguf` 和 `*.safetensors`
- 使用 `Dockerfile.optimized` 而不是原始 `Dockerfile`
- 考虑使用 Cloud Build

### 3. 推送失败
```bash
# 重新认证
gcloud auth login
gcloud auth configure-docker us-central1-docker.pkg.dev

# 检查项目ID
gcloud config get-value project
```

## 成本估算

- **存储**: ~$0.16/月 (8GB 模型文件)
- **CPU 版本**: ~$0.10/小时 使用时间
- **GPU 版本**: ~$1.00/小时 使用时间

GPU 版本生成速度比 CPU 快 20-50 倍，适合生产使用。