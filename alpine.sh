#!/bin/bash
# Distribution plug-in for Alpine Linux
# Auto-generated on 2026-09-01T21:58:00Z

DISTRO_NAME="Alpine Linux 3.20.10"
DISTRO_COMMENT="Alpine Linux official minirootfs from dl-cdn.alpinelinux.org"
DISTRO_ICON="🏔️"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/aarch64/alpine-minirootfs-3.20.10-aarch64.tar.gz"
TARBALL_SHA256['aarch64']="61ac877fdbcee6914731bc22a4ed5668ea3470f201f97a7078931c48b71bbeec"

TARBALL_URL['arm']="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/armv7/alpine-minirootfs-3.20.10-armv7.tar.gz"
TARBALL_SHA256['arm']="bb903f7e47b4991c91ebf5677bc8f66df5d8e8c24a9c093ba072222243c83b75"

TARBALL_URL['x86_64']="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-minirootfs-3.20.10-x86_64.tar.gz"
TARBALL_SHA256['x86_64']="0d44a414245f043ae56872a23762e6c9bee585da2cbe4aa81cbd0331eaf53223"

TARBALL_URL['x86']="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86/alpine-minirootfs-3.20.10-x86.tar.gz"
TARBALL_SHA256['x86']="7a80c1cfc1a8ca542c0b553fc3d42b962ad72531ba28850aecc8473f3472dd7a"

TARBALL_URL['riscv64']="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/riscv64/alpine-minirootfs-3.20.10-riscv64.tar.gz"
TARBALL_SHA256['riscv64']="972e8257ffded92877ff9a09a8418c3eb7c6f0e49c9413461777d7279fdc4b2f"

# Detect best URL for current arch
TARBALL_URL="${TARBALL_URL[$DISTRO_ARCH]:-${TARBALL_URL['aarch64']}}"
TARBALL_SHA256="${TARBALL_SHA256[$DISTRO_ARCH]:-}"

if [ -z "$TARBALL_URL" ]; then
    echo "ERROR: No tarball URL for architecture $DISTRO_ARCH" >&2
    exit 1
fi

mkdir -p "$DISTRO_ROOTFS"
TMP_TARBALL="$DISTRO_ROOTFS/.tmp_rootfs.tar.gz"
echo "Downloading $DISTRO_NAME rootfs for $DISTRO_ARCH..."
curl -sSL --fail --show-error -o "$TMP_TARBALL" "$TARBALL_URL" || {
    echo "ERROR: Download failed from $TARBALL_URL" >&2
    exit 1
}

if [ -n "$TARBALL_SHA256" ]; then
    echo "$TARBALL_SHA256  $TMP_TARBALL" | sha256sum -c - || {
        echo "ERROR: SHA256 mismatch" >&2
        rm -f "$TMP_TARBALL"
        exit 1
    }
fi

echo "Extracting rootfs..."
case "$TMP_TARBALL" in
    *.tar.xz|*.txz)
        tar -xJf "$TMP_TARBALL" -C "$DISTRO_ROOTFS" --strip-components=1
        ;;
    *.tar.bz2|*.tbz2)
        tar -xjf "$TMP_TARBALL" -C "$DISTRO_ROOTFS" --strip-components=1
        ;;
    *.tar.gz|*.tgz)
        tar -xzf "$TMP_TARBALL" -C "$DISTRO_ROOTFS" --strip-components=1
        ;;
    *.tar)
        tar -xf "$TMP_TARBALL" -C "$DISTRO_ROOTFS" --strip-components=1
        ;;
    *)
        echo "ERROR: Unknown archive format: $TMP_TARBALL" >&2
        rm -f "$TMP_TARBALL"
        exit 1
        ;;
esac

rm -f "$TMP_TARBALL"

cat <<'BOOTSTRAP_EOF' > "$DISTRO_ROOTFS/bootstrap.sh"
#!/bin/sh
#  =============================================================================
# RUNTIME & BOOTSTRAP CONFIGURATION
# ==============================================================================
# ENTRYPOINT: /bin/sh
# ENVIRONMENT: PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# SPECIAL MOUNTS / FLAGS: --link2symlink, custom /proc, /dev, /sys bind mounts
# POST-INSTALL HOOKS / BOOTSTRAP COMMANDS:
#   1. apk update && apk upgrade
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot cannot mimic full Linux kernel syscalls
#   - BusyBox init or OpenRC services do not run as real PID 1 inside PRoot.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

apk update && apk upgrade
BOOTSTRAP_EOF

chmod +x "$DISTRO_ROOTFS/bootstrap.sh"

mkdir -p "$DISTRO_ROOTFS/root"
cat <<'ENTRYPOINT_EOF' > "$DISTRO_ROOTFS/root/entrypoint.sh"
#!/bin/sh
# Entrypoint for Alpine Linux in PRoot

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ -f /bootstrap.sh ] && [ ! -f /bootstrap.done ]; then
    echo "[*] Running first-boot bootstrap..."
    sh /bootstrap.sh
    touch /bootstrap.done
fi

exec /bin/sh --login
ENTRYPOINT_EOF

chmod +x "$DISTRO_ROOTFS/root/entrypoint.sh"

cat <<'MARKER_EOF' > "$DISTRO_ROOTFS/.docker_image"
image=local-script
pulled_at=$(date +%s)
source=local-script
script=$(basename "$0")
MARKER_EOF

echo "$DISTRO_NAME rootfs prepared at: $DISTRO_ROOTFS"
echo "To boot: nh boot docker $(basename "$DISTRO_ROOTFS")"
exit 0
