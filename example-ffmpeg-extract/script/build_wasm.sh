#!/bin/bash

set -e

SCRIPT_DIR=$(cd $(dirname $0); pwd)
WORK_DIR="${SCRIPT_DIR}/.."
ROOT_DIR="${SCRIPT_DIR}/../.."
BUILD_ARCH="wasm"
LIBS_DIR="${ROOT_DIR}/prebuild/${BUILD_ARCH}"
DIST_DIR="${SCRIPT_DIR}/../wasm/dist"

mkdir -p ${DIST_DIR} 


em++ -O3 ${WORK_DIR}/src/extract.cpp  -I ${LIBS_DIR}/include ${LIBS_DIR}/lib/libavformat.a ${LIBS_DIR}/lib/libavcodec.a ${LIBS_DIR}/lib/libswscale.a ${LIBS_DIR}/lib/libswresample.a ${LIBS_DIR}/lib/libavutil.a \
-lworkerfs.js \
--pre-js ${WORK_DIR}/src/worker.js \
-s WASM=1 -o ${DIST_DIR}/extract.js \
-s EXTRA_EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]' \
-s EXPORTED_FUNCTIONS='["_main", "_destroy", "_extract_image","_extract_audio"]' \
-s ALLOW_MEMORY_GROWTH=1  \
-s TOTAL_MEMORY=33554432
