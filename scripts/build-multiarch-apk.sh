#!/bin/bash -xe

# must be set before running the script
: ${WORKSPACE?" not set"}

# ======================== 核心修改：默认编译完整版 ========================
# 1. 支持的架构（保留原有，可按需删减）
: ${PLATFORMS:="android-armv7a android-x86 android-arm64-v8a android-x86-64"}
# 2. 开启社区版（完整版），默认true（原默认false是精简版）
: ${COMMUNITY_BUILD:="true"}
# 3. 强制构建第三方依赖（确保测试场景的资源库被编译）
: ${BUILD_THIRDPARTY:="true"}
# 4. 显式指定产品ID为完整版（避免默认走corporate精简版）
: ${PRODUCT_ID:="gfxbench"}
# 5. 补充STORE_VERSION默认值，避免未定义报错
: ${STORE_VERSION:="false"}

# 商店版本兼容逻辑（保留，同时确保完整版配置）
if [ "$STORE_VERSION" = "true" ]; then
    echo "STORE_VERSION: COMMUNITY_BUILD=true, CONFIG=Release, BUNDLE_DATA=false"
    export COMMUNITY_BUILD=true
    export CONFIG=Release
    export BUNDLE_DATA=false
else
    # 非商店版本：强制绑定所有测试场景资源（核心！精简版就是这里false）
    export BUNDLE_DATA=true
fi

# 导出关键环境变量，确保编译脚本识别完整版配置
export PRODUCT_ID=${PRODUCT_ID}
export COMMUNITY_BUILD=${COMMUNITY_BUILD}
export ARCHIVE_ROOT=${WORKSPACE}/archive
export APPLICATION_TYPE=gui  # 启用GUI版，包含所有测试场景入口
export BUILD_APK=false

# 提取最后一个架构（用于最终打包APK）
LAST_PLATFORM=($PLATFORMS)
LAST_PLATFORM=${LAST_PLATFORM[@]:(-1)}

# 编译多架构原生测试代码，并收集资源（关键：BUNDLE_DATA=true会打包所有测试场景）
# 最后一个架构编译时触发APK打包（包含所有架构）
for PLATFORM in $PLATFORMS
do
    if [ "$LAST_PLATFORM" = "$PLATFORM" ]; then
        BUILD_APK=true
    fi
    if [ "$BUILD_THIRDPARTY" = "true" ]; then
        PLATFORM=$PLATFORM ${WORKSPACE}/scripts/build-3rdparty.sh
    fi
    PLATFORM=$PLATFORM ${WORKSPACE}/scripts/build.sh
    # 仅第一次编译时绑定数据，后续架构复用（避免重复拷贝，提升效率）
    export BUNDLE_DATA=false
    export KEEP_TFW_PACKAGE=true
done

# APK签名逻辑（保留原有，不影响功能）
if [ "$USE_APK_SIGNER" = "true" ]
then
    ARCHIVE_NAME="$(ls $PWD/archive)"
    if [ -f '../frameworks/keys/jar_signer.sh' ]
    then
        . ../frameworks/keys/jar_signer.sh
    fi
fi
