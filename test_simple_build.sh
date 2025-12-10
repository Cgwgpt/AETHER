#!/bin/bash

# 测试简化版Dockerfile构建

echo "=== 测试简化版Dockerfile构建 ==="

# 检查预构建二进制
if [ -f "stable-diffusion.cpp/build/bin/sd" ]; then
    echo "✅ 发现预构建二进制文件"
    file stable-diffusion.cpp/build/bin/sd
    
    # 测试二进制文件
    echo ""
    echo "=== 测试二进制文件 ==="
    ./stable-diffusion.cpp/build/bin/sd --help 2>&1 | head -10
    
    echo ""
    echo "=== 模拟Docker COPY操作 ==="
    mkdir -p /tmp/test-docker
    cp stable-diffusion.cpp/build/bin/sd /tmp/test-docker/
    ls -la /tmp/test-docker/
    
    echo ""
    echo "✅ 简化版Dockerfile应该可以工作"
    echo "使用命令: docker build -f Dockerfile.simple -t aether-simple ."
    
else
    echo "❌ 未发现预构建二进制文件"
    echo "需要先构建: cd stable-diffusion.cpp && cmake . -B build && cmake --build build"
fi

echo ""
echo "=== 检查应用文件 ==="
echo "gradio_app_fixed.py: $([ -f gradio_app_fixed.py ] && echo '✅ 存在' || echo '❌ 不存在')"
echo "Dockerfile.simple: $([ -f Dockerfile.simple ] && echo '✅ 存在' || echo '❌ 不存在')"