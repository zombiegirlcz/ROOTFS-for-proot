#!/bin/bash
# Distribution plug-in for Arch Linux
# Auto-generated on 2026-09-01T22:15:00Z

DISTRO_NAME="Arch Linux"
DISTRO_COMMENT="Arch Linux official LXC rootfs"
DISTRO_ICON="🏹"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/archlinux/current/amd64/default/20260917_04%3A18/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="2c43bb6900bd035928547bb6169c89c079f9414d6d61e6a448d5013be336c0a0"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/archlinux/current/arm64/default/20260917_04%3A18/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="082fbd22567aa887fc902f0900964e8c68b7222cf49ac9e7c9552a87e90f6de1"

TARBALL_URL['loong64']="https://images.linuxcontainers.org/images/archlinux/current/loong64/default/20260917_04%3A18/rootfs.tar.xz"
TARBALL_SHA256['loong64']="a6c9f2cc04445273eb13a1ee4d7243fa43045b5e114d9dc8f5ecd716959c4230"

TARBALL_URL['riscv64']="https://images.linuxcontainers.org/images/archlinux/current/riscv64/default/20260917_04%3A18/rootfs.tar.xz"
TARBALL_SHA256['riscv64']="1d248b62bc21041f8a34430c5049b70226db2e413963ee94a0a5463ea76b95b0"

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
#   1. pacman -Syu --noconfirm
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

pacman -Syu --noconfirm
BOOTSTRAP_EOF

chmod +x "$DISTRO_ROOTFS/bootstrap.sh"

mkdir -p "$DISTRO_ROOTFS/root"
cat <<'ENTRYPOINT_EOF' > "$DISTRO_ROOTFS/root/entrypoint.sh"
#!/bin/sh
# Entrypoint for Arch Linux in PRoot

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
