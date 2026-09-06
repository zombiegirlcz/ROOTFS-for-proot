# Distro Plug-in Script Format Specification

## Overview

Each `.sh` file in this repo is a **self-contained distro plug-in** for the NetHunter app.
The app downloads the script, executes it inside a fresh PRoot rootfs, and then boots that rootfs.

**One script = one distro.**
The script must define **everything** the distro needs: tarball location, bootstrap config, and boot command.

---

## Required Environment Variables

The app injects these env vars before executing the script:

| Variable | Description |
|----------|-------------|
| `DISTRO_ROOTFS` | Absolute path to the extracted rootfs directory (e.g. `/data/user/0/com.linux_core/files/nh/distro/docker/kali`) |
| `DISTRO_NAME` | Human-readable name (fallback: script filename without `.sh`) |
| `DISTRO_ARCH` | Device architecture: `aarch64`, `arm`, `x86_64`, or `x86` |
| `DISTRO_OUTPUT_DIR` | Parent directory where the rootfs should be extracted (usually `$DISTRO_ROOTFS` parent) |
| `NH_BIN` | Path to the app's `boot` launcher inside the rootfs (`$DISTRO_ROOTFS/usr/bin/boot`) |
| `NH_PREFIX` | Path to the rootfs prefix (`$DISTRO_ROOTFS`) |

**The script MUST use `$DISTRO_ROOTFS` as the extraction target — never hardcode paths.**

---

## Script Structure (mandatory sections)

```bash
#!/bin/bash
# Distribution plug-in for <DISTRO NAME>
# Auto-generated on <DATE>

# ── 1. METADATA ──────────────────────────────────────────────────────────────
# These variables are parsed by the app for catalog display.
# ALL are mandatory unless marked optional.

DISTRO_NAME="<Human-readable name>"
DISTRO_COMMENT="<Short description / tagline>"
DISTRO_ICON="<emoji>"                          # optional: shown in UI picker

# Architecture → tarball URL mapping.
# Keys MUST match: aarch64 | arm | x86_64 | x86
declare -A TARBALL_URL
TARBALL_URL['aarch64']="https://..."
TARBALL_URL['arm']="https://..."               # optional: if unsupported, omit
TARBALL_URL['x86_64']="https://..."
TARBALL_URL['x86']="https://..."

# Architecture → SHA256 mapping (same keys as TARBALL_URL).
# Used for integrity verification after download.
declare -A TARBALL_SHA256
TARBALL_SHA256['aarch64']="<sha256hex>"
TARBALL_SHA256['x86_64']="<sha256hex>"

# ── 2. DOWNLOAD & EXTRACT ───────────────────────────────────────────────────
# The app runs this script INSIDE an empty rootfs directory.
# The script itself MUST download and extract the rootfs tarball.
# Supported formats: .tar.gz, .tgz, .tar.xz, .txz, .tar.bz2, .tbz2, .tar

# Detect best URL for current arch
TARBALL_URL="${TARBALL_URL[$DISTRO_ARCH]:-${TARBALL_URL['aarch64']}}"
TARBALL_SHA256="${TARBALL_SHA256[$DISTRO_ARCH]:-}"

if [ -z "$TARBALL_URL" ]; then
    echo "ERROR: No tarball URL for architecture $DISTRO_ARCH" >&2
    exit 1
fi

# Download to a temp file in the rootfs
TMP_TARBALL="$DISTRO_ROOTFS/.tmp_rootfs.tar.xz"
echo "Downloading $DISTRO_NAME rootfs for $DISTRO_ARCH..."
curl -sSL --fail --show-error -o "$TMP_TARBALL" "$TARBALL_URL" || {
    echo "ERROR: Download failed from $TARBALL_URL" >&2
    exit 1
}

# Verify SHA256 if available
if [ -n "$TARBALL_SHA256" ]; then
    echo "$TARBALL_SHA256  $TMP_TARBALL" | sha256sum -c - || {
        echo "ERROR: SHA256 mismatch" >&2
        rm -f "$TMP_TARBALL"
        exit 1
    }
fi

# Extract based on file extension
echo "Extracting rootfs..."
case "$TMP_TARBALL" in
    *.tar.xz|*.txz)
        tar -xJf "$TMP_TARBALL" -C "$DISTRO_ROOTFS" --strip-components=1
        ;;
    *.tar.bz2|*.tbz2)
        tar -xjf "$TMP_TARBALL" -C "$DISTRO_ROOTFS" --strip-components=1
        ;;
    *.tar.gz|*.tgz)
        tar -xzf "$TMP_TARBALL" -C "$DISTRO_ROOTFS" --strip-components=1
        ;;
    *.tar)
        tar -xf "$TMP_TARBALL" -C "$DISTRO_ROOTFS" --strip-components=1
        ;;
    *)
        echo "ERROR: Unknown archive format: $TMP_TARBALL" >&2
        rm -f "$TMP_TARBALL"
        exit 1
        ;;
esac

# Cleanup temp file
rm -f "$TMP_TARBALL"

# ── 3. GENERATE bootstrap.sh ────────────────────────────────────────────────
# This script runs ONCE after first boot, inside the rootfs.
# Use it for apt-get update, package installs, user creation, etc.

cat <<'BOOTSTRAP_EOF' > "$DISTRO_ROOTFS/bootstrap.sh"
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
BOOTSTRAP_EOF

chmod +x "$DISTRO_ROOTFS/bootstrap.sh"

# ── 4. GENERATE root/entrypoint.sh ─────────────────────────────────────────
# This is the FINAL command executed by the app's boot launcher.
# It must exec the user's preferred shell as root.

cat <<'ENTRYPOINT_EOF' > "$DISTRO_ROOTFS/root/entrypoint.sh"
#!/bin/sh
# Entrypoint for $DISTRO_NAME in PRoot
# This script is executed by the app's boot launcher after all mounts are ready.
# It runs as real root (PRoot -0), but confined to the rootfs.

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# If bootstrap.sh exists and hasn't run yet, execute it
if [ -f /bootstrap.sh ] && [ ! -f /bootstrap.done ]; then
    echo "[*] Running first-boot bootstrap..."
    sh /bootstrap.sh
    touch /bootstrap.done
fi

# Drop into interactive shell
exec /bin/bash --login
ENTRYPOINT_EOF

chmod +x "$DISTRO_ROOTFS/root/entrypoint.sh"

# ── 5. MARKER (optional but recommended) ───────────────────────────────────
# The app checks for this file to identify docker rootfs directories.
cat <<'MARKER_EOF' > "$DISTRO_ROOTFS/.docker_image"
image=local-script
pulled_at=$(date +%s)
source=local-script
script=$(basename "$0")
MARKER_EOF

# ── 6. FINALIZE ────────────────────────────────────────────────────────────
echo "$DISTRO_NAME rootfs prepared at: $DISTRO_ROOTFS"
echo "To boot: nh boot docker $(basename "$DISTRO_ROOTFS")"
exit 0
```

---

## App Execution Contract

When the user taps a preset in the UI, the app:

1. Creates an empty rootfs directory: `$DISTRO_ROOTFS`
2. Sets env vars: `DISTRO_ROOTFS`, `DISTRO_NAME`, `DISTRO_ARCH`, `DISTRO_OUTPUT_DIR`, `NH_BIN`, `NH_PREFIX`
3. Executes the script inside that directory
4. After script exits 0, reads `entrypoint.sh` from the rootfs
5. Boots the rootfs via: `boot <entrypoint> -- /root/entrypoint.sh`

**If the script exits non-zero, the app shows an error and does NOT boot.**

---

## Mandatory Rules for Script Authors

1. **Never hardcode paths.** Use `$DISTRO_ROOTFS` for all file operations.
2. **Download must use curl** (or wget) with `-sSL --fail`. The app does NOT download the tarball for you.
3. **Extract with tar** using `--strip-components=1` to avoid nesting.
4. **Generate `bootstrap.sh`** — the app does NOT create this for you.
5. **Generate `root/entrypoint.sh`** — the app does NOT create this for you.
6. **Exit 0 on success** — the app only boots on clean exit.
7. **Exit non-zero on error** — the app shows the error message from stderr.

---

## Example: Minimal Script

```bash
#!/bin/bash
# Alpine Linux plug-in

DISTRO_NAME="Alpine Linux"
DISTRO_COMMENT="Minimal Alpine Linux rootfs"
DISTRO_ICON="🏔️"

declare -A TARBALL_URL
TARBALL_URL['aarch64']="https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/aarch64/alpine-minirootfs-3.19.0-aarch64.tar.gz"
TARBALL_URL['x86_64']="https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-3.19.0-x86_64.tar.gz"

declare -A TARBALL_SHA256
TARBALL_SHA256['aarch64']="abc123..."
TARBALL_SHA256['x86_64']="def456..."

# Download
TARBALL_URL="${TARBALL_URL[$DISTRO_ARCH]:-${TARBALL_URL['aarch64']}}"
TMP_TARBALL="$DISTRO_ROOTFS/.tmp_rootfs.tar.gz"
curl -sSL --fail -o "$TMP_TARBALL" "$TARBALL_URL"

# Extract
tar -xzf "$TMP_TARBALL" -C "$DISTRO_ROOTFS" --strip-components=1
rm -f "$TMP_TARBALL"

# Bootstrap
cat <<'EOF' > "$DISTRO_ROOTFS/bootstrap.sh"
#!/bin/sh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
echo "nameserver 1.1.1.1" > /etc/resolv.conf
apk update && apk upgrade
EOF
chmod +x "$DISTRO_ROOTFS/bootstrap.sh"

# Entrypoint
cat <<'EOF' > "$DISTRO_ROOTFS/root/entrypoint.sh"
#!/bin/sh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ -f /bootstrap.sh ] && [ ! -f /bootstrap.done ]; then
    echo "[*] Running first-boot bootstrap..."
    sh /bootstrap.sh
    touch /bootstrap.done
fi
exec /bin/sh --login
EOF
chmod +x "$DISTRO_ROOTFS/root/entrypoint.sh"

# Marker
cat <<'EOF' > "$DISTRO_ROOTFS/.docker_image"
image=alpine
pulled_at=$(date +%s)
source=local-script
EOF

exit 0
```

---

## Agent Prompt (for maintaining this repo)

```markdown
You maintain the distro plug-in scripts in this repository.

Each script MUST follow this exact format:
1. Define DISTRO_NAME, DISTRO_COMMENT, DISTRO_ICON
2. Define TARBALL_URL[arch] and TARBALL_SHA256[arch] for all supported architectures
3. Download the rootfs tarball to $DISTRO_ROOTFS/.tmp_rootfs.* using curl
4. Extract with tar --strip-components=1 into $DISTRO_ROOTFS
5. Generate bootstrap.sh in $DISTRO_ROOTFS/
6. Generate root/entrypoint.sh in $DISTRO_ROOTFS/
7. Write .docker_image marker in $DISTRO_ROOTFS/
8. Exit 0 on success, non-zero on error

Never hardcode paths. Always use $DISTRO_ROOTFS, $DISTRO_ARCH, and other provided env vars.
The app handles booting after the script exits 0.
```
