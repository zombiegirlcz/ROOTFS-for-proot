#!/bin/bash
# Distribution plug-in for OpenCloudOS 9.6
# Auto-generated on 2026-09-22T22:00:00Z

DISTRO_NAME="OpenCloudOS 9.6"
DISTRO_COMMENT="OpenCloudOS official container rootfs"
DISTRO_ICON="☁️"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://mirrors.opencloudos.tech/opencloudos/9/images/docker/x86_64/20260920.1/OpenCloudOS-Container-Minimal-9.6-20260920.1.x86_64.tar.xz"
TARBALL_SHA256['x86_64']="12fc84dd95016394f8fd9489e000432b56f78901c241b795bc1c3fc2ee3d0e57"

TARBALL_URL['aarch64']="https://mirrors.opencloudos.tech/opencloudos/9/images/docker/aarch64/20260920.1/OpenCloudOS-Container-Minimal-9.6-20260920.1.aarch64.tar.xz"
TARBALL_SHA256['aarch64']="61bd8b1ebd9d01ab8f35409c68fd2f5f7ddd88e30b950bf3d864651b7cc78588"

# Detect best URL for current arch
SELECTED_URL="${TARBALL_URL[$DISTRO_ARCH]:-${TARBALL_URL['aarch64']}}"
SELECTED_SHA256="${TARBALL_SHA256[$DISTRO_ARCH]:-}"

if [ -z "$SELECTED_URL" ]; then
    echo "ERROR: No tarball URL for architecture $DISTRO_ARCH" >&2
    exit 1
fi

mkdir -p "$DISTRO_ROOTFS"
TMP_TARBALL="$DISTRO_ROOTFS/.tmp_rootfs.tar.xz"
echo "Downloading $DISTRO_NAME rootfs for $DISTRO_ARCH..."
curl -sSL --fail --show-error -o "$TMP_TARBALL" "$SELECTED_URL" || {
    echo "ERROR: Download failed from $SELECTED_URL" >&2
    exit 1
}

if [ -n "$SELECTED_SHA256" ]; then
    echo "$SELECTED_SHA256  $TMP_TARBALL" | sha256sum -c - || {
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

if [ -f "$DISTRO_ROOTFS/layer.tar" ]; then
    tar -xf "$DISTRO_ROOTFS/layer.tar" -C "$DISTRO_ROOTFS"
    rm -f "$DISTRO_ROOTFS/layer.tar" "$DISTRO_ROOTFS/json" "$DISTRO_ROOTFS/VERSION"
fi

cat <<'BOOTSTRAP_EOF' > "$DISTRO_ROOTFS/bootstrap.sh"
#!/bin/sh
#  =============================================================================
# RUNTIME & BOOTSTRAP CONFIGURATION
# ==============================================================================
# ENTRYPOINT: /bin/sh
# ENVIRONMENT: PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# SPECIAL MOUNTS / FLAGS: --link2symlink, custom /proc, /dev, /sys bind mounts
# POST-INSTALL HOOKS / BOOTSTRAP COMMANDS:
#   1. dnf update -y
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

dnf update -y
BOOTSTRAP_EOF

chmod +x "$DISTRO_ROOTFS/bootstrap.sh"

chmod u+w "$DISTRO_ROOTFS/root" 2>/dev/null; mkdir -p "$DISTRO_ROOTFS/root"
cat <<'ENTRYPOINT_EOF' > "$DISTRO_ROOTFS/root/entrypoint.sh"
#!/bin/sh
# Entrypoint for OpenCloudOS in PRoot

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
