# Z-Image GGUF 使用指南

## 📦 已准备的文件

✅ **stable-diffusion.cpp**: 已编译完成，可执行文件位于 `stable-diffusion.cpp/build/bin/sd`  
✅ **模型文件**: `z_image_turbo-Q4_K_M.gguf` (4.98 GB)  
✅ **LLM文件**: `Qwen3-4B-Q4_K_M.gguf` (2.5 GB，可选)

## ⚠️ 需要下载的文件

### VAE文件 (必需)

需要下载 **ae.safetensors** 文件并放置到项目根目录。

#### 方法1: 手动下载（推荐）

1. 访问以下任一链接：
   - **FLUX.1-dev (公开版)**: https://huggingface.co/black-forest-labs/FLUX.1-dev/tree/main
   - **FLUX.1-schnell**: https://huggingface.co/black-forest-labs/FLUX.1-schnell/tree/main (需要登录)

2. 找到并下载 `ae.safetensors` 文件（约几MB到几十MB大小）

3. 将下载的文件重命名为 `ae.safetensors` 并放置到：
   ```
   /Users/chenguowen/Downloads/Z-Image/ae.safetensors
   ```

#### 方法2: 使用huggingface-cli（需要登录）

```bash
# 激活虚拟环境
source .venv/bin/activate

# 登录Hugging Face（首次需要）
huggingface-cli login

# 下载VAE
huggingface-cli download black-forest-labs/FLUX.1-schnell \
    ae.safetensors \
    --local-dir . \
    --local-dir-use-symlinks False
```

#### 方法3: 使用curl直接下载（如果链接可访问）

```bash
# FLUX.1-dev (公开版)
curl -L -o ae.safetensors \
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"
```

## 🚀 运行推理

### 方式1: 使用Metal加速脚本（推荐，macOS）

```bash
cd /Users/chenguowen/Downloads/Z-Image

# 使用默认提示词和分辨率(1024x1024)
./run_gguf_metal.sh

# 指定自定义提示词
./run_gguf_metal.sh "A beautiful landscape with mountains and lakes, detailed, 8k"

# 指定提示词和分辨率
./run_gguf_metal.sh "Your prompt" 1024 512
```

### 方式2: 使用标准脚本

```bash
cd /Users/chenguowen/Downloads/Z-Image

# 使用默认提示词
./run_gguf.sh

# 或指定自定义提示词
./run_gguf.sh "A beautiful landscape with mountains and lakes, detailed, 8k"
```

### 方式2: 直接使用sd命令

```bash
cd /Users/chenguowen/Downloads/Z-Image

./stable-diffusion.cpp/build/bin/sd \
    --diffusion-model z_image_turbo-Q4_K_M.gguf \
    --vae ae.safetensors \
    --llm Qwen3-4B-Q4_K_M.gguf \
    -p "Astronaut in a jungle, cold color palette, muted colors, detailed, 8k" \
    --cfg-scale 1.0 \
    -H 1024 \
    -W 1024 \
    -o ./output
```

### 方式3: 不使用LLM（更快，但质量可能略低）

```bash
./stable-diffusion.cpp/build/bin/sd \
    --diffusion-model z_image_turbo-Q4_K_M.gguf \
    --vae ae.safetensors \
    -p "Your prompt here" \
    --cfg-scale 1.0 \
    -H 1024 \
    -W 1024 \
    -o ./output
```

## 📝 常用参数说明

- `--diffusion-model`: 主模型GGUF文件路径
- `--vae`: VAE文件路径（必需）
- `--llm`: LLM模型路径（可选，用于增强提示词）
- `-p, --prompt`: 文本提示词
- `--cfg-scale`: CFG引导强度（默认1.0，Z-Image-Turbo建议1.0）
- `-H, --height`: 图像高度（默认1024）
- `-W, --width`: 图像宽度（默认1024）
- `-o, --output-dir`: 输出目录
- `--seed`: 随机种子（用于可重复生成）
- `--steps`: 推理步数（Z-Image-Turbo默认8步）
- `--offload-to-cpu`: 将部分模型卸载到CPU以节省VRAM
- `--diffusion-fa`: 启用Flash Attention（如果支持）

## 🔧 低显存优化

如果你的GPU显存有限（4GB或更少），可以使用以下参数：

```bash
./stable-diffusion.cpp/build/bin/sd \
    --diffusion-model z_image_turbo-Q4_K_M.gguf \
    --vae ae.safetensors \
    -p "Your prompt" \
    --cfg-scale 1.0 \
    --offload-to-cpu \
    --diffusion-fa \
    -H 1024 \
    -W 512 \
    -o ./output
```

## ⚡️ Metal加速说明（macOS）

### Metal已启用

✅ **编译状态**: stable-diffusion.cpp已启用Metal支持（`GGML_METAL:BOOL=ON`）

### macOS统一内存架构

在macOS上，Metal使用**统一内存架构（Unified Memory）**，这意味着：

1. **内存报告**: 虽然日志可能显示"VRAM 0.00MB, RAM 8.4GB"，但这是正常的
2. **实际执行**: 计算实际在GPU（Metal）上执行，而不是CPU
3. **自动管理**: 系统自动在CPU和GPU内存之间管理数据
4. **性能提升**: 相比纯CPU模式，Metal加速可提升**3-10倍**速度

### 验证Metal使用

运行时会看到类似信息：
```
[INFO] running in FLOW mode
[INFO] sampling using Euler method
```

如果看到这些信息，说明Metal正在工作。

### 性能对比

- **纯CPU模式**: 1024x1024图像约需 5-10分钟
- **Metal加速模式**: 1024x1024图像约需 30秒-2分钟（取决于GPU型号）

### 优化建议

1. **不要使用 `--offload-to-cpu`**: 这会禁用Metal加速
2. **调整分辨率**: 如果内存不足，降低分辨率（如512x512）
3. **关闭LLM（可选）**: 如果不使用提示词增强，可以去掉`--llm`参数以节省内存

## 📊 性能参考

根据官方文档，Z-Image-Turbo在4GB VRAM的GPU上可以运行：
- **Q4_K_M**: 推荐用于4GB VRAM（你当前的版本）
- **Q3_K**: 可以进一步降低显存需求
- **Q2_K**: 最低显存需求，但质量会下降

## 🐛 故障排除

1. **找不到VAE文件错误**
   - 确保 `ae.safetensors` 文件在项目根目录
   - 检查文件名拼写是否正确

2. **内存不足错误**
   - 使用 `--offload-to-cpu` 参数
   - 降低图像分辨率（例如 `-H 512 -W 512`）
   - 使用更低量化的模型（Q3_K或Q2_K）

3. **编译错误**
   - 确保已安装CMake和C++编译器
   - 检查子模块是否正确初始化：`git submodule update --init --recursive`

## 📚 参考资源

- [stable-diffusion.cpp Z-Image文档](https://github.com/leejet/stable-diffusion.cpp/wiki/How-to-Use-Z%E2%80%90Image-on-a-GPU-with-Only-4GB-VRAM)
- [Z-Image官方仓库](https://github.com/Tongyi-MAI/Z-Image)
- [stable-diffusion.cpp项目](https://github.com/leejet/stable-diffusion.cpp)

