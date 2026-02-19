# Локальный CI-конвейер для Nginx

Этот проект реализует локальный CI-конвейер сборки для Nginx, используя:

- Docker (изолированная среда сборки)
- Python (оркестрация конвейера)
- Bash (этапы сборки)
- ccache (ускорение сборки)
- lcov/gcov (анализ покрытия кода)

---

## Модель конвейера

### Проверка образа Docker

Основной скрипт:

- Проверяет, существует ли образ `nginx-builder:latest`
- Если нет — собирает его из Dockerfile
- Затем запускает контейнер на основе этого образа

---

## Типы сборки

### Релиз

- Оптимизированная сборка
- Удалены отладочные символы (strip)
- Создает пакет `.deb`
- Формат версии: `nginx_<revision>_<nginxVersion-buildNumber>.deb`

---

### Отладка

- Сборка с `--with-debug`
- Отладочные символы извлечены в отдельный файл `.debug`
- Сгенерирован пакет `.deb`

Артефакты:
- пакет deb
- файл отладочных символов

---

### Покрытие кода

- Сборка выполнена с использованием инструментария gcov
- Выполнен smoke тест (`nginx -t`)
- Отчет о покрытии кода сгенерирован с помощью lcov + genhtml
- Процент покрытия по сравнению с предыдущим запуском

---

## Требования

- Docker
- Python 3

## Параметры запуска

### --type (required)
Определяет тип сборки.

Возможные  значения:

- release:Оптимизированная сборка 
- debug: Отладочная сборка 
- coverage: Сборка с покрытием

### --nginx-tag (опционально)
Определяет какую версию nginx собирать.

По умолчанию:
```
release-1.24.0
```
Пример: 
```
python3 build.py --type release --nginx-tag release-1.22.1
```
## Артефакты сборки
### Release:
```
artifacts/deb/nginx_rN_<nginxVersion-buildNumber>.deb
```
### Debug:
```
artifacts/deb/nginx_rN_<nginxVersion-buildNumber>.deb
artifacts/debug/nginx_rN.debug
```
### Coverage:
```
artifacts/deb/nginx_rN_<nginxVersion-buildNumber>.deb
artifacts/coverage/rN/index.html
```
Процент покрытия содержится в файле
```
state/current_coverage.txt
```