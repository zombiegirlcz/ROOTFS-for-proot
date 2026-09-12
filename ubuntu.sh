#!/bin/bash
# Distribution plug-in for Ubuntu 24.04 LTS (Noble Numbat)
# Auto-generated on 2026-09-12T04:35:00Z

DISTRO_NAME="Ubuntu 24.04 LTS"
DISTRO_COMMENT="Ubuntu Base 24.04.5 LTS rootfs"
DISTRO_ICON="🍥"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-arm64.tar.gz"
TARBALL_SHA256['aarch64']="a91d5a93010193712d346d761372b7c9db6dfcf093893161c64ca107f05914f2"

TARBALL_URL['arm']="https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-armhf.tar.gz"
TARBALL_SHA256['arm']="4fcee4d278f1c5232e085a021a85e4c6cef3853557a88d98ff380b5e5d5841bb"

TARBALL_URL['x86_64']="https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-amd64.tar.gz"
TARBALL_SHA256['x86_64']="e77b6f10c2590cef872b33ee9f635a0e3fd1f57fb074c0e52b5c7f56147a0c86"

TARBALL_URL['riscv64']="https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-riscv64.tar.gz"
TARBALL_SHA256['riscv64']="651c516f291259ec913caa1efd0cfff738cd223adfc6617c884f07af487f08cf"

# Detect best URL for current arch
SELECTED_URL="${TARBALL_URL[$DISTRO_ARCH]:-${TARBALL_URL['aarch64']}}"
SELECTED_SHA256="${TARBALL_SHA256[$DISTRO_ARCH]:-}"

if [ -z "$SELECTED_URL" ]; then
    echo "ERROR: No tarball URL for architecture $DISTRO_ARCH" >&2
    exit 1
fi

mkdir -p "$DISTRO_ROOTFS"
TMP_TARBALL="$DISTRO_ROOTFS/.tmp_rootfs.tar.gz"
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

cat <<'BOOTSTRAP_EOF' > "$DISTRO_ROOTFS/bootstrap.sh"
#!/bin/sh
#  =============================================================================
# RUNTIME & BOOTSTRAP CONFIGURATION
# ==============================================================================
# ENTRYPOINT: /bin/sh
# ENVIRONMENT: PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# SPECIAL MOUNTS / FLAGS: --link2symlink, custom /proc, /dev, /sys bind mounts
# POST-INSTALL HOOKS / BOOTSTRAP COMMANDS:
#   1. apt-get update && apt-get upgrade -y
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

apt-get update && apt-get upgrade -y
BOOTSTRAP_EOF

chmod +x "$DISTRO_ROOTFS/bootstrap.sh"

mkdir -p "$DISTRO_ROOTFS/root"
cat <<'ENTRYPOINT_EOF' > "$DISTRO_ROOTFS/root/entrypoint.sh"
#!/bin/sh
# Entrypoint for Ubuntu in PRoot

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
