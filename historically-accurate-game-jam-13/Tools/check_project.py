import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=shutil.which("godot") or shutil.which("godot4"))
    arguments = parser.parse_args()
    if not arguments.godot:
        parser.error("Pass --godot /path/to/Godot or put godot in PATH.")
    with tempfile.TemporaryDirectory(prefix="laika-check-") as profile:
        environment = os.environ.copy()
        for key, directory in [("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache")]:
            environment[key] = str(Path(profile) / directory)
        godot = [arguments.godot, "--headless", "--path", str(PROJECT)]
        subprocess.run(godot + ["--import"], env=environment, timeout=300, capture_output=True)
        tests = sorted(PROJECT.glob("tests/unit/*_test.gd")) + sorted(PROJECT.glob("tests/whole_flow/*_flow.gd"))
        failed = []
        for script in tests:
            path = "res://" + script.relative_to(PROJECT).as_posix()
            if subprocess.run(godot + ["--script", path], env=environment, timeout=180).returncode:
                failed.append(path)
        if failed:
            print("Failed: " + ", ".join(failed))
            return 1
    unit_tests = subprocess.call([sys.executable, "-m", "unittest", "discover", "-s", str(PROJECT / "Tools/Localization"), "-p", "test_*.py"])
    if unit_tests:
        return unit_tests
    return subprocess.call([sys.executable, str(PROJECT / "Tools/Localization/export_messages.py"), "--check"])


if __name__ == "__main__":
    raise SystemExit(main())
