#!/bin/bash

# The whole script is one brace group, so bash parses all of it before running any of it:
# piped from curl (`curl -fsSL .../spawn.sh | bash -s -- <target> [options]`) a dropped
# connection then fails as a syntax error instead of running a truncated script.
{

# Release assets built by .github/workflows/release-bundle.yml. The tarball unpacks to a
# top-level .devcontainer/; releases/latest/download always serves the newest release.
RELEASES_URL="https://github.com/cmu-sei/devcontainer-features/releases"
ASSET="devcontainer.tar.gz"

# --- Argument parsing ---
TARGET_DIR=""
INIT_GIT=false
VERSION=""
CHAT=false

usage() {
    echo "Usage: spawn.sh [<target-directory>] [--git] [--version <tag>] [--chat]"
    echo "   or: curl -fsSL $RELEASES_URL/latest/download/spawn.sh | bash -s -- [<target-directory>] [options]"
    echo ""
    echo "Downloads the latest released dev container bundle, then runs its setup to pick the"
    echo "provider profiles, the features to build and the profiles' API keys."
    echo ""
    echo "The target decides what happens:"
    echo "  new or empty directory   .devcontainer/ and a starter README become a new project"
    echo "  an existing project      only .devcontainer/ is added; nothing the project"
    echo "                           already has is modified or removed"
    echo ""
    echo "With no target directory, spawn asks for one (when there is a terminal to ask on)."
    echo ""
    echo "Options:"
    echo "  --git, -g            Preselect \"yes\" in the Git prompt (initialize a repository and"
    echo "                       make an initial commit once setup is done)"
    echo "  --version <tag>      Download a specific release, e.g. v1.2.3 (default: the latest release)"
    echo "  --chat               Preselect the browser-chat stack (LiteLLM, Open WebUI, Open Terminal,"
    echo "                       SearXNG, supervisord) in the feature prompt. Off by default for a"
    echo "                       leaner, faster build"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --git|-g)
            INIT_GIT=true
            ;;
        --chat)
            CHAT=true
            ;;
        --version)
            if [ -z "${2:-}" ]; then
                echo "Error: '$1' requires a release tag."
                usage
                exit 1
            fi
            VERSION="$2"
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            if [ -z "$TARGET_DIR" ]; then
                TARGET_DIR="$1"
            else
                echo "Error: Unexpected argument '$1'"
                usage
                exit 1
            fi
            ;;
    esac
    shift
done

# Ask for the target when none was given. From /dev/tty, like every prompt in setup.sh:
# piped from curl, stdin is the script itself. There is no default — an empty answer, or no
# terminal to ask on, prints usage — because silently adopting the current directory is the
# costlier mistake. read doesn't expand a typed ~, so that is done here.
if [ -z "$TARGET_DIR" ] && (exec 3< /dev/tty) 2>/dev/null; then
    echo "Where should the project go? A new folder, or an existing project to add .devcontainer/ to."
    read -r -p "Project directory: " TARGET_DIR < /dev/tty || TARGET_DIR=""
    case "$TARGET_DIR" in
        "~"|"~/"*) TARGET_DIR="$HOME${TARGET_DIR#\~}" ;;
    esac
fi
if [ -z "$TARGET_DIR" ]; then
    usage
    exit 1
fi

if [ -n "$VERSION" ]; then
    ARCHIVE_URL="$RELEASES_URL/download/$VERSION/$ASSET"
else
    ARCHIVE_URL="$RELEASES_URL/latest/download/$ASSET"
fi

# Check required tools
for cmd in curl tar; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is required but not installed."
        exit 1
    fi
done

# Only check for git if --git is used. The identity is NOT checked here: setup asks for
# one when the global config has none and sets it on the new repo alone (see setup.sh's
# setup_git), so a missing global identity is no longer a reason to refuse the spawn.
if [ "$INIT_GIT" = true ] && ! command -v git &>/dev/null; then
    echo "Error: 'git' is required when using --git but is not installed."
    exit 1
fi

# --- Resolve the target to an absolute path ---
# Before anything else, because the project name is the basename and `spawn.sh .` is the
# natural way to adopt the directory you are standing in — where basename is ".". Missing
# intermediate directories are created, as they always were.
mkdir -p "$(dirname "$TARGET_DIR")" 2>/dev/null
if [ -d "$TARGET_DIR" ]; then
    TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
else
    TARGET_PARENT="$(cd "$(dirname "$TARGET_DIR")" 2>/dev/null && pwd)"
    if [ -z "$TARGET_PARENT" ]; then
        echo "Error: the parent directory of '$TARGET_DIR' does not exist and could not be created."
        exit 1
    fi
    TARGET_DIR="$TARGET_PARENT/$(basename "$TARGET_DIR")"
fi

# True when the directory holds nothing a project would miss — empty, or holding only a
# bare `git init` and Finder droppings. Treated as greenfield so the common
# `mkdir proj && cd proj && spawn .` doesn't land in adoption mode. An unmatched glob
# expands to itself, which the -e test discards.
dir_is_bare() {
    local entry
    for entry in "$1"/* "$1"/.*; do
        [ -e "$entry" ] || continue
        case "$(basename "$entry")" in
            .|..|.git|.DS_Store) continue ;;
        esac
        return 1
    done
    return 0
}

# --- Classify the target: greenfield or adoption ---
# Two supported shapes, and one that has to be refused:
#   greenfield  nothing there, or an empty/bare directory — the whole cleaned tree
#               becomes the project.
#   adopt       an existing project with no .devcontainer/ — only .devcontainer/ is
#               added, and nothing the project already owns is touched.
#   refused     an existing .devcontainer/. Replacing it would take out the feature set
#               chosen in devcontainer.json, the credentials in devcontainer.env and the
#               profiles the CUI question deleted; and two devcontainer.json files cannot
#               be merged automatically. Both repairs are manual, and they are different,
#               so the message says which one applies.
MODE=greenfield
if [ -e "$TARGET_DIR" ]; then
    if [ ! -d "$TARGET_DIR" ]; then
        echo "Error: '$TARGET_DIR' exists and is not a directory."
        exit 1
    fi
    if [ -e "$TARGET_DIR/.devcontainer" ]; then
        echo "Error: '$TARGET_DIR/.devcontainer' already exists."
        echo ""
        if [ -d "$TARGET_DIR/.devcontainer/profiles" ]; then
            echo "  This project already has agent-dev's dev container. Spawning over it would"
            echo "  discard the feature set you chose in .devcontainer/devcontainer.json, the"
            echo "  credentials in .devcontainer/devcontainer.env, and the provider profiles the"
            echo "  CUI question deleted. To update it, replace .devcontainer/ by hand."
        else
            echo "  That is another dev container's configuration, and two devcontainer.json"
            echo "  files cannot be merged automatically. Move it aside first, then run this"
            echo "  again to add agent-dev's."
        fi
        echo ""
        exit 1
    fi
    if ! dir_is_bare "$TARGET_DIR"; then
        MODE=adopt
    fi
fi

# Whether a repository was already here, recorded BEFORE setup runs: the closing summary
# reads .git to report what the Git prompt settled on, and a bare `git init` counts as
# greenfield, so without this the script would claim credit for a repo it merely found.
GIT_PRE=false
if [ -d "$TARGET_DIR/.git" ]; then
    GIT_PRE=true
fi

# --- Download and stage ---
# Everything — extract, clean slate AND setup's questions — happens in a STAGING copy of
# the project, and only the finished result is moved into the target, as the very last
# step. So a spawn that is cancelled or fails at any point (Ctrl-C during a prompt, a
# failed download, setup exiting non-zero) leaves the target exactly as it was: no
# half-configured project to delete before running spawn again. The failure paths also
# delete what they were handed, which must never be the user's tree.
#
# The payload sits in "$STAGE/<project name>" rather than in $STAGE itself, because setup
# names the project after its directory (the banner, the stub README), and because
# `mktemp -d` makes $STAGE 0700: a plain `mkdir` gets the process umask, so the payload
# directory can be renamed into place as the project root.
#
# The staging directory goes next to the payload's destination rather than in /tmp, which
# is a separate filesystem on most Linux hosts: every move below is then a rename within
# one filesystem, so it is cheap and the file modes survive exactly as tar wrote them.
# Inside the target when it already exists, beside it when it doesn't — adopting a project
# whose PARENT isn't writable is perfectly normal, and the target itself has to be
# writable either way. Either way the payload has the same enclosing repositories the
# target has, so setup's "already inside a Git repository" check answers for the target.
if [ -d "$TARGET_DIR" ]; then
    STAGE_PARENT="$TARGET_DIR"
else
    STAGE_PARENT="$(dirname "$TARGET_DIR")"
fi
STAGE="$(mktemp -d "$STAGE_PARENT/.agent-dev-spawn.XXXXXX")"
if [ -z "$STAGE" ] || [ ! -d "$STAGE" ]; then
    echo "Error: could not create a staging directory in '$STAGE_PARENT'."
    exit 1
fi
TMPARCHIVE="$(mktemp /tmp/devcontainer-XXXXXX.tar.gz)"
trap 'rm -f "$TMPARCHIVE"; rm -rf "$STAGE"' EXIT
# Turn Ctrl-C and kill into a normal exit so the EXIT trap above always cleans up.
trap 'exit 130' INT TERM

PROJECT_NAME="$(basename "$TARGET_DIR")"
PAYLOAD="$STAGE/$PROJECT_NAME"
if ! mkdir "$PAYLOAD"; then
    echo "Error: could not create a staging directory in '$STAGE_PARENT'."
    exit 1
fi

echo "Downloading ${VERSION:-the latest} dev container release..."
if ! curl -fsSL -o "$TMPARCHIVE" "$ARCHIVE_URL"; then
    echo "Failed to download archive from:"
    echo "  $ARCHIVE_URL"
    exit 1
fi

if ! tar -xzf "$TMPARCHIVE" -C "$PAYLOAD"; then
    echo "Failed to extract archive."
    exit 1
fi

# --- Clean slate ---
# Give the new project a starter README. All of it runs in the STAGING directory, so
# nothing here can reach a file the user already had. The container service/maintenance
# docs in .devcontainer/README.md are left in place.
STUB="$PAYLOAD/.devcontainer/templates/README.spawn.md"
if [ -f "$STUB" ]; then
    sed "s/__PROJECT_NAME__/${PROJECT_NAME}/g" "$STUB" > "$PAYLOAD/README.md"
fi
# Remove the templates dir — it has served its purpose.
rm -rf "$PAYLOAD/.devcontainer/templates"
# The release carries only .devcontainer/, so agent-dev's root files (AGENTS.md, .claude/,
# .gitignore, the spawn scripts) never arrive here. The template marker is removed anyway:
# it makes setup skip the CUI data question, a bypass meant only for a checkout of
# agent-dev itself, and a project must always be asked. Never drop this line on the
# grounds that the release "doesn't contain it".
rm -f "$PAYLOAD/.template-container"
# Nothing to strip for .devcontainer/devcontainer-lock.json: it is a build output the Dev
# Containers CLI regenerates, and the release is built from tracked files only, where it is
# gitignored. Each spawned project generates and owns its own lockfile.

# initializeCommand executes this one directly, so its exec bit is load-bearing and must
# not depend on what the archive happened to store.
chmod +x "$PAYLOAD/.devcontainer/scripts/init" 2>/dev/null

# --- Profile, feature, CUI and credential selection (pre-container) ---
# Hand off to the project's own setup script rather than duplicating any of it here:
# --spawning tells it that it is running on the host, before the container exists, so it
# asks everything — CUI, profiles, features, the profiles' API keys, and Git — and writes
# devcontainer.env itself. That file is gitignored (setup asserts the rule before it
# stages anything), so a real key in it is never at risk of being committed, and asking
# here means the container create is completely non-interactive. A key the user hasn't
# generated yet is skipped with an empty answer and added later with
# `.devcontainer/scripts/setup.sh <profile>`, which setup prints when that happens.
#
# Why this has to happen HERE and not at initializeCommand like everything else: a
# feature is fetched and installed at IMAGE BUILD, from the devcontainer.json the CLI
# parsed before initializeCommand ever ran. So the only moment an answer can still
# change what gets built is before the project is opened at all — and this is it.
# The bedrock feature is the sharpest case: it pulls in the aws-cli feature through
# dependsOn, so an `opal`-only project would build both for nothing.
#
# --chat and --git are passed through as DEFAULTS for two of setup's prompts, not as
# actions taken here. --chat presets the chat feature's entry in the feature list: the
# browser-chat bundle (LiteLLM, Open WebUI, Open Terminal, SearXNG, supervisord) is the
# bulk of the build and no coding agent touches it, so it stays off unless asked for.
# --git presets the answer to "initialize a Git repository?".
#
# Git belongs to setup for the same reason the rest does — it has to come after every
# edit so the initial commit is the finished state — and keeping it there means one
# implementation instead of two. setup.sh likewise owns every devcontainer.json edit;
# there is deliberately no second copy of either in this script.
#
# Identical in both modes, and nothing here tells setup which one it was: every question
# it asks is about the container, not about the tree. setup_git returns with a note when
# any ancestor is already a repository, which is the normal adoption case, so it never
# writes to a history it didn't create. The one adoption case it can't see is an
# un-versioned project where the user asks for a repository — handled after the move.
SETUP="$PAYLOAD/.devcontainer/scripts/setup.sh"
if [ -f "$SETUP" ]; then
    SETUP_ARGS=()
    if [ "$CHAT" = true ]; then
        SETUP_ARGS+=("--chat")
    fi
    if [ "$INIT_GIT" = true ]; then
        SETUP_ARGS+=("--git")
    fi
    if ! bash "$SETUP" --spawning "${SETUP_ARGS[@]}"; then
        echo ""
        echo "Setup did not finish — '$TARGET_DIR' was not changed."
        exit 1
    fi
fi

# --- Move the finished project into the target ---
if [ "$MODE" = adopt ]; then
    # Only .devcontainer/. The project owns everything else, and the classifier has
    # already established that the destination has no .devcontainer/, so this can neither
    # overwrite nor merge anything.
    # A rename within one filesystem, so it either happens or it doesn't — there is no
    # half-copied .devcontainer/ to clean up after.
    if ! mv "$PAYLOAD/.devcontainer" "$TARGET_DIR/"; then
        echo "Failed to add .devcontainer/ to '$TARGET_DIR' — nothing was changed."
        exit 1
    fi
    # A project with no README at all still gets the stub; one that has a README keeps it.
    if [ ! -e "$TARGET_DIR/README.md" ] && [ -f "$PAYLOAD/README.md" ]; then
        mv "$PAYLOAD/README.md" "$TARGET_DIR/"
    fi
    # The project had no repository and the user asked setup for one, which setup created
    # (and committed) in the staging copy. Carry it over and re-record the initial commit
    # from the project's real tree — the staged one held only .devcontainer/ and the stub.
    # The repository keeps setup's repo-local identity, and the devcontainer.env ignore
    # rule setup verified travels in .devcontainer/.gitignore.
    if [ -d "$PAYLOAD/.git" ] && mv "$PAYLOAD/.git" "$TARGET_DIR/"; then
        # The staging directory is inside the target, so it goes first or it gets staged.
        rm -rf "$STAGE"
        git -C "$TARGET_DIR" add -A
        if git -C "$TARGET_DIR" rev-parse -q --verify HEAD >/dev/null; then
            git -C "$TARGET_DIR" commit -q --amend --no-edit
        fi
    fi
elif [ ! -d "$TARGET_DIR" ]; then
    # Greenfield, new directory: rename the whole payload into place in one step.
    if ! mv "$PAYLOAD" "$TARGET_DIR"; then
        echo "Failed to create '$TARGET_DIR'."
        exit 1
    fi
else
    # Greenfield into an existing bare directory (empty, or holding only a `git init`), so
    # nothing can collide: the payload has no .DS_Store, and no .git either — setup saw
    # this directory's repository as an enclosing one and left it alone. An unmatched glob
    # expands to itself, which the -e test discards.
    for ENTRY in "$PAYLOAD"/* "$PAYLOAD"/.*; do
        [ -e "$ENTRY" ] || continue
        case "$(basename "$ENTRY")" in
            .|..) continue ;;
        esac
        if ! mv "$ENTRY" "$TARGET_DIR/"; then
            echo "Failed to populate '$TARGET_DIR'. Remove it and run this again."
            exit 1
        fi
    done
fi

echo ""
VERSION_NOTE=""
if [ -n "$VERSION" ]; then
    VERSION_NOTE=" (release '$VERSION')"
fi
# Report what the Git prompt actually settled on, not what --git asked for — the same
# reason the chat line below reads devcontainer.json instead of $CHAT.
if [ "$MODE" = adopt ]; then
    echo "Added .devcontainer/ to '$TARGET_DIR'$VERSION_NOTE."
    echo "Nothing else in the project was touched."
    if [ -d "$TARGET_DIR/.git" ]; then
        echo "Review and commit .devcontainer/ yourself — spawn does not write to a"
        echo "history it didn't create. devcontainer.env stays out of it either way:"
        echo ".devcontainer/.gitignore covers it."
    fi
elif [ "$GIT_PRE" = true ]; then
    echo "Spawned '$TARGET_DIR'$VERSION_NOTE into the Git repository that was already there."
elif [ -d "$TARGET_DIR/.git" ]; then
    echo "Spawned '$TARGET_DIR'$VERSION_NOTE with a clean Git repository."
else
    echo "Spawned '$TARGET_DIR'$VERSION_NOTE."
fi
# Report what the feature prompt actually settled on rather than what --chat asked for:
# the answer may have been flipped there, and this is the line people act on.
# Matches both the local ./features/chat and the published ghcr.io/.../chat:N reference.
if grep -qE '^[[:space:]]*"(\./features/chat|ghcr\.io/cmu-sei/devcontainer-features/chat:[0-9]+)"' \
    "$TARGET_DIR/.devcontainer/devcontainer.json" 2>/dev/null; then
    # Autostart is that feature's second answer, and it is read back from the env file for
    # the same reason — setup's [Y/n] decided it, and with no terminal there is no file yet.
    if grep -qE '^CHAT_AUTOSTART=1' \
        "$TARGET_DIR/.devcontainer/devcontainer.env" 2>/dev/null; then
        echo "Browser-chat stack included, starting with the container."
    else
        echo "Browser-chat stack included; start it on demand with 'start_chat_stack'"
        echo "(or set CHAT_AUTOSTART=1 in .devcontainer/devcontainer.env)."
    fi
else
    echo "Browser-chat stack omitted — the coding agents are unaffected."
fi
echo "Any feature you turned off is commented out in .devcontainer/devcontainer.json;"
echo "uncomment it and rebuild to add it back."
echo ""
echo "Instructions for generating each provider's API key are at:"
echo ""
echo "  https://code.sei.cmu.edu/bitbucket/projects/CMR/repos/agent-dev/browse/README.md"
echo ""
echo "Open the project in VS Code to build the dev container — it will not ask"
echo "you anything:"
echo ""
echo "  code $TARGET_DIR"
echo ""

exit 0
}
