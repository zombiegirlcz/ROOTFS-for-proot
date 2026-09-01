#!/bin/bash
# This is a distribution plug-in for Debian 12 (Bookworm).
# Auto-generated on 2026-09-01T22:07:00Z

DISTRO_NAME="Debian 12 (Bookworm)"
DISTRO_COMMENT="Debian official LXC rootfs from images.linuxcontainers.org"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/debian/bookworm/arm64/default/20260901_19%3A32/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="f73616fc3266ae7692958eeda6f6ec7656f9ea22881ce3cf25dc106a8a7e2d9d"

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/debian/bookworm/amd64/default/20260901_19%3A08/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="ef7e716028c85b33fab12aeaf0692b9ae3e4d3d68255e993f974c4d110ee19e1"

# Generate runtime bootstrap script and configuration metadata
cat <<'EOF' > bootstrap.sh
#!/bin/bash
# ==============================================================================
# RUNTIME & BOOTSTRAP CONFIGURATION
# ==============================================================================
# ENTRYPOINT: /bin/bash
# ENVIRONMENT: PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# SPECIAL MOUNTS / FLAGS: --link2symlink, custom /proc, /dev, /sys bind mounts
# POST-INSTALL HOOKS / BOOTSTRAP COMMANDS:
#   1. apt-get update && apt-get upgrade -y
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
#   3. useradd -m -s /bin/bash debian
# LIMITATIONS / KNOWN ISSUES:
#   - systemd / init system services cannot run as real PID 1 inside PRoot.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Setup resolv.conf if missing or invalid
if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

# Update package repository index
apt-get update
EOF

chmod +x bootstrap.sh
