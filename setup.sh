#!/usr/bin/env bash
# Copyright (C) 2026 Chubby Hippo
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

bash scripts/check.sh

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
