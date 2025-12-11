#!/bin/bash

# AETHER Cloud Run 百分百成功部署脚本
# 解决所有已知问题的完整方案

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
echo_success() { echo -e "${GREEN}✅ $1${NC}"; }
echo_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
echo_error() { echo -e "${RED}❌ $1${NC}"; }

# 配置变量
export PROJECT_ID=$(gcloud config get-value project)
export REGION=${REGION:-us-central1}
export BUCKET_NAME=${BUCKET_NAME:-aether-models-$(date +%s)}
export REPO_NAME=${REPO_NAME:-aether-repo}
export SERVICE_NAME=${SERVICE_NAME:-aether}

echo_info "开始 AETHER Cloud Run 百分百成功部署"
echo_info "项目ID: $PROJECT_ID"
echo_info "区域: $REGION"
echo_info "存储桶: $BUCKET_NAME"

# 1. 预检查
echo_info "步骤 1/8: 预检查环境"

# 检查gcloud认证
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo_error "gcloud未认证，请运行: gcloud auth login"
    exit 1
fi

# 检查项目ID
if [ -z "$PROJECT_ID" ]; then
    echo_error "未设置项目ID，请运行: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

# 启用必要的API
echo_info "启用必要的Google Cloud APIs..."
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable artifactregistry.googleapis.com

echo_success "预检查完成"

# 2. 检查构建环境
echo_info "步骤 2/8: 检查构建环境"

# 选择最佳构建策略
if [ -f "stable-diffusion.cpp/build/bin/sd" ]; then
    echo_info "✅ 发现预构建二进制文件，将使用快速构建模式"
    DOCKERFILE="Dockerfile.robust"
    BUILD_MODE="预构建二进制"
else
    echo_info "⚠️ 未发现预构建二进制文件，将使用完整构建模式"
    DOCKERFILE="Dockerfile.cloud-run"
    BUILD_MODE="完整构建"
    
    # 只有在完整构建模式下才需要子模块
    if [ -d "stable-diffusion.cpp/.git" ]; then
        echo_info "初始化stable-diffusion.cpp子模块..."
        (cd stable-diffusion.cpp && git submodule update --init --recursive)
    else
        echo_warning "stable-diffusion.cpp不是git仓库，跳过子模块初始化"
    fi
fi

# 只有在本地构建时才清理Docker空间
if [[ "${USE_CLOUD_BUILD:-true}" != "true" ]]; then
    echo_info "本地构建模式，清理Docker空间..."
    docker system prune -f --volumes 2>/dev/null || echo "Docker清理跳过"
    docker builder prune -f 2>/dev/null || echo "Docker builder清理跳过"
fi

echo_success "构建环境检查完成 - 模式: $BUILD_MODE"

# 3. 创建GCS存储桶
echo_info "步骤 3/8: 创建GCS存储桶"
if ! gcloud storage buckets describe gs://$BUCKET_NAME &>/dev/null; then
    gcloud storage buckets create gs://$BUCKET_NAME --location=$REGION
    echo_success "存储桶创建成功: gs://$BUCKET_NAME"
else
    echo_warning "存储桶已存在: gs://$BUCKET_NAME"
fi

# 4. 上传模型文件
echo_info "步骤 4/8: 上传模型文件到GCS"
model_files_found=false

if ls *.gguf 1> /dev/null 2>&1; then
    echo_info "上传 .gguf 文件..."
    gcloud storage cp *.gguf gs://$BUCKET_NAME/
    model_files_found=true
fi

if ls *.safetensors 1> /dev/null 2>&1; then
    echo_info "上传 .safetensors 文件..."
    gcloud storage cp *.safetensors gs://$BUCKET_NAME/
    model_files_found=true
fi

if [ "$model_files_found" = false ]; then
    echo_warning "未找到模型文件，请确保 .gguf 和 .safetensors 文件在当前目录"
    echo_info "继续部署，模型文件可以稍后上传"
fi

echo_success "模型文件处理完成"

# 5. 创建Artifact Registry
echo_info "步骤 5/8: 配置Artifact Registry"
if ! gcloud artifacts repositories describe $REPO_NAME --location=$REGION &>/dev/null; then
    gcloud artifacts repositories create $REPO_NAME \
        --repository-format=docker \
        --location=$REGION \
        --description="AETHER Docker Repository"
    echo_success "Artifact Registry创建成功"
else
    echo_warning "Artifact Registry已存在"
fi

gcloud auth configure-docker $REGION-docker.pkg.dev
echo_success "Docker认证配置完成"

# 6. 验证构建文件
echo_info "步骤 6/8: 验证构建文件"

if [ ! -f "$DOCKERFILE" ]; then
    echo_error "Dockerfile不存在: $DOCKERFILE"
    exit 1
fi

if [ ! -f "gradio_app_fixed.py" ]; then
    echo_error "应用文件不存在: gradio_app_fixed.py"
    exit 1
fi

echo_success "构建文件验证完成"

# 7. 构建并推送镜像
export IMAGE_URI=$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/aether:latest

echo_info "步骤 7/8: 构建Docker镜像"
echo_info "镜像URI: $IMAGE_URI"

# 使用之前选择的Dockerfile
echo_info "使用Dockerfile: $DOCKERFILE ($BUILD_MODE)"

# 检查是否使用Cloud Build
# 根据经验教训，默认使用Cloud Build避免空间问题
if [[ "${USE_CLOUD_BUILD:-true}" == "true" ]]; then
    echo_info "使用Cloud Build构建镜像（推荐，避免磁盘空间问题）..."
    
    # Cloud Build需要使用cloudbuild.yaml或默认Dockerfile
    # 创建临时的cloudbuild.yaml来指定自定义Dockerfile
    cat > cloudbuild.yaml << EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-f', '$DOCKERFILE', '-t', '$IMAGE_URI', '.']
- name: 'gcr.io/cloud-builders/docker'
  args: ['push', '$IMAGE_URI']
EOF
    
    if gcloud builds submit --config cloudbuild.yaml .; then
        echo_success "Cloud Build构建成功"
    else
        echo_error "Cloud Build构建失败"
        rm -f cloudbuild.yaml
        exit 1
    fi
    rm -f cloudbuild.yaml
else
    echo_warning "本地构建镜像（可能遇到磁盘空间问题）..."
    echo_warning "推荐使用: USE_CLOUD_BUILD=true ./deploy_to_cloud_run_fixed.sh"
    
    if docker build --platform linux/amd64 -f $DOCKERFILE -t $IMAGE_URI .; then
        echo_success "本地构建成功"
        if docker push $IMAGE_URI; then
            echo_success "镜像推送成功"
        else
            echo_error "镜像推送失败"
            exit 1
        fi
    else
        echo_error "本地构建失败，建议使用Cloud Build"
        echo_info "尝试运行: USE_CLOUD_BUILD=true ./deploy_to_cloud_run_fixed.sh"
        exit 1
    fi
fi

echo_success "镜像构建并推送成功"

# 8. 部署到Cloud Run
echo_info "步骤 8/8: 部署到Cloud Run"

# 基础部署参数
DEPLOY_ARGS=(
    "run" "deploy" "$SERVICE_NAME"
    "--image=$IMAGE_URI"
    "--region=$REGION"
    "--execution-environment=gen2"
    "--allow-unauthenticated"
    "--port=7860"
    "--memory=16Gi"
    "--cpu=4"
    "--timeout=3600"
    "--concurrency=1"
    "--max-instances=10"
    "--add-volume=name=models,type=cloud-storage,bucket=$BUCKET_NAME"
    "--add-volume-mount=volume=models,mount-path=/app/models"
    "--set-env-vars=MODEL_PATH=/app/models,PYTHONUNBUFFERED=1"
)

# 检查是否使用GPU
if [[ "${USE_GPU:-false}" == "true" ]]; then
    echo_info "部署GPU版本..."
    DEPLOY_ARGS+=(
        "--gpu=1"
        "--gpu-type=nvidia-l4"
    )
    SERVICE_NAME="${SERVICE_NAME}-gpu"
    DEPLOY_ARGS[2]="$SERVICE_NAME"
else
    echo_info "部署CPU版本..."
fi

# 执行部署
gcloud "${DEPLOY_ARGS[@]}"

echo_success "部署完成！"

# 获取服务URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format='value(status.url)')

echo ""
echo "🎉 AETHER 部署成功！"
echo ""
echo "📋 部署信息:"
echo "- 服务名称: $SERVICE_NAME"
echo "- 区域: $REGION"
echo "- 存储桶: gs://$BUCKET_NAME"
echo "- 镜像: $IMAGE_URI"
echo "- 服务URL: $SERVICE_URL"
echo ""
echo "🌐 访问您的AETHER应用:"
echo "$SERVICE_URL"
echo ""
echo "💡 提示:"
echo "- 首次启动可能需要1-2分钟"
echo "- 如果遇到问题，请检查Cloud Run日志"
echo "- GPU版本生成速度比CPU快20-50倍"
echo ""
echo "🔧 故障排除:"
echo "- 查看日志: gcloud run logs tail $SERVICE_NAME --region=$REGION"
echo "- 重新部署: ./deploy_to_cloud_run_fixed.sh"
echo "- 使用GPU: USE_GPU=true ./deploy_to_cloud_run_fixed.sh"