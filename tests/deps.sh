#!/bin/sh
set -eu

revision=74b06c6c75e4eeb3108ec01852001636d85a932b
destination=.deps/plenary.nvim
if [ ! -d "$destination/.git" ]; then
  git clone https://github.com/nvim-lua/plenary.nvim "$destination"
fi
if [ "$(git -C "$destination" rev-parse HEAD)" != "$revision" ]; then
  git -C "$destination" fetch origin "$revision"
  git -C "$destination" checkout --detach "$revision"
fi
