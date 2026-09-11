#!/bin/bash
# Distribution plug-in for GNU Guix System
# Auto-generated on 2026-09-11T04:20:00Z

DISTRO_NAME="GNU Guix 1.5.0"
DISTRO_COMMENT="GNU Guix transactional package manager and distribution"
DISTRO_ICON="🐂"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="https://ftp.gnu.org/gnu/guix/guix-binary-1.5.0.aarch64-linux.tar.xz"
TARBALL_SHA256['aarch64']="a5d58b1d0294cad6adb1f2aff627d37feb5db763fdffbceb8551f2b12123cf39"

TARBALL_URL['arm']="https://ftp.gnu.org/gnu/guix/guix-binary-1.5.0.armhf-linux.tar.xz"
TARBALL_SHA256['arm']="e92ddecf4476ce1e41b85e4eb1c8fd9a4756d77c817c1fd986ab24253612b0fa"

TARBALL_URL['x86_64']="https://ftp.gnu.org/gnu/guix/guix-binary-1.5.0.x86_64-linux.tar.xz"
TARBALL_SHA256['x86_64']="aa41025489c5061543e9c48873eaa829b900b2da75d40f9648913622f5f47817"

TARBALL_URL['x86']="https://ftp.gnu.org/gnu/guix/guix-binary-1.5.0.i686-linux.tar.xz"
TARBALL_SHA256['x86']="e2aae143a826e218b9724a3e416b3688ff753b11fb63283164010b9802b4b1a4"

TARBALL_URL['riscv64']="https://ftp.gnu.org/gnu/guix/guix-binary-1.5.0.riscv64-linux.tar.xz"
TARBALL_SHA256['riscv64']="3112abc99c9b0fcd122a6a0f4daa076dd4daf2db366b3f0a675cbe396fa1ae0d"

# Detect best URL for current arch
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
# ENVIRONMENT: PATH=/var/guix/profiles/per-user/root/current-guix/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# SPECIAL MOUNTS / FLAGS: --link2symlink, custom /proc, /dev, /sys bind mounts
# POST-INSTALL HOOKS / BOOTSTRAP COMMANDS:
#   1. guix pull
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers and daemon services.

export PATH=/var/guix/profiles/per-user/root/current-guix/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

guix pull || true
BOOTSTRAP_EOF

chmod +x "$DISTRO_ROOTFS/bootstrap.sh"

mkdir -p "$DISTRO_ROOTFS/root"
cat <<'ENTRYPOINT_EOF' > "$DISTRO_ROOTFS/root/entrypoint.sh"
#!/bin/sh
# Entrypoint for GNU Guix in PRoot

export PATH=/var/guix/profiles/per-user/root/current-guix/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ -f /bootstrap.sh ] && [ ! -f /bootstrap.done ]; then
    echo "[*] Running first-boot bootstrap..."
    sh /bootstrap.sh
    touch /bootstrap.done
fi

if [ -x /bin/bash ]; then
    exec /bin/bash --login
else
    exec /bin/sh --login
fi
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
