# Deploying AETHER to Google Cloud Run

This guide describes how to deploy AETHER to Google Cloud Run, a serverless platform for running containers.

## Prerequisites

1.  **Google Cloud Project**: You need a GCP project with billing enabled.
2.  **gcloud CLI**: Installed and authenticated (`gcloud auth login`).
3.  **Docker**: Installed locally for building the image.

## 1. Prepare Model Storage (GCS FUSE)

Since AETHER models are large (>7GB), we cannot include them in the Docker image. Instead, we will store them in a Google Cloud Storage (GCS) bucket and mount it to the Cloud Run container using Cloud Storage FUSE.

1.  **Create a GCS Bucket**:
    ```bash
    export BUCKET_NAME=z-image-models
    export REGION=us-central1  # Choose a region with GPU availability if needed

    gcloud storage buckets create gs://$BUCKET_NAME --location=$REGION
    ```

2.  **Upload Models**:
    Upload your local `.gguf` and `.safetensors` files to the bucket root.
    ```bash
    gcloud storage cp *.gguf gs://$BUCKET_NAME/
    gcloud storage cp *.safetensors gs://$BUCKET_NAME/
    ```

## 2. Build and Push Docker Image

1.  **Configure Artifact Registry**:
    ```bash
    export REPO_NAME=z-image-repo
    gcloud artifacts repositories create $REPO_NAME --repository-format=docker \
        --location=$REGION --description="Z-Image Docker Repository"
    
    gcloud auth configure-docker $REGION-docker.pkg.dev
    ```

2.  **Build and Push**:
    ```bash
    export IMAGE_URI=$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/z-image:latest
    
    # Build for linux/amd64 (required for Cloud Run)
    docker build --platform linux/amd64 -t $IMAGE_URI .
    
    docker push $IMAGE_URI
    ```

## 3. Deploy to Cloud Run

We will deploy using the `gcloud` command. We need to configure the GCS volume mount.

### Option A: CPU Deployment (Lower Cost)

Suitable for testing, but generation will be slow.

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

### Option B: GPU Deployment (High Performance)

Requires a region with Cloud Run GPU availability.

```bash
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

## 4. Access the Application

After deployment, Cloud Run will provide a URL (e.g., `https://z-image-xyz.a.run.app`). Open this URL in your browser to access the Z-Image Web UI.

## Important Notes

*   **Cold Starts**: Large containers with GCS mounts may take a minute to start.
*   **Cost**: You pay for CPU/Memory/GPU while the request is processing (and potentially min instances). GCS storage costs apply.
*   **Region**: Ensure your GCS bucket and Cloud Run service are in the same region to minimize latency and data transfer costs.
