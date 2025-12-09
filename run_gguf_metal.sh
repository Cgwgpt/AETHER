#!/bin/bash
# Z-Image GGUF推理脚本 - Metal加速优化版

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
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 设置提示词（可从命令行参数获取，默认为示例提示词）
PROMPT="${1:-Astronaut in a jungle, cold color palette, muted colors, detailed, 8k}"

echo "=========================================="
echo "Z-Image GGUF 推理 - Metal加速模式"
echo "=========================================="
echo "模型: $MODEL_FILE"
echo "VAE: $VAE_FILE"
if [ -f "$LLM_FILE" ]; then
    echo "LLM: $LLM_FILE"
fi
echo "提示词: $PROMPT"
echo ""

# 检查Metal是否可用
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "检测到macOS系统，将使用Metal加速"
    # macOS上Metal会自动使用统一内存架构
    # 报告可能显示RAM，但实际计算在GPU上执行
fi

# 构建命令
CMD="$SD_CPP_BIN"
CMD="$CMD --diffusion-model $MODEL_FILE"
CMD="$CMD --vae $VAE_FILE"

# 如果存在LLM文件，添加LLM参数
if [ -f "$LLM_FILE" ]; then
    CMD="$CMD --llm $LLM_FILE"
fi

CMD="$CMD -p \"$PROMPT\""
CMD="$CMD --cfg-scale 1.0"

# Metal优化参数
# 注意：不要使用 --offload-to-cpu，这会禁用Metal加速
# 在macOS上，Metal使用统一内存，会自动管理内存

# 分辨率设置（可根据GPU显存调整）
HEIGHT="${2:-1024}"
WIDTH="${3:-1024}"
CMD="$CMD -H $HEIGHT -W $WIDTH"

# Flash Attention (如果支持)
CMD="$CMD --diffusion-fa"

# 输出目录
CMD="$CMD -o $OUTPUT_DIR"

# 线程数（Metal会自动使用GPU，CPU线程数影响较小）
# CMD="$CMD -t 4"

# 显示完整命令
echo "执行命令:"
echo "$CMD"
echo ""
echo "提示：在macOS上，Metal使用统一内存架构"
echo "     虽然报告显示RAM，但计算实际在GPU上执行"
echo "=========================================="
echo ""

# 记录开始时间
START_TIME=$(date +%s)

# 执行命令
eval $CMD

# 记录结束时间
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=========================================="
echo "完成! 生成耗时: ${DURATION}秒"
echo "输出目录: $OUTPUT_DIR"
echo "=========================================="

