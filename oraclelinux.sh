#!/bin/bash
# This is a distribution plug-in for Oracle Linux 9.
# Auto-generated on 2026-09-04T22:00:00Z

DISTRO_NAME="Oracle Linux 9"
DISTRO_COMMENT="Oracle Linux official LXC rootfs"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/oracle/9/amd64/default/20260904_07%3A46/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="d5fa789d051dad090820759637d5dd2a1bee683184abddd06b74587bf108b581"

TARBALL_URL['aarch64']="https://images.linuxcontainers.org/images/oracle/9/arm64/default/20260904_08%3A03/rootfs.tar.xz"
TARBALL_SHA256['aarch64']="733e1b84f617a61e14f1ad1235277d1bc5642b713d15cfe42bc9d05ca8676ee8"

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
