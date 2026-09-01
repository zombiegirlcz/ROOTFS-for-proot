#!/bin/bash
# This is a distribution plug-in for Ubuntu 24.04 LTS (Noble Numbat).
# Auto-generated on 2026-09-01T22:05:00Z

DISTRO_NAME="Ubuntu 24.04.4 LTS"
DISTRO_COMMENT="Ubuntu Base official rootfs from cdimage.ubuntu.com"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="http://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-arm64.tar.gz"
TARBALL_SHA256['aarch64']="04207713ece899c3740823d33690441ad3a7f0ded1101aca744e2b0f37ac7ff2"

TARBALL_URL['arm']="http://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-armhf.tar.gz"
TARBALL_SHA256['arm']="991520b47f6586f38a78505cf016e300b6191bb8ff86a0723481ec23a37ab7f4"

TARBALL_URL['x86_64']="http://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-amd64.tar.gz"
TARBALL_SHA256['x86_64']="c1e67ef7b17a6300e136118bd1dc04725009cb376c1aad10abcf8cd453628d58"

TARBALL_URL['riscv64']="http://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-riscv64.tar.gz"
TARBALL_SHA256['riscv64']="1b3cdb6a9c2370491584313b79e35838eaec0ec6a8d6b67f3ffff578c34cce2d"

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
#   3. useradd -m -s /bin/bash ubuntu
# LIMITATIONS / KNOWN ISSUES:
#   - systemd / init system services cannot run as real PID 1 inside PRoot.
#   - Set PATH explicitly in subshells.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Setup resolv.conf if missing or invalid
if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi

# Update package repository index
apt-get update
EOF

chmod +x bootstrap.sh
