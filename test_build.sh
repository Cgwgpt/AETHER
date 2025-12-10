#!/bin/bash

# 测试构建脚本 - 验证文件结构

echo "=== 检查stable-diffusion.cpp目录结构 ==="
ls -la stable-diffusion.cpp/

echo ""
echo "=== 检查CMakeLists.txt ==="
if [ -f "stable-diffusion.cpp/CMakeLists.txt" ]; then
    echo "✅ CMakeLists.txt 存在"
    head -10 stable-diffusion.cpp/CMakeLists.txt
else
    echo "❌ CMakeLists.txt 不存在"
fi

echo ""
echo "=== 检查ggml子模块 ==="
if [ -d "stable-diffusion.cpp/ggml" ]; then
    echo "✅ ggml目录存在"
    ls -la stable-diffusion.cpp/ggml/ | head -10
else
    echo "❌ ggml目录不存在"
fi

echo ""
echo "=== 检查构建目录 ==="
if [ -d "stable-diffusion.cpp/build" ]; then
    echo "✅ build目录存在"
    ls -la stable-diffusion.cpp/build/
else
    echo "❌ build目录不存在"
fi

echo ""
echo "=== 检查二进制文件 ==="
if [ -f "stable-diffusion.cpp/build/bin/sd" ]; then
    echo "✅ sd二进制文件存在"
    file stable-diffusion.cpp/build/bin/sd
else
    echo "❌ sd二进制文件不存在"
fi

echo ""
echo "=== 检查应用文件 ==="
echo "gradio_app_fixed.py: $([ -f gradio_app_fixed.py ] && echo '✅ 存在' || echo '❌ 不存在')"
echo "Dockerfile.cloud-run: $([ -f Dockerfile.cloud-run ] && echo '✅ 存在' || echo '❌ 不存在')"

echo ""
echo "=== 构建准备检查完成 ==="