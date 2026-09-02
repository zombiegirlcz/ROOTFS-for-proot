#!/bin/bash
# This is a distribution plug-in for Arch Linux.
# Auto-generated on 2026-09-01T22:15:00Z

DISTRO_NAME="Arch Linux"
DISTRO_COMMENT="Arch Linux official LXC rootfs"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/archlinux/current/amd64/default/20260901_20%3A34/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="44bb2595321de4c5d4406d28bf12babfb733f79ad176971d80b5bd2313f3fb2e"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/archlinux/current/arm64/default/20260901_20%3A34/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="b511d92071d444629dbb330394fab63c5cc3a7c92b8ebddd43bec3c8118457c3"

TARBALL_URL['loong64']="https://images.linuxcontainers.org/images/archlinux/current/loong64/default/20260901_20%3A34/rootfs.tar.xz"
TARBALL_SHA256['loong64']="fd37985eb65f46f7eb91a97c2ff33829016df2e9dc447dd47579ad12f3f69d7e"

TARBALL_URL['riscv64']="https://images.linuxcontainers.org/images/archlinux/current/riscv64/default/20260901_20%3A34/rootfs.tar.xz"
TARBALL_SHA256['riscv64']="b92a826dcc9c00625efec8fb633ea0c48ff519db9f5179a31ac76b9d228a7623"

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
#   1. pacman -Syu --noconfirm
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

pacman -Syu --noconfirm
EOF

chmod +x bootstrap.sh
