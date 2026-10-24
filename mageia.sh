#!/bin/bash
# Distribution plug-in for Mageia 9
# Auto-generated on 2026-09-15T22:00:00Z

DISTRO_NAME="Mageia 9"
DISTRO_COMMENT="Mageia 9 official Docker/LXC rootfs"
DISTRO_ICON="🔮"

if [ -z "$DISTRO_ROOTFS" ]; then
    echo "ERROR: DISTRO_ROOTFS environment variable is not set." >&2
    exit 1
fi

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="https://raw.githubusercontent.com/juanluisbaptiste/docker-brew-mageia/dist/dist/9/aarch64/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="77d04ef9e9f2e2d08fc81b96b8957ed430ef60d8ff6e7aa1ee19d33920423179"

TARBALL_URL['arm']="https://raw.githubusercontent.com/juanluisbaptiste/docker-brew-mageia/dist/dist/9/armv7hl/rootfs.tar.xz"
TARBALL_SHA256['arm']="594e81ae2e30c602f2bf4d29fea0a81d3c73d33f9c03f5d57e16ef4a157617a8"

TARBALL_URL['x86_64']="https://raw.githubusercontent.com/juanluisbaptiste/docker-brew-mageia/dist/dist/9/x86_64/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="0a9b330e6986b8931f0233f98fdb9a2966fe247f29c7fc4b6b408b465a95e250"

# Detect best URL for current arch
SELECTED_ARCH="${DISTRO_ARCH:-aarch64}"
SELECTED_URL="${TARBALL_URL[$SELECTED_ARCH]:-${TARBALL_URL['aarch64']}}"
SELECTED_SHA256="${TARBALL_SHA256[$SELECTED_ARCH]:-}"

if [ -z "$SELECTED_URL" ]; then
    echo "ERROR: No tarball URL for architecture ${DISTRO_ARCH:-unknown}" >&2
    exit 1
fi

mkdir -p "$DISTRO_ROOTFS"
TMP_TARBALL="$DISTRO_ROOTFS/.tmp_rootfs.tar.xz"
echo "Downloading $DISTRO_NAME rootfs for ${DISTRO_ARCH:-$SELECTED_ARCH}..."
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
TOP_LEVEL_COUNT=$(tar -tf "$TMP_TARBALL" | cut -d/ -f1 | grep -v '^$' | sort -u | wc -l)
if [ "$TOP_LEVEL_COUNT" -eq 1 ]; then
    STRIP_OPT="--strip-components=1"
else
    STRIP_OPT=""
fi

case "$TMP_TARBALL" in
    *.tar.xz|*.txz)
        tar -xJf "$TMP_TARBALL" -C "$DISTRO_ROOTFS" $STRIP_OPT
        ;;
    *.tar.bz2|*.tbz2)
        tar -xjf "$TMP_TARBALL" -C "$DISTRO_ROOTFS" $STRIP_OPT
        ;;
    *.tar.gz|*.tgz)
        tar -xzf "$TMP_TARBALL" -C "$DISTRO_ROOTFS" $STRIP_OPT
        ;;
    *.tar)
        tar -xf "$TMP_TARBALL" -C "$DISTRO_ROOTFS" $STRIP_OPT
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
#   1. dnf update -y
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

dnf -y makecache || urpmi.update -a || true
BOOTSTRAP_EOF

chmod +x "$DISTRO_ROOTFS/bootstrap.sh"

mkdir -p "$DISTRO_ROOTFS/root"
cat <<'ENTRYPOINT_EOF' > "$DISTRO_ROOTFS/root/entrypoint.sh"
#!/bin/sh
# Entrypoint for Mageia 9 in PRoot.
# Bootstrap nespouštět — boot ho pustí jednou podle NH_BOOTSTRAP v manifestu.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
exec /bin/bash -l
ENTRYPOINT_EOF

chmod +x "$DISTRO_ROOTFS/root/entrypoint.sh"

# ── MANIFEST: jak rootfs spustit (čte appka + boot, viz AGENTS.md) ──
mkdir -p "$DISTRO_ROOTFS/.nh"
cat <<'MANIFEST_EOF' > "$DISTRO_ROOTFS/.nh/manifest"
NH_SHELL=/bin/bash
NH_ENTRYPOINT=/root/entrypoint.sh
NH_BOOTSTRAP=/bootstrap.sh
NH_PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
NH_WORKDIR=/root
NH_PKG=dnf
NH_LIBC=glibc
NH_INTEGRATION=minimal
MANIFEST_EOF

cat <<'MARKER_EOF' > "$DISTRO_ROOTFS/.docker_image"
image=local-script
pulled_at=$(date +%s)
source=local-script
script=$(basename "$0")
MARKER_EOF

echo "$DISTRO_NAME rootfs prepared at: $DISTRO_ROOTFS"
echo "To boot: nh boot docker $(basename "$DISTRO_ROOTFS")"
exit 0
