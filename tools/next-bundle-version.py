#!/usr/bin/env python3
"""Print the next bundle tag: the largest feature bump since the latest v* tag, or nothing."""
import json
import subprocess
import sys

LEVELS = ["patch", "minor", "major"]
RELEASED_PATHS = ["bundle", "tools/spawn.sh", "tools/spawn.ps1"]


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout.strip()


def feature_versions(ref):
    versions = {}
    for path in git("ls-tree", "--name-only", f"{ref}:src").splitlines():
        try:
            metadata = git("show", f"{ref}:src/{path}/devcontainer-feature.json")
        except subprocess.CalledProcessError:
            continue
        versions[path] = tuple(int(part) for part in json.loads(metadata)["version"].split("."))
    return versions


def bump_level(old, new):
    if new[0] > old[0]:
        return "major"
    if new[:2] > old[:2]:
        return "minor"
    return "patch"


def main():
    tags = git("tag", "--list", "v*", "--sort=-v:refname", "--merged", "HEAD").splitlines()
    if not tags:
        sys.exit("No v* tag is reachable from HEAD; create the first bundle release manually.")
    base = tags[0]
    old, new = feature_versions(base), feature_versions("HEAD")

    levels = []
    for feature in old.keys() | new.keys():
        if feature not in new:
            levels.append("major")
        elif feature not in old:
            levels.append("minor")
        elif old[feature] != new[feature]:
            levels.append(bump_level(old[feature], new[feature]))
    if not levels and git("diff", "--name-only", base, "HEAD", "--", *RELEASED_PATHS):
        levels.append("patch")
    if not levels:
        return

    major, minor, patch = (int(part) for part in base.removeprefix("v").split("."))
    level = max(levels, key=LEVELS.index)
    if level == "major":
        major, minor, patch = major + 1, 0, 0
    elif level == "minor":
        minor, patch = minor + 1, 0
    else:
        patch += 1
    print(f"v{major}.{minor}.{patch}")


if __name__ == "__main__":
    main()
