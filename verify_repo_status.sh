#!/bin/bash

echo "🔍 验证AETHER仓库状态"
echo "========================"

echo ""
echo "📁 检查关键文件是否在仓库中:"
key_files=(
    "deploy_to_cloud_run_fixed.sh"
    "Dockerfile.robust"
    "Dockerfile.cloud-run" 
    "Dockerfile.simple"
    "gradio_app_fixed.py"
    "validate_deployment.sh"
    "CLOUD_RUN_TROUBLESHOOTING.md"
    "DEPLOY_GUIDE.md"
)

for file in "${key_files[@]}"; do
    if git ls-files | grep -q "^$file$"; then
        echo "✅ $file (在仓库中)"
    else
        echo "❌ $file (不在仓库中)"
    fi
done

echo ""
echo "🌐 检查远程仓库同步状态:"
git fetch origin &>/dev/null

local_commit=$(git rev-parse HEAD)
remote_commit=$(git rev-parse origin/main)

if [ "$local_commit" = "$remote_commit" ]; then
    echo "✅ 本地与远程仓库同步"
else
    echo "⚠️ 本地与远程仓库不同步"
    echo "   本地: $local_commit"
    echo "   远程: $remote_commit"
fi

echo ""
echo "📊 最新提交:"
git log --oneline -1

echo ""
echo "🔗 仓库URL:"
git remote get-url origin

echo ""
echo "✅ 验证完成！"