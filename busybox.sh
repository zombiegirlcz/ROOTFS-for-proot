#!/bin/bash
# This is a distribution plug-in for BusyBox 1.38.
# Auto-generated on 2026-09-01T22:15:00Z

DISTRO_NAME="BusyBox 1.38"
DISTRO_COMMENT="BusyBox official LXC rootfs"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/busybox/1.38.0/amd64/default/20260901_06%3A00/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="047f5a1875e0d6ef5f63584158593ce59ce02999158f85288f49cf5e4b8ea11d"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/busybox/1.38.0/arm64/default/20260901_06%3A00/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="7dbac9caf02758333f26f56d61dd7549f37e3f48e04e97f065ec10b57d60cb4d"

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
#   1. echo BusyBox ready
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

echo BusyBox ready
EOF

chmod +x bootstrap.sh
