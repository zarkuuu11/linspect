#!/usr/bin/env bash
# Installs linspect to /usr/local/bin (or ~/.local/bin if not writable).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SRC="$SCRIPT_DIR/linspect.sh"

if [[ ! -f "$SRC" ]]; then
  echo "linspect.sh not found next to install.sh" >&2
  exit 1
fi

if [[ -w /usr/local/bin ]]; then
  DEST="/usr/local/bin/linspect"
else
  mkdir -p "$HOME/.local/bin"
  DEST="$HOME/.local/bin/linspect"
  echo "Note: installing to $DEST — make sure ~/.local/bin is on your PATH."
fi

cp "$SRC" "$DEST"
chmod +x "$DEST"
echo "Installed: $DEST"
echo "Run it with: linspect --help"
