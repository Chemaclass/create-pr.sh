#!/bin/bash
set -euo pipefail

function main::create_pr() {
  validate_base_branch_exists
  validate_the_branch_has_commits
  validate_the_current_branch_is_not_target

  # Push the current branch
  if ! git push -u origin "$BRANCH_NAME"; then
      error_and_exit "Failed to push the current branch to the remote repository."\
        "Please check your git remote settings."
  fi

  if [[ "$PR_USING_CLIENT" == "gitlab" ]]; then
    main::create_pr_gitlab
  else
    main::create_pr_github
  fi
}

function main::create_pr_gitlab() {
  validate_glab_cli_is_installed

  local glab_command=(
    glab mr create
      --title "$PR_TITLE"
      --target-branch "$BASE_BRANCH"
      --source-branch "$BRANCH_NAME"
      --assignee "$PR_ASSIGNEE"
      --label "$PR_LABEL"
      --description "$PR_BODY"
  )

  if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
    glab_command+=("${EXTRA_ARGS[@]}")
  fi

  if ! "${glab_command[@]}"; then
    error_and_exit "Failed to create the Merge Request." \
      "Ensure you have the correct permissions and the repository is properly configured."
  fi
}

function main::create_pr_github() {
  validate_gh_cli_is_installed

  local gh_command=(
    gh pr create
      --title "$PR_TITLE"
      --base "$BASE_BRANCH"
      --head "$BRANCH_NAME"
      --assignee "$PR_ASSIGNEE"
      --label "$PR_LABEL"
      --body "$PR_BODY"
  )

  if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
    gh_command+=("${EXTRA_ARGS[@]}")
  fi

  if ! "${gh_command[@]}"; then
      error_and_exit "Failed to create the Pull Request." \
        "Ensure you have the correct permissions and the repository is properly configured."
  fi
}
