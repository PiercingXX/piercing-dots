# Black Minimalistic Cursor Theme (Vendored)

This directory vendors a Linux-compatible conversion of the upstream cursor set:
- Source page: https://www.rw-designer.com/cursor-set/black-minimalistic
- Source archive: `upstream/black-minimalistic.zip`
- Upstream readme: `upstream/readme.txt`

## Why this is vendored
The theme is stored in-repo so installs do not depend on RW Designer availability.

## Contents
- `cursors/`: converted Xcursor files and symlinks used by Linux desktops
- `index.theme`: theme metadata
- `upstream/`: original downloaded source files for reproducibility

## Refresh process
If you need to rebuild from upstream:
1. Download the latest upstream zip into `upstream/black-minimalistic.zip`.
2. Convert `*.cur` and `*.ani` files with `win2xcur` into `cursors/`.
3. Recreate symlinks for standard Linux cursor aliases.
