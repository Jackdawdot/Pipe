import argparse
import subprocess
import sys
from pathlib import Path
from datetime import datetime


DOCKER_IMAGE = "nginx-builder:latest"
DOCKERFILE_PATH = "docker/Dockerfile"
DEFAULT_NGINX_TAG = "release-1.24.0"


def run(cmd: list[str]) -> str:
    print(">>", " ".join(cmd))
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr, file=sys.stderr)
        raise RuntimeError(f"Command failed: {' '.join(cmd)}")

    return result.stdout.strip()


def docker_image_exists() -> bool:
    out = run(["docker", "images", "-q", DOCKER_IMAGE])
    return len(out) > 0


def build_image():
    run(["docker", "build", "-t", DOCKER_IMAGE, "-f", DOCKERFILE_PATH, "."])


def get_and_increment_build_number(state_dir: Path) -> int:
    state_dir.mkdir(exist_ok=True)
    f = state_dir / "build_number.txt"

    if f.exists():
        num = int(f.read_text().strip())
    else:
        num = 0

    num += 1
    f.write_text(str(num))
    return num


def write_report(build_number: int, revision: str, build_type: str, coverage: str | None):
    reports_dir = Path("reports")
    reports_dir.mkdir(exist_ok=True)

    ts = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    report_file = reports_dir / f"build_report_{ts}.txt"

    lines = [
        f"build_number: {build_number}",
        f"revision: {revision}",
        f"build_type: {build_type}",
    ]
    if coverage is not None:
        lines.append(f"coverage_lines: {coverage}")

    report_file.write_text("\n".join(lines) + "\n")
    print(f"[INFO] Report saved: {report_file}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--type", required=True, choices=["release", "debug", "coverage"])
    parser.add_argument("--nginx-tag", default=DEFAULT_NGINX_TAG)
    args = parser.parse_args()

    state_dir = Path("state")
    build_number = get_and_increment_build_number(state_dir)
    revision = f"r{build_number}"
    deb_version = str(build_number)

    if not docker_image_exists():
        print("[INFO] Docker image not found, building...")
        build_image()
    else:
        print("[INFO] Docker image exists.")

    project_dir = str(Path.cwd().resolve())

    run([
        "docker", "run", "--rm",
        "-v", f"{project_dir}:/workspace",
        "-v", f"{project_dir}/state:/workspace/state",
        "-v", f"{project_dir}/artifacts:/workspace/artifacts",
        DOCKER_IMAGE,
        "bash", "-c",
        f"chmod +x /workspace/scripts/*.sh && "
        f"/workspace/scripts/container_build.sh {args.type} {revision} {deb_version} {args.nginx_tag}"
    ])

    coverage_value = None
    last_cov_file = Path("state/last_coverage.txt")
    if args.type == "coverage" and last_cov_file.exists():
        coverage_value = last_cov_file.read_text().strip()

    write_report(build_number, revision, args.type, coverage_value)


if __name__ == "__main__":
    main()