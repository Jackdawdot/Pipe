#!/bin/bash
set -e

REVISION="$1"
DEB_VERSION="$2"
SRC_DIR="/workspace/src/nginx"

cd "$SRC_DIR"

export CC="ccache gcc"
export CXX="ccache g++"
ccache -z || true   # Сбрасываем статистику перед запуском

echo "[INFO] Configuring release build..."

# Release-конфигурация:
# -O2 — оптимизация
# -DNDEBUG — отключение assert'ов
# -Wl,--as-needed — уменьшение лишних зависимостей при линковке
./auto/configure --with-http_ssl_module \
  --with-cc-opt="-O2 -DNDEBUG" \
  --with-ld-opt="-Wl,--as-needed"

echo "[INFO] Building..."
# Параллельная сборка по количеству доступных CPU.
make -j"$(nproc)"

echo "[INFO] ccache stats:"
ccache -s || true

echo "[INFO] Stripping binary..."
strip objs/nginx

 /workspace/scripts/package_deb.sh "$REVISION" "$DEB_VERSION" "Nginx release build"