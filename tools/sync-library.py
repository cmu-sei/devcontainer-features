#!/usr/bin/env python3
"""Copy shared helpers into self-contained feature packages; --check detects drift."""
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parents[1]
# update.sh only ships with the features whose tools update themselves at container start.
AGENT_FEATURES = {"claude", "codex", "grok", "herdr", "opencode", "pi"}
stale = []
for feature in sorted((root / "src").iterdir()):
    names = ["build.sh", "runtime.sh"] + (["update.sh"] if feature.name in AGENT_FEATURES else [])
    for name in names:
        source = root / "tools/lib" / name
        target = feature / ("org-" + name)
        if "--check" in sys.argv:
            if not target.exists() or target.read_bytes() != source.read_bytes():
                stale.append(str(target.relative_to(root)))
        else:
            target.write_bytes(source.read_bytes())
if stale:
    sys.exit("Run python3 tools/sync-library.py: " + ", ".join(stale))
