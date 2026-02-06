#!/bin/bash
set -e

REVISION="$1"
DEB_VERSION="$2"
DESC="$3"

SRC_BIN="/workspace/src/nginx/objs/nginx"
PKG_DIR="/tmp/nginx_deb_pkg"
OUT="/workspace/artifacts/deb/nginx_${REVISION}_${DEB_VERSION}.deb"

if [ -z "$REVISION" ] || [ -z "$DEB_VERSION" ] || [ -z "$DESC" ]; then
  echo "Usage: package_deb.sh <revision> <deb_version> <description>"
  exit 1
fi

rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/usr/sbin"

cp "$SRC_BIN" "$PKG_DIR/usr/sbin/nginx"

cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: nginx
Version: ${DEB_VERSION}
Architecture: amd64
Maintainer: local-ci <local@ci>
Description: ${DESC}

EOF

dpkg-deb --build "$PKG_DIR" "$OUT"

echo "[INFO] Deb package created: $OUT"