#!/bin/bash
# Distribution plug-in for Debian 14 (Forky)
# Auto-generated on 2026-10-30T14:45:00Z

DISTRO_NAME="Debian 14 (Forky)"
DISTRO_COMMENT="Debian 14 (Forky) official LXC rootfs from images.linuxcontainers.org"
DISTRO_ICON="🌀"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/debian/forky/arm64/default/20261029_05%3A24/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="0e8dda6fc59603abc56196d2df4f180867d1c939707ae61a5b8346b00ed9f4d6"

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/debian/forky/amd64/default/20261029_05%3A24/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="4f0b9027d706673f277e3682f2e209a827af3e48e894faa16475505d90471ace"

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
