#!/bin/bash

set -e
export KBUILD_BUILD_USER=root
export KBUILD_BUILD_HOST=b7ad1189e79e
export KBUILD_BUILD_TIMESTAMP="Fri May 8 05:22:58 UTC 2026"
export KBUILD_BUILD_VERSION=1
# Set correct path
export PATH="$(realpath ../../../clang-r563880c/bin):$PATH"

which clang
clang --version

export KROOT="$(realpath ../)"

export OUT="${KROOT}/out"

export BUILD_OPTIONS=(
    -C "${KROOT}"
    O="${OUT}"
    -j$(nproc --all)
    ARCH=arm64
    CC=clang
    CROSS_COMPILE=aarch64-linux-gnu-
    LLVM=1
    LLVM_IAS=1
    LD=ld.lld
    AR=llvm-ar
    NM=llvm-nm
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
)

export KCFLAGS="-Wno-incompatible-function-pointer-types"

# This is required, audio will not work otherwise
export TARGET_PRODUCT=bangkk

configure() {
  make "${BUILD_OPTIONS[@]}" \
        vendor/holi-qgki_defconfig \
        vendor/ext_config/lineage_moto-holi.config \
        vendor/ext_config/moto-holi-bangkk.config
}

build_image() {
  make "${BUILD_OPTIONS[@]}"
}

build_modules() {
  make "${BUILD_OPTIONS[@]}" modules
}

modules_install() {
  rm -rf "${OUT}/modules_install"
  make "${BUILD_OPTIONS[@]}" modules_install INSTALL_MOD_PATH=modules_install
}


make_anykernel() {
  rm -rf {Image,dtb,dtb.img,dtbo.img,modules/vendor/lib/modules,modules/system/lib/modules}

  mkdir -p modules/{system,vendor}/lib/modules

  cp "${OUT}/arch/arm64/boot/Image" Image

  python mkdtboimg.py create dtbo.img --page_size=4096 "${OUT}/arch/arm64/boot/dts/vendor/qcom/blair-bangkk-evb1-overlay.dtbo"

  cp "${OUT}/arch/arm64/boot/dts/vendor/qcom/blair-moto-bangkk-base.dtb" dtb

  ./place-modules.sh "${OUT}/modules_install/lib/modules"/* modules/vendor/lib/modules "/vendor/lib/modules"

  find modules -name "*.ko" -exec llvm-strip --strip-unneeded -g {} \;

  rm -f "moto-$ZIPPREFIX-anykernel.zip"

  zip -r "moto-$ZIPPREFIX-anykernel.zip" * -x *anykernel.zip place-modules.sh mkdtboimg.py .gitignore .build-placeholder *.txt
}


if [ ! -e .build-placeholder ]; then
  echo "Be in anykernel dir"
  exit 1
fi

configure

[ "$BUILD" = 1 ] && (build_image && build_modules && modules_install)

[ "$ANYKERNEL" = 1 ] && make_anykernel


# Build command
# BUILD=1 ANYKERNEL=1 ZIPPREFIX=test ./build.sh
