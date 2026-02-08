#!/bin/bash

# GitHub Actions专用的GFXBench多架构构建脚本
# 简化版，适配云端环境

set -e  # 遇到错误就停止
echo "🚀 开始多架构Android构建..."

# 检查必需的环境变量
echo "🔍 检查环境变量..."
if [ -z "$WORKSPACE" ]; then
    WORKSPACE=$(pwd)
    echo "⚠️  WORKSPACE未设置，使用当前目录: $WORKSPACE"
fi

if [ -z "$PLATFORMS" ]; then
    PLATFORMS="android-arm64-v8a android-armv7a"
    echo "⚠️  PLATFORMS未设置，使用默认: $PLATFORMS"
fi

# GitHub Actions特有设置
if [ -n "$GITHUB_ACTIONS" ]; then
    echo "🌐 GitHub Actions环境检测到"
    # 使用更短的构建路径避免问题
    BUILD_ROOT="/tmp/gfxbench_build"
    mkdir -p "$BUILD_ROOT"
    ln -sf "$WORKSPACE" "$BUILD_ROOT/src" 2>/dev/null || true
    export WORKSPACE="$BUILD_ROOT/src"
    cd "$BUILD_ROOT"
fi

# 设置默认值
: ${CONFIG:="Release"}
: ${APPLICATION_TYPE:="gui"}
: ${COMMUNITY_BUILD:="false"}
: ${BUILD_THIRDPARTY:="true"}
: ${BUNDLE_DATA:="true"}

echo "📋 构建配置:"
echo "  WORKSPACE:      $WORKSPACE"
echo "  PLATFORMS:      $PLATFORMS"
echo "  CONFIG:         $CONFIG"
echo "  APPLICATION_TYPE: $APPLICATION_TYPE"
echo "  BUILD_THIRDPARTY: $BUILD_THIRDPARTY"

# 如果是商店版本
if [ "$STORE_VERSION" = "true" ]; then
    echo "🛒 商店版本构建"
    export COMMUNITY_BUILD=false
    export CONFIG=Release
    export BUNDLE_DATA=false
fi

# 设置输出目录
export ARCHIVE_ROOT="${WORKSPACE}/archive"
export KEEP_TFW_PACKAGE=true
export OUTPUT_DIR="${WORKSPACE}/tfw-pkg"
mkdir -p "$ARCHIVE_ROOT" "$OUTPUT_DIR"

# 转换平台字符串为数组
IFS=' ' read -ra PLATFORM_ARRAY <<< "$PLATFORMS"
LAST_PLATFORM="${PLATFORM_ARRAY[-1]}"

echo "🔄 开始构建平台: ${#PLATFORM_ARRAY[@]} 个平台"

# 为每个平台构建
for CURRENT_PLATFORM in "${PLATFORM_ARRAY[@]}"; do
    echo ""
    echo "========================================"
    echo "🏗️  构建平台: $CURRENT_PLATFORM"
    echo "========================================"
    
    # 设置当前平台
    export PLATFORM="$CURRENT_PLATFORM"
    
    # 判断是否为最后一个平台（是否生成APK）
    if [ "$LAST_PLATFORM" = "$CURRENT_PLATFORM" ]; then
        export BUILD_APK=true
        echo "🎯 这是最后一个平台，将生成APK"
    else
        export BUILD_APK=false
        echo "📦 中间平台，只构建库文件"
    fi
    
    # 构建第三方库（第一步）
    if [ "$BUILD_THIRDPARTY" = "true" ]; then
        echo "📚 第一步：构建第三方库..."
        cd "$WORKSPACE"
        
        # 检查脚本是否存在
        if [ ! -f "scripts/build-3rdparty.sh" ]; then
            echo "❌ 错误: 找不到 scripts/build-3rdparty.sh"
            exit 1
        fi
        
        # 执行构建
        bash scripts/build-3rdparty.sh 2>&1 | tee "$ARCHIVE_ROOT/build-3rdparty-$PLATFORM.log"
        
        # 检查结果
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            echo "❌ 第三方库构建失败！查看日志: $ARCHIVE_ROOT/build-3rdparty-$PLATFORM.log"
            exit 1
        fi
        
        echo "✅ 第三方库构建完成"
    fi
    
    # 构建主程序（第二步）
    echo "📱 第二步：构建GFXBench主程序..."
    cd "$WORKSPACE"
    
    if [ ! -f "scripts/build.sh" ]; then
        echo "❌ 错误: 找不到 scripts/build.sh"
        exit 1
    fi
    
    # 执行构建
    bash scripts/build.sh 2>&1 | tee "$ARCHIVE_ROOT/build-main-$PLATFORM.log"
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "❌ 主程序构建失败！查看日志: $ARCHIVE_ROOT/build-main-$PLATFORM.log"
        exit 1
    fi
    
    echo "✅ 平台 $PLATFORM 构建完成"
    
    # 后续构建不再复制数据（节省时间）
    export BUNDLE_DATA=false
    
done

echo ""
echo "========================================"
echo "🎉 所有平台构建完成！"
echo "========================================"

# 检查生成的APK文件
echo "🔍 查找APK文件..."
APK_FILES=$(find "$WORKSPACE" -name "*.apk" -type f 2>/dev/null)

if [ -n "$APK_FILES" ]; then
    echo "✅ 找到APK文件:"
    for apk in $APK_FILES; do
        apk_size=$(stat -c%s "$apk" 2>/dev/null || stat -f%z "$apk" 2>/dev/null)
        apk_size_mb=$((apk_size / 1024 / 1024))
        echo "  📦 $apk (${apk_size_mb}MB)"
        
        # 复制到输出目录
        cp "$apk" "$OUTPUT_DIR/" 2>/dev/null || true
    done
else
    echo "⚠️  没有找到APK文件，检查以下目录:"
    echo "  - $WORKSPACE/tfw-pkg/"
    echo "  - $WORKSPACE/out/build/"
    
    # 列出可能包含APK的目录
    find "$WORKSPACE" -type d -name "*apk*" -o -name "*tfw*" | head -10
fi

# APK签名（如果需要）
if [ "$USE_APK_SIGNER" = "true" ]; then
    echo "🔏 开始APK签名..."
    
    # 检查签名脚本
    if [ -f "../frameworks/keys/jar_signer.sh" ]; then
        source ../frameworks/keys/jar_signer.sh
    elif [ -f "$WORKSPACE/app_android/debug.jks" ]; then
        echo "🔑 使用debug.jks进行签名"
        # 这里可以添加签名命令
    else
        echo "⚠️  没有找到签名密钥，跳过签名"
    fi
fi

# 输出总结
echo ""
echo "📊 构建总结:"
echo "  ✅ 构建的平台数: ${#PLATFORM_ARRAY[@]}"
echo "  📁 输出目录: $OUTPUT_DIR"
echo "  📁 归档目录: $ARCHIVE_ROOT"
echo "  📄 构建日志: $ARCHIVE_ROOT/build-*.log"

# 列出最终的文件
if [ -d "$OUTPUT_DIR" ]; then
    echo ""
    echo "📁 输出目录内容:"
    ls -la "$OUTPUT_DIR/" 2>/dev/null || echo "无法访问输出目录"
fi

echo ""
echo "🎊 构建流程完成！"
