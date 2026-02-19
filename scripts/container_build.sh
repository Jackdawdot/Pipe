#!/bin/bash
set -e
# set -e — при любой ошибке внутри вызываемых скриптов выполнение немедленно прекращается.

TYPE="$1"        # Тип сборки: release | debug | coverage
REVISION="$2"    # Человекочитаемый номер ревизии (например r3)
DEB_VERSION="$3" # Версия пакета Debian

# Данный скрипт — диспетчер сборки внутри контейнера.
# Он не выполняет сборку сам, а делегирует её специализированным скриптам
# в зависимости от выбранного типа сборки.

case "$TYPE" in
  release)
    /workspace/scripts/build_release.sh "$REVISION" "$DEB_VERSION"
    ;;
  debug)
    # символы выносятся в отдельный файл, бинарник strip'ится
    /workspace/scripts/build_debug.sh "$REVISION" "$DEB_VERSION"
    ;;
  coverage)
    /workspace/scripts/build_coverage.sh "$REVISION" "$DEB_VERSION"
    ;;
  *)
    # Если передан неизвестный тип — считаем это ошибкой конфигурации пайплайна
    echo "Unknown build type: $TYPE"
    exit 1
    ;;
esac