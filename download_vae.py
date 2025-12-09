"""下载VAE文件ae.safetensors"""
import os
from huggingface_hub import hf_hub_download

def download_vae():
    """从black-forest-labs/FLUX.1-schnell下载VAE"""
    try:
        print("正在从 black-forest-labs/FLUX.1-schnell 下载 ae.safetensors...")
        local_file = hf_hub_download(
            repo_id="black-forest-labs/FLUX.1-schnell",
            filename="ae.safetensors",
            local_dir="./",
            local_dir_use_symlinks=False,
        )
        print(f"✓ 下载成功: {local_file}")
        return local_file
    except Exception as e:
        print(f"✗ 下载失败: {e}")
        print("\n尝试备用方案：从Tongyi-MAI/Z-Image-Turbo下载...")
        try:
            local_file = hf_hub_download(
                repo_id="Tongyi-MAI/Z-Image-Turbo",
                filename="ae.safetensors",
                local_dir="./",
                local_dir_use_symlinks=False,
            )
            print(f"✓ 备用方案下载成功: {local_file}")
            return local_file
        except Exception as e2:
            print(f"✗ 备用方案也失败: {e2}")
            return None

if __name__ == "__main__":
    download_vae()

