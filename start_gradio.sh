#!/bin/bash
# 启动Z-Image-Turbo Gradio Web界面

cd "$(dirname "$0")"

# 激活虚拟环境
if [ -d ".venv" ]; then
    source .venv/bin/activate
else
    echo "错误: 未找到虚拟环境 .venv"
    echo "请先运行: python3.12 -m venv .venv && source .venv/bin/activate && pip install -e . gradio"
    exit 1
fi

# 检查必需文件
MISSING=0
if [ ! -f "./stable-diffusion.cpp/build/bin/sd" ]; then
    echo "警告: 未找到 sd 可执行文件"
    MISSING=1
fi
if [ ! -f "./z_image_turbo-Q4_K_M.gguf" ]; then
    echo "警告: 未找到模型文件 z_image_turbo-Q4_K_M.gguf"
    MISSING=1
fi
if [ ! -f "./ae.safetensors" ]; then
    echo "警告: 未找到VAE文件 ae.safetensors"
    MISSING=1
fi

if [ $MISSING -eq 1 ]; then
    echo ""
    echo "请确保所有必需文件已准备好。"
    echo ""
fi

# 启动Gradio界面
echo "正在启动 AETHER Web界面..."
echo "界面将在 http://localhost:7860 打开"
echo "按 Ctrl+C 停止服务"
echo ""

python gradio_app.py

