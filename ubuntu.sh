#!/bin/bash
# Distribution plug-in for Ubuntu 24.04 LTS (Noble Numbat)
# Auto-generated on 2026-09-01T22:05:00Z

DISTRO_NAME="Ubuntu 24.04.4 LTS"
DISTRO_COMMENT="Ubuntu Base official rootfs from cdimage.ubuntu.com"
DISTRO_ICON="🟠"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="http://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-arm64.tar.gz"
TARBALL_SHA256['aarch64']="04207713ece899c3740823d33690441ad3a7f0ded1101aca744e2b0f37ac7ff2"

TARBALL_URL['arm']="http://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-armhf.tar.gz"
TARBALL_SHA256['arm']="991520b47f6586f38a78505cf016e300b6191bb8ff86a0723481ec23a37ab7f4"

TARBALL_URL['x86_64']="http://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-amd64.tar.gz"
TARBALL_SHA256['x86_64']="c1e67ef7b17a6300e136118bd1dc04725009cb376c1aad10abcf8cd453628d58"

TARBALL_URL['riscv64']="http://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-riscv64.tar.gz"
TARBALL_SHA256['riscv64']="1b3cdb6a9c2370491584313b79e35838eaec0ec6a8d6b67f3ffff578c34cce2d"

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
#!/bin/bash
# ==============================================================================
# RUNTIME & BOOTSTRAP CONFIGURATION
# ==============================================================================
# ENTRYPOINT: /bin/bash
# ENVIRONMENT: PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# SPECIAL MOUNTS / FLAGS: --link2symlink, custom /proc, /dev, /sys bind mounts
# POST-INSTALL HOOKS / BOOTSTRAP COMMANDS:
#   1. apt-get update && apt-get upgrade -y
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
#   3. useradd -m -s /bin/bash ubuntu
# LIMITATIONS / KNOWN ISSUES:
#   - systemd / init system services cannot run as real PID 1 inside PRoot.

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
