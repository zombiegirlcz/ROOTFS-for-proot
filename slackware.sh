#!/bin/bash
# This is a distribution plug-in for Slackware Linux 15.0.
# Auto-generated on 2026-09-05T21:35:04Z

DISTRO_NAME="Slackware Linux 15.0"
DISTRO_COMMENT="Slackware Linux official LXC rootfs"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['x86_64']="https://images.linuxcontainers.org/images/slackware/15.0/amd64/default/20260904_23%3A08/rootfs.tar.xz"
TARBALL_SHA256['x86_64']="9453cf6e63677b3c54bd2882a7c677240546c898c0c425e3ff80384ef2f1bf0f"

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
#   1. setup DNS /etc/resolv.conf (echo "nameserver 1.1.1.1" > /etc/resolv.conf)
#   2. configure slackpkg mirror in /etc/slackpkg/mirrors if required
# LIMITATIONS / KNOWN ISSUES:
#   - PRoot syscall limitations for unprivileged containers.
#   - Init scripts and SysV services do not run as PID 1 inside PRoot.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -s /etc/resolv.conf ]; then
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
fi
EOF

chmod +x bootstrap.sh
