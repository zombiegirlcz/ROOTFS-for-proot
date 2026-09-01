#!/bin/bash
# This is a distribution plug-in for Alpine Linux.
# Auto-generated on 2026-09-01T21:58:00Z

DISTRO_NAME="Alpine Linux 3.20.3"
DISTRO_COMMENT="Alpine Linux official minirootfs from dl-cdn.alpinelinux.org"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/aarch64/alpine-minirootfs-3.20.3-aarch64.tar.gz"
TARBALL_SHA256['aarch64']="041fa34a81788242df9e78fa69b97ab45b8ec47ddbf88864755610414a7bf3de"

TARBALL_URL['arm']="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/armv7/alpine-minirootfs-3.20.3-armv7.tar.gz"
TARBALL_SHA256['arm']="ea8823fb4c4cf5f71f1d180e47904fb36ae74d3ded06c980230116b129fc5f07"

TARBALL_URL['x86_64']="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-minirootfs-3.20.3-x86_64.tar.gz"
TARBALL_SHA256['x86_64']="d4e6fd67dcf75e40c451560ac7265166c2b72a0f38ddc9aae756a7de3d1efa0c"

TARBALL_URL['x86']="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86/alpine-minirootfs-3.20.3-x86.tar.gz"
TARBALL_SHA256['x86']="4c7ba1c9e6642692dd5cb302e5e58943221901f2e15991af7d5cb4ded80dc7b9"

TARBALL_URL['riscv64']="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/riscv64/alpine-minirootfs-3.20.3-riscv64.tar.gz"
TARBALL_SHA256['riscv64']="290d402a3e2770a74e86caf1e43205dbf337b9aec1610c6c6d8ffbd2d52796a1"

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
#   1. apk update && apk upgrade
#   2. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
#   3. adduser -D user
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot cannot mimic full Linux kernel syscalls (e.g. ping/ICMP RAW sockets without root capability)
#   - BusyBox init or OpenRC services do not run as real PID 1 inside PRoot.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Setup resolv.conf if missing or invalid
if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

# Update package repository index
apk update
EOF

chmod +x bootstrap.sh
