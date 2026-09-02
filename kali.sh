#!/bin/bash
# This is a distribution plug-in for Kali Linux.
# Auto-generated on 2026-09-01T22:15:00Z

DISTRO_NAME="Kali Linux"
DISTRO_COMMENT="Kali Linux official LXC rootfs"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/kali/current/amd64/default/20260901_17%3A14/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="67fbf9bf10c3e7a51aafeb37f85cc192ae756134bd0a24cefcb7b3c5bedaa2af"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/kali/current/arm64/default/20260901_17%3A14/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="02408cd3efdbf9c4b195a865317ce033dd546324f120378537b68abddd749892"

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
#   1. apt-get update && apt-get upgrade -y
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

apt-get update && apt-get upgrade -y
EOF

chmod +x bootstrap.sh
