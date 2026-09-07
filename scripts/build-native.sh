#!/bin/bash
# Drive live-build to produce SAS.iso.
#
# Runs as root on a Debian host, or (recommended) inside the container that
# docker/Dockerfile defines. Invoke it through ../build.sh rather than
# directly unless you know the host already has the toolchain.
#
#   build-native.sh [--clean] [--keep-work]
#
set -euo pipefail
# Without this, `lb build | tee` reports tee's exit status and a failed build
# looks like a success. This was a real bug in the original script.
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
. "$REPO_ROOT/scripts/lib/common.sh"
# shellcheck source=../sas.conf
. "$REPO_ROOT/sas.conf"

CLEAN=0
KEEP_WORK=0
for arg in "$@"; do
    case "$arg" in
        --clean)     CLEAN=1 ;;
        --keep-work) KEEP_WORK=1 ;;
        *) die "unknown argument: $arg" ;;
    esac
done

DIST_DIR="$REPO_ROOT/dist"
START=$SECONDS

require_root
require_cmds lb debootstrap mksquashfs xorriso

step "Preparing work directory"
# The original script deleted the work tree unconditionally on every run.
# Now it is opt-in, so an interrupted 40-minute build can be resumed.
if [ -d "$WORK_DIR" ]; then
    if [ "$CLEAN" -eq 1 ]; then
        log "cleaning $WORK_DIR"
        ( cd "$WORK_DIR" && lb clean --purge >/dev/null 2>&1 ) || true
        # Empty the directory rather than removing it: under a container
        # build it *is* the bind-mount point and cannot be unlinked.
        find "$WORK_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
    else
        log "reusing $WORK_DIR (pass --clean to start fresh)"
        ( cd "$WORK_DIR" && lb clean --binary >/dev/null 2>&1 ) || true
    fi
fi
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

step "Configuring live-build"
# `noauto` keeps lb from re-running config from its own auto/ scripts.
lb config noauto \
    --distribution "$DISTRIBUTION" \
    --architectures "$ARCHITECTURE" \
    --archive-areas "$ARCHIVE_AREAS" \
    --mode debian \
    --debian-installer live \
    --debian-installer-gui true \
    --debian-installer-distribution "$DISTRIBUTION" \
    --mirror-bootstrap "http://${MIRROR_HOST}${MIRROR_PATH}/" \
    --mirror-chroot "http://${MIRROR_HOST}${MIRROR_PATH}/" \
    --mirror-binary "http://${MIRROR_HOST}${MIRROR_PATH}/" \
    --mirror-debian-installer "http://${MIRROR_HOST}${MIRROR_PATH}/" \
    --apt-indices false \
    --apt-recommends true \
    --binary-images iso-hybrid \
    --bootloaders "syslinux,grub-efi" \
    --bootappend-live "boot=live components quiet splash" \
    --iso-application "$ISO_APPLICATION" \
    --iso-publisher "$ISO_PUBLISHER" \
    --iso-volume "$ISO_VOLUME" \
    --iso-preparer "SAS build system; https://github.com/modShik/SAS" \
    --memtest none \
    --zsync false \
    --win32-loader false
ok "live-build configured for $DISTRIBUTION/$ARCHITECTURE"

step "Seeding bootloader templates"
# Providing config/bootloaders/<name>/ makes live-build use that directory
# *instead of* its stock template, so the .c32 modules and helper configs
# must be present first. Seed them, then overlay only our own files.
# syslinux_common holds the shared .c32 modules that isolinux pulls in.
for bl in syslinux_common isolinux grub-pc; do
    if [ ! -d "$WORK_DIR/config/bootloaders/$bl" ]; then
        for src in /usr/share/live/build/bootloaders /usr/share/live-build/bootloaders; do
            if [ -d "$src/$bl" ]; then
                mkdir -p "$WORK_DIR/config/bootloaders"
                cp -a "$src/$bl" "$WORK_DIR/config/bootloaders/"
                ok "seeded $bl from $src"
                break
            fi
        done
    fi
done

step "Applying SAS configuration overlay"
# cp -a src/. dst/ merges into the tree live-build just generated rather
# than replacing it.
cp -a "$REPO_ROOT/config/." "$WORK_DIR/config/"
chmod +x "$WORK_DIR"/config/hooks/normal/*.hook.chroot 2>/dev/null || true
ok "overlay applied"

step "Substituting installer settings"
PRESEED="$WORK_DIR/config/includes.installer/preseed.cfg"
[ -f "$PRESEED" ] || die "preseed.cfg missing from overlay"
sed -i \
    -e "s|@LOCALE@|$LOCALE|g" \
    -e "s|@KEYMAP@|$KEYMAP|g" \
    -e "s|@TIMEZONE@|$TIMEZONE|g" \
    -e "s|@HOSTNAME@|$TARGET_HOSTNAME|g" \
    -e "s|@MIRROR_HOST@|$MIRROR_HOST|g" \
    -e "s|@MIRROR_PATH@|$MIRROR_PATH|g" \
    "$PRESEED"
# Comments are exempt: the file documents its own placeholder syntax.
# The trailing `|| true` matters -- with `set -e -o pipefail` an empty grep
# result (the success case here) would otherwise abort the whole build.
LEFTOVER="$(grep -v '^[[:space:]]*#' "$PRESEED" | grep -o '@[A-Z_]\+@' | sort -u | tr '\n' ' ' || true)"
[ -z "$LEFTOVER" ] || die "unsubstituted tokens left in preseed.cfg: $LEFTOVER"
ok "locale=$LOCALE keymap=$KEYMAP tz=$TIMEZONE hostname=$TARGET_HOSTNAME"

step "Rendering wallpaper"
"$REPO_ROOT/scripts/gen-wallpaper.sh" \
    "$WORK_DIR/config/includes.chroot/usr/share/backgrounds/sasos"

step "Building the image (this takes a while)"
log "log file: $WORK_DIR/build.log"
if ! lb build 2>&1 | tee "$WORK_DIR/build.log"; then
    warn "build failed; last 40 lines of $WORK_DIR/build.log:"
    tail -n 40 "$WORK_DIR/build.log" >&2 || true
    die "lb build failed"
fi

step "Collecting artefacts"
ISO_SRC="$(find "$WORK_DIR" -maxdepth 1 -name '*.iso' -print -quit)"
[ -n "$ISO_SRC" ] || die "lb build reported success but produced no .iso"

mkdir -p "$DIST_DIR"
mv -f "$ISO_SRC" "$DIST_DIR/$ISO_NAME"
( cd "$DIST_DIR" && sha256sum "$ISO_NAME" > "$ISO_NAME.sha256" )

if [ "$KEEP_WORK" -eq 0 ]; then
    log "removing intermediate chroot to reclaim disk (keeping config + log)"
    rm -rf "$WORK_DIR/chroot" "$WORK_DIR/binary" || true
fi

printf '\n'
ok "$DIST_DIR/$ISO_NAME  ($(du -h "$DIST_DIR/$ISO_NAME" | cut -f1))"
ok "sha256: $(cut -d' ' -f1 < "$DIST_DIR/$ISO_NAME.sha256")"
ok "built in $(fmt_elapsed $(( SECONDS - START )))"
