#!/bin/bash
# This is a distribution plug-in for Gentoo Linux.
# Auto-generated on 2026-09-02T22:00:00Z

DISTRO_NAME="Gentoo Linux"
DISTRO_COMMENT="Gentoo Linux official stage3 OpenRC rootfs from distfiles.gentoo.org"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="https://distfiles.gentoo.org/releases/arm64/autobuilds/20260830T234553Z/stage3-arm64-openrc-20260830T234553Z.tar.xz"
TARBALL_SHA256['aarch64']="cac51286eb9935b538df3bc91a65ed821a1c4bb84a8274e7a06635e6a01c9349"

TARBALL_URL['arm']="https://distfiles.gentoo.org/releases/arm/autobuilds/20260826T233058Z/stage3-armv7a_hardfp-openrc-20260826T233058Z.tar.xz"
TARBALL_SHA256['arm']="086e391f3fd791096e7b89a9831d3e18942432d58aad3fa5feffd548121c8a7b"

TARBALL_URL['x86_64']="https://distfiles.gentoo.org/releases/amd64/autobuilds/20260830T151604Z/stage3-amd64-openrc-20260830T151604Z.tar.xz"
TARBALL_SHA256['x86_64']="a27b4e5c011cd3c8756a42a61b0b8f873144b6b2bfab0ea27cfbeb5bc18e1917"

TARBALL_URL['x86']="https://distfiles.gentoo.org/releases/x86/autobuilds/20260901T170056Z/stage3-i686-openrc-20260901T170056Z.tar.xz"
TARBALL_SHA256['x86']="eee9bfeafe47e1af202e034b332039fc157245f0293a255cba9ed2a7e5a55582"

TARBALL_URL['riscv64']="https://distfiles.gentoo.org/releases/riscv/autobuilds/20260827T174602Z/stage3-rv64_lp64d-openrc-20260827T174602Z.tar.xz"
TARBALL_SHA256['riscv64']="5b95b652b8b2000d82bee39796d00b0f87f852b3825bf776436655f8015ee68d"

# Generate runtime bootstrap script and configuration metadata
cat <<'EOF' > bootstrap.sh
#!/bin/sh
#  =============================================================================
# RUNTIME & BOOTSTRAP CONFIGURATION
# ==============================================================================
# ENTRYPOINT: /bin/bash
# ENVIRONMENT: PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# SPECIAL MOUNTS / FLAGS: --link2symlink, custom /proc, /dev, /sys bind mounts
# POST-INSTALL HOOKS / BOOTSTRAP COMMANDS:
#   1. getuto 2>/dev/null || true && emerge-webrsync
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
#   3. useradd -m -s /bin/bash gentoo
# LIMITATIONS / KNOWN ISSUES:
#   - OpenRC services do not run as real PID 1 inside PRoot.
#   - Compiling large packages with Portage in PRoot requires sufficient RAM/SWAP.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Setup resolv.conf if missing or invalid
if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

# Sync Portage binary/package repos
getuto 2>/dev/null || true
emerge-webrsync
EOF

chmod +x bootstrap.sh
