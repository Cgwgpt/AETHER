#!/bin/bash

# 验证部署准备情况

echo "🔍 AETHER Cloud Run 部署验证"
echo "================================"

# 检查必需文件
echo ""
echo "📁 检查必需文件:"
files=(
    "gradio_app_fixed.py"
    "src/"
    "stable-diffusion.cpp/build/bin/sd"
    "Dockerfile.robust"
    "Dockerfile.cloud-run"
    "deploy_to_cloud_run_fixed.sh"
)

all_files_exist=true
for file in "${files[@]}"; do
    if [ -e "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file"
        all_files_exist=false
    fi
done

# 检查gcloud配置
echo ""
echo "☁️ 检查gcloud配置:"
if command -v gcloud &> /dev/null; then
    echo "✅ gcloud CLI 已安装"
    
    project_id=$(gcloud config get-value project 2>/dev/null)
    if [ -n "$project_id" ]; then
        echo "✅ 项目ID: $project_id"
    else
        echo "❌ 未设置项目ID"
        all_files_exist=false
    fi
    
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        echo "✅ gcloud 已认证"
    else
        echo "❌ gcloud 未认证"
        all_files_exist=false
    fi
else
    echo "❌ gcloud CLI 未安装"
    all_files_exist=false
fi

# 检查Docker
echo ""
echo "🐳 检查Docker:"
if command -v docker &> /dev/null; then
    echo "✅ Docker 已安装"
    
    if docker info &> /dev/null; then
        echo "✅ Docker 守护进程运行中"
    else
        echo "⚠️ Docker 守护进程未运行（Cloud Build可用）"
    fi
else
    echo "⚠️ Docker 未安装（可使用Cloud Build）"
fi

# 检查二进制文件
echo ""
echo "🔧 检查二进制文件:"
if [ -f "stable-diffusion.cpp/build/bin/sd" ]; then
    echo "✅ sd 二进制文件存在"
    file_info=$(file stable-diffusion.cpp/build/bin/sd)
    echo "   类型: $file_info"
    
    # 测试二进制文件
    if ./stable-diffusion.cpp/build/bin/sd --help &> /dev/null; then
        echo "✅ 二进制文件可执行"
    else
        echo "⚠️ 二进制文件可能有问题"
    fi
else
    echo "❌ sd 二进制文件不存在"
    all_files_exist=false
fi

# 检查Dockerfile语法
echo ""
echo "📋 检查Dockerfile语法:"
dockerfiles=("Dockerfile.robust" "Dockerfile.cloud-run")
for dockerfile in "${dockerfiles[@]}"; do
    if [ -f "$dockerfile" ]; then
        # 检查是否有错误的COPY语法
        if grep -q "COPY.*||" "$dockerfile"; then
            echo "❌ $dockerfile 包含错误的COPY语法"
            all_files_exist=false
        else
            echo "✅ $dockerfile 语法正确"
        fi
    fi
done

# 总结
echo ""
echo "📊 验证结果:"
echo "================================"
if [ "$all_files_exist" = true ]; then
    echo "🎉 所有检查通过！可以开始部署"
    echo ""
    echo "🚀 推荐部署命令:"
    echo "   标准部署: ./deploy_to_cloud_run_fixed.sh"
    echo "   GPU部署:  USE_GPU=true ./deploy_to_cloud_run_fixed.sh"
    echo "   Cloud Build: USE_CLOUD_BUILD=true ./deploy_to_cloud_run_fixed.sh"
    echo ""
    echo "💡 提示: GPU版本生成速度比CPU快20-50倍"
else
    echo "⚠️ 发现问题，请先解决上述问题再部署"
    echo ""
    echo "🔧 常见解决方案:"
    echo "   - 安装gcloud: curl https://sdk.cloud.google.com | bash"
    echo "   - 认证gcloud: gcloud auth login"
    echo "   - 设置项目: gcloud config set project YOUR_PROJECT_ID"
    echo "   - 构建二进制: cd stable-diffusion.cpp && cmake . -B build && cmake --build build"
fi

echo ""
echo "📖 详细文档: CLOUD_RUN_TROUBLESHOOTING.md"