"""Verify and package the Unity Windows and Web players for one release."""
import argparse
from pathlib import Path
import os
import subprocess
import tempfile
from zipfile import ZIP_DEFLATED, ZIP_STORED, ZipFile

APP = Path(__file__).resolve().parents[1]
PLAYER = "EvacuationControl"
NATIVE_ROOT_FILES = {
    PLAYER + ".exe", "UnityPlayer.dll", "UnityCrashHandler64.exe",
    "GameAssembly.dll", "baselib.dll", "WinPixEventRuntime.dll",
}
NATIVE_ROOT_DIRS = {PLAYER + "_Data", "D3D12", "MonoBleedingEdge"}
LICENSES = ("HTS-Mei.txt", "NotoSansJP-OFL.txt")
WEB_FILES = {"index.html", "offline.js", "game.webmanifest", "train-192.png", "train-512.png"}


def require_file(root, relative):
    file = root / relative
    if not file.is_file() or file.stat().st_size == 0:
        raise ValueError(f"Missing or empty player file: {file}")
    return file


def debug_file(relative):
    return relative.suffix.lower() in {".pdb", ".mdb", ".log", ".ilk"} or any(
        "donotship" in component.lower() or "butdontship" in component.lower()
        for component in relative.parts
    )


def walk_runtime(root, directory):
    for source in sorted((root / directory).rglob("*")):
        if source.is_symlink():
            raise ValueError(f"Unexpected symbolic link in player: {source}")
        relative = source.relative_to(root)
        if source.is_file() and not debug_file(relative):
            yield relative.as_posix(), source


def windows_files(root):
    data = PLAYER + "_Data"
    for name in [PLAYER + ".exe", "UnityPlayer.dll", f"{data}/data.unity3d",
                 f"{data}/Managed/Assembly-CSharp.dll", "MonoBleedingEdge/EmbedRuntime/mono-2.0-bdwgc.dll"]:
        require_file(root, name)

    entries = {}
    for name in sorted(NATIVE_ROOT_FILES):
        if (root / name).is_file():
            entries[name] = root / name
    for name in sorted(NATIVE_ROOT_DIRS):
        entries.update(walk_runtime(root, name))

    # The same bundled assets are used on both platforms. Older native exports may
    # predate StreamingAssets, so include their notices from the project when missing.
    for license_name in LICENSES:
        name = f"{data}/StreamingAssets/Licenses/{license_name}"
        if name not in entries:
            entries[name] = require_file(APP / "Game/Assets/StreamingAssets/Licenses", license_name)
    return entries


def web_files(root):
    subprocess.run(["node", str(APP / "scripts/verify-web.mjs"), "--verify-only", str(root)], check=True)
    entries = {name: root / name for name in WEB_FILES}
    for directory in ["Build", "StreamingAssets"]:
        entries.update(walk_runtime(root, directory))
    files = {"web-player/" + name: source for name, source in entries.items()}
    files["scripts/play.py"] = require_file(APP, "scripts/play.py")
    return files


def write_archive(archive, files):
    with ZipFile(archive, "w", compression=ZIP_DEFLATED, compresslevel=6) as output:
        for name, source in sorted(files.items()):
            # Unity already gzip-compressed these files, and PNGs are compressed too.
            compression = ZIP_STORED if source.suffix in {".unityweb", ".png"} else ZIP_DEFLATED
            output.write(source, name, compress_type=compression)
    with ZipFile(archive) as output:
        bad = output.testzip()
        if bad is not None:
            raise ValueError(f"ZIP CRC check failed for {bad}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--windows", type=Path, default=APP / "Game/Builds/Windows")
    parser.add_argument("--web", type=Path, default=APP / "web-player")
    parser.add_argument("--output", type=Path, required=True, help="Directory for both release ZIPs")
    args = parser.parse_args()
    native, web, destination = [p.resolve() for p in (args.windows, args.web, args.output)]
    if any(destination == root or root in destination.parents for root in (native, web)):
        parser.error("The release directory must be outside both input builds.")

    try:
        archives = {
            f"{PLAYER}-Windows-x64.zip": windows_files(native),
            f"{PLAYER}-Web.zip": web_files(web),
        }
        destination.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix=".evac-release-", dir=destination) as folder:
            for name, files in archives.items():
                write_archive(Path(folder) / name, files)
            for name in archives:
                target = destination / name
                os.replace(Path(folder) / name, target)
                print(f"{target}  ({target.stat().st_size:,} bytes)")
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Packaging failed: {error}\n")


if __name__ == "__main__":
    main()
