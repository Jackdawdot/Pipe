#!/bin/bash
set -e

REVISION="$1"
SRC_DIR="/workspace/src/nginx"

cd "$SRC_DIR"

echo "[INFO] Configuring debug build..."
./auto/configure --with-debug --with-http_ssl_module

echo "[INFO] Building..."
make -j"$(nproc)"

echo "[INFO] Extracting debug symbols..."
objcopy --only-keep-debug objs/nginx /workspace/artifacts/debug/nginx_${REVISION}.debug

echo "[INFO] Stripping binary..."
strip objs/nginx

echo "[INFO] Adding debug link..."
objcopy --add-gnu-debuglink=/workspace/artifacts/debug/nginx_${REVISION}.debug objs/nginx

/workspace/scripts/package_deb.sh "$REVISION" "debug" "Nginx debug build (symbols separated)"
