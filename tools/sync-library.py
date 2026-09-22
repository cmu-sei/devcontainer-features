#!/usr/bin/env python3
"""Copy shared helpers into self-contained feature packages; --check detects drift."""
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parents[1]
stale = []
for feature in sorted((root / "src").iterdir()):
    for name in ("build.sh", "runtime.sh"):
        source = root / "tools/lib" / name
        target = feature / ("org-" + name)
        if "--check" in sys.argv:
            if not target.exists() or target.read_bytes() != source.read_bytes():
                stale.append(str(target.relative_to(root)))
        else:
            target.write_bytes(source.read_bytes())
if stale:
    sys.exit("Run python3 tools/sync-library.py: " + ", ".join(stale))
