#!/usr/bin/env bash

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'Error: this command must be run inside a Git repository.\n' >&2
  exit 1
fi

if git diff --cached --quiet --exit-code; then
  printf 'Error: no staged changes to commit. Stage your changes first.\n' >&2
  exit 1
fi

raw_message_file=$(mktemp)
commit_message_file=$(mktemp)
trap 'rm -f "$raw_message_file" "$commit_message_file"' EXIT

printf 'Enter your commit message.\n'
printf 'Use the first line for the main message, then add detail lines below it.\n'
printf 'Detail lines will be formatted with hyphens automatically.\n'
printf 'Press Ctrl+D when finished.\n\n'

if ! cat >"$raw_message_file"; then
  printf 'Error: failed to read commit message.\n' >&2
  exit 1
fi

if ! grep -q '[^[:space:]]' "$raw_message_file"; then
  printf 'Error: commit message cannot be empty.\n' >&2
  exit 1
fi

line_number=0
while IFS= read -r line || [ -n "$line" ]; do
  line_number=$((line_number + 1))

  if [ "$line_number" -eq 1 ]; then
    printf '%s\n' "$line" >>"$commit_message_file"
  elif [ -z "${line//[[:space:]]/}" ]; then
    printf '\n' >>"$commit_message_file"
  elif [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
    printf '%s\n' "$line" >>"$commit_message_file"
  else
    printf -- '- %s\n' "$line" >>"$commit_message_file"
  fi
done <"$raw_message_file"

printf '\nCommit message preview:\n'
printf '%s\n' '-----------------------'
cat "$commit_message_file"
printf '%s\n' '-----------------------'

while true; do
  read -r -p 'Create commit with this message? [y/n] ' confirmation
  case "$confirmation" in
  [Yy])
    git commit -F "$commit_message_file"
    break
    ;;
  [Nn])
    printf 'Commit cancelled.\n'
    exit 0
    ;;
  *)
    printf 'Please answer y or n.\n'
    ;;
  esac
done
