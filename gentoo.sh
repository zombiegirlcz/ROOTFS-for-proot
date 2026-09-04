#!/bin/bash
# This is a distribution plug-in for Gentoo Linux.
# Auto-generated on 2026-09-03T22:15:00Z

DISTRO_NAME="Gentoo Linux"
DISTRO_COMMENT="Gentoo official LXC rootfs"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/gentoo/current/amd64/openrc/20260903_16%3A07/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="24d44778cd76deae9eb22659da0f2d1ba4d746926526e68e7708b1fae5805872"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/gentoo/current/arm64/openrc/20260903_16%3A07/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="dd1efe47e3845a04d3b597d926a0a72ca94988fb8f811d95a4780d101acb416b"

TARBALL_URL['loong64']="https://images.linuxcontainers.org/images/gentoo/current/loong64/openrc/20260903_16%3A07/rootfs.tar.xz"
TARBALL_SHA256['loong64']="ae3ceec159b8f5a7ed97f1b6fe8e0bf20263f19931a079dd69536e4ad9a08fdb"

# Generate runtime bootstrap script and configuration metadata
cat <<'EOF' > bootstrap.sh
#!/bin/sh
#  =============================================================================
# RUNTIME & BOOTSTRAP CONFIGURATION
# ==============================================================================
# ENTRYPOINT: /bin/sh
# ENVIRONMENT: PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# SPECIAL MOUNTS / FLAGS: --link2symlink, custom /proc, /dev, /sys bind mounts
# POST-INSTALL HOOKS / BOOTSTRAP COMMANDS:
#   1. emerge-webrsync / emerge --sync
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers and OpenRC service manager.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

emerge-webrsync
EOF

chmod +x bootstrap.sh
