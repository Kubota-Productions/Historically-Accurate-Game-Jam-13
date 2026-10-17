import argparse
import shutil
import subprocess
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
EXCLUDED = {
    "Scenes/Player/Scripts/FPSplayer.gd",
    "Scenes/Player/Scripts/FPScamera.gd",
}


def main():
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--write", action="store_true")
    arguments = parser.parse_args()
    formatter = shutil.which("gdformat")
    if formatter is None:
        parser.exit(1, "Install gdtoolkit==4.3.4 from requirements-dev.txt.\n")
    version = subprocess.check_output([formatter, "--version"], text=True).strip()
    if version != "gdformat 4.3.4":
        parser.exit(1, f"Expected gdformat 4.3.4, found {version}.\n")
    paths = []
    for folder in ("Code", "GameData", "Scenes", "tests"):
        for path in sorted((PROJECT / folder).rglob("*.gd")):
            relative = path.relative_to(PROJECT).as_posix()
            if relative not in EXCLUDED and "/screenspace_projection/" not in relative:
                paths.append(str(path))
    flags = ["--check"] if arguments.check else []
    raise SystemExit(subprocess.call([formatter, *flags, *paths], cwd=PROJECT.parent))


if __name__ == "__main__":
    main()
