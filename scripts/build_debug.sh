#!/bin/bash
set -e

REVISION="$1"      # Логическая ревизия сборки (например r3)
DEB_VERSION="$2"   # Версия Debian-пакета (например 1.24.0-4)
SRC_DIR="/workspace/src/nginx"

cd "$SRC_DIR"

# Включаем ccache для ускорения повторных сборок.
# PATH уже настроен в Dockerfile, поэтому достаточно переопределить компиляторы.
export CC="ccache gcc"
export CXX="ccache g++"

# Обнуляем статистику перед сборкой (чтобы видеть hits/misses только для текущего запуска).
ccache -z || true

echo "[INFO] Configuring debug build..."
# --with-debug включает отладочную информацию в бинарник.
./auto/configure --with-debug --with-http_ssl_module

echo "[INFO] Building..."
# Параллельная сборка по количеству доступных ядер.
make -j"$(nproc)"

echo "[INFO] ccache stats:"
# Выводим статистику кэша — полезно для демонстрации эффективности ccache.
ccache -s || true

# Гарантируем существование каталога для debug-артефактов.
mkdir -p /workspace/artifacts/debug

echo "[INFO] Extracting debug symbols..."
# Выносим отладочные символы в отдельный файл.
# Это позволяет:
# 1) оставить бинарник компактным,
# 2) сохранить возможность отладки.
objcopy --only-keep-debug objs/nginx "/workspace/artifacts/debug/nginx_${REVISION}.debug"

echo "[INFO] Stripping binary..."
# Удаляем символы из основного бинарника перед упаковкой в deb.
strip objs/nginx

echo "[INFO] Adding debug link..."
# Добавляем в бинарник ссылку на внешний файл с символами.
# Это позволяет отладчику автоматически находить debug-файл.
objcopy --add-gnu-debuglink="/workspace/artifacts/debug/nginx_${REVISION}.debug" objs/nginx

# Упаковка бинарника в Debian-пакет.
 /workspace/scripts/package_deb.sh "$REVISION" "$DEB_VERSION" "Nginx debug build (symbols separated)"