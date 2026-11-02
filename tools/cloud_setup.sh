#!/usr/bin/env bash
# Cloud session setup (Claude Code on the web / iPad). Run by the SessionStart hook in
# .claude/settings.json; does nothing on the laptop (only when CLAUDE_CODE_REMOTE=true).
# Downloads the Linux build of Godot (cached in ~/godot), pulls Git LFS files, imports the
# project headless, and exports GODOT for the session. Never fails the session.
[ "$CLAUDE_CODE_REMOTE" = "true" ] || exit 0

VERSION="4.7.2-stable"
DIR="$HOME/godot"
BIN="$DIR/Godot_v${VERSION}_linux.x86_64"
URL="https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip"
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}" || exit 0

if [ ! -x "$BIN" ]; then
	mkdir -p "$DIR"
	if curl -fsSL "$URL" -o "$DIR/godot.zip" && python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$DIR/godot.zip" "$DIR"; then
		chmod +x "$BIN"
		rm -f "$DIR/godot.zip"
	else
		echo "cloud_setup: could not download Godot from $URL (set the environment's network access to Full)."
		exit 0
	fi
fi

if [ -n "$CLAUDE_ENV_FILE" ]; then
	echo "export GODOT=\"$BIN\"" >> "$CLAUDE_ENV_FILE"
	echo "export GODOT_HEADLESS=1" >> "$CLAUDE_ENV_FILE"
fi
ln -sf "$BIN" /usr/local/bin/godot 2>/dev/null

# Binary assets live in Git LFS; a clone without them leaves pointer files.
if command -v git-lfs > /dev/null 2>&1 || (command -v apt-get > /dev/null && apt-get install -y -qq git-lfs > /dev/null 2>&1); then
	git lfs install --local > /dev/null 2>&1
	git lfs pull > /dev/null 2>&1 || echo "cloud_setup: git lfs pull failed (textures/audio may be missing)."
fi

# Build the .godot import cache (class names, imported resources) so --check-only works.
timeout 600 "$BIN" --headless --path . --import > /tmp/godot_import.log 2>&1
echo "cloud_setup: Godot $VERSION ready at \$GODOT (headless only: no rendering, no playtesting)."
exit 0
