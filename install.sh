#!/bin/sh
# laser-cli-claude installer
# Copies every skill in skills/ into ~/.claude/skills/.
# Usage:
#   curl -fsSL https://cli.laserdata.cloud/claude.sh | sh

set -eu

REPO="${LASER_CLAUDE_REPO:-laserdata/laser-cli-claude}"
REF="${LASER_CLAUDE_REF:-main}"
DEST="${LASER_CLAUDE_DEST:-${HOME}/.claude/skills}"

# ---- log helpers ----------------------------------------------------

if [ -t 1 ] && [ -z "${NO_COLOR-}" ]; then
    BOLD="$(printf '\033[1m')"
    DIM="$(printf '\033[2m')"
    RED="$(printf '\033[31m')"
    GREEN="$(printf '\033[32m')"
    RESET="$(printf '\033[0m')"
else
    BOLD=""; DIM=""; RED=""; GREEN=""; RESET=""
fi

info()  { printf '%s>%s %s\n' "$GREEN" "$RESET" "$*"; }
note()  { printf '%s%s%s\n' "$DIM" "$*" "$RESET"; }
err()   { printf '%serror:%s %s\n' "$RED$BOLD" "$RESET" "$*" >&2; exit 1; }

# ---- prereqs --------------------------------------------------------

command -v curl  >/dev/null 2>&1 || err "curl is required"
command -v tar   >/dev/null 2>&1 || err "tar is required"
command -v mkdir >/dev/null 2>&1 || err "mkdir is required"

# ---- fetch + extract -----------------------------------------------

work="$(mktemp -d 2>/dev/null || mktemp -d -t 'laser-claude')"
trap 'rm -rf "$work"' EXIT

archive="${work}/skills.tar.gz"
url="https://codeload.github.com/${REPO}/tar.gz/${REF}"

info "downloading skill pack"
note "  ${url}"
curl -fsSL "$url" -o "$archive" || err "download failed: $url"

info "extracting"
tar -xzf "$archive" -C "$work"
src_root="$(find "$work" -maxdepth 1 -mindepth 1 -type d -name 'laser-cli-claude-*' | head -n 1)"
[ -d "${src_root}/skills" ] || err "no skills/ directory in archive"

# ---- copy -----------------------------------------------------------

mkdir -p "$DEST"
copied=0
for skill in "${src_root}/skills"/*.md; do
    [ -f "$skill" ] || continue
    cp -f "$skill" "$DEST/"
    copied=$((copied + 1))
done
[ "$copied" -gt 0 ] || err "no skills found in archive"

info "installed ${copied} skill(s) -> ${DEST}"
note "  reload Claude Code (or run /reload-skills) to pick them up"
