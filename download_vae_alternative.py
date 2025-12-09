"""尝试从多个来源下载VAE"""
import os
import subprocess

def try_download_with_curl(url, output_path):
    """使用curl下载文件"""
    try:
        result = subprocess.run(
            ["curl", "-L", "-o", output_path, url, "--max-time", "300", "--retry", "3"],
            capture_output=True,
            text=True,
            timeout=320
        )
        if result.returncode == 0 and os.path.exists(output_path):
            size = os.path.getsize(output_path)
            # VAE文件应该至少几MB，如果太小说明下载失败
            if size > 1000000:  # 大于1MB
                return True
        return False
    except Exception as e:
        print(f"下载失败: {e}")
        return False

def download_vae():
    """尝试从多个来源下载VAE"""
    output_path = "./ae.safetensors"
    
    # 方案1: 尝试从Tongyi-MAI/Z-Image-Turbo下载（如果存在）
    print("尝试方案1: Tongyi-MAI/Z-Image-Turbo...")
    url1 = "https://huggingface.co/Tongyi-MAI/Z-Image-Turbo/resolve/main/vae/ae.safetensors"
    if try_download_with_curl(url1, output_path):
        print(f"✓ 下载成功: {output_path}")
        return output_path
    
    # 方案2: 尝试从Comfy-Org/z_image_turbo下载
    print("\n尝试方案2: Comfy-Org/z_image_turbo...")
    url2 = "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/vae/ae.safetensors"
    if try_download_with_curl(url2, output_path):
        print(f"✓ 下载成功: {output_path}")
        return output_path
    
    # 方案3: 尝试下载FLUX.1-dev的VAE（公开版本）
    print("\n尝试方案3: black-forest-labs/FLUX.1-dev...")
    url3 = "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"
    if try_download_with_curl(url3, output_path):
        print(f"✓ 下载成功: {output_path}")
        return output_path
    
    print("\n✗ 所有下载方案都失败了")
    print("\n建议手动下载VAE文件:")
    print("1. 访问 https://huggingface.co/black-forest-labs/FLUX.1-dev")
    print("2. 下载 ae.safetensors 文件")
    print("3. 放置到当前目录: /Users/chenguowen/Downloads/Z-Image/ae.safetensors")
    return None

if __name__ == "__main__":
    download_vae()

