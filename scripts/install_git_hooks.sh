#!/bin/sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
git config --local core.hooksPath .githooks
chmod +x "$repo_root/.githooks/commit-msg" "$repo_root/scripts/check_commit_message.py"
printf '%s\n' "RHOIDS Git hooks installed. Commit messages will be checked for emoji."
