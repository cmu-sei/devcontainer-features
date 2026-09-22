#!/usr/bin/env python3
"""Validate packaging invariants before invoking the Dev Container CLI tests."""
import json
import pathlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
subprocess.run(["python3", str(root / "tools/sync-library.py"), "--check"], check=True)
features = sorted((root / "src").iterdir())
for directory in features:
    metadata = json.loads((directory / "devcontainer-feature.json").read_text())
    assert metadata["id"] == directory.name, directory
    assert re.fullmatch(r"\d+\.\d+\.\d+", metadata["version"]), directory
    assert (directory / "install.sh").exists(), directory
    for dependency in metadata.get("installsAfter", []):
        assert ":" not in dependency and "@" not in dependency, dependency
    for key, command in metadata.items():
        if key.endswith("Command"):
            prefix = f"bash -l /usr/local/share/org-features/{directory.name}/"
            assert command.startswith(prefix), command
            assert (directory / command.removeprefix(prefix)).is_file(), command
    for script in directory.rglob("*.sh"):
        subprocess.run(["bash", "-n", str(script)], check=True)
subprocess.run(["bash", "-n", str(root / "src/grok/bedrock-api-key")], check=True)
print(f"Validated {len(features)} feature packages and shell syntax.")
