# spawn.ps1 - Download the latest released dev container bundle into a project
#
# Usage: .\spawn.ps1 [<target-directory>] [-Git] [-Version <tag>] [-Chat]
#    or: & ([scriptblock]::Create((irm <releases>/latest/download/spawn.ps1))) [<target-directory>] [options]

param(
    [Parameter(Position = 0)]
    [string]$TargetDir,

    [Alias("g")]
    [switch]$Git,

    [string]$Version,

    [switch]$Chat
)

# Release assets built by .github/workflows/release-bundle.yml. The zip unpacks to a
# top-level .devcontainer\; releases/latest/download always serves the newest release.
$ReleasesUrl = "https://github.com/cmu-sei/devcontainer-features/releases"
$Asset = "devcontainer.zip"

# Every failure path stops through Stop-Spawn rather than `exit`. Run as a script block (the
# download-and-run one-liner above) `exit` would close the user's PowerShell session, so the
# stop is thrown, caught at the bottom, and turned into `exit 1` only when this is running
# as a script file ($PSCommandPath is empty for a script block). The inner finally blocks
# run on the way out either way, so the staging copy is still cleaned up.
function Stop-Spawn { throw [System.OperationCanceledException]::new("spawn stopped") }

$SpawnExit = 0
try {
    # --- Validate arguments ---

    # Ask for the target when none was given and there is a console to ask on (the same
    # test setup.ps1 uses). There is no default - an empty answer prints usage - because
    # silently adopting the current directory is the costlier mistake. Quotes are stripped
    # because a pasted or dragged-in path often arrives wrapped in them.
    if ([string]::IsNullOrEmpty($TargetDir) -and [Environment]::UserInteractive -and
        -not [Console]::IsInputRedirected) {
        Write-Host "Where should the project go? A new folder, or an existing project to add .devcontainer\ to."
        $TargetDir = (Read-Host "Project directory").Trim().Trim('"', "'")
    }

    if ([string]::IsNullOrEmpty($TargetDir)) {
        Write-Host "Usage: spawn.ps1 [<target-directory>] [-Git] [-Version <tag>] [-Chat]"
        Write-Host "   or: & ([scriptblock]::Create((irm $ReleasesUrl/latest/download/spawn.ps1))) [<target-directory>] [options]"
        Write-Host ""
        Write-Host "Downloads the latest released dev container bundle, then runs its setup to pick the"
        Write-Host "provider profiles, the features to build and the profiles' API keys."
        Write-Host ""
        Write-Host "The target decides what happens:"
        Write-Host "  new or empty directory   .devcontainer\ and a starter README become a new project"
        Write-Host "  an existing project      only .devcontainer\ is added; nothing the project"
        Write-Host "                           already has is modified or removed"
        Write-Host ""
        Write-Host "With no target directory, spawn asks for one (when there is a console to ask on)."
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -Git, -g            Preselect ""yes"" in the Git prompt (initialize a repository and"
        Write-Host "                      make an initial commit once setup is done)"
        Write-Host "  -Version <tag>      Download a specific release, e.g. v1.2.3 (default: the latest release)"
        Write-Host "  -Chat               Preselect the browser-chat stack (LiteLLM, Open WebUI, Open Terminal,"
        Write-Host "                      SearXNG, supervisord) in the feature prompt. Off by default for a"
        Write-Host "                      leaner, faster build"
        Stop-Spawn
    }

    if (-not [string]::IsNullOrEmpty($Version)) {
        $ArchiveUrl = "$ReleasesUrl/download/$([System.Uri]::EscapeDataString($Version))/$Asset"
    } else {
        $ArchiveUrl = "$ReleasesUrl/latest/download/$Asset"
    }

    # Only check for git if -Git is used. The identity is NOT checked here: setup asks for one
    # when the global config has none and sets it on the new repo alone (see setup.ps1's
    # Initialize-GitRepo), so a missing global identity is no longer a reason to refuse the
    # spawn.
    if ($Git -and -not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Error: 'git' is required when using -Git but is not installed."
        Stop-Spawn
    }

    # --- Resolve the target to an absolute path ---
    # Before anything else, because the project name is the leaf and `spawn.ps1 .` is the
    # natural way to adopt the directory you are standing in - where the leaf is ".". Missing
    # intermediate directories are created, as they always were.
    $TargetParent = Split-Path $TargetDir -Parent
    if ([string]::IsNullOrEmpty($TargetParent)) {
        $TargetParent = (Get-Location).Path
    }
    if (Test-Path $TargetDir -PathType Container) {
        $TargetDir = (Resolve-Path $TargetDir).Path
    } else {
        New-Item -ItemType Directory -Path $TargetParent -Force -ErrorAction SilentlyContinue | Out-Null
        if (-not (Test-Path $TargetParent -PathType Container)) {
            Write-Host "Error: the parent directory of '$TargetDir' does not exist and could not be created."
            Stop-Spawn
        }
        $TargetDir = Join-Path (Resolve-Path $TargetParent).Path (Split-Path $TargetDir -Leaf)
    }

    # True when the directory holds nothing a project would miss - empty, or holding only a
    # bare `git init` and Finder droppings. Treated as greenfield so the common
    # "make a folder, then spawn into it" flow does not land in adoption mode.
    function Test-DirIsBare {
        param([string]$Dir)
        $Items = @(Get-ChildItem -LiteralPath $Dir -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne ".git" -and $_.Name -ne ".DS_Store" })
        return ($Items.Count -eq 0)
    }

    # --- Classify the target: greenfield or adoption ---
    # Two supported shapes, and one that has to be refused:
    #   greenfield  nothing there, or an empty/bare directory - the whole cleaned tree
    #               becomes the project.
    #   adopt       an existing project with no .devcontainer\ - only .devcontainer\ is
    #               added, and nothing the project already owns is touched.
    #   refused     an existing .devcontainer\. Replacing it would take out the feature set
    #               chosen in devcontainer.json, the credentials in devcontainer.env and the
    #               profiles the CUI question deleted; and two devcontainer.json files cannot
    #               be merged automatically. Both repairs are manual, and they are different,
    #               so the message says which one applies.
    $Mode = "greenfield"
    if (Test-Path $TargetDir) {
        if (-not (Test-Path $TargetDir -PathType Container)) {
            Write-Host "Error: '$TargetDir' exists and is not a directory."
            Stop-Spawn
        }
        if (Test-Path (Join-Path $TargetDir ".devcontainer")) {
            # Join-Path rather than a literal backslash: this one interpolates a real absolute
            # path, and spawn.ps1 also runs under pwsh on macOS/Linux.
            Write-Host "Error: '$(Join-Path $TargetDir ".devcontainer")' already exists."
            Write-Host ""
            if (Test-Path (Join-Path $TargetDir ".devcontainer/profiles")) {
                Write-Host "  This project already has agent-dev's dev container. Spawning over it would"
                Write-Host "  discard the feature set you chose in .devcontainer\devcontainer.json, the"
                Write-Host "  credentials in .devcontainer\devcontainer.env, and the provider profiles the"
                Write-Host "  CUI question deleted. To update it, replace .devcontainer\ by hand."
            } else {
                Write-Host "  That is another dev container's configuration, and two devcontainer.json"
                Write-Host "  files cannot be merged automatically. Move it aside first, then run this"
                Write-Host "  again to add agent-dev's."
            }
            Write-Host ""
            Stop-Spawn
        }
        if (-not (Test-DirIsBare $TargetDir)) {
            $Mode = "adopt"
        }
    }

    # Whether a repository was already here, recorded BEFORE setup runs: the closing summary
    # reads .git to report what the Git prompt settled on, and a bare `git init` counts as
    # greenfield, so without this the script would claim credit for a repo it merely found.
    $GitPre = Test-Path (Join-Path $TargetDir ".git")

    # --- Download and stage ---
    # Everything - extract, clean slate AND setup's questions - happens in a STAGING copy of
    # the project, and only the finished result is moved into the target, as the very last
    # step. So a spawn that is cancelled or fails at any point (Ctrl-C during a prompt, a
    # failed download, setup exiting non-zero) leaves the target exactly as it was: no
    # half-configured project to delete before running spawn again. The failure paths also
    # delete what they were handed, which must never be the user's tree.
    #
    # The payload sits in "$Stage\<project name>" rather than in $Stage itself, because setup
    # names the project after its directory (the banner, the stub README), and so a new
    # target can be created by renaming the payload into place in one step.
    #
    # The staging directory goes inside the target when it already exists and beside it when it
    # does not: adopting a project whose PARENT is not writable is perfectly normal, and the
    # target itself has to be writable either way. Either way the payload has the same
    # enclosing repositories the target has, so setup's "already inside a Git repository"
    # check answers for the target.
    if (Test-Path $TargetDir -PathType Container) {
        $StageParent = $TargetDir
    } else {
        $StageParent = Split-Path $TargetDir -Parent
    }
    $Stage = Join-Path $StageParent ".agent-dev-spawn-$(Get-Random)"
    $ProjectName = Split-Path $TargetDir -Leaf
    $Payload = Join-Path $Stage $ProjectName
    try {
        New-Item -ItemType Directory -Path $Payload -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "Error: could not create a staging directory in '$StageParent'."
        Stop-Spawn
    }

    $TmpZip = Join-Path ([System.IO.Path]::GetTempPath()) "devcontainer-$(Get-Random).zip"

    # The finally below runs on Ctrl-C too, so a cancelled spawn removes the staging copy.
    try {
        $VersionLabel = if ([string]::IsNullOrEmpty($Version)) { "the latest" } else { $Version }
        Write-Host "Downloading $VersionLabel dev container release..."
        try {
            Invoke-WebRequest -Uri $ArchiveUrl -OutFile $TmpZip -UseBasicParsing -ErrorAction Stop
        } catch {
            Write-Host "Failed to download archive from:"
            Write-Host "  $ArchiveUrl"
            Stop-Spawn
        }

        # Extract into the staging directory
        try {
            Expand-Archive -Path $TmpZip -DestinationPath $Payload -ErrorAction Stop
        } catch {
            Write-Host "Failed to extract archive."
            Stop-Spawn
        }

        # --- Clean slate ---
        # Give the new project a starter README. All of it runs in the STAGING directory, so
        # nothing here can reach a file the user already had. The container
        # service/maintenance docs in .devcontainer\README.md are left in place.
        $Stub = Join-Path $Payload ".devcontainer/templates/README.spawn.md"
        if (Test-Path $Stub) {
            (Get-Content $Stub -Raw).Replace("__PROJECT_NAME__", $ProjectName) |
                Set-Content (Join-Path $Payload "README.md") -NoNewline
        }
        # Every Remove-Item below needs -Force: on non-Windows PowerShell a leading dot marks
        # the item hidden, and Remove-Item silently skips hidden items.
        #
        # Remove the templates dir - it has served its purpose.
        Remove-Item (Join-Path $Payload ".devcontainer/templates") -Recurse -Force -ErrorAction SilentlyContinue
        # The release carries only .devcontainer\, so agent-dev's root files (AGENTS.md,
        # .claude\, .gitignore, the spawn scripts) never arrive here. The template marker is
        # removed anyway: it makes setup skip the CUI data question, a bypass meant only for a
        # checkout of agent-dev itself, and a project must always be asked. Never drop this
        # line on the grounds that the release "doesn't contain it".
        Remove-Item (Join-Path $Payload ".template-container") -Force -ErrorAction SilentlyContinue
        # Nothing to strip for .devcontainer\devcontainer-lock.json: it is a build output the
        # Dev Containers CLI regenerates, and the release is built from tracked files only,
        # where it is gitignored. Each spawned project owns its own lockfile.

        # --- Profile, feature, CUI and credential selection (pre-container) ---
        # Hand off to the project's own setup script rather than duplicating any of it here:
        # -Spawning tells it that it is running on the host, before the container exists, so it
        # asks everything - CUI, profiles, features, the profiles' API keys, and Git - and
        # writes devcontainer.env itself. That file is gitignored (setup asserts the rule before
        # it stages anything), so a real key in it is never at risk of being committed, and
        # asking here means the container create is completely non-interactive. A key the user
        # has not generated yet is skipped with an empty answer and added later with
        # .devcontainer\scripts\setup.ps1 <profile>, which setup prints when that happens.
        #
        # Why this has to happen HERE and not at initializeCommand like everything else: a
        # feature is fetched and installed at IMAGE BUILD, from the devcontainer.json the CLI
        # parsed before initializeCommand ever ran. So the only moment an answer can still
        # change what gets built is before the project is opened at all - and this is it.
        # The bedrock feature is the sharpest case: it pulls in the aws-cli feature through
        # dependsOn, so an `opal`-only project would build both for nothing.
        #
        # -Chat and -Git are passed through as DEFAULTS for two of setup's prompts, not as
        # actions taken here. -Chat presets the chat feature's entry in the feature list: the
        # browser-chat bundle (LiteLLM, Open WebUI, Open Terminal, SearXNG, supervisord) is the
        # bulk of the build and no coding agent touches it, so it stays off unless asked for.
        # -Git presets the answer to "initialize a Git repository?".
        #
        # Git belongs to setup for the same reason the rest does - it has to come after every
        # edit so the initial commit is the finished state - and keeping it there means one
        # implementation instead of two. setup.ps1 likewise owns every devcontainer.json edit;
        # there is deliberately no second copy of either in this script. The one adoption case
        # it can't see is an un-versioned project where the user asks for a repository -
        # handled after the move.
        $SetupScript = Join-Path $Payload ".devcontainer/scripts/setup.ps1"
        if (Test-Path $SetupScript) {
            $SetupArgs = @{ Spawning = $true }
            if ($Chat) { $SetupArgs["Chat"] = $true }
            if ($Git) { $SetupArgs["Git"] = $true }
            # setup.ps1 reports failure with `exit 1`, which sets $LASTEXITCODE; a script that
            # ends without `exit` leaves it untouched, hence the reset.
            $global:LASTEXITCODE = 0
            & $SetupScript @SetupArgs
            if ($LASTEXITCODE -ne 0) {
                Write-Host ""
                Write-Host "Setup did not finish - '$TargetDir' was not changed."
                Stop-Spawn
            }
        }

        # --- Move the finished project into the target ---
        # No exec-bit mirror of the POSIX side's `chmod +x init`: on Windows initializeCommand
        # resolves init.cmd through PATHEXT, and NTFS has no execute bit to set.
        if ($Mode -eq "adopt") {
            # Only .devcontainer\. The project owns everything else, and the classifier has
            # already established that the destination has no .devcontainer\, so this can
            # neither overwrite nor merge anything.
            try {
                Move-Item (Join-Path $Payload ".devcontainer") $TargetDir -ErrorAction Stop
            } catch {
                Write-Host "Failed to add .devcontainer\ to '$TargetDir' - nothing was changed."
                Stop-Spawn
            }
            # A project with no README at all still gets the stub; one that has a README keeps it.
            $StagedReadme = Join-Path $Payload "README.md"
            if ((-not (Test-Path (Join-Path $TargetDir "README.md"))) -and (Test-Path $StagedReadme)) {
                Move-Item $StagedReadme $TargetDir -ErrorAction SilentlyContinue
            }
            # The project had no repository and the user asked setup for one, which setup
            # created (and committed) in the staging copy. Carry it over and re-record the
            # initial commit from the project's real tree - the staged one held only
            # .devcontainer\ and the stub. The repository keeps setup's repo-local identity, and
            # the devcontainer.env ignore rule setup verified travels in .devcontainer\.gitignore.
            $StagedGit = Join-Path $Payload ".git"
            if (Test-Path $StagedGit) {
                Move-Item $StagedGit $TargetDir -Force -ErrorAction SilentlyContinue
                if (Test-Path (Join-Path $TargetDir ".git")) {
                    # The staging directory is inside the target, so it goes first or it gets staged.
                    Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue
                    git -C $TargetDir add -A
                    git -C $TargetDir rev-parse -q --verify HEAD 2>$null | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        git -C $TargetDir commit -q --amend --no-edit
                    }
                }
            }
        } elseif (-not (Test-Path $TargetDir -PathType Container)) {
            # Greenfield, new directory: rename the whole payload into place in one step.
            try {
                Move-Item $Payload $TargetDir -ErrorAction Stop
            } catch {
                Write-Host "Failed to create '$TargetDir'."
                Stop-Spawn
            }
        } else {
            # Greenfield into an existing bare directory (empty, or holding only a `git init`),
            # so nothing can collide: the payload has no .DS_Store, and no .git either - setup
            # saw this directory's repository as an enclosing one and left it alone.
            # @() materializes the listing before the first move, so the enumerator is never
            # walking a directory that is being emptied underneath it.
            try {
                foreach ($Entry in @(Get-ChildItem -LiteralPath $Payload -Force)) {
                    Move-Item $Entry.FullName $TargetDir -ErrorAction Stop
                }
            } catch {
                Write-Host "Failed to populate '$TargetDir'. Remove it and run this again."
                Stop-Spawn
            }
        }

        Write-Host ""
        $VersionNote = ""
        if (-not [string]::IsNullOrEmpty($Version)) {
            $VersionNote = " (release '$Version')"
        }
        # Report what the Git prompt actually settled on, not what -Git asked for - the same
        # reason the chat line below reads devcontainer.json instead of $Chat.
        if ($Mode -eq "adopt") {
            Write-Host "Added .devcontainer\ to '$TargetDir'$VersionNote."
            Write-Host "Nothing else in the project was touched."
            if (Test-Path (Join-Path $TargetDir ".git")) {
                Write-Host "Review and commit .devcontainer\ yourself - spawn does not write to a"
                Write-Host "history it didn't create. devcontainer.env stays out of it either way:"
                Write-Host ".devcontainer\.gitignore covers it."
            }
        } elseif ($GitPre) {
            Write-Host "Spawned '$TargetDir'$VersionNote into the Git repository that was already there."
        } elseif (Test-Path (Join-Path $TargetDir ".git")) {
            Write-Host "Spawned '$TargetDir'$VersionNote with a clean Git repository."
        } else {
            Write-Host "Spawned '$TargetDir'$VersionNote."
        }
        # Report what the feature prompt actually settled on rather than what -Chat asked for:
        # the answer may have been flipped there, and this is the line people act on.
        $DcJson = Join-Path $TargetDir ".devcontainer/devcontainer.json"
        $ChatOn = $false
        if (Test-Path $DcJson) {
            # Matches both the local ./features/chat and the published ghcr.io/.../chat:N reference.
            $ChatOn = [bool](Get-Content $DcJson | Where-Object {
                $_ -match '^\s*"(\./features/chat|ghcr\.io/cmu-sei/devcontainer-features/chat:\d+)"' })
        }
        if ($ChatOn) {
            # Autostart is that feature's second answer, and it is read back from the env file
            # for the same reason - setup's [Y/n] decided it, and with no console there is no
            # file yet.
            $DcEnv = Join-Path $TargetDir ".devcontainer/devcontainer.env"
            $AutostartOn = $false
            if (Test-Path $DcEnv) {
                $AutostartOn = [bool](Get-Content $DcEnv | Where-Object { $_ -match '^CHAT_AUTOSTART=1' })
            }
            if ($AutostartOn) {
                Write-Host "Browser-chat stack included, starting with the container."
            } else {
                Write-Host "Browser-chat stack included; start it on demand with 'start_chat_stack'"
                Write-Host "(or set CHAT_AUTOSTART=1 in .devcontainer\devcontainer.env)."
            }
        } else {
            Write-Host "Browser-chat stack omitted - the coding agents are unaffected."
        }
        Write-Host "Any feature you turned off is commented out in .devcontainer\devcontainer.json;"
        Write-Host "uncomment it and rebuild to add it back."
        Write-Host ""
        Write-Host "Instructions for generating each provider's API key are at:"
        Write-Host ""
        Write-Host "  https://code.sei.cmu.edu/bitbucket/projects/CMR/repos/agent-dev/browse/README.md"
        Write-Host ""
        Write-Host "Open the project in VS Code to build the dev container - it will not ask"
        Write-Host "you anything:"
        Write-Host ""
        Write-Host "  code $TargetDir"

    } finally {
        # Clean up the temp zip and the staging directory. It survives every failure, a
        # Ctrl-C, and the paths that move only the payload's contents out of it. It sits inside
        # the target when the target already existed, so leaving it behind would litter the
        # user's project.
        Remove-Item $TmpZip -ErrorAction SilentlyContinue
        Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch [System.OperationCanceledException] {
    $SpawnExit = 1
}
if ($PSCommandPath) {
    exit $SpawnExit
}
$global:LASTEXITCODE = $SpawnExit
