#!/usr/bin/env bash
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$here"

sources=(lua plugin tests scripts)
shell_sources=(setup.sh scripts/check.sh)

mise_synced=0
sync_mise_tools() {
  if [ "$mise_synced" = 1 ] || ! command -v mise >/dev/null 2>&1; then
    return 0
  fi
  mise_synced=1
  mise install >/dev/null 2>&1 || true
}

resolve() {
  local bin="$1"
  if command -v "$bin" >/dev/null 2>&1; then
    printf '%s' "$bin"
    return 0
  fi
  sync_mise_tools
  if command -v mise >/dev/null 2>&1 && mise which "$bin" >/dev/null 2>&1; then
    printf 'mise exec -- %s' "$bin"
    return 0
  fi
  return 1
}

require() {
  local bin="$1"
  local cmd
  if ! cmd="$(resolve "$bin")"; then
    echo "error: $bin not found on PATH and not available via mise" >&2
    echo "install mise (https://mise.jdx.dev) and run 'mise install' in this repo," >&2
    echo "or put $bin on your PATH — mise.toml pins the versions this repo checks with" >&2
    exit 1
  fi
  printf '%s' "$cmd"
}

nvim_cmd="$(require nvim)"
stylua_cmd="$(require stylua)"
selene_cmd="$(require selene)"
shellcheck_cmd="$(require shellcheck)"

echo "==> neovim: $($nvim_cmd --version | head -1)"

echo "==> stylua --check (formatting)"
$stylua_cmd --check "${sources[@]}"

echo "==> selene (lint)"
$selene_cmd "${sources[@]}"

echo "==> shellcheck (shell lint)"
$shellcheck_cmd "${shell_sources[@]}"

echo "==> lua/neomeow/default_rc.lua in sync with .neomeowrc"
$nvim_cmd -l scripts/check_default_rc.lua

echo "==> the BDD suite (tests/run.lua)"
$nvim_cmd -l tests/run.lua

echo "==> the adapter smoke test (tests/smoke.lua)"
$nvim_cmd --headless -u NONE -i NONE -l tests/smoke.lua
