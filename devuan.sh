#!/bin/bash
# This is a distribution plug-in for Devuan Daedalus.
# Auto-generated on 2026-09-01T22:15:00Z

DISTRO_NAME="Devuan Daedalus"
DISTRO_COMMENT="Devuan official LXC rootfs"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/devuan/daedalus/amd64/default/20260901_11%3A50/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="ec5e6af294dd5676636b466b56a588bf971c4834ba6bba0f42c76ae7fa2df384"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/devuan/daedalus/arm64/default/20260901_11%3A50/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="9be31cec2b5c2f10fd77ed5169ccb79952f11136f85c292313360bf154180d7a"

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
#   1. apt-get update
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

apt-get update
EOF

chmod +x bootstrap.sh
