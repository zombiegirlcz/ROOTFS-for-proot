#!/bin/bash
# This is a distribution plug-in for OpenWrt 24.10.
# Auto-generated on 2026-09-01T22:15:00Z

DISTRO_NAME="OpenWrt 24.10"
DISTRO_COMMENT="OpenWrt official LXC rootfs"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/openwrt/24.10/amd64/default/20260901_11%3A57/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="535cee8d5ff678ccf60fdbb5fa044dd542f5206b2f0e34be70e14c9dc961bc52"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/openwrt/24.10/arm64/default/20260901_11%3A57/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="0bf0a998e90431c2c81badeb3f34bb734b8ef0c76001197d13bc8946e69597ea"

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
#   1. opkg update
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

opkg update
EOF

chmod +x bootstrap.sh
