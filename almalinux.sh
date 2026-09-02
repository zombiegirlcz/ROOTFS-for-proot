#!/bin/bash
# This is a distribution plug-in for AlmaLinux 9.
# Auto-generated on 2026-09-01T22:15:00Z

DISTRO_NAME="AlmaLinux 9"
DISTRO_COMMENT="AlmaLinux official LXC rootfs"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/almalinux/9/amd64/default/20260831_23%3A08/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="7ec0599d66034692e15e61176a02bead3971a5b7009f0bfd68bfca02df7dd597"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/almalinux/9/arm64/default/20260831_23%3A08/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="506081f9c69ade339d7af7b225a068537c7342d14bcaeab575852ce84b0cdcd7"

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
#   1. dnf update -y
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

dnf update -y
EOF

chmod +x bootstrap.sh
