#!/usr/bin/env bash
#
# ubuntu-ai-tools : tools.sh
# Installs the token-efficient CLI tool set and wires the AI instruction file
# (ubuntu-ai-tools.md) into the user-level ~/.claude/CLAUDE.md.
#
# CakePHP-specific instructions are handled separately by ./cakephp.sh.
#
# Re-runnable (idempotent). Strategy: apt -> snap -> GitHub release.
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN="${HOME}/.local/bin"
CLAUDE_DIR="${HOME}/.claude"
ARCH="$(dpkg --print-architecture)"   # amd64 / arm64
case "$ARCH" in
  amd64) ARCH_RE="amd64|x86_64" ;;
  arm64) ARCH_RE="arm64|aarch64" ;;
  *)     ARCH_RE="$ARCH" ;;
esac
MARKER_BEGIN="# >>> ubuntu-ai-tools >>>"
MARKER_END="# <<< ubuntu-ai-tools <<<"

INSTALLED=(); SKIPPED=(); FAILED=()

# colors
if [[ -t 1 ]]; then
  C_OK=$'\e[32m'; C_WARN=$'\e[33m'; C_ERR=$'\e[31m'; C_DIM=$'\e[2m'; C_RST=$'\e[0m'
else
  C_OK=""; C_WARN=""; C_ERR=""; C_DIM=""; C_RST=""
fi

log()  { printf '%s==>%s %s\n' "$C_OK"   "$C_RST" "$*"; }
warn() { printf '%s[!]%s %s\n'  "$C_WARN" "$C_RST" "$*" >&2; }
err()  { printf '%s[x]%s %s\n'  "$C_ERR"  "$C_RST" "$*" >&2; }
dim()  { printf '%s    %s%s\n'  "$C_DIM"  "$*" "$C_RST"; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
preflight() {
  [[ "$(uname -s)" == "Linux" ]] || { err "Linux only."; exit 1; }
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    err "Run as a normal user (this script calls sudo itself) — not via 'sudo ./tools.sh'."
    err "Otherwise files land in /root instead of your home."
    exit 1
  fi
  have apt-get || { err "Not an apt-based system."; exit 1; }
  have curl    || sudo apt-get install -y curl
  have unzip   || sudo apt-get install -y unzip
  [[ "$ARCH" == "amd64" || "$ARCH" == "arm64" ]] || warn "Unknown arch ($ARCH); GitHub binaries may be skipped."

  mkdir -p "$LOCAL_BIN" "$CLAUDE_DIR"

  log "Checking sudo privileges (apt/snap)…"
  sudo -v

  # Is ~/.local/bin on PATH?
  case ":${PATH}:" in
    *":${LOCAL_BIN}:"*) : ;;
    *)
      warn "${LOCAL_BIN} is not on PATH — adding it to the shell rc."
      local rc="${HOME}/.bashrc"
      [[ "${SHELL:-}" == *zsh ]] && rc="${HOME}/.zshrc"
      printf '\n# ubuntu-ai-tools\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
      export PATH="${LOCAL_BIN}:${PATH}"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Installer helpers
# ---------------------------------------------------------------------------
APT_UPDATED=0
apt_update_once() {
  [[ "$APT_UPDATED" == 1 ]] && return 0
  log "apt-get update…"
  sudo apt-get update -qq
  APT_UPDATED=1
}

# apt_pkg <command-to-check> <apt-package>
apt_pkg() {
  local cmd="$1" pkg="$2"
  if have "$cmd"; then SKIPPED+=("$cmd"); return 0; fi
  apt_update_once
  if sudo apt-get install -y -qq "$pkg" >/dev/null 2>&1; then
    INSTALLED+=("$cmd"); log "installed: $pkg"
  else
    FAILED+=("$cmd"); warn "apt failed: $pkg"
    return 1
  fi
}

# snap_pkg <command-to-check> <snap-name> [--classic]
snap_pkg() {
  local cmd="$1" name="$2"; shift 2 || true
  if have "$cmd"; then SKIPPED+=("$cmd"); return 0; fi
  have snap || { warn "snap missing; skipping $name"; FAILED+=("$cmd"); return 1; }
  if sudo snap install "$name" "$@" >/dev/null 2>&1; then
    INSTALLED+=("$cmd"); log "installed (snap): $name"
  else
    FAILED+=("$cmd"); warn "snap failed: $name"
    return 1
  fi
}

# Fetch the latest release tag from the GitHub API (works without jq)
gh_latest_tag() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | grep -m1 '"tag_name"' | cut -d'"' -f4
}

# gh_binary <cmd> <repo> <asset-name-token> [tarball-inner-binname]
# Downloads the latest linux release asset for this arch into ~/.local/bin.
# Handles arch matching (amd64<->x86_64) and prefers the musl/gnu build.
# If the asset is a .tar.gz/.tar.xz/.zip, extracts it and copies out <inner>.
gh_binary() {
  local cmd="$1" repo="$2" pat="$3" inner="${4:-$1}"
  if have "$cmd"; then SKIPPED+=("$cmd"); return 0; fi
  log "GitHub: $repo ($cmd)…"
  local all cand url
  all="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
        | grep '"browser_download_url"' | cut -d'"' -f4)" || true
  cand="$(printf '%s\n' "$all" \
        | grep -Ei "$pat" \
        | grep -Ei 'linux' \
        | grep -Eiv 'darwin|windows|\.sha|\.asc|\.sig' \
        | grep -Ei "$ARCH_RE")" || true
  url="$(printf '%s\n' "$cand" | grep -i musl | head -n1)"
  [[ -z "$url" ]] && url="$(printf '%s\n' "$cand" | grep -i gnu | head -n1)"
  [[ -z "$url" ]] && url="$(printf '%s\n' "$cand" | grep -v '^$' | head -n1)"
  if [[ -z "$url" ]]; then FAILED+=("$cmd"); warn "no asset: $repo"; return 1; fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp:-}" 2>/dev/null || true; trap - RETURN' RETURN
  local file="${tmp}/${url##*/}"
  if ! curl -fsSL "$url" -o "$file"; then FAILED+=("$cmd"); warn "download failed: $url"; return 1; fi

  case "$file" in
    *.tar.gz|*.tgz)  tar -xzf "$file" -C "$tmp" ;;
    *.tar.xz)        tar -xJf "$file" -C "$tmp" ;;
    *.tar.bz2|*.tbz) tar -xjf "$file" -C "$tmp" ;;
    *.zip)           ( cd "$tmp" && unzip -qq "$file" ) ;;
  esac

  local src
  if [[ "$file" == *.tar.* || "$file" == *.tgz || "$file" == *.zip ]]; then
    src="$(find "$tmp" -type f -name "$inner" | head -n1)"
  else
    src="$file"
  fi
  if [[ -z "${src:-}" || ! -f "$src" ]]; then FAILED+=("$cmd"); warn "binary not found: $cmd"; return 1; fi

  install -m 0755 "$src" "${LOCAL_BIN}/${cmd}"
  INSTALLED+=("$cmd"); log "installed (gh): $cmd"
}

# gh_deb <cmd> <repo> <asset-name-token>
gh_deb() {
  local cmd="$1" repo="$2" pat="$3"
  if have "$cmd"; then SKIPPED+=("$cmd"); return 0; fi
  log "GitHub .deb: $repo ($cmd)…"
  local url
  url="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
        | grep '"browser_download_url"' | cut -d'"' -f4 \
        | grep -Ei "$pat" | grep -Ei "$ARCH_RE" | grep -i '\.deb$' | head -n1)" || true
  if [[ -z "$url" ]]; then FAILED+=("$cmd"); warn "no .deb: $repo"; return 1; fi
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:-}" 2>/dev/null || true; trap - RETURN' RETURN
  local file="${tmp}/${url##*/}"
  curl -fsSL "$url" -o "$file" || { FAILED+=("$cmd"); warn "download failed"; return 1; }
  if sudo apt-get install -y -qq "$file" >/dev/null 2>&1; then
    INSTALLED+=("$cmd"); log "installed (deb): $cmd"
  else
    FAILED+=("$cmd"); warn ".deb install failed: $cmd"
  fi
}

# ---------------------------------------------------------------------------
# Tool groups
# ---------------------------------------------------------------------------
install_core() {
  log "== Required tools =="
  apt_pkg jq        jq            || true
  apt_pkg rg        ripgrep       || true
  apt_pkg fdfind    fd-find       || true
  apt_pkg batcat    bat           || true
  apt_pkg xclip     xclip         || true
  apt_pkg ccache    ccache        || true
  apt_pkg curl      curl          || true
  apt_pkg tldr      tldr          || true

  # yq: mikefarah (Go) — apt ships the python yq, so use a direct GitHub binary
  install_yq || snap_pkg yq yq || true
  # websocat: GitHub binary (standalone, not an archive)
  gh_binary websocat vi/websocat "websocat" || true
}

# yq direct download (stable asset name: yq_linux_<arch>)
install_yq() {
  if have yq; then SKIPPED+=("yq"); return 0; fi
  local tag; tag="$(gh_latest_tag mikefarah/yq)"
  [[ -z "$tag" ]] && { warn "could not resolve yq tag"; return 1; }
  if curl -fsSL "https://github.com/mikefarah/yq/releases/download/${tag}/yq_linux_${ARCH}" \
       -o "${LOCAL_BIN}/yq"; then
    chmod +x "${LOCAL_BIN}/yq"; INSTALLED+=("yq"); log "installed (gh): yq ${tag}"
  else
    rm -f "${LOCAL_BIN}/yq"; FAILED+=("yq"); return 1
  fi
}

install_media() {
  log "== Media / image / video =="
  apt_pkg ffmpeg   ffmpeg                  || true
  apt_pkg convert  imagemagick             || true   # ImageMagick -> convert/magick
  apt_pkg exiftool libimage-exiftool-perl  || true
  apt_pkg gifsicle gifsicle                || true
  apt_pkg optipng  optipng                 || true
  apt_pkg jpegoptim jpegoptim              || true
  apt_pkg pngquant pngquant                || true
  apt_pkg cwebp    webp                    || true   # webp encode/decode
  apt_pkg gs       ghostscript             || true
  apt_pkg pdftotext poppler-utils          || true   # PDF -> text/img
  apt_pkg tesseract tesseract-ocr          || true   # OCR
  install_ytdlp || apt_pkg yt-dlp yt-dlp   || true
}

# yt-dlp: the apt build lags badly and breaks against sites quickly, so prefer
# the official standalone binary. Self-updates later with `yt-dlp -U`.
install_ytdlp() {
  local self="${LOCAL_BIN}/yt-dlp"
  [[ -x "$self" ]] && { SKIPPED+=("yt-dlp"); return 0; }
  local asset="yt-dlp_linux"
  [[ "$ARCH" == "arm64" ]] && asset="yt-dlp_linux_aarch64"
  log "GitHub: yt-dlp/yt-dlp ($asset)…"
  if curl -fsSL "https://github.com/yt-dlp/yt-dlp/releases/latest/download/${asset}" -o "$self"; then
    chmod +x "$self"; INSTALLED+=("yt-dlp"); log "installed (gh): yt-dlp"
  else
    rm -f "$self"; warn "yt-dlp binary download failed; falling back to apt"; return 1
  fi
}

install_modern() {
  log "== Modern CLI (maximal) =="
  apt_pkg fzf       fzf        || true
  apt_pkg eza       eza        || true
  apt_pkg zoxide    zoxide     || true
  apt_pkg duf       duf        || true
  apt_pkg hyperfine hyperfine  || true
  apt_pkg aria2c    aria2      || true
  apt_pkg parallel  parallel   || true
  apt_pkg sqlite3   sqlite3    || true
  apt_pkg pandoc    pandoc     || true
  apt_pkg tree      tree       || true
  apt_pkg ncdu      ncdu       || true
  apt_pkg btop      btop       || true
  apt_pkg entr      entr       || true
  apt_pkg tig       tig        || true
  apt_pkg http      httpie     || true
  apt_pkg gron      gron       || true
  apt_pkg sponge    moreutils  || true   # sponge, ts, vipe…

  # May be missing from apt -> GitHub fallback (helpers handle arch matching)
  gh_deb    delta dandavison/delta "git-delta" \
    || gh_binary delta dandavison/delta "delta" delta || true
  gh_binary sd    chmln/sd            "sd-v"     sd    || true
  gh_deb    dust  bootandy/dust       "du-dust"        \
    || gh_binary dust bootandy/dust   "dust-v"   dust  || true
  gh_binary jless PaulJuliusMartinez/jless "jless" jless || true
  gh_deb    glow  charmbracelet/glow  "glow"           \
    || gh_binary glow charmbracelet/glow "glow"  glow  || true
}

install_db() {
  log "== Database clients =="
  apt_pkg psql    postgresql-client      || true   # PostgreSQL
  apt_pkg mysql   default-mysql-client   || true   # MySQL / MariaDB
  apt_pkg sqlite3 sqlite3                || true   # SQLite (also in modern set)

  # MongoDB shell — .deb (plain build bundles openssl; avoid the shared-* variants)
  gh_deb mongosh mongodb-js/mongosh "mongodb-mongosh_" || true
  # MS SQL Server — Microsoft go-sqlcmd (tar.bz2)
  gh_binary sqlcmd microsoft/go-sqlcmd "sqlcmd-linux" sqlcmd || true
  # Universal client (pg/mysql/mssql/sqlite/mongo/…) — xo/usql, static build
  # (the archived binary is named usql_static; installed as 'usql')
  gh_binary usql xo/usql "usql_static" usql_static || true
}

# ---------------------------------------------------------------------------
# Ubuntu binary-name fixes
# ---------------------------------------------------------------------------
fix_symlinks() {
  log "== Symlink fix (Ubuntu) =="
  if have fdfind && ! have fd; then ln -sf "$(command -v fdfind)" "${LOCAL_BIN}/fd"; dim "fd -> fdfind"; fi
  if have batcat && ! have bat; then ln -sf "$(command -v batcat)" "${LOCAL_BIN}/bat"; dim "bat -> batcat"; fi
}

update_caches() {
  if have tldr; then
    log "Updating tldr cache…"
    tldr --update >/dev/null 2>&1 || tldr -u >/dev/null 2>&1 || true
  fi
}

# ---------------------------------------------------------------------------
# Wire the AI instruction into the user CLAUDE.md
# ---------------------------------------------------------------------------
wire_claude_md() {
  log "== Wiring AI instruction =="
  local src="${SCRIPT_DIR}/ubuntu-ai-tools.md"
  local dst="${CLAUDE_DIR}/ubuntu-ai-tools.md"
  local md="${CLAUDE_DIR}/CLAUDE.md"

  [[ -f "$src" ]] || { warn "missing: $src"; return 1; }
  cp -f "$src" "$dst"
  dim "copied -> $dst"

  touch "$md"
  # Remove any existing block (idempotent), then append a fresh one
  if grep -qF "$MARKER_BEGIN" "$md"; then
    sed -i "/${MARKER_BEGIN}/,/${MARKER_END}/d" "$md"
    dim "existing block refreshed"
  fi
  {
    printf '%s\n' "$MARKER_BEGIN"
    printf '@ubuntu-ai-tools.md\n'
    printf '%s\n' "$MARKER_END"
  } >> "$md"
  log "wired: $md"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
summary() {
  echo
  log "Summary"
  printf '  %sInstalled:%s %s\n' "$C_OK"   "$C_RST" "${INSTALLED[*]:-(nothing new)}"
  printf '  %sPresent:%s   %s\n' "$C_DIM"  "$C_RST" "${SKIPPED[*]:-—}"
  [[ ${#FAILED[@]} -gt 0 ]] && printf '  %sFailed:%s    %s\n' "$C_ERR" "$C_RST" "${FAILED[*]}"
  echo
  warn "Open a new terminal or run 'exec \$SHELL' to refresh PATH."
}

main() {
  preflight
  install_core
  install_media
  install_modern
  install_db
  fix_symlinks
  update_caches
  wire_claude_md
  summary
}

main "$@"
