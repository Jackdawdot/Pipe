#!/bin/bash
set -e

BUILD_TYPE="$1"
REVISION="$2"
NGINX_TAG="$3"

if [ -z "$BUILD_TYPE" ] || [ -z "$REVISION" ] || [ -z "$NGINX_TAG" ]; then
  echo "Usage: container_build.sh <release|debug|coverage> <revision> <nginx_tag>"
  exit 1
fi

SRC_DIR="/workspace/src/nginx"
ARTIFACTS_DIR="/workspace/artifacts"
STATE_DIR="/workspace/state"

mkdir -p /workspace/src
mkdir -p "$ARTIFACTS_DIR/deb" "$ARTIFACTS_DIR/debug" "$ARTIFACTS_DIR/coverage"

if [ ! -d "$SRC_DIR/.git" ]; then
  echo "[INFO] Cloning nginx..."
  git clone https://github.com/nginx/nginx.git "$SRC_DIR"
fi

cd "$SRC_DIR"
git fetch --tags
git checkout "$NGINX_TAG"

case "$BUILD_TYPE" in
  release)
    /workspace/scripts/build_release.sh "$REVISION"
    ;;
  debug)
    /workspace/scripts/build_debug.sh "$REVISION"
    ;;
  coverage)
    /workspace/scripts/build_coverage.sh "$REVISION"
    ;;
  *)
    echo "Unknown build type: $BUILD_TYPE"
    exit 1
    ;;
esac