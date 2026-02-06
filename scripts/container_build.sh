#!/bin/bash
set -e

TYPE="$1"
REVISION="$2"
DEB_VERSION="$3"

case "$TYPE" in
  release)
    /workspace/scripts/build_release.sh "$REVISION" "$DEB_VERSION"
    ;;
  debug)
    /workspace/scripts/build_debug.sh "$REVISION" "$DEB_VERSION"
    ;;
  coverage)
    /workspace/scripts/build_coverage.sh "$REVISION" "$DEB_VERSION"
    ;;
  *)
    echo "Unknown build type: $TYPE"
    exit 1
    ;;
esac
