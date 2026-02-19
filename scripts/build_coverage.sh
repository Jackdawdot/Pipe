#!/bin/bash
set -e

REVISION="$1"      # Логическая ревизия сборки (например r3)
DEB_VERSION="$2"   # Версия Debian-пакета (например 1.24.0-4)
SRC_DIR="/workspace/src/nginx"

cd "$SRC_DIR"

# Включаем ccache для ускорения повторных сборок.
export CC="ccache gcc"
export CXX="ccache g++"
ccache -z || true   # Обнуляем статистику перед запуском

echo "[INFO] Configuring coverage build..."
# -fprofile-arcs + -ftest-coverage добавляют генерацию .gcno/.gcda файлов.
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

# Сбрасываем предыдущие счётчики, чтобы отчёт отражал только текущий запуск.
lcov --zerocounters --directory . || true

# Базовый снимок покрытия (чтобы tracefile всегда был валидным,
# даже если тесты не вызвали часть кода).
lcov --capture --initial --directory . --output-file coverage_base.info

echo "[INFO] Running smoke test..."
# Примитивный интеграционный тест — проверка конфигурации nginx.
# Именно этот запуск генерирует .gcda файлы.
./objs/nginx -t -c conf/nginx.conf || true

# Захватываем данные после выполнения теста.
lcov --capture --directory . --output-file coverage_run.info

# Объединяем baseline + run.
lcov -a coverage_base.info -a coverage_run.info -o coverage.info

# Убираем системные заголовки и лишние пути.
lcov --remove coverage.info '/usr/*' --output-file coverage.info

echo "[INFO] coverage.info size:"
ls -la coverage.info || true
echo "[INFO] coverage.info first lines:"
head -n 20 coverage.info || true

# Сохраняем HTML-отчёт в артефакты.
REPORT_DIR="/workspace/artifacts/coverage/${REVISION}"
mkdir -p "$REPORT_DIR"

echo "[INFO] Generating HTML report..."
genhtml coverage.info --output-directory "$REPORT_DIR" >/dev/null

echo "[INFO] Extracting line coverage percent..."
echo "[INFO] lcov summary:"
LCOV_SUMMARY="$(lcov --summary coverage.info || true)"
echo "$LCOV_SUMMARY"

# Извлекаем процент покрытия строк из вывода lcov.
SUMMARY="$(echo "$LCOV_SUMMARY" | sed -n 's/^[[:space:]]*[Ll]ines.*: *\([0-9.]\+\)%.*/\1/p')"
if [ -z "$SUMMARY" ]; then
  SUMMARY="$(echo "$LCOV_SUMMARY" | sed -n 's/^[[:space:]]*lines[^:]*: *\([0-9.]\+\)%.*/\1/p')"
fi

if [ -z "$SUMMARY" ]; then
  echo "[ERROR] Could not parse lines coverage percent from lcov summary."
  exit 1
fi

echo "[INFO] Lines coverage: $SUMMARY"

# Сохраняем текущее значение для отчёта build.py.
echo "$SUMMARY" > /workspace/state/current_coverage.txt

LAST_FILE="/workspace/state/last_coverage.txt"
if [ -f "$LAST_FILE" ]; then
  # Убираем возможные пробелы и переводы строки.
  LAST="$(cat "$LAST_FILE" | tr -d ' \r\n\t')"
else
  LAST="0"
fi

# Если файл существовал, но был пуст — считаем прошлое покрытие равным 0.
if [ -z "$LAST" ]; then
  LAST="0"
fi

echo "[INFO] Previous coverage: $LAST"

# Сравнение текущего и предыдущего покрытия.
# Если покрытие уменьшилось — сборка завершается с ошибкой.
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