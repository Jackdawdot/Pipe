#!/bin/bash
set -e

REVISION="$1"
DEB_VERSION="$2"
SRC_DIR="/workspace/src/nginx"

cd "$SRC_DIR"

echo "[INFO] Configuring coverage build..."
CCFLAGS="-fprofile-arcs -ftest-coverage" \
LDFLAGS="-fprofile-arcs -ftest-coverage -lgcov" \
./auto/configure --with-http_ssl_module \
  --with-cc-opt="-fprofile-arcs -ftest-coverage" \
  --with-ld-opt="-lgcov"

echo "[INFO] Building..."
make -j"$(nproc)"

echo "[INFO] Running smoke test..."
./objs/nginx -V || true

echo "[INFO] Capturing coverage..."
lcov --capture --directory . --output-file coverage.info
lcov --remove coverage.info '/usr/*' --output-file coverage.info

REPORT_DIR="/workspace/artifacts/coverage/${REVISION}"
mkdir -p "$REPORT_DIR"

echo "[INFO] Generating HTML report..."
genhtml coverage.info --output-directory "$REPORT_DIR"

echo "[INFO] Extracting line coverage percent..."
SUMMARY=$(lcov --summary coverage.info | grep "lines" | awk '{print $2}' | sed 's/%//')

echo "[INFO] Lines coverage: $SUMMARY"

LAST_FILE="/workspace/state/last_coverage.txt"
if [ -f "$LAST_FILE" ]; then
  LAST=$(cat "$LAST_FILE")
else
  LAST="0"
fi

echo "[INFO] Previous coverage: $LAST"

python3 - <<EOF
cur=float("$SUMMARY")
last=float("$LAST")
if cur < last:
    raise SystemExit(1)
EOF

echo "[INFO] Coverage did not decrease. Saving new coverage..."
echo "$SUMMARY" > "$LAST_FILE"

echo "[INFO] Stripping binary..."
strip objs/nginx

/workspace/scripts/package_deb.sh "$REVISION" "1.0.0-coverage" "Nginx coverage build"