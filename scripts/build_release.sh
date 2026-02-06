#!/bin/bash
set -e

REVISION="$1"
DEB_VERSION="$2"
SRC_DIR="/workspace/src/nginx"

cd "$SRC_DIR"

echo "[INFO] Configuring release build..."
./auto/configure --with-http_ssl_module

echo "[INFO] Building..."
make -j"$(nproc)"

echo "[INFO] Stripping binary..."
strip objs/nginx

/workspace/scripts/package_deb.sh "$REVISION" "1.0.0-release" "Nginx release build"
