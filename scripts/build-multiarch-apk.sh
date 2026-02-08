#!/bin/bash -xe

# must be set before running the script（官方要求：必须设置WORKSPACE）
: ${WORKSPACE?"WORKSPACE environment variable is not set"}

# ======================== 核心修改：对齐官方GUI版默认配置 ========================
# 官方要求：GUI版需启用COMMUNITY_BUILD和BUNDLE_DATA，确保测试资源打包
: ${PLATFORMS:="android-armv7a android-x86 android-arm64-v8a android-x86-64"}  # 官方支持的架构
: ${COMMUNITY_BUILD:="true"}       # 默认启用完整版（官方GUI版必需）
: ${BUILD_THIRDPARTY:="true"}      # 默认构建第三方依赖
: ${BUNDLE_DATA:="true"}           # 默认打包测试资源（解决"file not found"）
: ${PRODUCT_ID:="gfxbench"}        # 官方指定产品ID
: ${STORE_VERSION:="false"}        # 非商店版本（商店版本需单独配置）

# 商店版本兼容逻辑（保留官方逻辑）
if [ "$STORE_VERSION" = "true" ]; then
    echo "STORE_VERSION: COMMUNITY_BUILD=true, CONFIG=Release, BUNDLE_DATA=false"
    export COMMUNITY_BUILD=true
    export CONFIG=Release
    export BUNDLE_DATA=false
else
    # 非商店版本：强制打包资源（覆盖默认值，确保测试资源不丢失）
    export BUNDLE_DATA=true
fi

# ======================== 路径修改：对应官方输出目录tfw-pkg ========================
# 官方说明：APK和测试资源默认输出到tfw-pkg，而非archive
export ARCHIVE_ROOT=${WORKSPACE}/tfw-pkg
export APPLICATION_TYPE=gui        # 固定为GUI版（带测试选择器，官方推荐）
export BUILD_APK=false             # 初始关闭APK打包，最后一个架构再启用

# 获取最后一个架构（确保所有架构编译完成后再打包APK）
LAST_PLATFORM=($PLATFORMS)
LAST_PLATFORM=${LAST_PLATFORM[@]:(-1)}

# ======================== 构建逻辑：按官方两步法执行 ========================
# 1. 编译多架构原生库；2. 最后一个架构编译时生成APK（包含所有架构）
for PLATFORM in $PLATFORMS
do
    # 仅在最后一个架构编译时启用APK打包（官方要求：单APK包含多架构）
    if [ "$LAST_PLATFORM" = "$PLATFORM" ]; then
        BUILD_APK=true
    fi
    
    # 构建第三方依赖（官方第一步：build-3rdparty.sh）
    if [ "$BUILD_THIRDPARTY" = "true" ]; then
        PLATFORM=$PLATFORM ${WORKSPACE}/scripts/build-3rdparty.sh
    fi
    
    # 构建GFXBench主程序（官方第二步：build.sh）
    PLATFORM=$PLATFORM ${WORKSPACE}/scripts/build.sh
    
    # 资源仅复制一次（避免重复拷贝，加速构建）
    export BUNDLE_DATA=false
    # 保留tfw-pkg目录（避免后续架构编译覆盖）
    export KEEP_TFW_PACKAGE=true
done

# ======================== 签名逻辑：使用官方默认debug.jks ========================
# 官方说明：默认提供app_android/debug.jks用于签名，无需额外配置
if [ "$USE_APK_SIGNER" = "true" ]
then
    # 适配tfw-pkg路径（原archive路径废弃）
    if [ -d "$ARCHIVE_ROOT" ]; then
        ARCHIVE_NAME=$(ls $ARCHIVE_ROOT | grep -E "gfxbench.*\.apk" | head -n 1)
    fi
    # 执行官方签名脚本（若存在）
    if [ -f "${WORKSPACE}/frameworks/keys/jar_signer.sh" ]
    then
        . ${WORKSPACE}/frameworks/keys/jar_signer.sh
    fi
fi
