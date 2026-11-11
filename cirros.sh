#!/bin/bash
# Distribution plug-in for CirrOS 0.6.3
# Auto-generated on 2026-11-11T03:00:00Z

DISTRO_NAME="CirrOS 0.6.3"
DISTRO_COMMENT="Official CirrOS test Linux distribution minimal rootfs"
DISTRO_ICON="☁️"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="https://github.com/cirros-dev/cirros/releases/download/0.6.3/cirros-0.6.3-aarch64-lxc.tar.xz"
TARBALL_SHA256['aarch64']="b8c6e106fdd7c01c371fac763ed27d6e266a6cd44fd2ec47cdde26b178c00bbd"

TARBALL_URL['arm']="https://github.com/cirros-dev/cirros/releases/download/0.6.3/cirros-0.6.3-arm-lxc.tar.xz"
TARBALL_SHA256['arm']="dd84628d8cd17d9deb42dbd299eb947704bb75d7ab6447cc1c97757697a0b53f"

TARBALL_URL['x86_64']="https://github.com/cirros-dev/cirros/releases/download/0.6.3/cirros-0.6.3-x86_64-lxc.tar.xz"
TARBALL_SHA256['x86_64']="91e552da5989bef96572da10c5d1d1d510150584513bbdcd0c28873a56a9cc3a"

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
exit 0
BOOTSTRAP_EOF
chmod +x "$DISTRO_ROOTFS/bootstrap.sh"

# ── Entrypoint (no bootstrap here — the launcher does it) ───────────────────
mkdir -p "$DISTRO_ROOTFS/root"
chmod u+w "$DISTRO_ROOTFS/root"
cat <<'ENTRYPOINT_EOF' > "$DISTRO_ROOTFS/root/entrypoint.sh"
#!/bin/sh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
exec /bin/sh -l
ENTRYPOINT_EOF
chmod +x "$DISTRO_ROOTFS/root/entrypoint.sh"

# ── Manifest (read by the app + launcher) ────────────────────────────────────
mkdir -p "$DISTRO_ROOTFS/.nh"
cat <<'MANIFEST_EOF' > "$DISTRO_ROOTFS/.nh/manifest"
NH_SHELL=/bin/sh
NH_ENTRYPOINT=/root/entrypoint.sh
NH_BOOTSTRAP=/bootstrap.sh
NH_PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
NH_WORKDIR=/root
NH_PKG=none
NH_LIBC=other
NH_INTEGRATION=minimal
MANIFEST_EOF

exit 0
