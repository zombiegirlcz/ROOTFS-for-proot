#!/bin/bash
# This is a distribution plug-in for CentOS Stream 9.
# Auto-generated on 2026-09-01T22:15:00Z

DISTRO_NAME="CentOS Stream 9"
DISTRO_COMMENT="CentOS Stream official LXC rootfs"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/centos/9-Stream/amd64/default/20260901_07%3A08/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="ce3e26557117d4c0b7ede0d9518fa0ebbb485a6e9bd4dd84b5179d2535837810"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/centos/9-Stream/arm64/default/20260901_07%3A08/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="38cbb698bdc884a2365ecf4181da7fb1cc6c5121d76abe4bb5699733ab9b4f4e"

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
