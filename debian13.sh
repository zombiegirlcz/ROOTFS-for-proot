#!/bin/bash
# Distribution plug-in for Debian 13 (Trixie)
# Auto-generated on 2026-10-07T22:30:00Z

DISTRO_NAME="Debian 13 (Trixie)"
DISTRO_COMMENT="Debian 13 (Trixie) official LXC rootfs from images.linuxcontainers.org"
DISTRO_ICON="🌀"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/debian/trixie/arm64/default/20261014_05%3A24/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="f21fd012f83396da720d2d678246a9f05dd28c25cc2842d72fe2ab4b72709672"

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/debian/trixie/amd64/default/20261014_05%3A24/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="3dedb8f1ad643c271c4929fbd80722a34df3f48c8d4b32a8f6dea871176bb8a3"

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
export DEBIAN_FRONTEND=noninteractive
[ -s /etc/resolv.conf ] || echo "nameserver 1.1.1.1" > /etc/resolv.conf
apt-get update
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
