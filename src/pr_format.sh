#!/bin/bash

# shellcheck disable=SC2155

function format_title() {
    branch_name="$1"
    local ticket_key=$(get_ticket_key "$branch_name")
    local ticket_number=$(get_ticket_number "$branch_name")

    if [[ -z "$ticket_key" || -z "$ticket_number" ]]; then
      normalize_pr_title "$branch_name"
      return
    fi

    # Initialize prefix and parts as empty
    prefix=""
    part1=""
    part2=""
    part3=""

    # Remove the prefix if it starts with any prefix followed by '/'
    if [[ "$branch_name" =~ ^[^/]+/ ]]; then
        prefix=$(echo "$branch_name" | cut -d'/' -f1)
        branch_name="${branch_name#*/}"

        case "$prefix" in
            fix|bug|bugfix) prefix="Fix" ;;
            *)              prefix="" ;;
        esac
    fi
    # Extract and format parts of the branch_name
    part1=$(echo "$branch_name" | cut -d'-' -f1 | tr '[:lower:]' '[:upper:]')
    part2=$(echo "$branch_name" | cut -d'-' -f2)
    part3=$(echo "$branch_name" | cut -d'-' -f3- | tr '-' ' '| tr '_' ' ')

    # Ensure there is no duplicated "Fix"
    if [[ "$part3" =~ Fix || "$part3" =~ fix ]]; then
        prefix=""
    fi

    # Construct the final formatted title
    if [[ -n "$prefix" ]]; then
        part3="$(echo "$part3" | tr '[:upper:]' '[:lower:]')"
        echo "$part1-$part2 $prefix $part3"
    else
        part3="$(echo "${part3:0:1}" | tr '[:lower:]' '[:upper:]')${part3:1}"
        echo "$part1-$part2 $part3"
    fi
}
function normalize_pr_title() {
  input="$1"
  # Remove the prefix before the first '/'
  input="${input#*/}"
  # Remove leading digits followed by a hyphen (e.g., "27-")
  input="${input#[0-9]*-}"

  result=$(echo "$input" | awk '
      {
          gsub(/_/, " ", $0)  # Replace underscores with spaces
          for (i = 1; i <= NF; i++) {
              # Capitalize first letter and lowercase the rest
              $i = toupper(substr($i, 1, 1)) tolower(substr($i, 2))
          }
          gsub(/-/, " ", $0)  # Replace hyphens with spaces
          print
      }' | sed 's/[[:space:]]*$//')

  echo "$result"
}

function get_ticket_number() {
  branch_name=$1
  echo "$branch_name" | grep -oE "[0-9]+" | head -n 1
}

function get_ticket_key() {
  branch_name=$1

  # Check if the branch name contains a '/'
  if [[ "$branch_name" == *"/"* ]]; then
    # Extract the part after the first '/' and process it
    branch_suffix="${branch_name#*/}"
    # Try to extract the pattern "KEY-NUMBER" and stop after the first occurrence
    ticket_key=$(echo "$branch_suffix" | grep -oE "[A-Za-z]+-[0-9]+" | head -n 1 | sed 's/-[0-9]*$//')

    # If no ticket key is found, ensure there's no ticket-like pattern and use the prefix if it's uppercase
    if [[ -z "$ticket_key" ]]; then
      first_part=$(echo "$branch_name" | cut -d'/' -f2 | grep -oE "^[A-Z]+")
      if [[ -n "$first_part" ]]; then
        ticket_key="$first_part"
      fi
    fi
  else
    # For branch names without '/'
    ticket_key=$(echo "$branch_name" | grep -oE "^[A-Za-z]+" | head -n 1)
  fi

  # If no ticket key is found, ensure there's no ticket-like pattern and return empty
  if [[ -z "$ticket_key" ]]; then
    if ! echo "$branch_name" | grep -qE "[A-Za-z]+-[0-9]+"; then
      echo ""
      return
    fi
  fi

  echo "$ticket_key" | tr '[:lower:]' '[:upper:]'
}

# Find the default label based on the branch prefix
function get_label() {
  local branch_name=$1
  local mapping=${2:-"feat|feature:enhancement;\
  fix|bug|bugfix:bug;\
  docs|documentation:documentation;\
  default:enhancement"}
  # Remove empty spaces due to indentation
  mapping=${mapping// /}
  # Extract the prefix (the part before the first slash or dash)
  local prefix
  prefix=$(echo "$branch_name" | sed -E 's@^([^/-]+).*@\1@')
  # Default label
  local default_label="enhancement"

  # Loop through the mapping string to find a match
  IFS=';' # Split mapping entries by semicolon
  for entry in $mapping; do
    # Split each entry into keys and value
    IFS=':' read -r keys value <<< "$entry"

    # Check if the prefix matches any of the keys
    IFS='|' # Split keys by pipe symbol
    for key in $keys; do
      if [[ "$prefix" == "$key" ]]; then
        echo "$value"
        return
      fi
    done

    # Set the default label if found
    if [[ "$keys" == "default" ]]; then
      default_label="$value"
    fi
  done

  # Return the default label if no match is found
  echo "$default_label"
}

# shellcheck disable=SC2001
function format_pr_body() {
  local branch_name=$1
  local pr_template=$2
  local pr_body

  local ticket_key
  ticket_key=$(get_ticket_key "$branch_name")

  local ticket_number
  ticket_number=$(get_ticket_number "$branch_name")

  local with_link=false
  if [[ -n "${PR_TICKET_LINK_PREFIX}" && -n "${ticket_number}" ]]; then
    with_link=true
  fi

  # {{TICKET_LINK}}
  local ticket_link="Nope"
  if [[ "$with_link" == true ]]; then
    if [[ -z "$ticket_key" ]]; then
      ticket_link="${PR_TICKET_LINK_PREFIX}${ticket_number}"
    else
      ticket_link="${PR_TICKET_LINK_PREFIX}${ticket_key}-${ticket_number}"
    fi
    ticket_link="${PR_TICKET_PREFIX_TEXT}${ticket_link}"
  fi
  pr_body=$(perl -pe 's/<!--\s*{{\s*(.*?)\s*}}\s*-->/{{ $1 }}/g' "$pr_template")
  pr_body=$(echo "$pr_body" | sed "s|{{[[:space:]]*TICKET_LINK[[:space:]]*}}|$ticket_link|g")

  # {{BACKGROUND}}
  local background_text="Provide some context to the reviewer before jumping in the code."
  if [[ "$with_link" == true ]]; then
    background_text="Details in the ticket."
  fi
  pr_body=$(echo "$pr_body" | sed "s|{{[[:space:]]*BACKGROUND[[:space:]]*}}|$background_text|g")

  # Trim leading and trailing whitespace from pr_body
  pr_body=$(echo "$pr_body" | awk '{$1=$1};1')

  echo "$pr_body"
}
