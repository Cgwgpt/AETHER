#!/bin/bash

# 测试Dockerfile语法

echo "=== 测试Dockerfile语法 ==="

echo ""
echo "=== 检查必需文件 ==="
echo "gradio_app_fixed.py: $([ -f gradio_app_fixed.py ] && echo '✅ 存在' || echo '❌ 不存在')"
echo "src/: $([ -d src ] && echo '✅ 存在' || echo '❌ 不存在')"
echo "inference.py: $([ -f inference.py ] && echo '✅ 存在' || echo '❌ 不存在')"
echo "download_vae.py: $([ -f download_vae.py ] && echo '✅ 存在' || echo '❌ 不存在')"
echo "stable-diffusion.cpp/build/bin/sd: $([ -f stable-diffusion.cpp/build/bin/sd ] && echo '✅ 存在' || echo '❌ 不存在')"

echo ""
echo "=== 验证Dockerfile语法 ==="

# 检查Dockerfile.robust
if [ -f "Dockerfile.robust" ]; then
    echo "✅ Dockerfile.robust 存在"
    echo "检查COPY指令..."
    grep "^COPY" Dockerfile.robust
    echo ""
else
    echo "❌ Dockerfile.robust 不存在"
fi

# 检查Dockerfile.cloud-run
if [ -f "Dockerfile.cloud-run" ]; then
    echo "✅ Dockerfile.cloud-run 存在"
    echo "检查COPY指令..."
    grep "^COPY" Dockerfile.cloud-run
    echo ""
else
    echo "❌ Dockerfile.cloud-run 不存在"
fi

echo "=== 语法检查完成 ==="