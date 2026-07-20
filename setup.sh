#!/usr/bin/env bash
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

nvim_cmd=""
if command -v nvim >/dev/null 2>&1; then
  nvim_cmd="nvim"
elif command -v mise >/dev/null 2>&1 && mise which nvim >/dev/null 2>&1; then
  nvim_cmd="mise exec -- nvim"
else
  echo "error: neovim not found on PATH and not available via mise" >&2
  echo "install Neovim 0.10+ (mise use neovim@latest, or your package manager)" >&2
  exit 1
fi

echo "==> neovim: $($nvim_cmd --version | head -1)"

echo "==> checking lua/neomeow/default_rc.lua is in sync with .neomeowrc"
$nvim_cmd -l scripts/check_default_rc.lua

echo "==> running the BDD suite (tests/run.lua)"
$nvim_cmd -l tests/run.lua

echo "==> running the adapter smoke test (tests/smoke.lua)"
$nvim_cmd --headless -u NONE -i NONE -l tests/smoke.lua

data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
dest="$data_dir/site/pack/neomeow/start/neomeow.nvim"
mkdir -p "$(dirname "$dest")"
if [ -e "$dest" ] || [ -L "$dest" ]; then
  if [ "$(readlink -f "$dest" 2>/dev/null || true)" = "$here" ]; then
    echo "==> already installed at $dest"
  else
    echo "==> replacing existing $dest"
    rm -rf "$dest"
    ln -s "$here" "$dest"
  fi
else
  ln -s "$here" "$dest"
  echo "==> installed (symlink) at $dest"
fi

cat <<'EOF'

==> done. Add to your init.lua:

    require('neomeow').setup()

Then open a file: every normal buffer starts in meow NORMAL. Press SPC ? for
the cheatsheet, SPC c m to open your neomeow.lua settings file.
EOF
