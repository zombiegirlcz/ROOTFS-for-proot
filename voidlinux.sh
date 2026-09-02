#!/bin/bash
# This is a distribution plug-in for Void Linux.
# Auto-generated on 2026-09-01T22:15:00Z

DISTRO_NAME="Void Linux"
DISTRO_COMMENT="Void Linux official LXC rootfs"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/voidlinux/current/amd64/default/20260901_17%3A10/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="09d37716d6d6f48f625001899b4a816359079001ef11e3ffae065c4f74208248"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/voidlinux/current/arm64/default/20260901_17%3A10/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="dd346686b3904f254b8fa3382be160268dccaff4be88879a6a49a68989491226"

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
#   1. xbps-install -Su
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

xbps-install -Su
EOF

chmod +x bootstrap.sh
