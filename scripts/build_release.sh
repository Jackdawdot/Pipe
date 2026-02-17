#!/bin/bash
set -e

REVISION="$1"
DEB_VERSION="$2"
SRC_DIR="/workspace/src/nginx"

cd "$SRC_DIR"

# Use ccache (bonus) and reset stats for visibility
export CC="ccache gcc"
export CXX="ccache g++"
ccache -z || true

echo "[INFO] Configuring release build..."
./auto/configure --with-http_ssl_module \
  --with-cc-opt="-O2 -DNDEBUG" \
  --with-ld-opt="-Wl,--as-needed"

echo "[INFO] Building..."
make -j"$(nproc)"

echo "[INFO] ccache stats:"
ccache -s || true

echo "[INFO] Stripping binary..."
strip objs/nginx

/workspace/scripts/package_deb.sh "$REVISION" "$DEB_VERSION" "Nginx release build"