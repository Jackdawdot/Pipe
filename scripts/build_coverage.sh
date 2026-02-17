#!/bin/bash
set -e

REVISION="$1"
DEB_VERSION="$2"
SRC_DIR="/workspace/src/nginx"

cd "$SRC_DIR"

# Enable ccache (bonus)
export CC="ccache gcc"
export CXX="ccache g++"
ccache -z || true

echo "[INFO] Configuring coverage build..."
CCFLAGS="-fprofile-arcs -ftest-coverage" \
LDFLAGS="-fprofile-arcs -ftest-coverage -lgcov" \
./auto/configure --with-http_ssl_module \
  --with-cc-opt="-fprofile-arcs -ftest-coverage" \
  --with-ld-opt="-lgcov"

echo "[INFO] Building..."
make -j"$(nproc)"

echo "[INFO] ccache stats:"
ccache -s || true

echo "[INFO] Capturing coverage..."
# 1) reset counters (cleanup any previous gcda data)
lcov --zerocounters --directory . || true

# 2) baseline capture (captures .gcno so the tracefile is always valid)
lcov --capture --initial --directory . --output-file coverage_base.info

# 3) run smoke test (must execute instrumented binary to generate .gcda)
echo "[INFO] Running smoke test..."
./objs/nginx -V || true

# 4) post-run capture (captures .gcda)
lcov --capture --directory . --output-file coverage_run.info

# 5) merge baseline + run
lcov -a coverage_base.info -a coverage_run.info -o coverage.info

# 6) filter noise
lcov --remove coverage.info '/usr/*' --output-file coverage.info

REPORT_DIR="/workspace/artifacts/coverage/${REVISION}"
mkdir -p "$REPORT_DIR"

echo "[INFO] Generating HTML report..."
genhtml coverage.info --output-directory "$REPORT_DIR" >/dev/null

echo "[INFO] Extracting line coverage percent..."
SUMMARY_LINE="$(lcov --summary coverage.info | grep -i '^ *lines' || true)"
SUMMARY="$(echo "$SUMMARY_LINE" | sed -n 's/.*: *\([0-9.]\+\)%.*/\1/p')"

if [ -z "$SUMMARY" ]; then
  echo "[ERROR] Could not parse lines coverage from lcov summary."
  echo "[ERROR] lcov summary output was:"
  lcov --summary coverage.info || true
  exit 1
fi

echo "[INFO] Lines coverage: $SUMMARY"

# Always write the current coverage for reporting (so build.py can include it)
echo "$SUMMARY" > /workspace/state/current_coverage.txt

LAST_FILE="/workspace/state/last_coverage.txt"
if [ -f "$LAST_FILE" ]; then
  LAST="$(cat "$LAST_FILE")"
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

/workspace/scripts/package_deb.sh "$REVISION" "$DEB_VERSION" "Nginx coverage build"