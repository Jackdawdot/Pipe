import argparse
import subprocess
import sys
from pathlib import Path
from datetime import datetime


# Имя docker-образа окружения сборки (toolchain). Если образа нет — собирается из Dockerfile.
DOCKER_IMAGE = "nginx-builder:latest"
DOCKERFILE_PATH = "docker/Dockerfile"

# Git-тег nginx, который будет собран по умолчанию (можно переопределить параметром --nginx-tag).
DEFAULT_NGINX_TAG = "release-1.24.0"


def run(cmd: list[str], *, quiet: bool = False) -> str:
    # quiet=True используется там, где нам нужен только вывод команды (например, проверки), но не нужны логи в консоль.
    print(">>", " ".join(cmd))

    if quiet:
        result = subprocess.run(cmd, capture_output=True, text=True)
    else:
        # Без capture_output stdout/stderr идут напрямую в консоль — удобно для просмотра логов сборки.
        result = subprocess.run(cmd, text=True)

    if result.returncode != 0:
        # При quiet=True вывод не отображается автоматически, поэтому печатаем его вручную для диагностики.
        if quiet:
            print(result.stdout)
            print(result.stderr, file=sys.stderr)
        raise RuntimeError(f"Command failed: {' '.join(cmd)}")

    return (result.stdout or "").strip() if quiet else ""


def docker_image_exists() -> bool:
    # Надёжная проверка наличия docker-образа (работает для формата repo:tag).
    # Возвращает True если образ есть локально, иначе False.
    result = subprocess.run(
        ["docker", "image", "inspect", DOCKER_IMAGE],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    return result.returncode == 0


def build_image():
    # Сборка docker-образа окружения сборки из Dockerfile.
    run(["docker", "build", "-t", DOCKER_IMAGE, "-f", DOCKERFILE_PATH, "."])


def get_and_increment_build_number(state_dir: Path) -> int:
    # Состояние пайплайна храним в папке state/ на хост-машине:
    # build_number.txt — монотонно растущий номер запуска (используется как "ревизия" и для версий артефактов).
    state_dir.mkdir(exist_ok=True)
    f = state_dir / "build_number.txt"

    if f.exists():
        # Файл мог оказаться пустым (например, после ручного редактирования) — в таком случае стартуем с 0.
        text = f.read_text().strip()
        num = int(text) if text else 0
    else:
        num = 0

    num += 1
    f.write_text(str(num))
    return num


def write_report(build_number: int, revision: str, build_type: str, coverage: str | None):
    # Каждый запуск создаёт отдельный отчёт с timestamp в имени файла.
    reports_dir = Path("reports")
    reports_dir.mkdir(exist_ok=True)

    ts = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    report_file = reports_dir / f"build_report_{ts}.txt"

    lines = [
        f"build_number: {build_number}",
        f"revision: {revision}",
        f"build_type: {build_type}",
    ]
    # Для coverage-сборки дополнительно фиксируем процент покрытия.
    if coverage is not None:
        lines.append(f"coverage_lines: {coverage}")

    report_file.write_text("\n".join(lines) + "\n")
    print(f"[INFO] Report saved: {report_file}")


def main():
    # CLI: тип сборки обязателен, тег nginx опционален.
    parser = argparse.ArgumentParser()
    parser.add_argument("--type", required=True, choices=["release", "debug", "coverage"])
    parser.add_argument("--nginx-tag", default=DEFAULT_NGINX_TAG)
    args = parser.parse_args()

    state_dir = Path("state")
    build_number = get_and_increment_build_number(state_dir)

    # revision добавляется в имя артефактов как человекочитаемый идентификатор запуска.
    revision = f"r{build_number}"

    # Debian-версия пакета должна начинаться с цифры; используем версию nginx из тега + номер запуска.
    nginx_ver = args.nginx_tag.replace("release-", "")
    deb_version = f"{nginx_ver}-{build_number}"

    # 1) Готовим docker-образ окружения сборки.
    if not docker_image_exists():
        print("[INFO] Docker image not found, building...")
        build_image()
    else:
        print("[INFO] Docker image exists.")

    project_dir = str(Path.cwd().resolve())

    # 2) Запускаем сборку внутри контейнера:
    # - монтируем репозиторий в /workspace (скрипты и рабочие директории)
    # - state/ сохраняет состояние между запусками (номер сборки, прошлое покрытие)
    # - state/ccache примонтирован в /ccache, чтобы ccache работал между разными контейнерами
    # - artifacts/ — выходные артефакты (deb, debug symbols, coverage report)
    run([
        "docker", "run", "--rm",
        "-v", f"{project_dir}:/workspace",
        "-v", f"{project_dir}/state:/workspace/state",
        "-v", f"{project_dir}/state/ccache:/ccache",
        "-v", f"{project_dir}/artifacts:/workspace/artifacts",
        DOCKER_IMAGE,
        "bash", "-c",
        f"chmod +x /workspace/scripts/*.sh && "
        f"/workspace/scripts/container_build.sh {args.type} {revision} {deb_version} {args.nginx_tag}"
    ])

    # В режиме coverage скрипт внутри контейнера сохраняет текущий процент в state/current_coverage.txt
    coverage_value = None
    cur_cov_file = Path("state/current_coverage.txt")
    if args.type == "coverage" and cur_cov_file.exists():
        coverage_value = cur_cov_file.read_text().strip()

    write_report(build_number, revision, args.type, coverage_value)


if __name__ == "__main__":
    main()