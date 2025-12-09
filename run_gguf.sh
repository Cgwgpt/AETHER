#!/bin/bash
# Z-Image GGUF推理脚本

# 设置路径
SD_CPP_BIN="./stable-diffusion.cpp/build/bin/sd"
MODEL_FILE="./z_image_turbo-Q4_K_M.gguf"
VAE_FILE="./ae.safetensors"
LLM_FILE="./Qwen3-4B-Q4_K_M.gguf"
OUTPUT_DIR="./output"

# 检查可执行文件
if [ ! -f "$SD_CPP_BIN" ]; then
    echo "错误: 找不到 sd 可执行文件: $SD_CPP_BIN"
    echo "请确保已经编译 stable-diffusion.cpp"
    exit 1
fi

# 检查模型文件
if [ ! -f "$MODEL_FILE" ]; then
    echo "错误: 找不到模型文件: $MODEL_FILE"
    exit 1
fi

# 检查VAE文件
if [ ! -f "$VAE_FILE" ]; then
    echo "警告: 找不到VAE文件: $VAE_FILE"
    echo "请手动下载VAE文件:"
    echo "  访问 https://huggingface.co/black-forest-labs/FLUX.1-dev"
    echo "  下载 ae.safetensors 并放置到当前目录"
    echo ""
    echo "或者使用以下命令下载（需要HF账号登录）:"
    echo "  huggingface-cli download black-forest-labs/FLUX.1-dev ae.safetensors --local-dir ."
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 设置提示词（可从命令行参数获取，默认为示例提示词）
PROMPT="${1:-Astronaut in a jungle, cold color palette, muted colors, detailed, 8k}"

echo "开始生成图像..."
echo "模型: $MODEL_FILE"
echo "VAE: $VAE_FILE"
echo "提示词: $PROMPT"
echo ""

# 构建命令
CMD="$SD_CPP_BIN"
CMD="$CMD --diffusion-model $MODEL_FILE"
CMD="$CMD --vae $VAE_FILE"

# 如果存在LLM文件，添加LLM参数
if [ -f "$LLM_FILE" ]; then
    echo "使用LLM: $LLM_FILE"
    CMD="$CMD --llm $LLM_FILE"
fi

CMD="$CMD -p \"$PROMPT\""
CMD="$CMD --cfg-scale 1.0"
CMD="$CMD -H 1024 -W 1024"
CMD="$CMD -o $OUTPUT_DIR"

# 显示完整命令
echo "执行命令:"
echo "$CMD"
echo ""

# 执行命令
eval $CMD

echo ""
echo "完成! 输出目录: $OUTPUT_DIR"

