#!/bin/bash -xe

# must be set before running the script
: ${WORKSPACE?" not set"}

# 默认启用完整版
: ${PLATFORMS:="android-armv7a android-x86 android-arm64-v8a android-x86-64"}
: ${COMMUNITY_BUILD:="true"}
: ${BUILD_THIRDPARTY:="true"}
: ${BUNDLE_DATA:="true"}
: ${STORE_VERSION:="false"}

# 商店版本兼容
if [ "$STORE_VERSION" = "true" ]; then
    echo "STORE_VERSION: COMMUNITY_BUILD=true, CONFIG=Release, BUNDLE_DATA=false"
    export COMMUNITY_BUILD=true
    export CONFIG=Release
    export BUNDLE_DATA=false
else
    export BUNDLE_DATA=true
fi

# 导出关键变量
export PRODUCT_ID=${PRODUCT_ID}
export COMMUNITY_BUILD=${COMMUNITY_BUILD}
export ARCHIVE_ROOT=${WORKSPACE}/archive
export APPLICATION_TYPE=gui
export BUILD_APK=false

LAST_PLATFORM=($PLATFORMS)
LAST_PLATFORM=${LAST_PLATFORM[@]:(-1)}

# 编译多架构
for PLATFORM in $PLATFORMS
do
    if [ "$LAST_PLATFORM" = "$PLATFORM" ]; then
        BUILD_APK=true
    fi
    if [ "$BUILD_THIRDPARTY" = "true" ]; then
        PLATFORM=$PLATFORM ${WORKSPACE}/scripts/build-3rdparty.sh
    fi
    PLATFORM=$PLATFORM ${WORKSPACE}/scripts/build.sh
    export BUNDLE_DATA=false
    export KEEP_TFW_PACKAGE=true
done

# APK签名
if [ "$USE_APK_SIGNER" = "true" ]
then
    ARCHIVE_NAME="$(ls $PWD/archive)"
    if [ -f '../frameworks/keys/jar_signer.sh' ]
    then
        . ../frameworks/keys/jar_signer.sh
    fi
fi
