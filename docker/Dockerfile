# Reproducible build environment for SAS OS.
#
# The build must happen on Debian: Ubuntu ships live-build 3.0~a57, an old
# fork whose `lb config` does not understand the options this project uses.
# Pinning to bookworm also keeps the host distro out of the equation.
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        live-build \
        debootstrap \
        squashfs-tools \
        xorriso \
        isolinux \
        syslinux \
        syslinux-common \
        syslinux-efi \
        grub-pc-bin \
        grub-efi-amd64-bin \
        mtools \
        dosfstools \
        librsvg2-bin \
        fonts-dejavu-core \
        ca-certificates \
        wget \
        curl \
        file \
        procps \
        rsync \
        cpio \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /sas
ENTRYPOINT ["/sas/scripts/build-native.sh"]
