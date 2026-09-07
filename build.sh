#!/bin/bash
# SAS OS build entry point.
#
#   ./build.sh                 build in a Debian container (default, recommended)
#   ./build.sh --native        build directly on this machine (needs Debian + root)
#   ./build.sh --clean         discard any previous work tree first
#   ./build.sh --keep-work     keep the chroot after building (for debugging)
#
# The container path needs Docker and does not need sudo if your user is in
# the `docker` group. The build itself runs privileged because live-build
# needs mount, chroot and loop devices.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$REPO_ROOT/scripts/lib/common.sh"
# shellcheck source=sas.conf
. "$REPO_ROOT/sas.conf"

IMAGE_TAG="sas-build:bookworm"
MODE="docker"
PASSTHRU=()

for arg in "$@"; do
    case "$arg" in
        --native)      MODE="native" ;;
        --docker)      MODE="docker" ;;
        --clean)       PASSTHRU+=("--clean") ;;
        --keep-work)   PASSTHRU+=("--keep-work") ;;
        # Print the header comment block, stopping at the first line of code,
        # so the help text cannot drift out of sync with the block's length.
        -h|--help)     awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
        *)             die "unknown argument: $arg (try --help)" ;;
    esac
done

if [ "$MODE" = "native" ]; then
    log "building natively"
    exec "$REPO_ROOT/scripts/build-native.sh" "${PASSTHRU[@]}"
fi

require_cmds docker
docker info >/dev/null 2>&1 || \
    die "cannot talk to the Docker daemon (add yourself to the 'docker' group, or use sudo)"

step "Building the builder image"
docker build -t "$IMAGE_TAG" "$REPO_ROOT/docker"
ok "image $IMAGE_TAG ready"

# live-build needs a real filesystem for the chroot: not tmpfs (too small)
# and not the container's overlayfs (whiteouts confuse debootstrap). Bind a
# host directory in instead.
mkdir -p "$WORK_DIR" "$REPO_ROOT/dist"

step "Running live-build in a container"
exec docker run --rm --privileged \
    -v "$REPO_ROOT":/sas \
    -v "$WORK_DIR":"$WORK_DIR" \
    -e WORK_DIR="$WORK_DIR" \
    -e ISO_NAME="$ISO_NAME" \
    -e ISO_VOLUME="$ISO_VOLUME" \
    -e ISO_APPLICATION="$ISO_APPLICATION" \
    -e ISO_PUBLISHER="$ISO_PUBLISHER" \
    -e DISTRIBUTION="$DISTRIBUTION" \
    -e ARCHITECTURE="$ARCHITECTURE" \
    -e ARCHIVE_AREAS="$ARCHIVE_AREAS" \
    -e MIRROR_HOST="$MIRROR_HOST" \
    -e MIRROR_PATH="$MIRROR_PATH" \
    -e LOCALE="$LOCALE" \
    -e KEYMAP="$KEYMAP" \
    -e TIMEZONE="$TIMEZONE" \
    -e TARGET_HOSTNAME="$TARGET_HOSTNAME" \
    "$IMAGE_TAG" "${PASSTHRU[@]}"
