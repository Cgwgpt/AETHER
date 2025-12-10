# 部署 AETHER 到 Google Cloud Run

本指南介绍如何将 AETHER 部署到 Google Cloud Run，这是一个用于运行容器的无服务器平台。

## 前置条件

1.  **Google Cloud 项目**: 您需要一个已启用计费的 GCP 项目。
2.  **gcloud CLI**: 已安装并完成认证 (`gcloud auth login`)。
3.  **Docker**: 本地已安装，用于构建镜像。

## 1. 准备模型存储 (GCS FUSE)

由于 AETHER 模型文件较大（>7GB），我们不能将其直接包含在 Docker 镜像中。相反，我们将把它们存储在 Google Cloud Storage (GCS) 存储桶中，并使用 Cloud Storage FUSE 将其挂载到 Cloud Run 容器。

1.  **创建 GCS 存储桶**:
    ```bash
    export BUCKET_NAME=z-image-models
    export REGION=us-central1  # 如果需要 GPU，请选择支持 GPU 的区域
    
    gcloud storage buckets create gs://$BUCKET_NAME --location=$REGION
    ```

2.  **上传模型**:
    将本地的 `.gguf` 和 `.safetensors` 文件上传到存储桶根目录。
    ```bash
    gcloud storage cp *.gguf gs://$BUCKET_NAME/
    gcloud storage cp *.safetensors gs://$BUCKET_NAME/
    ```

## 2. 构建并推送 Docker 镜像

### 解决构建空间不足问题

如果遇到 Docker 构建空间不足，请先清理：

```bash
# 清理 Docker 空间
docker system prune -a --volumes
docker builder prune -a

# 查看空间使用情况
docker system df
```

### 构建镜像

1.  **配置 Artifact Registry**:
    ```bash
    export PROJECT_ID=$(gcloud config get-value project)
    export REPO_NAME=z-image-repo
    gcloud artifacts repositories create $REPO_NAME --repository-format=docker \
        --location=$REGION --description="Z-Image Docker Repository"
    
    gcloud auth configure-docker $REGION-docker.pkg.dev
    ```

2.  **构建并推送**:
    ```bash
    export IMAGE_URI=$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/z-image:latest
    
    # 使用优化的 Dockerfile (不包含大文件)
    docker build --platform linux/amd64 -f Dockerfile.optimized -t $IMAGE_URI .
    
    # 如果需要 GPU 版本，使用 Dockerfile.gpu
    # docker build --platform linux/amd64 -f Dockerfile.gpu -t $IMAGE_URI .
    
    docker push $IMAGE_URI
    ```

### 替代方案：使用 Cloud Build

如果本地空间仍然不足，可以使用 Google Cloud Build：

```bash
# 提交代码到 Cloud Build 进行构建
gcloud builds submit --tag $IMAGE_URI .

# 或者使用 GPU Dockerfile
# gcloud builds submit --tag $IMAGE_URI --dockerfile Dockerfile.gpu .
```

## 3. 部署到 Cloud Run

我们将使用 `gcloud` 命令进行部署。我们需要配置 GCS 卷挂载。

### 选项 A: CPU 部署 (成本较低)

适合测试，但生成速度较慢。

```bash
gcloud run deploy z-image \
    --image=$IMAGE_URI \
    --region=$REGION \
    --execution-environment=gen2 \
    --allow-unauthenticated \
    --port=7860 \
    --memory=16Gi \
    --cpu=4 \
    --add-volume=name=models,type=cloud-storage,bucket=$BUCKET_NAME \
    --add-volume-mount=volume=models,mount-path=/app
```

### 选项 B: GPU 部署 (高性能)

需要选择支持 Cloud Run GPU 的区域 (如 `us-central1`, `asia-southeast1` 等)。
**注意**: 必须使用 `Dockerfile.gpu` 构建的镜像。

```bash
# 1. 构建 GPU 镜像
docker build --platform linux/amd64 -f Dockerfile.gpu -t $IMAGE_URI .
docker push $IMAGE_URI

# 2. 部署
gcloud run deploy z-image-gpu \
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
    --add-volume-mount=volume=models,mount-path=/app
```

## 4. 性能与速度分析

### CPU vs GPU 生成速度对比

*   **CPU (4 vCPU)**:
    *   **预估速度**: 约 **100 - 200 秒/张** (512x512)
    *   **适用场景**: 仅用于验证部署流程或极低频次使用。不推荐用于生产环境。

*   **GPU (NVIDIA L4)**:
    *   **显存**: 24GB GDDR6
    *   **预估速度**: 约 **3 - 6 秒/张** (512x512)
    *   **优势**: 相比 CPU 有 **20-50倍** 的性能提升。L4 专为 AI 推理设计，性价比极高。
    *   **Flash Attention**: 在 GPU 模式下，Flash Attention 将发挥最大效能，显著降低显存占用并提升高分辨率 (1024x1024+) 的生成速度。

## 5. 存储成本估算 (参考)

部署完成后，Cloud Run 会提供一个 URL (例如 `https://z-image-xyz.a.run.app`)。在浏览器中打开此 URL 即可访问 Z-Image Web 界面。

## 重要提示

*   **冷启动**: 带有 GCS 挂载的大型容器可能需要一分钟左右才能启动。
*   **成本**: 您只需为请求处理期间的 CPU/内存/GPU 使用量付费（如果设置了最小实例数则另计）。GCS 存储费用另计。
*   **区域**: 请确保您的 GCS 存储桶和 Cloud Run 服务位于同一区域，以最大限度地减少延迟和数据传输成本。

## 5. 存储成本估算 (参考)

Z-Image 模型文件总大小约为 7-8 GB。以下是基于 `us-central1` 区域的估算费用：

*   **Standard (标准存储)**: 约 $0.020 / GB / 月
    *   **存储费**: 8 GB * $0.02 = **$0.16 / 月**
    *   **适用场景**: 频繁访问。Cloud Run 实例启动时会读取模型，建议使用 Standard 级别以避免取回费用并获得最佳性能。
*   **Nearline (近线存储)**: 约 $0.010 / GB / 月
    *   **存储费**: 8 GB * $0.01 = **$0.08 / 月**
    *   **注意**: 虽然存储更便宜，但读取数据会有取回费 ($0.01/GB)。如果您的服务频繁重启（Cloud Run 的特性），Standard 可能反而更便宜且更快。

**结论**: 对于本项目，建议使用 **Standard** 存储级别，月成本极低（不到 $0.20）。

