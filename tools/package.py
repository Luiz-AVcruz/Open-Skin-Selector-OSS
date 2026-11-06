#!/usr/bin/env python3
"""Build deterministic install and full-source ZIPs using Python's standard library."""
from pathlib import Path
import hashlib
import os
import re
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "mod"
DIST = ROOT / "dist"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def files():
    install = [p for p in MOD.rglob("*") if p.is_file() and p.name != "id.txt"]
    source = [ROOT / n for n in ("README.md", "AGENTS.md", ".gitignore", "LICENSE", "ADDITIONAL-PERMISSION")]
    source += install
    for folder in ("Docs", "tests", "tools"):
        source += [p for p in (ROOT / folder).rglob("*") if p.is_file() and p.suffix in (".md", ".lua", ".py")]
    required = [MOD / "main.lua", MOD / "options.lua", MOD / "info.txt", MOD / "SOURCE.md", MOD / "preview.jpg",
                MOD / "preview-menu.png", MOD / "WORKSHOP-DESCRIPTION.txt",
                ROOT / "Docs/PROJETO.md", ROOT / "tests/test_runtime.lua", ROOT / "tests/test_ui.lua"]
    for path in source + required:
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"Expected a regular source file: {path}")
    for name in ("LICENSE", "ADDITIONAL-PERMISSION"):
        if (ROOT / name).read_bytes() != (MOD / name).read_bytes():
            raise ValueError(f"Root and runtime {name} differ")
    info = (MOD / "info.txt").read_text()
    if not re.search(r"(?m)^version\s*=\s*2$", info):
        raise ValueError("info.txt must declare scripting version 2")
    if not re.search(r"(?m)^preview\s*=\s*preview-menu.png$", info):
        raise ValueError("info.txt must reference preview-menu.png")
    description = re.search(r"(?m)^description\s*=\s*(.*)$", info)
    if not description or description[1] != " ".join((MOD / "WORKSHOP-DESCRIPTION.txt").read_text().split()):
        raise ValueError("Workshop description and local metadata differ")
    jpg = (MOD / "preview.jpg").read_bytes()
    png = (MOD / "preview-menu.png").read_bytes()
    if not jpg.startswith(b"\xff\xd8\xff") or len(jpg)>1_000_000:
        raise ValueError("preview.jpg must be JPEG under 1 MB")
    if png[:8] != b"\x89PNG\r\n\x1a\n" or int.from_bytes(png[16:20],"big")!=512 or int.from_bytes(png[20:24],"big")!=292:
        raise ValueError("preview-menu.png must be a 512 x 292 PNG")
    return sorted(install), sorted(set(source))


def archive(path, members, base, prefix):
    expected = {}
    with zipfile.ZipFile(path,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=9) as out:
        for source in members:
            name = prefix + "/" + source.relative_to(base).as_posix()
            data = source.read_bytes()
            entry = zipfile.ZipInfo(name, date_time=(1980,1,1,0,0,0))
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            out.writestr(entry,data,compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
            expected[name] = hashlib.sha256(data).digest()
    with zipfile.ZipFile(path) as check:
        if check.testzip() or set(check.namelist()) != set(expected):
            raise ValueError("Invalid archive members or CRC")
        for name, checksum in expected.items():
            if hashlib.sha256(check.read(name)).digest() != checksum:
                raise ValueError(f"Archive content differs: {name}")


def main():
    install, source = files()
    version = re.search(r'\bversion\s*=\s*"(\d+\.\d+\.\d+)"', (MOD / "scripts/common.lua").read_text())[1]
    DIST.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".oss-package-",dir=DIST) as tmp:
        tmp = Path(tmp)
        a = tmp / f"OpenSkinSelector-{version}.zip"
        b = tmp / f"OpenSkinSelector-{version}-source.zip"
        archive(a,install,MOD,"Open Skin Selector")
        archive(b,source,ROOT,"OpenSkinSelector-source")
        sums = tmp / "SHA256SUMS"
        sums.write_text("".join(f"{digest(p)}  {p.name}\n" for p in (a,b)),encoding="ascii")
        for path in (a,b,sums):
            target = DIST / path.name
            os.replace(path,target)
            print(target.relative_to(ROOT))


if __name__ == "__main__":
    main()
