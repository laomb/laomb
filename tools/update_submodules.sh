#!/usr/bin/env bash
set -euo pipefail

if [ "$(basename "$PWD")" = "tools" ]; then
  cd ..
fi

git submodule sync --recursive
git submodule update --init --remote --merge tools/adbg docs/bios-re
if ! git diff --quiet -- tools/adbg docs/bios-re; then
  git add tools/adbg docs/bios-re
  git commit -m "chore: bump submodules to latest master"
  git push
else
  echo "Submodules already at latest."
fi
