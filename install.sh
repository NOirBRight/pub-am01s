#!/usr/bin/env bash
# One-line install: curl -fsSL https://raw.githubusercontent.com/NOirBRight/pub-am01s/main/install.sh | bash
# Clones the latest release into ~/.local/share/pub-am01s, runs scripts/install.py
# there, then reloads Hyprland and the Omarchy shell. Run it again to upgrade.
set -euo pipefail

REPO="https://github.com/NOirBRight/pub-am01s.git"
DIR="${PUB_AM01S_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/pub-am01s}"

for cmd in git python3 node hyprctl omarchy-shell; do
  command -v "$cmd" >/dev/null || { echo "pub-am01s: missing $cmd (needs Omarchy with git, python3, node)" >&2; exit 1; }
done

if [ -d "$DIR/.git" ]; then
  git -C "$DIR" fetch --quiet --tags --force origin
else
  git clone --quiet "$REPO" "$DIR"
fi
tag="${PUB_AM01S_REF:-$(git -C "$DIR" tag --list 'v*' --sort=-v:refname | head -n1)}"
[ -n "$tag" ] || { echo "pub-am01s: no release tag found" >&2; exit 1; }
git -C "$DIR" -c advice.detachedHead=false checkout --quiet "$tag"
echo "pub-am01s: installing $tag into $DIR"

python3 "$DIR/scripts/install.py" "$@"
hyprctl reload >/dev/null
omarchy-restart-shell >/dev/null 2>&1 || true
echo "pub-am01s: done. Settings: Omarchy menu → PUB 设置"
