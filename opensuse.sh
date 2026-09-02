#!/bin/bash
# This is a distribution plug-in for OpenSUSE Tumbleweed.
# Auto-generated on 2026-09-01T22:15:00Z

DISTRO_NAME="OpenSUSE Tumbleweed"
DISTRO_COMMENT="OpenSUSE official LXC rootfs"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/opensuse/tumbleweed/amd64/default/20260901_04%3A20/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="1bb787111b6329007ca5564bc8e7dfa85b1e874b2da92434c2d3a26211a3dc50"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/opensuse/tumbleweed/arm64/default/20260901_04%3A20/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="00aefe3f4fbfd3c736fb13d130a53aab02d4d3fcefd00d5697e5b9641f80ace6"

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
#   1. zypper refresh && zypper update -y
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

zypper refresh && zypper update -y
EOF

chmod +x bootstrap.sh
