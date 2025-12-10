#!/bin/bash

# AETHER Cloud Run 部署脚本
# 解决 Docker 构建空间不足问题的完整解决方案

set -e

# 配置变量
export PROJECT_ID=$(gcloud config get-value project)
export REGION=${REGION:-us-central1}
export BUCKET_NAME=${BUCKET_NAME:-z-image-models-$(date +%s)}
export REPO_NAME=${REPO_NAME:-z-image-repo}
export SERVICE_NAME=${SERVICE_NAME:-z-image}

echo "🚀 开始部署 AETHER 到 Cloud Run"
echo "项目ID: $PROJECT_ID"
echo "区域: $REGION"
echo "存储桶: $BUCKET_NAME"

# 1. 清理 Docker 空间
echo "🧹 清理 Docker 空间..."
docker system prune -f
docker builder prune -f

# 2. 创建 GCS 存储桶
echo "📦 创建 GCS 存储桶..."
if ! gcloud storage buckets describe gs://$BUCKET_NAME &>/dev/null; then
    gcloud storage buckets create gs://$BUCKET_NAME --location=$REGION
    echo "✅ 存储桶创建成功"
else
    echo "ℹ️ 存储桶已存在"
fi

# 3. 上传模型文件
echo "⬆️ 上传模型文件到 GCS..."
if ls *.gguf *.safetensors 1> /dev/null 2>&1; then
    gcloud storage cp *.gguf gs://$BUCKET_NAME/ 2>/dev/null || echo "⚠️ 没有找到 .gguf 文件"
    gcloud storage cp *.safetensors gs://$BUCKET_NAME/ 2>/dev/null || echo "⚠️ 没有找到 .safetensors 文件"
    echo "✅ 模型文件上传完成"
else
    echo "⚠️ 没有找到模型文件，请确保 .gguf 和 .safetensors 文件在当前目录"
fi

# 4. 创建 Artifact Registry
echo "🏗️ 配置 Artifact Registry..."
if ! gcloud artifacts repositories describe $REPO_NAME --location=$REGION &>/dev/null; then
    gcloud artifacts repositories create $REPO_NAME --repository-format=docker \
        --location=$REGION --description="Z-Image Docker Repository"
    echo "✅ Artifact Registry 创建成功"
else
    echo "ℹ️ Artifact Registry 已存在"
fi

gcloud auth configure-docker $REGION-docker.pkg.dev

# 5. 构建并推送镜像
export IMAGE_URI=$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/z-image:latest

echo "🔨 构建 Docker 镜像..."
echo "镜像URI: $IMAGE_URI"

# 检查是否使用 Cloud Build
if [[ "${USE_CLOUD_BUILD:-false}" == "true" ]]; then
    echo "☁️ 使用 Cloud Build 构建镜像..."
    gcloud builds submit --tag $IMAGE_URI .
else
    echo "🏠 本地构建镜像..."
    docker build --platform linux/amd64 -f Dockerfile.optimized -t $IMAGE_URI .
    docker push $IMAGE_URI
fi

echo "✅ 镜像构建并推送成功"

# 6. 部署到 Cloud Run
echo "🚀 部署到 Cloud Run..."

# 检查是否使用 GPU
if [[ "${USE_GPU:-false}" == "true" ]]; then
    echo "🎮 部署 GPU 版本..."
    gcloud run deploy $SERVICE_NAME-gpu \
        --image=$IMAGE_URI \
        --region=$REGION \
        --execution-environment=gen2 \
        --allow-unauthenticated \
        --port=7860 \
        --memory=16Gi \
        --cpu=4 \
        --gpu=1 \
        --gpu-type=nvidia-l4 \
        --add-volume=name=models,type=cloud-storage,bucket=$BUCKET_NAME \
        --add-volume-mount=volume=models,mount-path=/app/models \
        --set-env-vars=MODEL_PATH=/app/models
else
    echo "💻 部署 CPU 版本..."
    gcloud run deploy $SERVICE_NAME \
        --image=$IMAGE_URI \
        --region=$REGION \
        --execution-environment=gen2 \
        --allow-unauthenticated \
        --port=7860 \
        --memory=16Gi \
        --cpu=4 \
        --add-volume=name=models,type=cloud-storage,bucket=$BUCKET_NAME \
        --add-volume-mount=volume=models,mount-path=/app/models \
        --set-env-vars=MODEL_PATH=/app/models
fi

echo "🎉 部署完成！"
echo ""
echo "📋 部署信息:"
echo "- 服务名称: $SERVICE_NAME"
echo "- 区域: $REGION"
echo "- 存储桶: gs://$BUCKET_NAME"
echo "- 镜像: $IMAGE_URI"
echo ""
echo "🌐 获取服务 URL:"
if [[ "${USE_GPU:-false}" == "true" ]]; then
    gcloud run services describe $SERVICE_NAME-gpu --region=$REGION --format='value(status.url)'
else
    gcloud run services describe $SERVICE_NAME --region=$REGION --format='value(status.url)'
fi