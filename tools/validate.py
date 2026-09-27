#!/usr/bin/env python3
"""
Validátor distro plug-in skriptů pro NetHunter app (com.linux_core).

Dělá PŘESNĚ to, co appka, a navíc rootfs opravdu nabootuje:

  1. parse   — stejné regexy jako RemoteRootfsCatalog.kt (DISTRO_NAME,
               TARBALL_URL['arch'], TARBALL_SHA256['arch'], heredocy
               bootstrap.sh / root/entrypoint.sh / .nh/manifest)
  2. url     — přípona, kterou appka umí rozbalit; URL odpovídá architektuře
  3. fetch   — stažení + SHA256
  4. archive — je to opravdu rootfs (ne ISO, `docker save`, OCI, installer,
               zabalený v jednom adresáři)
  5. extract — rozbalení bez --strip-components (appka nestripuje) + zápis
               heredoců tak, jak je zapisuje appka
  6. manifest— povinné klíče, cesty existují UVNITŘ rootfs (symlinky se
               vyhodnocují jako v guestu), ELF shellu je pro danou architekturu
  7. boot    — proot + stejný spouštěcí wrapper jako `boot` v appce;
               login shell musí odpovědět
  8. bootstrap (--full) — /.nh/bootstrap.done vznikne, správce balíčků běží

Použití:
  tools/validate.py alpine.sh                 # 1–7
  tools/validate.py --full alpine.sh          # 1–8 (síť, trvá minuty)
  tools/validate.py --all                     # všechny *.sh v kořeni repa
  tools/validate.py --static alpine.sh        # jen 1–2 (bez sítě)
  tools/validate.py --urls-only --all         # dostupnost VŠECH URL všech arch (rychlé)
  tools/validate.py --urls --all              # URL všech arch + stažení + boot aarch64

Závislosti: python3, tar, xz, bzip2, gzip, proot (+ qemu-user-static, pokud
host není aarch64). Exit 0 = vše prošlo, 1 = aspoň jedno FAIL.
"""

import argparse
import hashlib
import os
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.environ.get("VALIDATE_CACHE", os.path.expanduser("~/.cache/rootfs-validate"))

# Architektury, které appka zná (RemoteRootfsCatalog.detectCurrentArch).
ARCHES = ("aarch64", "arm", "x86_64", "x86")
# Slova v URL, která prozrazují JINOU architekturu, než je klíč.
ARCH_ALIASES = {
    "aarch64": ("aarch64", "arm64"),
    "arm": ("armhf", "armv7", "armv7l", "armel", "arm32"),
    "x86_64": ("x86_64", "amd64", "x86-64"),
    "x86": ("i386", "i686", "x86"),
}
ELF_MACHINE = {"aarch64": 183, "arm": 40, "x86_64": 62, "x86": 3}
REQUIRE_ARCH = False
QEMU = {"aarch64": "qemu-aarch64-static", "arm": "qemu-arm-static",
        "x86_64": "qemu-x86_64-static", "x86": "qemu-i386-static"}

MANIFEST_KEYS = {
    "NH_SHELL", "NH_ENTRYPOINT", "NH_BOOTSTRAP", "NH_PATH", "NH_WORKDIR",
    "NH_ENV", "NH_BIND", "NH_PKG", "NH_LIBC", "NH_INTEGRATION",
}
MANIFEST_REQUIRED = ("NH_SHELL", "NH_PKG", "NH_LIBC")
MANIFEST_REPEATABLE = ("NH_ENV", "NH_BIND")
PKG_CMD = {
    "apt": "apt-get", "apk": "apk", "dnf": "dnf", "yum": "yum", "microdnf": "microdnf",
    "tdnf": "tdnf", "pacman": "pacman", "xbps": "xbps-install", "zypper": "zypper",
    "emerge": "emerge", "opkg": "opkg", "urpmi": "urpmi", "slackpkg": "slackpkg",
    "swupd": "swupd", "eopkg": "eopkg", "nix": "nix-env", "guix": "guix",
    "kiss": "kiss", "scratchpkg": "scratch", "pkgtool": "installpkg", "none": None,
}

# Stejná heuristika jako `boot` (guest_env) — env -i + explicitní seznam.
GUEST_BASE_ENV = {
    "HOME": "/root", "USER": "root", "LOGNAME": "root", "TERM": "xterm-256color",
    "LANG": "C.UTF-8", "LC_CTYPE": "C.UTF-8",
}
DEFAULT_PATH = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Totožný s _launch v app boot_docker (jen značka bootstrapu na stejném místě).
LAUNCH = (
    'unset LD_PRELOAD PROOT_LOADER PROOT_TMP_DIR LD_LIBRARY_PATH; export PATH="$1"; '
    'cd "$2" 2>/dev/null || cd /; b="$3"; shift 3; '
    'if [ -n "$b" ] && [ -f "$b" ] && [ ! -f /.nh/bootstrap.done ]; then '
    'echo "[*] První start: $b"; if "$0" "$b"; then mkdir -p /.nh && : > /.nh/bootstrap.done; '
    'else echo "[!] $b selhal" >&2; fi; fi; exec "$@"'
)


class Report:
    def __init__(self, name):
        self.name = name
        self.fails = []
        self.warns = []
        self.skipped = None

    def ok(self, msg):
        print(f"  [PASS] {msg}")

    def fail(self, msg):
        self.fails.append(msg)
        print(f"  [FAIL] {msg}")

    def warn(self, msg):
        self.warns.append(msg)
        print(f"  [WARN] {msg}")

    def info(self, msg):
        print(f"         {msg}")


# ─── 1. parse (zrcadlí RemoteRootfsCatalog.kt) ─────────────────────────────

def bash_var(script, name):
    m = re.search(r'^\s*' + name + r'\s*=\s*"([^"]*)"', script, re.M)
    return m.group(1) if m else None


def tarball_map(script, name):
    return {m.group(1): m.group(2) for m in
            re.finditer(r"^\s*" + name + r"\['([^']+)'\]\s*=\s*\"([^\"]*)\"", script, re.M)}


def heredoc(script, target):
    pat = r"cat <<'([A-Z_]+)' > \"\$DISTRO_ROOTFS/" + re.escape(target) + r"\"[^\n]*\n(.*?)\n\1"
    m = re.search(pat, script, re.S)
    return m.group(2).strip() if m else ""


def parse_manifest(text, rep):
    single, multi = {}, {k: [] for k in MANIFEST_REPEATABLE}
    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            rep.fail(f"manifest řádek {n}: chybí '=': {raw!r}")
            continue
        k, v = line.split("=", 1)
        k = k.strip()
        v = v.strip()
        if len(v) >= 2 and v[0] == v[-1] == '"':
            v = v[1:-1]
        if k not in MANIFEST_KEYS:
            rep.fail(f"manifest: neznámý klíč {k}")
            continue
        if k in MANIFEST_REPEATABLE:
            multi[k].append(v)
        elif k in single:
            rep.fail(f"manifest: {k} je uvedený vícekrát")
        else:
            single[k] = v
    return single, multi


def check_static(path, arch, rep):
    script = open(path, encoding="utf-8", errors="replace").read()
    if subprocess.run(["bash", "-n", path], capture_output=True).returncode != 0:
        rep.fail("bash -n: syntaktická chyba ve skriptu")
    for var in ("DISTRO_NAME", "DISTRO_COMMENT"):
        if bash_var(script, var) is None:
            rep.fail(f'{var}="..." chybí (appka čte jen tvar s dvojitými uvozovkami)')
    urls = tarball_map(script, "TARBALL_URL")
    shas = tarball_map(script, "TARBALL_SHA256")
    for key in urls:
        if key not in ARCHES:
            rep.warn(f"TARBALL_URL['{key}']: appka tuhle architekturu nezná (jen {', '.join(ARCHES)})")
    if arch not in urls:
        if REQUIRE_ARCH:
            rep.fail(f"TARBALL_URL['{arch}'] chybí — nový skript musí podporovat {arch}")
        else:
            rep.skipped = f"nemá TARBALL_URL['{arch}'] (na {arch} se v appce nezobrazí)"
            print(f"  [SKIP] {rep.skipped}")
    else:
        rep.ok(f"TARBALL_URL['{arch}'] = {urls[arch]}")
    for key, url in urls.items():
        low = url.lower()
        if not low.startswith("https://"):
            rep.fail(f"TARBALL_URL['{key}'] není https")
        for other, words in ARCH_ALIASES.items():
            if other == key or other == "x86" and key == "x86_64":
                continue
            own = ARCH_ALIASES.get(key, ())
            hit = [w for w in words if re.search(r"(?<![a-z0-9])" + re.escape(w) + r"(?![a-z0-9])", low)]
            if hit and not any(re.search(r"(?<![a-z0-9])" + re.escape(w) + r"(?![a-z0-9])", low) for w in own):
                rep.fail(f"TARBALL_URL['{key}'] vypadá jako {other} build ({hit[0]}): {url}")
        fmt = tar_format(url)
        if fmt is None:
            rep.fail(f"TARBALL_URL['{key}']: přípona, kterou appka neumí "
                     "(jen .tar.xz .txz .tar.gz .tgz .tar.bz2 .tbz2 .tar na KONCI URL)")
        sha = shas.get(key, "")
        if not re.fullmatch(r"[0-9a-f]{64}", sha):
            rep.fail(f"TARBALL_SHA256['{key}'] chybí nebo není 64 hex znaků")
    for target in ("bootstrap.sh", "root/entrypoint.sh", ".nh/manifest"):
        if not heredoc(script, target):
            rep.fail(f"heredoc pro {target} chybí nebo nemá tvar: cat <<'MARK' > \"$DISTRO_ROOTFS/{target}\"")
    man_text = heredoc(script, ".nh/manifest")
    single, multi = parse_manifest(man_text, rep) if man_text else ({}, {})
    if man_text:
        for k in MANIFEST_REQUIRED:
            if not single.get(k):
                rep.fail(f"manifest: povinný klíč {k} chybí")
        for k in ("NH_SHELL", "NH_ENTRYPOINT", "NH_BOOTSTRAP", "NH_WORKDIR"):
            if single.get(k) and not single[k].startswith("/"):
                rep.fail(f"manifest: {k} musí být absolutní guest cesta")
        pkg = single.get("NH_PKG")
        if pkg and pkg not in PKG_CMD:
            rep.fail(f"manifest: NH_PKG={pkg} neznámý (povolené: {', '.join(PKG_CMD)})")
        if single.get("NH_LIBC") and single["NH_LIBC"] not in ("glibc", "musl", "other"):
            rep.fail("manifest: NH_LIBC musí být glibc|musl|other")
        if single.get("NH_INTEGRATION", "minimal") not in ("minimal", "full"):
            rep.fail("manifest: NH_INTEGRATION musí být minimal|full")
        for v in multi["NH_ENV"]:
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=\S*", v):
                rep.fail(f"manifest: NH_ENV={v} (tvar KEY=VALUE bez mezer)")
        for v in multi["NH_BIND"]:
            if not v.startswith("/") or " " in v:
                rep.fail(f"manifest: NH_BIND={v} (absolutní host cesta, bez mezer)")
        if single.get("NH_BOOTSTRAP") and not heredoc(script, single["NH_BOOTSTRAP"].lstrip("/")):
            rep.warn(f"NH_BOOTSTRAP={single['NH_BOOTSTRAP']} nevytváří heredoc skriptu — musí být přímo v archivu")
    entry = heredoc(script, "root/entrypoint.sh")
    if re.search(r"bootstrap\.sh", entry):
        rep.fail("root/entrypoint.sh nesmí spouštět bootstrap — to dělá boot podle NH_BOOTSTRAP")
    if re.search(r"--login\b", entry):
        rep.fail("root/entrypoint.sh: použij `-l`, ne `--login` (busybox/dash --login neznají)")
    return script, urls, shas, single, multi


def tar_format(url):
    low = url.lower().split("?")[0].split("#")[0]
    for ext, fmt in ((".tar.xz", "xz"), (".txz", "xz"), (".tar.bz2", "bz2"), (".tbz2", "bz2"),
                     (".tar.gz", "gz"), (".tgz", "gz"), (".tar", "")):
        if low.endswith(ext):
            return fmt
    # Appka určuje formát z CELÉ URL (i s query) — musí končit příponou.
    return None


# ─── 2b. dostupnost všech URL (všechny architektury) ─────────────────────

def check_url_alive(url):
    """Vrátí (ok, popis). HEAD, při odmítnutí GET s Range 0-0 (nic se nestahuje)."""
    last = ""
    for method, headers in (("HEAD", {}), ("GET", {"Range": "bytes=0-0"})):
        req = urllib.request.Request(url, method=method,
                                     headers={"User-Agent": "rootfs-validate/1", **headers})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                size = r.headers.get("Content-Length") if method == "HEAD" else \
                    (r.headers.get("Content-Range") or "").rpartition("/")[2]
                ctype = r.headers.get("Content-Type", "")
                if "text/html" in ctype:
                    return False, f"HTTP {r.status}, ale vrací HTML stránku (ne tarball)"
                return True, f"HTTP {r.status}" + (f", {int(size) // (1 << 20)} MB" if size and size.isdigit() else "")
        except urllib.error.HTTPError as e:
            last = f"HTTP {e.code}"
            if e.code not in (403, 405, 501):
                break
        except Exception as e:  # noqa: BLE001
            last = str(e)
            break
    return False, last


def check_all_urls(urls, rep):
    for key, url in sorted(urls.items()):
        ok, why = check_url_alive(url)
        if ok:
            rep.ok(f"URL ['{key}'] žije ({why})")
        else:
            rep.fail(f"URL ['{key}'] nedostupná ({why}): {url}")


# ─── 3. fetch ──────────────────────────────────────────────────────────────

def fetch(url, sha, rep):
    os.makedirs(CACHE, exist_ok=True)
    dest = os.path.join(CACHE, (sha or hashlib.sha256(url.encode()).hexdigest()) + ".tarball")
    if os.path.exists(dest) and sha and sha256(dest) == sha:
        rep.ok("tarball z cache, SHA256 sedí")
        return dest
    tmp = dest + ".part"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "rootfs-validate/1"})
        with urllib.request.urlopen(req, timeout=60) as r, open(tmp, "wb") as f:
            shutil.copyfileobj(r, f, 1 << 20)
    except Exception as e:  # noqa: BLE001
        rep.fail(f"stažení selhalo: {e}")
        return None
    got = sha256(tmp)
    if sha and got != sha:
        rep.fail(f"SHA256 nesedí: očekáváno {sha}, staženo {got}")
        os.remove(tmp)
        return None
    os.replace(tmp, dest)
    rep.ok(f"staženo {os.path.getsize(dest) // (1 << 20)} MB, SHA256 sedí")
    return dest


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# ─── 4. archive ────────────────────────────────────────────────────────────

def check_archive(path, fmt, rep):
    with open(path, "rb") as f:
        head = f.read(0x8006)
    if len(head) > 0x8005 and head[0x8001:0x8006] == b"CD001":
        rep.fail("archiv je ISO obraz, ne rootfs tarball")
        return False
    if head[:4] == b"PK\x03\x04":
        rep.fail("archiv je ZIP — appka umí jen tar (+xz/gz/bz2)")
        return False
    try:
        with tarfile.open(path, "r:" + fmt if fmt else "r:") as tf:
            names = []
            for m in tf:
                n = m.name
                while n.startswith("./"):
                    n = n[2:]
                n = n.lstrip("/")
                if n:
                    names.append(n)
    except Exception as e:  # noqa: BLE001
        rep.fail(f"nejde přečíst jako tar ({fmt or 'plain'}): {e}")
        return False
    top = {n.split("/", 1)[0] for n in names}
    if "manifest.json" in top and any(n.endswith("layer.tar") for n in names):
        rep.fail("archiv je `docker save` (manifest.json + layer.tar), ne rootfs — vezmi rootfs vrstvu/jiný zdroj")
        return False
    if "oci-layout" in top or "index.json" in top and "blobs" in top:
        rep.fail("archiv je OCI image layout, ne rootfs")
        return False
    if "etc" not in top or not ({"bin", "usr"} & top):
        if len(top) == 1:
            rep.fail(f"rootfs je zabalený v adresáři '{next(iter(top))}/' — appka nestripuje, "
                     "vyber tarball s bin/ etc/ usr/ přímo v kořeni")
        else:
            rep.fail(f"v kořeni archivu chybí etc/ a bin|usr/ — není to rootfs (kořen: {sorted(top)[:12]})")
        return False
    rep.ok(f"archiv je rootfs ({len(names)} položek)")
    return True


# ─── 5. extract (jako appka) ───────────────────────────────────────────────

def extract(path, fmt, rootfs, script, rep):
    flag = {"xz": "-J", "gz": "-z", "bz2": "-j", "": ""}[fmt]
    cmd = ["tar", "-x", "--no-same-owner", "-f", path, "-C", rootfs]
    if flag:
        cmd.insert(1, flag)
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        # Zařízení/mknod v archivu jako ne-root selžou; appka je stejně přeskočí.
        errs = [ln for ln in r.stderr.splitlines() if "Cannot mknod" not in ln
                and "Exiting with failure" not in ln]
        if errs:
            rep.fail("tar selhal: " + " | ".join(errs[:3]))
            return False
    subprocess.run(["chmod", "-R", "u+rwX", rootfs], capture_output=True)
    # Heredocy zapisuje appka (RootfsManager.pullRemoteDistroScript), skript se NESPOUŠTÍ.
    for target, mode in (("bootstrap.sh", 0o755), ("root/entrypoint.sh", 0o755), (".nh/manifest", 0o644)):
        body = heredoc(script, target)
        if not body:
            continue
        dst = os.path.join(rootfs, target)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.lexists(dst) and not os.path.isdir(dst):
            os.remove(dst)
        with open(dst, "w", encoding="utf-8") as f:
            f.write(body + ("\n" if target == ".nh/manifest" else ""))
        os.chmod(dst, mode)
    # ProotManager.updateResolvConf (symlink nahradí souborem).
    rc = os.path.join(rootfs, "etc/resolv.conf")
    if os.path.islink(rc):
        os.remove(rc)
    os.makedirs(os.path.dirname(rc), exist_ok=True)
    with open(rc, "w") as f:
        f.write("nameserver 1.1.1.1\nnameserver 8.8.8.8\n")
    for d in ("dev", "proc", "sys", "tmp", "root"):
        p = os.path.join(rootfs, d)
        if not os.path.lexists(p):
            os.makedirs(p, exist_ok=True)
    rep.ok("rozbaleno + heredocy zapsané jako v appce")
    return True


# ─── 6. manifest proti rootfs ──────────────────────────────────────────────

def resolve(rootfs, guest_path):
    """Guest cesta → výsledná guest cesta po symlinkách uvnitř rootfs (jako boot)."""
    rest = [c for c in guest_path.strip("/").split("/") if c]
    cur, hops = [], 0
    while rest:
        c = rest.pop(0)
        if c in ("", "."):
            continue
        if c == "..":
            if cur:
                cur.pop()
            continue
        host = os.path.join(rootfs, *cur, c)
        if os.path.islink(host):
            hops += 1
            if hops > 40:
                return None
            t = os.readlink(host)
            if t.startswith("/"):
                cur = []
            rest = [x for x in t.split("/") if x] + rest
        else:
            cur.append(c)
    final = os.path.join(rootfs, *cur)
    return "/" + "/".join(cur) if os.path.lexists(final) else None


def elf_machine(path):
    try:
        with open(path, "rb") as f:
            h = f.read(20)
    except OSError:
        return None
    if h[:4] != b"\x7fELF":
        return None
    return int.from_bytes(h[18:20], "little" if h[5] == 1 else "big")


def shebang_interp(path):
    try:
        with open(path, "rb") as f:
            first = f.readline(256)
    except OSError:
        return None
    if first.startswith(b"#!"):
        return first[2:].decode(errors="replace").strip().split()[0]
    return None


def check_manifest_in_rootfs(rootfs, single, arch, rep):
    ok = True
    sh = single.get("NH_SHELL")
    res = resolve(rootfs, sh) if sh else None
    if not res or not os.path.isfile(rootfs + res) or not os.access(rootfs + res, os.X_OK):
        rep.fail(f"NH_SHELL={sh} v rootfs neexistuje nebo není spustitelný")
        ok = False
    else:
        mach = elf_machine(rootfs + res)
        if mach is not None and mach != ELF_MACHINE[arch]:
            rep.fail(f"NH_SHELL {sh} -> {res} je ELF pro jinou architekturu (e_machine={mach}), ne {arch}")
            ok = False
        else:
            rep.ok(f"NH_SHELL {sh} -> {res}")
    for key in ("NH_ENTRYPOINT", "NH_BOOTSTRAP"):
        p = single.get(key)
        if not p:
            continue
        r = resolve(rootfs, p)
        if not r:
            rep.fail(f"{key}={p} v rootfs neexistuje")
            ok = False
            continue
        if key == "NH_ENTRYPOINT":
            if not os.access(rootfs + r, os.X_OK):
                rep.fail(f"{key}={p} není spustitelný")
                ok = False
            interp = shebang_interp(rootfs + r)
            if interp and not resolve(rootfs, interp):
                rep.fail(f"{key}={p}: interpret ze shebangu {interp} v rootfs chybí")
                ok = False
        rep.ok(f"{key} {p} existuje")
    if single.get("NH_WORKDIR") and not resolve(rootfs, single["NH_WORKDIR"]):
        rep.warn(f"NH_WORKDIR={single['NH_WORKDIR']} neexistuje, boot použije /")
    return ok


# ─── 7./8. boot pod proot ──────────────────────────────────────────────────

def proot_base(rootfs, arch, workdir):
    proot = shutil.which("proot")
    if not proot:
        return None
    # Upstream proot (Debian/Ubuntu 5.1.0) nezná --kill-on-exit ani --link2symlink
    # (Termux fork ano). Na běžném Linuxu hardlinky fungují, takže je nepotřebujeme.
    helptext = subprocess.run([proot, "--help"], capture_output=True, text=True).stdout
    cmd = [proot, "-0", "-r", rootfs, "-b", "/dev", "-b", "/proc", "-b", "/sys", "-w", workdir]
    for opt in ("--kill-on-exit", "--link2symlink"):
        if opt in helptext:
            cmd.insert(1, opt)
    # Samotest: proot uvnitř proot/ptrace sandboxu (např. na telefonu) neběží.
    if subprocess.run([proot, "-r", "/", "/bin/true"], capture_output=True).returncode != 0:
        return "broken"
    host = platform.machine().lower()
    native = {"aarch64": ("aarch64", "arm64"), "x86_64": ("x86_64", "amd64"),
              "arm": ("armv7l", "armv8l"), "x86": ("i686", "i386")}[arch]
    if host not in native:
        q = shutil.which(QEMU[arch])
        if not q:
            return "noqemu"
        cmd[1:1] = ["-q", q]
    return cmd


def run_boot(rootfs, single, multi, arch, with_bootstrap, rep, timeout):
    workdir = single.get("NH_WORKDIR", "/root")
    if not resolve(rootfs, workdir):
        workdir = "/"
    base = proot_base(rootfs, arch, workdir)
    if base is None:
        rep.fail("proot není nainstalovaný — boot test nejde udělat (apt install proot)")
        return
    if base == "broken":
        rep.fail("proot na tomto hostu nefunguje (vnořený ptrace?) — pusť validaci s --no-boot "
                 "a boot test nech na CI, nebo spusť na normálním Linuxu")
        return
    if base == "noqemu":
        rep.fail(f"host není {arch} a chybí {QEMU[arch]} (apt install qemu-user-static)")
        return
    env = dict(GUEST_BASE_ENV)
    env["PATH"] = single.get("NH_PATH", DEFAULT_PATH)
    for kv in multi.get("NH_ENV", []):
        k, v = kv.split("=", 1)
        env[k] = v
    binds = []
    for b in multi.get("NH_BIND", []):
        if os.path.exists(b.split(":", 1)[0]):
            binds += ["-b", b]
    sh = single["NH_SHELL"]
    boot = single.get("NH_BOOTSTRAP", "") if with_bootstrap else ""
    tail = [single["NH_ENTRYPOINT"]] if single.get("NH_ENTRYPOINT") else [sh, "-l"]

    # 8. bootstrap zvlášť (stdin /dev/null — na zařízení nesmí čekat na vstup).
    if boot:
        rep.info(f"bootstrap: {boot} (limit {timeout} s)")
        cmd = base + binds + [sh, "-c", LAUNCH, sh, env["PATH"], workdir, boot, "true"]
        try:
            r = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                               timeout=timeout, env=env)
            out = r.stdout + r.stderr
        except subprocess.TimeoutExpired:
            out = ""
            rep.fail(f"bootstrap visel déle než {timeout} s (čeká na vstup? chybí -y / noninteractive?)")
        if os.path.exists(os.path.join(rootfs, ".nh/bootstrap.done")):
            rep.ok("bootstrap doběhl (/.nh/bootstrap.done)")
        else:
            if out:
                rep.fail("bootstrap selhal (/.nh/bootstrap.done nevznikl); konec výstupu:")
            for ln in out.strip().splitlines()[-25:]:
                rep.info("| " + ln)
            return

    # 7. login shell / entrypoint musí odpovědět na příkazy ze stdin.
    cmd = base + binds + [sh, "-c", LAUNCH, sh, env["PATH"], workdir, ""] + tail
    probe = "echo NH_SHELL_OK; echo NH_UID=$(id -u 2>/dev/null); exit 0\n"
    rep.info("boot: " + " ".join(tail))
    try:
        r = subprocess.run(cmd, input=probe, capture_output=True, text=True, timeout=180, env=env)
    except subprocess.TimeoutExpired:
        rep.fail("boot visel déle než 180 s (entrypoint čeká na něco jiného než shell?)")
        return
    out = r.stdout + r.stderr
    if "NH_SHELL_OK" in r.stdout:
        rep.ok("login shell odpověděl (NH_SHELL_OK)")
    else:
        rep.fail(f"login shell neodpověděl (exit {r.returncode}); konec výstupu:")
        for ln in out.strip().splitlines()[-15:]:
            rep.info("| " + ln)
        return
    if boot:
        pkg = PKG_CMD.get(single.get("NH_PKG", ""))
        if pkg:
            chk = base + [sh, "-c", f'export PATH="{env["PATH"]}"; command -v {pkg} && echo NH_PKG_OK']
            r2 = subprocess.run(chk, capture_output=True, text=True, timeout=120, env=env)
            if "NH_PKG_OK" in r2.stdout:
                rep.ok(f"správce balíčků {pkg} je k dispozici")
            else:
                rep.fail(f"NH_PKG={single.get('NH_PKG')}: příkaz {pkg} v guestu chybí")


# ─── main ──────────────────────────────────────────────────────────────────

def validate(path, args):
    rep = Report(os.path.basename(path))
    print(f"\n=== {rep.name} ({args.arch}) ===")
    script, urls, shas, single, multi = check_static(path, args.arch, rep)
    if args.urls and not args.static:
        check_all_urls(urls, rep)
    if args.static or args.urls_only or rep.fails or args.arch not in urls:
        return rep
    url, sha = urls[args.arch], shas.get(args.arch, "")
    tarball = fetch(url, sha, rep)
    if not tarball:
        return rep
    fmt = tar_format(url)
    if not check_archive(tarball, fmt, rep):
        return rep
    work = tempfile.mkdtemp(prefix="rootfs-validate-")
    rootfs = os.path.join(work, "rootfs")
    os.makedirs(rootfs)
    try:
        if not extract(tarball, fmt, rootfs, script, rep):
            return rep
        if not check_manifest_in_rootfs(rootfs, single, args.arch, rep):
            return rep
        if not args.no_boot:
            run_boot(rootfs, single, multi, args.arch, args.full, rep, args.timeout)
    finally:
        if args.keep:
            print(f"         rootfs ponechán: {rootfs}")
        else:
            subprocess.run(["chmod", "-R", "u+rwX", work], capture_output=True)
            shutil.rmtree(work, ignore_errors=True)
    return rep


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("scripts", nargs="*")
    ap.add_argument("--all", action="store_true", help="všechny *.sh v kořeni repa")
    ap.add_argument("--arch", default="aarch64", choices=ARCHES)
    ap.add_argument("--static", action="store_true", help="jen parse + URL kontroly, bez sítě")
    ap.add_argument("--no-boot", action="store_true", help="bez proot boot testu")
    ap.add_argument("--full", action="store_true", help="i bootstrap (síť, minuty)")
    ap.add_argument("--timeout", type=int, default=1800, help="limit pro --full boot (s)")
    ap.add_argument("--keep", action="store_true", help="nemazat rozbalený rootfs")
    ap.add_argument("--urls", action="store_true",
                    help="ověřit dostupnost VŠECH TARBALL_URL (všechny architektury), bez stahování")
    ap.add_argument("--urls-only", action="store_true",
                    help="jen parse + --urls, bez stažení a bootu (rychlá kontrola všech URL)")
    ap.add_argument("--require-arch", action="store_true",
                    help="chybějící URL pro --arch je FAIL (pro nové/změněné skripty v PR)")
    args = ap.parse_args()
    if args.urls_only:
        args.urls = True
    global REQUIRE_ARCH
    REQUIRE_ARCH = args.require_arch
    scripts = list(args.scripts)
    if args.all:
        scripts += sorted(os.path.join(REPO, f) for f in os.listdir(REPO) if f.endswith(".sh"))
    if not scripts:
        ap.error("zadej skript(y) nebo --all")
    reports = [validate(s, args) for s in scripts]
    print("\n=== Souhrn ===")
    bad = 0
    for r in reports:
        state = "FAIL" if r.fails else "SKIP" if r.skipped else "PASS"
        bad += bool(r.fails)
        print(f"  {state}  {r.name}" + (f" — {r.fails[0]}" if r.fails else f" — {r.skipped}" if r.skipped else "")
              + (f" ({len(r.warns)} varování)" if r.warns else ""))
    print(f"\n{len(reports) - bad}/{len(reports)} bez chyby ({sum(1 for r in reports if r.skipped and not r.fails)} přeskočeno)")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
