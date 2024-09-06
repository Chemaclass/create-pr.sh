#!/bin/bash
set -euo pipefail

# shellcheck disable=SC2034
declare -r CREATE_PR_VERSION="0.4.0"

ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# shellcheck disable=SC1091
[[ -f .env ]] &&  source .env
# shellcheck disable=SC1091
[[ -f .env.local ]] && source .env.local

source "$ROOT_DIR/src/console_header.sh"
source "$ROOT_DIR/src/generic.sh"
source "$ROOT_DIR/src/pr_format.sh"
source "$ROOT_DIR/src/dev/debug.sh"


while [[ $# -gt 0 ]]; do
  argument="$1"
  case $argument in
    --debug)
      set -x
      ;;
    -e|--env)
      # shellcheck disable=SC1090
      source "$2"
      shift
      ;;
    -v|--version)
      console_header::print_version
      trap '' EXIT && exit 0
      ;;
    --help)
      console_header::print_help
      trap '' EXIT && exit 0
      ;;
  esac
  shift
done

# Template Configuration
APP_ROOT_DIR=$(git rev-parse --show-toplevel) || error_and_exit "This directory is not a git repository"
PR_TEMPLATE_DIR=${PR_TEMPLATE_DIR:-".github/PULL_REQUEST_TEMPLATE.md"}
PR_TEMPLATE="$APP_ROOT_DIR/$PR_TEMPLATE_DIR"
[ -z "$PR_TEMPLATE" ] && error_and_exit "PR template file $PR_TEMPLATE not found."

BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || error_and_exit "Failed to get the current branch name."
BASE_BRANCH=${BASE_BRANCH:-"main"}
ASSIGNEE=${ASSIGNEE:-"@me"}

LABEL=${LABEL:-$(get_label "$BRANCH_NAME" "${LABEL_MAPPING:-}")}
PR_TITLE=$(format_title "$BRANCH_NAME")
PR_BODY=$(format_pr_body "$BRANCH_NAME" "$PR_TEMPLATE")

validate_gh_cli_is_installed
validate_the_branch_has_commits
validate_base_branch_exists

# Push the current branch
if ! git push -u origin "$BRANCH_NAME"; then
    error_and_exit "Failed to push the current branch to the remote repository."\
      "Please check your git remote settings."
fi

# Create the PR with the specified options
if ! gh pr create --title "$PR_TITLE" \
                  --base "$BASE_BRANCH" \
                  --head "$BRANCH_NAME" \
                  --assignee "$ASSIGNEE" \
                  --label "$LABEL" \
                  --body "$PR_BODY"; then
    error_and_exit "Failed to create the pull request."\
      "Ensure you have the correct permissions and the repository is properly configured."
fi

echo "Pull request created successfully."
