#!/bin/bash
set -o allexport

GH_CLI_INSTALLATION_URL="https://cli.github.com/"
GLAB_CLI_INSTALLATION_URL="https://gitlab.com/gitlab-org/cli/"

function error_and_exit() {
    echo "Error: $1" >&2
    exit 1
}

function validate_base_branch_exists() {
  if ! git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    error_and_exit "Base branch '$BRANCH_NAME' does not exist. Please check the base branch name or create it."
  fi
}

function validate_the_branch_has_commits() {
  if [ "$(git rev-list --count "$BRANCH_NAME")" -eq 0 ]; then
    error_and_exit "The current branch has no commits. Make sure the branch is not empty."
  fi
}

function validate_the_current_branch_is_not_target() {
  if [ "$BRANCH_NAME" = "$BASE_BRANCH" ]; then
    error_and_exit "You are on the same branch as target -> $BRANCH_NAME"
  fi
}

function validate_gh_cli_is_installed() {
  if ! command -v gh &> /dev/null; then
    error_and_exit "gh CLI is not installed. Please install it from $GH_CLI_INSTALLATION_URL and try again."
  fi
}

function validate_glab_cli_is_installed() {
  if ! command -v glab &> /dev/null; then
    error_and_exit "glab CLI is not installed. Please install it from $GLAB_CLI_INSTALLATION_URL and try again."
  fi
}
