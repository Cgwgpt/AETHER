#!/bin/bash
# 重新编译 stable-diffusion.cpp 以确保 Metal 加速正确启用

set -e  # 遇到错误立即退出

cd "$(dirname "$0")"

echo "=========================================="
echo "重新编译 stable-diffusion.cpp (Metal优化)"
echo "=========================================="
echo ""

# 进入 stable-diffusion.cpp 目录
cd stable-diffusion.cpp

# 清理之前的编译
echo "1. 清理之前的编译..."
rm -rf build
mkdir -p build
cd build

# 配置 CMake，明确启用 Metal
echo ""
echo "2. 配置 CMake (启用 Metal)..."
cmake .. \
    -DSD_METAL=ON \
    -DSD_BUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release

# 编译
echo ""
echo "3. 开始编译 (这可能需要几分钟)..."
cmake --build . --config Release -j $(sysctl -n hw.ncpu)

echo ""
echo "=========================================="
echo "编译完成!"
echo "=========================================="
echo ""
echo "验证 Metal 支持:"
otool -L bin/sd | grep -i metal || echo "警告: 未找到 Metal 框架链接"

echo ""
echo "下一步:"
echo "1. 重启 Gradio 应用: bash start_gradio.sh"
echo "2. 测试图像生成速度"
echo ""
