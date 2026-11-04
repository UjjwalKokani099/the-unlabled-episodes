#!/usr/bin/env bash
# Fetches the CC0 MakeHuman data the character builder uses (base mesh, macro targets,
# default skeleton + weights, eyes) into tools/_build/makehuman (not committed; ~110 MB).
# MakeHuman assets were released as CC0 in September 2020 (licence in that repository).
set -e
cd "$(dirname "$0")/../.."
DEST=tools/_build/makehuman
if [ -f "$DEST/makehuman/data/3dobjs/base.obj" ]; then touch "$DEST/.gdignore"; echo "makehuman data present"; exit 0; fi
mkdir -p tools/_build
GIT_LFS_SKIP_SMUDGE=1 git clone -q --depth 1 --filter=blob:none --sparse \
	https://github.com/makehumancommunity/makehuman "$DEST"
git -C "$DEST" sparse-checkout set makehuman/data/3dobjs makehuman/data/targets/macrodetails \
	makehuman/data/rigs makehuman/data/eyes
touch "$DEST/.gdignore"  # Godot must not import MakeHuman's own .obj files
echo "makehuman data in $DEST"
