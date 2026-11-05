"""Release build (studio spec 15): bumps the version, exports the desktop builds, zips them and
writes a CHANGELOG.md entry.

    python tools/build_release.py patch          # 0.1.0 -> 0.1.1, export Windows + Linux
    python tools/build_release.py minor --no-export   # only bump + changelog (CI exports on the tag)
    python tools/build_release.py none --platforms windows

Steps: project.godot application/config/version (semantic versioning) -> CHANGELOG.md entry from
the commit subjects since the last v* tag -> `godot --headless --export-release` per preset ->
build/release/Unlabeled-<version>-<platform>.zip. It never commits or tags: it prints the git
commands to run (the tag "v<version>" makes .github/workflows/desktop.yml build and test it).
Godot = $GODOT, else the Windows console exe from CLAUDE.md, else `godot` on PATH. Needs the
4.7.2 export templates installed (Editor > Manage Export Templates).
"""
import argparse
import datetime
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(ROOT, "project.godot")
CHANGELOG = os.path.join(ROOT, "CHANGELOG.md")
PRESETS = {"windows": ("Windows Desktop", "build/windows/Unlabeled.exe"),
           "linux": ("Linux", "build/linux/Unlabeled.x86_64")}
WINDOWS_GODOT = r"C:\Users\ujjwa\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"


def read_version() -> str:
    m = re.search(r'config/version="([^"]+)"', open(PROJECT, encoding="utf-8").read())
    return m.group(1) if m else "0.0.0"


def bump(version: str, part: str) -> str:
    major, minor, patch = (int(x) for x in (version.split("-")[0].split(".") + ["0", "0"])[:3])
    if part == "major":
        return f"{major + 1}.0.0"
    if part == "minor":
        return f"{major}.{minor + 1}.0"
    if part == "patch":
        return f"{major}.{minor}.{patch + 1}"
    return version


def write_version(version: str) -> None:
    text = open(PROJECT, encoding="utf-8").read()
    text = re.sub(r'config/version="[^"]+"', f'config/version="{version}"', text, count=1)
    open(PROJECT, "w", encoding="utf-8").write(text)


def git(*args) -> str:
    try:
        return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def changelog_entry(version: str) -> str:
    last_tag = git("describe", "--tags", "--abbrev=0", "--match", "v*")
    rng = f"{last_tag}..HEAD" if last_tag else "HEAD~30..HEAD"
    subjects = [s for s in git("log", "--no-merges", "--format=%s", rng).splitlines() if s]
    lines = [f"- {s}" for s in subjects if not s.lower().startswith(("tests:", "wip"))] or ["- (no changes recorded)"]
    date = datetime.date.today().isoformat()
    return f"## v{version} ({date})\n\n" + "\n".join(lines) + "\n"


def write_changelog(entry: str) -> None:
    head = "# Changelog\n\nRelease notes, newest first (tools/build_release.py adds an entry per release).\n\n"
    old = open(CHANGELOG, encoding="utf-8").read() if os.path.exists(CHANGELOG) else head
    if old.startswith(head):
        old = old[len(head):]
    open(CHANGELOG, "w", encoding="utf-8").write(head + entry + "\n" + old)


def find_godot() -> str:
    for cand in (os.environ.get("GODOT"), WINDOWS_GODOT, shutil.which("godot")):
        if cand and os.path.exists(cand):
            return cand
    sys.exit("Godot not found: set GODOT to the console executable.")


def export(godot: str, platform: str, version: str) -> str:
    preset, out = PRESETS[platform]
    out_dir = os.path.join(ROOT, os.path.dirname(out))
    shutil.rmtree(out_dir, ignore_errors=True)
    os.makedirs(out_dir)
    print(f"exporting {preset} ...")
    subprocess.run([godot, "--headless", "--path", ROOT, "--export-release", preset, out], cwd=ROOT, check=True)
    pck = os.path.splitext(os.path.join(ROOT, out))[0] + ".pck"
    if not os.path.exists(os.path.join(ROOT, out)) or not os.path.exists(pck):
        sys.exit(f"{preset}: export produced no executable/pck (export templates installed?)")
    os.makedirs(os.path.join(ROOT, "build", "release"), exist_ok=True)
    base = os.path.join(ROOT, "build", "release", f"Unlabeled-{version}-{platform}")
    return shutil.make_archive(base, "zip", out_dir)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("part", choices=["major", "minor", "patch", "none"])
    ap.add_argument("--platforms", default="windows,linux")
    ap.add_argument("--no-export", action="store_true", help="only bump the version and write the changelog")
    args = ap.parse_args()
    old = read_version()
    version = bump(old, args.part)
    if version != old:
        write_version(version)
        write_changelog(changelog_entry(version))
        print(f"version {old} -> {version}; CHANGELOG.md updated")
    if not args.no_export:
        godot = find_godot()
        for platform in args.platforms.split(","):
            print("wrote", export(godot, platform.strip(), version))
    print("\nNext:\n  git add project.godot CHANGELOG.md && git commit -m \"Release v%s\"\n"
          "  git tag v%s && git push origin HEAD v%s     # CI builds + smoke-tests it\n" % (version, version, version))


if __name__ == "__main__":
    main()
