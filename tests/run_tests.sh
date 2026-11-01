#!/usr/bin/env bash
# Runs every tests/test_*.gd and prints PASS/FAIL lines plus any engine errors.
# Usage (from project root, Git Bash): bash tests/run_tests.sh
# Opens a small game window per test (rendering is needed for mouse capture).
GODOT="/c/Users/ujjwa/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"
cd "$(dirname "$0")/.." || exit 1
"$GODOT" --headless --path . --import > /dev/null 2>&1
total_fail=0
for t in tests/test_*.gd; do
	echo "=== $t"
	out=$(timeout 120 "$GODOT" --path . --quit-after 20000 --script "res://$t" 2>&1)
	echo "$out" | grep -E "^(PASS|FAIL|RESULT)|SCRIPT ERROR|^ERROR|WARNING" | grep -v "^PASS"
	echo "$out" | grep -q "RESULT fails=0" || total_fail=$((total_fail + 1))
done
echo "=== failing test files: $total_fail"
exit $total_fail
