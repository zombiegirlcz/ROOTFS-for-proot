#!/bin/bash
# This is a distribution plug-in for Rocky Linux 9.
# Auto-generated on 2026-09-01T22:15:00Z

DISTRO_NAME="Rocky Linux 9"
DISTRO_COMMENT="Rocky Linux official LXC rootfs"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/rockylinux/9/amd64/default/20260901_02%3A06/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="252b741e4794d929e2c24a48b9b15e6b2838f30e190077bea6244bb08b5e285e"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/rockylinux/9/arm64/default/20260901_02%3A06/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="29b0ae7784af1a40cfca004fa27face95341d8b22e47a6ba56446c63c57c3d98"

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
