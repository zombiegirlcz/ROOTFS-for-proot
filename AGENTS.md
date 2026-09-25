# Distro Plug-in Scripts for the NetHunter App (`com.linux_core`)

Each `<slug>.sh` in the repository root describes **one Linux rootfs** that the
Android app offers under "presets". The app boots it with PRoot on a phone
(aarch64, Android kernel, no root, SELinux).

> **Hard rule: a script is only done when `tools/validate.py --full --require-arch <slug>.sh`
> passes.** CI runs that on every PR on a real aarch64 runner and the PR is merged
> only if it passes. Do not open a PR that you have not validated.

---

## 1. What the app really does (the contract)

The app **never executes the script.** It downloads the file from GitHub and
extracts data from it with regexes (`RemoteRootfsCatalog.kt`). Anything that is
not in one of the exact forms below is invisible to the app.

| The app reads | Exact form (one per line, at line start) |
|---|---|
| Name | `DISTRO_NAME="..."` (double quotes) |
| Description | `DISTRO_COMMENT="..."` (double quotes) |
| Tarball URL per arch | `TARBALL_URL['aarch64']="https://..."` |
| SHA256 per arch | `TARBALL_SHA256['aarch64']="<64 lowercase hex>"` |
| Bootstrap | heredoc `cat <<'BOOTSTRAP_EOF' > "$DISTRO_ROOTFS/bootstrap.sh"` |
| Entrypoint | heredoc `cat <<'ENTRYPOINT_EOF' > "$DISTRO_ROOTFS/root/entrypoint.sh"` |
| Manifest | heredoc `cat <<'MANIFEST_EOF' > "$DISTRO_ROOTFS/.nh/manifest"` |

Then, when the user taps the preset, the app:

1. Picks `TARBALL_URL[<device arch>]` — **exact key only**. Arch keys the app
   knows: `aarch64`, `arm`, `x86_64`, `x86`. A script without the device's key is
   hidden on that device. There is no fallback to another arch.
2. Downloads it and checks `TARBALL_SHA256[<arch>]`.
3. Detects the format **from the end of the URL**: `.tar.xz` `.txz` `.tar.gz`
   `.tgz` `.tar.bz2` `.tbz2` `.tar`. Anything else (`.zip`, `.iso`, `.qcow2`,
   `/download/1`, `?query` after the extension) does not work.
4. Extracts it into `nh/distro/docker/<slug>/` **without** `--strip-components`.
   So `bin/ etc/ usr/` must be at the archive root. Hardlinks are copied,
   symlinks kept, device nodes skipped.
5. Writes the three heredoc bodies to `/bootstrap.sh`, `/root/entrypoint.sh`
   (both `chmod +x`) and `/.nh/manifest`. Writes `/etc/resolv.conf`.
6. Boots: `proot … <NH_SHELL> -c <launcher>`, which runs `NH_BOOTSTRAP` once
   (first boot, marker `/.nh/bootstrap.done`, retried on failure), then
   `exec NH_ENTRYPOINT` (or `NH_SHELL -l`). The environment is **clean**
   (`env -i`): only `HOME USER LOGNAME TERM COLORTERM LANG=C.UTF-8 LC_CTYPE PATH`
   plus the manifest's `NH_ENV`.

Because the script is never executed, its download/extract code is only a
convenience for running it by hand. What matters are the lines above.

---

## 2. The manifest (`/.nh/manifest`)

Plain `KEY=VALUE` lines. The app and the launcher only **read** it (never
`source` it): no quotes needed, no variables, no command substitution, no spaces
in values, `#` comments allowed.

| Key | Required | Meaning |
|---|---|---|
| `NH_SHELL` | yes | Absolute guest path of a POSIX shell that exists in the rootfs (`/bin/sh`, `/bin/bash`). Symlinks are followed **inside** the rootfs. Runs the bootstrap and the login shell (`-l`). |
| `NH_PKG` | yes | Package manager: `apt apk dnf yum microdnf tdnf pacman xbps zypper emerge opkg urpmi slackpkg swupd eopkg nix guix kiss scratchpkg pkgtool none`. |
| `NH_LIBC` | yes | `glibc`, `musl` or `other`. |
| `NH_ENTRYPOINT` | no | Absolute guest path of an executable script run after the bootstrap instead of `NH_SHELL -l`. Its shebang interpreter must exist in the rootfs. It must end with `exec <shell> -l`. It must **not** run the bootstrap. |
| `NH_BOOTSTRAP` | no | Absolute guest path of the one-time first-boot script, run as `NH_SHELL <path>`. |
| `NH_PATH` | no | Guest `PATH` (default `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`). |
| `NH_WORKDIR` | no | Start directory (default `/root`). |
| `NH_ENV` | no, repeatable | Extra environment variable, `KEY=VALUE`, no spaces. |
| `NH_BIND` | no, repeatable | Extra PRoot bind, `/host/path[:/guest/path]`, absolute, no spaces. Almost never needed. |
| `NH_INTEGRATION` | no | `minimal` (default): the app does not touch the rootfs. `full`: the app also deploys its Debian-oriented bootstrap/zshrc/profile. Use `full` only for Debian-family images you validated with it. |

---

## 3. Canonical script template

Copy this and change only what is marked. Keep the exact heredoc lines.

```bash
#!/bin/bash
# Distribution plug-in for <NAME>
# Auto-generated on <UTC ISO DATE>

DISTRO_NAME="<Human readable name + version>"
DISTRO_COMMENT="<Where the rootfs comes from, e.g. 'Official minirootfs from dl-cdn.alpinelinux.org'>"
DISTRO_ICON="<one emoji>"

declare -A TARBALL_URL
declare -A TARBALL_SHA256

# aarch64 is REQUIRED. Add other arches only if you verified their URL + SHA too.
TARBALL_URL['aarch64']="https://<direct link to rootfs tarball>"
TARBALL_SHA256['aarch64']="<sha256 of that exact file>"

# ── Manual use only: the app never runs the code below ──────────────────────
set -euo pipefail
: "${DISTRO_ROOTFS:?}" "${DISTRO_ARCH:=aarch64}"
URL="${TARBALL_URL[$DISTRO_ARCH]:-}"
SHA="${TARBALL_SHA256[$DISTRO_ARCH]:-}"
[ -n "$URL" ] || { echo "ERROR: no tarball for $DISTRO_ARCH" >&2; exit 1; }
mkdir -p "$DISTRO_ROOTFS"
TMP="$DISTRO_ROOTFS/.tmp_rootfs"
curl -fsSL -o "$TMP" "$URL"
echo "$SHA  $TMP" | sha256sum -c -
tar -xaf "$TMP" -C "$DISTRO_ROOTFS" 2>/dev/null || tar -xf "$TMP" -C "$DISTRO_ROOTFS"
rm -f "$TMP"

# ── First-boot bootstrap (runs once, non-interactive, no stdin) ─────────────
cat <<'BOOTSTRAP_EOF' > "$DISTRO_ROOTFS/bootstrap.sh"
#!/bin/sh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
[ -s /etc/resolv.conf ] || echo "nameserver 1.1.1.1" > /etc/resolv.conf
<refresh package index, non-interactive — see section 5>
BOOTSTRAP_EOF
chmod +x "$DISTRO_ROOTFS/bootstrap.sh"

# ── Entrypoint (no bootstrap here — the launcher does it) ───────────────────
mkdir -p "$DISTRO_ROOTFS/root"
cat <<'ENTRYPOINT_EOF' > "$DISTRO_ROOTFS/root/entrypoint.sh"
#!/bin/sh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
exec /bin/sh -l
ENTRYPOINT_EOF
chmod +x "$DISTRO_ROOTFS/root/entrypoint.sh"

# ── Manifest (read by the app + launcher) ────────────────────────────────────
mkdir -p "$DISTRO_ROOTFS/.nh"
cat <<'MANIFEST_EOF' > "$DISTRO_ROOTFS/.nh/manifest"
NH_SHELL=/bin/sh
NH_ENTRYPOINT=/root/entrypoint.sh
NH_BOOTSTRAP=/bootstrap.sh
NH_PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
NH_WORKDIR=/root
NH_PKG=<apt|apk|dnf|...>
NH_LIBC=<glibc|musl|other>
NH_INTEGRATION=minimal
MANIFEST_EOF

exit 0
```

---

## 4. What counts as a valid rootfs tarball

The validator rejects everything else, so check before you spend time:

- A **plain filesystem tree**: `bin/` (or `usr/bin/`) and `etc/` at the archive
  root, not wrapped in a single directory.
- Built for **aarch64** (arm64). Check the ELF of `/bin/sh` (`file`), not only
  the URL. An `amd64` URL under the `aarch64` key is a hard failure.
- A compressed tar with one of the extensions listed in section 1, and the URL
  must **end** with that extension.
- A **direct, stable** download link (HTTP 200 without login/cookies).

Not a rootfs (rejected): ISO/IMG/QCOW2 disk images, `docker save` archives
(`manifest.json` + `*/layer.tar`), OCI layouts (`oci-layout`, `blobs/`),
installers (Nix/Guix binary tarballs, `install` scripts), Termux bootstrap
`.zip`, WSL `.appx`, anything that only works after running an installer.

Good sources (prefer in this order):

1. The distro's own official "minirootfs"/"base"/"container rootfs" tarball
   (Alpine minirootfs, Ubuntu Base, Void ROOTFS, Chimera ROOTFS, Adélie mini, …).
2. `images.linuxcontainers.org` (LXC). Build directories are **dated and deleted
   after a few days**, so always resolve the newest build:
   ```bash
   base=https://images.linuxcontainers.org/images/<distro>/<release>/arm64/default/
   build=$(curl -fsSL "$base" | grep -o 'href="[0-9]\{8\}_[^"/]*/"' | tail -1 | cut -d'"' -f2)
   url="$base${build}rootfs.tar.xz"
   sha=$(curl -fsSL "$base${build}SHA256SUMS" | awk '$2=="rootfs.tar.xz"{print $1}')
   ```
   If `arm64/` does not exist for that distro, the distro has **no aarch64 build
   there** — find another source or pick another distro.
3. Official docker-brew / container rootfs repositories that publish the rootfs
   tarball itself (not a Dockerfile, not a `docker save`).

Always compute the SHA256 yourself from the downloaded file
(`sha256sum`). Never copy a checksum you did not verify.

---

## 5. Bootstrap rules

The bootstrap runs once on the phone, as fake root under PRoot, **with no stdin
and no TTY**. It must finish without questions and exit 0.

- Only refresh the package index (+ at most a few small packages). Do **not**
  install init systems, kernels, systemd services, or run full dist-upgrades that
  pull in `systemd`/`filesystem`/`glibc` post-install scripts — those often fail
  under PRoot.
- Always non-interactive:
  - apt: `export DEBIAN_FRONTEND=noninteractive; apt-get update && apt-get -y upgrade`
  - apk: `apk update && apk upgrade`
  - dnf/yum/tdnf/microdnf: `dnf -y makecache` (or `-y upgrade`)
  - pacman: `pacman -Syu --noconfirm` (initialise keyring first if the image needs it)
  - xbps: `xbps-install -Syu` (`-y` is mandatory)
  - zypper: `zypper --non-interactive refresh && zypper --non-interactive update`
  - opkg: `opkg update`
- Do not run `sh /bootstrap.sh` from the entrypoint — the launcher does it once.
- `exit` non-zero on real failure; the launcher retries on the next boot.

---

## 6. Validation (mandatory, local and CI)

```bash
python3 tools/validate.py --static --all                      # fast, no network
python3 tools/validate.py --full --require-arch <slug>.sh      # what CI runs on PRs
python3 tools/validate.py --no-boot <slug>.sh                  # where proot can't run (nested ptrace)
```

Steps: parse (same regexes as the app) → URL checks → download + SHA256 →
archive is a real rootfs → extract like the app → manifest paths exist inside
the rootfs, `NH_SHELL` ELF matches the arch → boot under PRoot with the app's
launcher, login shell must answer → (`--full`) bootstrap creates
`/.nh/bootstrap.done` and `NH_PKG`'s command exists.

It needs `proot` (and `qemu-user-static` on a non-aarch64 host; `-q` is added
automatically). CI (`.github/workflows/validate.yml`) runs on `ubuntu-24.04-arm`:

- **PR**: `--static --all`, then `--full --require-arch` on every added/changed
  root `*.sh`. The validator is taken from the **base branch**, so a PR cannot
  weaken it. PRs that touch `tools/` or `.github/` are never auto-merged.
- **Nightly**: all scripts (boot, no bootstrap). Failures open/update the issue
  labelled `broken-distro`.
- `auto-merge-prs.yml` merges a PR only after validation succeeded on its
  current head commit, otherwise it comments with the log link.

---

## 7. Agent prompt (daily maintenance)

```markdown
You maintain the distro plug-in scripts in zombiegirlcz/ROOTFS-for-proot.
Read AGENTS.md completely before doing anything. It is the contract with the app.

Every run, in this order:

1. REPAIR FIRST
   - Run `python3 tools/validate.py --all` (or `--no-boot --all` if proot cannot run
     in your sandbox) and read the open issue labelled `broken-distro`.
   - For every FAIL: fix it (usually a stale LXC build URL → resolve the newest
     build + its SHA256SUMS as in AGENTS.md §4). If a distro has no valid aarch64
     rootfs anymore, remove its `TARBALL_URL['aarch64']`/SHA lines (the app then
     hides it on phones) — never point the aarch64 key at another arch.
   - Put the repairs in their own PR.

2. ADD EXACTLY ONE NEW DISTRO (only if step 1 left nothing broken)
   - Pick a distro that is not in the repo yet and that has an official aarch64
     rootfs tarball meeting AGENTS.md §4. If you cannot find one in a reasonable
     time, pick a different distro. Do not invent URLs.
   - Download it yourself, compute SHA256, inspect it:
     `tar -tf <file> | head` (bin/ etc/ usr/ at the root?) and
     `file <extracted>/bin/sh` → must say "ARM aarch64" (or be a symlink to one).
   - Write `<slug>.sh` from the template in AGENTS.md §3. Slug = lowercase
     distro name, no version unless needed to distinguish releases.
   - Set the manifest from what you actually saw in the rootfs: `NH_SHELL`
     must exist there (`/bin/bash` only if bash is really in the tarball),
     correct `NH_PKG` and `NH_LIBC`.
   - Bootstrap per AGENTS.md §5: non-interactive, index refresh, no systemd.

3. VALIDATE — DEFINITION OF DONE
   - `python3 tools/validate.py --full --require-arch <slug>.sh` must print
     `PASS`. If proot cannot run in your environment, run at least
     `--no-boot --require-arch` and state that in the PR; CI will do the boot.
   - Fix and re-run until it passes. Never "fix" a failure by weakening the
     script's claims (e.g. deleting the manifest) or by editing tools/ or .github/.

4. OPEN THE PR
   - One distro per PR (repairs separate). Title: `Add <Name> <version> (aarch64)`
     or `Fix <slugs>: <what>`.
   - Paste the validator's final summary into the PR description.
   - Do not touch tools/, .github/ or AGENTS.md — those PRs are never auto-merged.
   - If CI comments "Validace neprošla", read the log, fix, push again.

Never:
- put a non-aarch64 URL under the 'aarch64' key;
- use ISO/QCOW2/IMG, `docker save`, OCI layouts, installer tarballs or zips;
- use URLs that do not end in .tar.xz/.txz/.tar.gz/.tgz/.tar.bz2/.tbz2/.tar;
- copy SHA256 values you did not compute from the downloaded file;
- run the bootstrap from the entrypoint, or use `--login` (use `-l`);
- use interactive commands (anything that can ask a question) in the bootstrap.
```
