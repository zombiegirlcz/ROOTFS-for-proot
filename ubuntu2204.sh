#!/bin/bash
# Distribution plug-in for Ubuntu 22.04 LTS
# Auto-generated on 2026-10-09T13:30:00Z

DISTRO_NAME="Ubuntu 22.04 LTS"
DISTRO_COMMENT="Ubuntu 22.04 LTS (Jammy Jellyfish) rootfs from images.linuxcontainers.org"
DISTRO_ICON="🍥"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/ubuntu/jammy/arm64/default/20261011_07%3A42/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="f18103c5630f755dceb3a87a11208d26a9fa3cdfeb3f618ac255009e69a726cd"

TARBALL_URL['arm']="https://images.linuxcontainers.org/images/ubuntu/jammy/armhf/default/20261011_07%3A42/rootfs.tar.xz"
TARBALL_SHA256['arm']="9692a611f4cb3c2ab04a0cc6107a66a44c71a6fbf0d22e033d7a0c0f64016d47"

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/ubuntu/jammy/amd64/default/20261011_07%3A42/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="11b89f76cc90ad7e95dbde8d025cd2baa50d35246322f5085a7d9b119441c1eb"

# ── Manual use only: the app never runs the code below ──────────────────────
set -euo pipefail
: "${DISTRO_ROOTFS:?}" "${DISTRO_ARCH:=aarch64}"
URL="${TARBALL_URL[$DISTRO_ARCH]:-}"
SHA="${TARBALL_SHA256[$DISTRO_ARCH]:-}"
[ -n "$URL" ] || { echo "ERROR: no tarball for $DISTRO_ARCH" >&2; exit 1; }
mkdir -p "$DISTRO_ROOTFS"
TMP="$DISTRO_ROOTFS/.tmp_rootfs"
curl -fsSL -o "$TMP" "$URL"
echo "$SHA  $TMP" | sha256sum -c -
tar -xaf "$TMP" -C "$DISTRO_ROOTFS" 2>/dev/null || tar -xf "$TMP" -C "$DISTRO_ROOTFS"
rm -f "$TMP"

# ── First-boot bootstrap (runs once, non-interactive, no stdin) ─────────────
cat <<'BOOTSTRAP_EOF' > "$DISTRO_ROOTFS/bootstrap.sh"
#!/bin/sh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
[ -s /etc/resolv.conf ] || echo "nameserver 1.1.1.1" > /etc/resolv.conf
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get -y upgrade
BOOTSTRAP_EOF
chmod +x "$DISTRO_ROOTFS/bootstrap.sh"

# ── Entrypoint (no bootstrap here — the launcher does it) ───────────────────
mkdir -p "$DISTRO_ROOTFS/root"
cat <<'ENTRYPOINT_EOF' > "$DISTRO_ROOTFS/root/entrypoint.sh"
#!/bin/sh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
exec /bin/bash -l
ENTRYPOINT_EOF
chmod +x "$DISTRO_ROOTFS/root/entrypoint.sh"

# ── Manifest (read by the app + launcher) ────────────────────────────────────
mkdir -p "$DISTRO_ROOTFS/.nh"
cat <<'MANIFEST_EOF' > "$DISTRO_ROOTFS/.nh/manifest"
NH_SHELL=/bin/bash
NH_ENTRYPOINT=/root/entrypoint.sh
NH_BOOTSTRAP=/bootstrap.sh
NH_PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
NH_WORKDIR=/root
NH_PKG=apt
NH_LIBC=glibc
NH_INTEGRATION=minimal
MANIFEST_EOF

exit 0
