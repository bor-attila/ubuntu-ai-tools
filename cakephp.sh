#!/usr/bin/env bash
#
# ubuntu-ai-tools : cakephp.sh
# Installs the CakePHP 5.x instruction file (CAKEPHP.md) into ~/.claude and wires
# a CONDITIONAL reference into the user-level ~/.claude/CLAUDE.md — the AI reads it
# only when a project's composer.json requires cakephp/cakephp (not @imported, so
# it never loads for non-CakePHP projects).
#
# Re-runnable (idempotent). Manages its own marker block, independent of tools.sh.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
MARKER_BEGIN="# >>> ubuntu-ai-tools:cakephp >>>"
MARKER_END="# <<< ubuntu-ai-tools:cakephp <<<"

if [[ -t 1 ]]; then
  C_OK=$'\e[32m'; C_WARN=$'\e[33m'; C_DIM=$'\e[2m'; C_RST=$'\e[0m'
else
  C_OK=""; C_WARN=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s==>%s %s\n' "$C_OK"   "$C_RST" "$*"; }
warn() { printf '%s[!]%s %s\n'  "$C_WARN" "$C_RST" "$*" >&2; }
dim()  { printf '%s    %s%s\n'  "$C_DIM"  "$*" "$C_RST"; }

main() {
  local src="${SCRIPT_DIR}/CAKEPHP.md"
  local dst="${CLAUDE_DIR}/CAKEPHP.md"
  local md="${CLAUDE_DIR}/CLAUDE.md"

  [[ -f "$src" ]] || { warn "missing: $src"; exit 1; }
  mkdir -p "$CLAUDE_DIR"

  cp -f "$src" "$dst"
  log "installed CakePHP instructions"
  dim "copied -> $dst"

  touch "$md"
  # Remove any existing block (idempotent), then append a fresh one
  if grep -qF "$MARKER_BEGIN" "$md"; then
    sed -i "/${MARKER_BEGIN}/,/${MARKER_END}/d" "$md"
    dim "existing block refreshed"
  fi
  {
    printf '%s\n' "$MARKER_BEGIN"
    printf 'If composer.json requires cakephp/cakephp, read ~/.claude/CAKEPHP.md before doing any work.\n'
    printf '%s\n' "$MARKER_END"
  } >> "$md"
  log "wired: $md"
}

main "$@"
