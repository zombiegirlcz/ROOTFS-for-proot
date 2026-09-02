#!/bin/bash
# This is a distribution plug-in for Termux.
# Auto-generated on 2026-09-01T22:18:00Z

DISTRO_NAME="Termux"
DISTRO_COMMENT="Termux official bootstrap releases from termux-packages GitHub"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

TARBALL_URL['aarch64']="https://github.com/termux/termux-packages/releases/download/bootstrap-2026.08.30-r1%2Bapt.android-7/bootstrap-aarch64.zip"
TARBALL_SHA256['aarch64']="7e92f4c435d16207cdda63d5629e666ab98441f09eefa6a8423037ef13263346"

TARBALL_URL['arm']="https://github.com/termux/termux-packages/releases/download/bootstrap-2026.08.30-r1%2Bapt.android-7/bootstrap-arm.zip"
TARBALL_SHA256['arm']="67c605cb43632f5871355afc38632aa5b5206e91dc13e9639b20a3ec3727959f"

TARBALL_URL['x86']="https://github.com/termux/termux-packages/releases/download/bootstrap-2026.08.30-r1%2Bapt.android-7/bootstrap-i686.zip"
TARBALL_SHA256['x86']="e7f142c4e64c258911dc308e9248372ed0624e1e0abe2df10b1f4cfa7a72ed70"

TARBALL_URL['x86_64']="https://github.com/termux/termux-packages/releases/download/bootstrap-2026.08.30-r1%2Bapt.android-7/bootstrap-x86_64.zip"
TARBALL_SHA256['x86_64']="35f68d3dde3378e74df86b7a45d1065b0f686734d7e5308b62f7e0f5b3840584"

# Generate runtime bootstrap script and configuration metadata
cat <<'EOF' > bootstrap.sh
#!/bin/sh
#  =============================================================================
# RUNTIME & BOOTSTRAP CONFIGURATION
# ==============================================================================
# ENTRYPOINT: /data/data/com.termux/files/usr/bin/bash
# ENVIRONMENT: PATH=/data/data/com.termux/files/usr/bin
# SPECIAL MOUNTS / FLAGS: --link2symlink
# POST-INSTALL HOOKS / BOOTSTRAP COMMANDS:
#   1. pkg update && pkg upgrade
# LIMITATIONS / KNOWN ISSUES:
#   - Relies on Android paths under /data/data/com.termux/files/usr

export PATH=/data/data/com.termux/files/usr/bin:$PATH

pkg update
EOF

chmod +x bootstrap.sh
