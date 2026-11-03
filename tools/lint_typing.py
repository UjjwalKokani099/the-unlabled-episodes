"""Static-typing lint for game GDScript (studio rule: typed vars, args and returns).

Run from the project root:  python tools/lint_typing.py   (exit code 1 if anything is untyped)
Checks every .gd under core/ systems/ player/ ui/ chapters/ (tests/ and tools/ are exempt:
test scripts must reach autoloads untyped, see CLAUDE.md):
- `var` without a type (`var x = 1`, `var x`)  -> use `var x: int = 1` or `var x := 1`
- function parameters without a type          -> `func f(a: int)`
- functions without a return type             -> `func f() -> void:`
Lambdas count too. Prints file:line: message.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDERS = ("core", "systems", "player", "ui", "chapters")

VAR = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?var\s+(\w+)\s*(.*)$")
FUNC = re.compile(r"\bfunc\b\s*(\w*)\s*\((.*?)\)\s*(->\s*[\w\[\], .]+)?\s*:")


def split_params(params: str) -> list:
    out, depth, cur = [], 0, ""
    for ch in params:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur)
    return [p.strip() for p in out]


def lint_file(path: str) -> list:
    problems = []
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        code = line.split("#")[0] if "#" in line and '"' not in line else line
        m = VAR.match(code)
        if m:
            rest = m.group(2).strip()
            if not (rest.startswith(":")):
                problems.append((i + 1, f"untyped var '{m.group(1)}'"))
        # functions (may span lines until the closing ':')
        if re.search(r"\bfunc\b", code):
            sig = code
            j = i
            while not re.search(r"\)\s*(->\s*[\w\[\], .]+)?\s*:", sig) and j + 1 < len(lines) and j - i < 6:
                j += 1
                sig += " " + lines[j].strip()
            fm = FUNC.search(sig)
            if fm:
                name = fm.group(1) or "<lambda>"
                for p in split_params(fm.group(2)):
                    pname = p.split("=")[0].strip()
                    if pname and ":" not in pname:
                        problems.append((i + 1, f"untyped parameter '{pname}' in {name}()"))
                if not fm.group(3):
                    problems.append((i + 1, f"no return type on {name}()"))
        i += 1
    return problems


def main() -> int:
    total = 0
    for folder in FOLDERS:
        for dirpath, _, files in os.walk(os.path.join(ROOT, folder)):
            for name in sorted(files):
                if not name.endswith(".gd"):
                    continue
                path = os.path.join(dirpath, name)
                for line, msg in lint_file(path):
                    print(f"{os.path.relpath(path, ROOT)}:{line}: {msg}")
                    total += 1
    print(f"{total} typing problem(s)")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
