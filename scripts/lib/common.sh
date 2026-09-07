# Shared helpers. Sourced, never executed.
# shellcheck shell=bash

_c_reset=$'\033[0m'; _c_blue=$'\033[1;34m'; _c_green=$'\033[1;32m'
_c_yellow=$'\033[1;33m'; _c_red=$'\033[1;31m'; _c_dim=$'\033[2m'

# Drop colour when not writing to a terminal (log files, CI).
if [ ! -t 1 ]; then
    _c_reset=""; _c_blue=""; _c_green=""; _c_yellow=""; _c_red=""; _c_dim=""
fi

log()  { printf '%s==>%s %s\n'  "$_c_blue"   "$_c_reset" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$_c_green"  "$_c_reset" "$*"; }
warn() { printf '%swarn%s %s\n' "$_c_yellow" "$_c_reset" "$*" >&2; }
die()  { printf '%serr %s %s\n' "$_c_red"    "$_c_reset" "$*" >&2; exit 1; }
step() { printf '\n%s%s%s\n' "$_c_dim" "-- $* " "$_c_reset"; }

require_root() {
    [ "$(id -u)" -eq 0 ] || die "must run as root (try: sudo $0)"
}

require_cmds() {
    local missing=()
    for c in "$@"; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
    [ ${#missing[@]} -eq 0 ] || die "missing commands: ${missing[*]}"
}

# Human-readable elapsed time from a SECONDS snapshot.
fmt_elapsed() {
    local s=$1
    printf '%dm %02ds' $(( s / 60 )) $(( s % 60 ))
}
