#!/bin/bash
# This is a distribution plug-in for Fedora 43.
# Auto-generated on 2026-09-01T22:15:00Z

DISTRO_NAME="Fedora 43"
DISTRO_COMMENT="Fedora official LXC rootfs"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/fedora/43/amd64/default/20260901_20%3A33/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="67eed9f546fddda2c89fd38c2735516ccede3ee4c16a57b2628e26ec7a05ad12"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/fedora/43/arm64/default/20260901_20%3A33/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="64b70f1e15c7a94a6d7c26af6b8023f34f018dfbe656dae87bef107569a767ce"

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
