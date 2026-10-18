#!/bin/bash
# Distribution plug-in for Ubuntu 22.04 LTS
# Auto-generated on 2026-10-09T13:30:00Z

DISTRO_NAME="Ubuntu 22.04 LTS"
DISTRO_COMMENT="Ubuntu 22.04 LTS (Jammy Jellyfish) rootfs from images.linuxcontainers.org"
DISTRO_ICON="🍥"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/ubuntu/jammy/arm64/default/20261018_13%3A46/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="cc2c2a3a53d3baf3eb050e9500b4451b7ed2acc04566f3f416b690048aa6e7b1"

TARBALL_URL['arm']="https://images.linuxcontainers.org/images/ubuntu/jammy/armhf/default/20261018_07%3A42/rootfs.tar.xz"
TARBALL_SHA256['arm']="518e3b3f558e96398c44c5cc5cccfcfc8b29b86f2a0a8ddbb4328fe15f85694e"

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/ubuntu/jammy/amd64/default/20261018_07%3A42/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="de52383f20e5ad4b7e8cf4c6fedb3467263b2482cf3645ffbee717e9d28dd34d"

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
