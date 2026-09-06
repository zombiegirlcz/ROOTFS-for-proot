#!/bin/bash
# Distribution plug-in for Devuan Daedalus
# Auto-generated on 2026-09-01T22:15:00Z

DISTRO_NAME="Devuan Daedalus"
DISTRO_COMMENT="Devuan official LXC rootfs"
DISTRO_ICON="🐱"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/devuan/daedalus/amd64/default/20260901_11%3A50/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="ec5e6af294dd5676636b466b56a588bf971c4834ba6bba0f42c76ae7fa2df384"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/devuan/daedalus/arm64/default/20260901_11%3A50/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="9be31cec2b5c2f10fd77ed5169ccb79952f11136f85c292313360bf154180d7a"

TARBALL_URL="${TARBALL_URL[$DISTRO_ARCH]:-${TARBALL_URL['aarch64']}}"
TARBALL_SHA256="${TARBALL_SHA256[$DISTRO_ARCH]:-}"

if [ -z "$TARBALL_URL" ]; then
    echo "ERROR: No tarball URL for architecture $DISTRO_ARCH" >&2
    exit 1
fi

mkdir -p "$DISTRO_ROOTFS"
TMP_TARBALL="$DISTRO_ROOTFS/.tmp_rootfs.tar.xz"
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
        tar -xJf "$TMP_TARBALL" -C "$DISTRO_ROOTFS"
        ;;
    *.tar.bz2|*.tbz2)
        tar -xjf "$TMP_TARBALL" -C "$DISTRO_ROOTFS"
        ;;
    *.tar.gz|*.tgz)
        tar -xzf "$TMP_TARBALL" -C "$DISTRO_ROOTFS"
        ;;
    *.tar)
        tar -xf "$TMP_TARBALL" -C "$DISTRO_ROOTFS"
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
#   1. apt-get update
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

apt-get update
BOOTSTRAP_EOF

chmod +x "$DISTRO_ROOTFS/bootstrap.sh"

mkdir -p "$DISTRO_ROOTFS/root"
cat <<'ENTRYPOINT_EOF' > "$DISTRO_ROOTFS/root/entrypoint.sh"
#!/bin/sh
# Entrypoint for Devuan in PRoot

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ -f /bootstrap.sh ] && [ ! -f /bootstrap.done ]; then
    echo "[*] Running first-boot bootstrap..."
    sh /bootstrap.sh
    touch /bootstrap.done
fi

exec /bin/bash --login
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
