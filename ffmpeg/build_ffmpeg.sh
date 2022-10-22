#!/bin/bash

set -e

SCRIPT_DIR=$(cd $(dirname $0); pwd)
ROOT_DIR="${SCRIPT_DIR}/.."
WORK_DIR="${SCRIPT_DIR}"
BUILD_ARCH="wasm"
MY_BUILD_DIR="${ROOT_DIR}/build"
FFMPEG_DIR="${WORK_DIR}/FFmpeg-release-4.3"
BUILD_DIR="${MY_BUILD_DIR}/${BUILD_ARCH}"
INSTALL_DIR="${SCRIPT_DIR}/../prebuild/${BUILD_ARCH}"

if [ -e "${FFMPEG_DIR}" ]; then
  cd "${FFMPEG_DIR}"
else
  echo "not fond path"
  exit
fi

mkdir -p ${BUILD_DIR} 
cd ${BUILD_DIR} 

CPPFLAGS="-D_POSIX_C_SOURCE=200112 -D_XOPEN_SOURCE=600" \
emconfigure  ${FFMPEG_DIR}/configure \
    --prefix="${INSTALL_DIR}" \
    --cc="emcc" \
    --cxx="em++" \
    --ar="emar" \
    --ranlib="emranlib" \
    --target-os=none \
    --enable-cross-compile \
    --enable-lto \
    --cpu=generic \
    --arch=x86_64 \
    --disable-asm \
    --disable-inline-asm \
    --disable-programs \
    --disable-avdevice \
    --disable-doc \
    --disable-postproc  \
    --disable-avfilter \
    --disable-pthreads \
    --disable-w32threads \
    --disable-os2threads \
    --disable-network \
    --disable-logging \
    --disable-everything \
    --enable-gpl \
    --enable-version3 \
    --enable-static \
    --enable-demuxers \
    --enable-parsers \
    --enable-decoder=pcm_mulaw \
    --enable-decoder=pcm_alaw \
    --enable-decoder=adpcm_ima_smjpeg \
    --enable-protocol=file \
    --enable-protocol=pipe \
    --enable-protocol=http \
    --enable-protocol=tcp \
    --enable-decoder=h264 \
    --enable-decoder=hevc

make && make install
