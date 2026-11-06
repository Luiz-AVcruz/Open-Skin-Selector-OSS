#!/usr/bin/env python3
"""Validate Lua 5.1 syntax and run isolated contract tests; never launches the game."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "mod"


def expand(path, active=()):
    path = path.resolve()
    if not path.is_relative_to(MOD.resolve()) or path in active:
        raise ValueError(f"Invalid include: {path}")
    lines = []
    for line in path.read_text().splitlines():
        if line.startswith("#version "):
            if line.strip() != "#version 2":
                raise ValueError(f"Unsupported scripting generation: {path}")
            continue
        match = re.fullmatch(r'#include "([^"]+)"', line.strip())
        lines.append(expand(MOD / match[1], active + (path,)) if match else line)
    return "\n".join(lines) + "\n"


def main():
    runtime = shutil.which("luajit")
    if not runtime:
        raise SystemExit("Development checks need LuaJIT (Lua 5.1 compatible). Players do not.")
    with tempfile.TemporaryDirectory(prefix="oss-check-") as tmp:
        bundle = Path(tmp) / "main.lua"
        bundle.write_text(expand(MOD / "main.lua"))
        subprocess.run([runtime, "-b", str(bundle), str(Path(tmp) / "syntax.luac")], check=True)
        options = Path(tmp) / "options.lua"
        options.write_text(expand(MOD / "options.lua"))
        subprocess.run([runtime, "-b", str(options), str(Path(tmp) / "options.luac")], check=True)
        for test in sorted((ROOT / "tests").glob("test_*.lua")):
            subprocess.run([runtime, str(test), str(bundle), str(options)], cwd=ROOT, check=True)
    print("PASS: entry point, Lua 5.1 syntax and contract tests (not a game runtime test)")


if __name__ == "__main__":
    main()
