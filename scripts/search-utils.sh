#!/usr/bin/env bash

search_engine() {
  if command -v rg >/dev/null 2>&1; then
    printf 'rg'
  else
    printf 'grep'
  fi
}

search_file() {
  local pattern="$1"
  local file="$2"

  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$file"
  else
    grep -nE "$pattern" "$file"
  fi
}

quiet_search_file() {
  local pattern="$1"
  local file="$2"

  if command -v rg >/dev/null 2>&1; then
    rg -q "$pattern" "$file"
  else
    grep -Eq "$pattern" "$file"
  fi
}
