#!/bin/sh
# Xcode Cloud post-clone step: apply the repository commit-message policy.
#
# Pull request builds check every commit in the pull request
# (CI_PULL_REQUEST_TARGET_COMMIT..CI_PULL_REQUEST_SOURCE_COMMIT).
# Branch and tag builds check only CI_COMMIT, because Xcode Cloud does not
# expose the previous head of the branch. Commits pushed directly to a branch
# in a batch are therefore only fully covered when they arrive through a
# pull request.
set -eu

repo_root="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
cd "$repo_root"

remote="$(git remote | head -n 1)"

fail() {
  printf '%s\n' "ci_post_clone: $*" >&2
  exit 1
}

has_commit() {
  git cat-file -e "$1^{commit}" 2>/dev/null
}

ensure_full_history() {
  if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
    [ -n "$remote" ] || fail "shallow clone with no remote to fetch history from"
    echo "Fetching full history from $remote"
    git fetch --quiet --unshallow "$remote" || fail "could not unshallow the clone"
  fi
}

ensure_commit() {
  if ! has_commit "$1"; then
    [ -n "$remote" ] || fail "commit $1 is missing and no remote is configured"
    echo "Fetching missing commit $1 from $remote"
    git fetch --quiet "$remote" "$1" || true
  fi
  has_commit "$1" || fail "commit $1 is not available in the clone"
}

check_commit() {
  message_file="${TMPDIR:-/tmp}/rhoids-commit-message-$1.txt"
  git show -s --format=%B "$1" > "$message_file"
  echo "Checking $1"
  python3 scripts/check_commit_message.py --file "$message_file"
  rm -f "$message_file"
}

pr_target="${CI_PULL_REQUEST_TARGET_COMMIT:-}"
pr_source="${CI_PULL_REQUEST_SOURCE_COMMIT:-}"

if [ -n "$pr_target" ] && [ -n "$pr_source" ]; then
  ensure_full_history
  ensure_commit "$pr_target"
  ensure_commit "$pr_source"
  base="$(git merge-base "$pr_target" "$pr_source")" || fail "no merge base between $pr_target and $pr_source"
  commits="$(git rev-list --reverse "$base..$pr_source")"
  if [ -z "$commits" ]; then
    echo "No commits introduced by this pull request."
  fi
  for commit in $commits; do
    check_commit "$commit"
  done
elif [ -n "${CI_COMMIT:-}" ]; then
  ensure_commit "$CI_COMMIT"
  check_commit "$CI_COMMIT"
else
  fail "neither pull request commits nor CI_COMMIT are set"
fi

echo "Commit message policy passed."
