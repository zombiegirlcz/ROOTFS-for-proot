#!/bin/bash
# Distribution plug-in for Termux
# Auto-generated on 2026-09-01T22:18:00Z

DISTRO_NAME="Termux"
DISTRO_COMMENT="Termux official bootstrap releases from termux-packages GitHub"
DISTRO_ICON="💻"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="https://github.com/termux/termux-packages/releases/download/bootstrap-2026.08.30-r1%2Bapt.android-7/bootstrap-aarch64.zip"
TARBALL_SHA256['aarch64']="7e92f4c435d16207cdda63d5629e666ab98441f09eefa6a8423037ef13263346"

TARBALL_URL['arm']="https://github.com/termux/termux-packages/releases/download/bootstrap-2026.08.30-r1%2Bapt.android-7/bootstrap-arm.zip"
TARBALL_SHA256['arm']="67c605cb43632f5871355afc38632aa5b5206e91dc13e9639b20a3ec3727959f"

TARBALL_URL['x86']="https://github.com/termux/termux-packages/releases/download/bootstrap-2026.08.30-r1%2Bapt.android-7/bootstrap-i686.zip"
TARBALL_SHA256['x86']="e7f142c4e64c258911dc308e9248372ed0624e1e0abe2df10b1f4cfa7a72ed70"

TARBALL_URL['x86_64']="https://github.com/termux/termux-packages/releases/download/bootstrap-2026.08.30-r1%2Bapt.android-7/bootstrap-x86_64.zip"
TARBALL_SHA256['x86_64']="35f68d3dde3378e74df86b7a45d1065b0f686734d7e5308b62f7e0f5b3840584"

TARBALL_URL="${TARBALL_URL[$DISTRO_ARCH]:-${TARBALL_URL['aarch64']}}"
TARBALL_SHA256="${TARBALL_SHA256[$DISTRO_ARCH]:-}"

if [ -z "$TARBALL_URL" ]; then
    echo "ERROR: No tarball URL for architecture $DISTRO_ARCH" >&2
    exit 1
fi

mkdir -p "$DISTRO_ROOTFS"
TMP_TARBALL="$DISTRO_ROOTFS/.tmp_rootfs.zip"
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
if command -v unzip >/dev/null 2>&1; then
    unzip -q "$TMP_TARBALL" -d "$DISTRO_ROOTFS"
else
    echo "ERROR: unzip utility is required to extract Termux rootfs" >&2
    rm -f "$TMP_TARBALL"
    exit 1
fi

rm -f "$TMP_TARBALL"

cat <<'BOOTSTRAP_EOF' > "$DISTRO_ROOTFS/bootstrap.sh"
#!/bin/sh
#  =============================================================================
# RUNTIME & BOOTSTRAP CONFIGURATION
# ==============================================================================
# ENTRYPOINT: /data/data/com.termux/files/usr/bin/bash
# ENVIRONMENT: PATH=/data/data/com.termux/files/usr/bin
# SPECIAL MOUNTS / FLAGS: --link2symlink
# POST-INSTALL HOOKS / BOOTSTRAP COMMANDS:
#   1. pkg update && pkg upgrade
# LIMITATIONS / KNOWN ISSUES:
#   - Relies on Android paths under /data/data/com.termux/files/usr

export PATH=/data/data/com.termux/files/usr/bin:$PATH

pkg update
BOOTSTRAP_EOF

chmod +x "$DISTRO_ROOTFS/bootstrap.sh"

mkdir -p "$DISTRO_ROOTFS/root"
cat <<'ENTRYPOINT_EOF' > "$DISTRO_ROOTFS/root/entrypoint.sh"
#!/bin/sh
# Entrypoint for Termux in PRoot

export PATH=/data/data/com.termux/files/usr/bin:$PATH

if [ -f /bootstrap.sh ] && [ ! -f /bootstrap.done ]; then
    echo "[*] Running first-boot bootstrap..."
    sh /bootstrap.sh
    touch /bootstrap.done
fi

exec /data/data/com.termux/files/usr/bin/bash --login 2>/dev/null || exec /bin/sh --login
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
