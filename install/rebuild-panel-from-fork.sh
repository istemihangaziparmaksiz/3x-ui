#!/usr/bin/env bash
# Rebuild the 3x-ui panel binary from a git fork (embeds Vite web/dist) and restart systemd.
# Requires Debian/Ubuntu as root.
#
# IMPORTANT — memory: "npm ci" + "vite build" can use 2–4+ GB RAM. On small VPS (1 GB)
# the kernel OOM killer may stop sshd, nginx, or freeze the machine. This script:
#   - Refuses to build by default if free RAM is too low (unless you opt in).
#   - Can add temporary swap (X_UI_BUILD_AUTO_SWAP=1).
#   - Uses conservative Node / Go parallelism.
#
# Typical safe run on a 1–2 GB VPS:
#   X_UI_BUILD_AUTO_SWAP=1 curl -fsSL https://raw.githubusercontent.com/istemihangaziparmaksiz/3x-ui/main/install/rebuild-panel-from-fork.sh | bash
#
# Or build the binary on your PC (same arch) and copy only "x-ui" — no Node on server.
#
# Optional env: REPO_URL, BRANCH, XUI_DIR, GO_VER, X_UI_BUILD_AUTO_SWAP,
#   X_UI_SWAP_MB, X_UI_MIN_FREE_MB, X_UI_FORCE_LOW_MEM, NODE_OPTIONS

set -euo pipefail

[[ ${EUID:-99} -eq 0 ]] || {
  echo "Run as root (e.g. sudo bash)."
  exit 1
}

REPO_URL="${REPO_URL:-https://github.com/istemihangaziparmaksiz/3x-ui.git}"
BRANCH="${BRANCH:-main}"
XUI_DIR="${XUI_DIR:-/usr/local/x-ui}"
GO_VER="${GO_VER:-1.26.3}"
X_UI_SWAP_MB="${X_UI_SWAP_MB:-4096}"
X_UI_MIN_FREE_MB="${X_UI_MIN_FREE_MB:-1536}"
SWAP_FILE="${SWAP_FILE:-/var/tmp/x-ui-build.swap}"
X_UI_BUILD_AUTO_SWAP="${X_UI_BUILD_AUTO_SWAP:-0}"

if [[ -f /etc/os-release ]]; then
  # shellcheck source=/dev/null
  source /etc/os-release
else
  echo "Cannot detect OS."
  exit 1
fi

if [[ ! -x "${XUI_DIR}/x-ui" ]]; then
  echo "Panel binary not found at ${XUI_DIR}/x-ui — set XUI_DIR to your install directory."
  exit 1
fi

mem_avail_kb() {
  awk '/^MemAvailable:/ {print $2}' /proc/meminfo
}

mem_total_kb() {
  awk '/^MemTotal:/ {print $2}' /proc/meminfo
}

swap_free_kb() {
  awk '/^SwapFree:/ {print $2}' /proc/meminfo
}

combined_headroom_mb() {
  local a s
  a="$(mem_avail_kb)"
  s="$(swap_free_kb)"
  echo $(((a + s) / 1024))
}

BUILD_SWAP_ACTIVATED=0

deactivate_build_swap() {
  if [[ "${BUILD_SWAP_ACTIVATED}" -eq 1 ]] && [[ -f "${SWAP_FILE}" ]]; then
    echo "Disabling temporary build swap..."
    swapoff "${SWAP_FILE}" 2>/dev/null || true
    rm -f "${SWAP_FILE}" 2>/dev/null || true
    BUILD_SWAP_ACTIVATED=0
  fi
}

activate_build_swap() {
  local mb="$1"
  local bytes=$((mb * 1024 * 1024))
  if swapon --show 2>/dev/null | grep -q .; then
    echo "Swap already active; not creating ${SWAP_FILE}."
    return 0
  fi
  if [[ -f "${SWAP_FILE}" ]]; then
    echo "Removing stale swap file ${SWAP_FILE} ..."
    swapoff "${SWAP_FILE}" 2>/dev/null || true
    rm -f "${SWAP_FILE}"
  fi
  echo "Creating temporary swap ${mb} MiB at ${SWAP_FILE} (slow on small disks) ..."
  mkdir -p "$(dirname "${SWAP_FILE}")"
  if command -v fallocate >/dev/null 2>&1; then
    fallocate -l "${bytes}" "${SWAP_FILE}" || dd if=/dev/zero of="${SWAP_FILE}" bs=1M count="${mb}" status=none
  else
    dd if=/dev/zero of="${SWAP_FILE}" bs=1M count="${mb}" status=none
  fi
  chmod 600 "${SWAP_FILE}"
  mkswap "${SWAP_FILE}" >/dev/null
  swapon "${SWAP_FILE}"
  BUILD_SWAP_ACTIVATED=1
  echo "Temporary swap enabled."
}

preflight_memory() {
  local avail_kb total_kb avail_mb total_mb headroom_mb
  avail_kb="$(mem_avail_kb)"
  total_kb="$(mem_total_kb)"
  avail_mb=$((avail_kb / 1024))
  total_mb=$((total_kb / 1024))
  headroom_mb="$(combined_headroom_mb)"
  echo "Memory: MemAvailable≈${avail_mb} MiB, MemTotal≈${total_mb} MiB, MemAvail+SwapFree≈${headroom_mb} MiB"

  if [[ "${avail_mb}" -ge "${X_UI_MIN_FREE_MB}" ]]; then
    return 0
  fi

  if [[ "${X_UI_BUILD_AUTO_SWAP}" == "1" ]]; then
    echo "Low MemAvailable (${avail_mb} MiB < ${X_UI_MIN_FREE_MB} MiB). Auto swap requested."
    activate_build_swap "${X_UI_SWAP_MB}"
    headroom_mb="$(combined_headroom_mb)"
    avail_kb="$(mem_avail_kb)"
    avail_mb=$((avail_kb / 1024))
    echo "After swap: MemAvailable≈${avail_mb} MiB, MemAvail+SwapFree≈${headroom_mb} MiB"
  fi

  headroom_mb="$(combined_headroom_mb)"
  if [[ "${headroom_mb}" -lt "${X_UI_MIN_FREE_MB}" ]] && [[ "${X_UI_FORCE_LOW_MEM:-0}" != "1" ]]; then
    echo ""
    echo "Refusing to run npm/vite: MemAvail+SwapFree≈${headroom_mb} MiB < ${X_UI_MIN_FREE_MB} MiB."
    echo "Options:"
    echo "  1) Re-run with:  X_UI_BUILD_AUTO_SWAP=1  (adds ~${X_UI_SWAP_MB} MiB temporary swap)"
    echo "  2) Add permanent swap in provider panel, reboot, then re-run."
    echo "  3) Build on a PC (same CPU arch), copy only the 'x-ui' binary to ${XUI_DIR}/x-ui"
    echo "  4) Last resort (may still OOM): X_UI_FORCE_LOW_MEM=1"
    echo ""
    deactivate_build_swap
    exit 1
  fi
  if [[ "${headroom_mb}" -lt "${X_UI_MIN_FREE_MB}" ]]; then
    echo "WARNING: X_UI_FORCE_LOW_MEM=1 — build may OOM and kill SSH. Continuing..."
  fi
}

case "$(uname -m)" in
  x86_64 | amd64) GO_ARCH=amd64 ;;
  aarch64 | arm64) GO_ARCH=arm64 ;;
  *)
    echo "Unsupported CPU: $(uname -m)"
    exit 1
    ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git curl ca-certificates build-essential sqlite3 libsqlite3-dev xz-utils

install_go() {
  echo "Installing Go ${GO_VER} to /usr/local/go ..."
  rm -rf /usr/local/go
  curl -fL "https://go.dev/dl/go${GO_VER}.linux-${GO_ARCH}.tar.gz" | tar -C /usr/local -xzf -
}

export PATH="/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
gv=""
if command -v go >/dev/null 2>&1; then
  gv=$(go version 2>/dev/null | awk '{print $3}' | sed 's/^go//')
fi
if [[ -z "${gv}" ]] || [[ "$(printf '%s\n' "${GO_VER}" "${gv}" | sort -V | head -n1)" != "${GO_VER}" ]]; then
  install_go
fi

if [[ "${ID:-}" == "ubuntu" || "${ID:-}" == "debian" ]]; then
  if ! command -v node >/dev/null 2>&1 || [[ "$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)" -lt 22 ]]; then
    echo "Installing Node.js 22.x (NodeSource) ..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y -qq nodejs
  fi
else
  if ! command -v node >/dev/null 2>&1; then
    echo "Please install Node.js >= 22 and npm, then re-run this script."
    exit 1
  fi
fi

preflight_memory

if systemctl is-active --quiet x-ui 2>/dev/null; then
  echo "Stopping x-ui before clone/build to free RAM ..."
  systemctl stop x-ui
fi

WORKDIR="$(mktemp -d)"
cleanup() {
  deactivate_build_swap
  rm -rf "${WORKDIR}"
}
trap cleanup EXIT

echo "Cloning ${REPO_URL} (${BRANCH}) ..."
git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${WORKDIR}/src"

# Conservative Node / npm (reduces peak RAM a bit; build is slower)
export npm_config_maxsockets="${npm_config_maxsockets:-2}"
export npm_config_jobs="${npm_config_jobs:-1}"
export UV_THREADPOOL_SIZE="${UV_THREADPOOL_SIZE:-2}"
# Heap cap for Vite / Rollup (MiB). Lower if still OOM; raise slightly if build fails with OOM in JS.
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=768}"

cd "${WORKDIR}/src/frontend"
echo "npm ci (low parallelism) ..."
npm ci --no-audit --no-fund
sync
echo "vite build ..."
npx vite build
sync

cd "${WORKDIR}/src"
export CGO_ENABLED=1
export GOMAXPROCS="${GOMAXPROCS:-1}"
echo "go build (GOMAXPROCS=${GOMAXPROCS}) ..."
go build -p 1 -trimpath -ldflags="-s -w" -o "${WORKDIR}/x-ui-new" .

bak="${XUI_DIR}/x-ui.bak.$(date +%s)"
cp -a "${XUI_DIR}/x-ui" "${bak}"
echo "Backup saved: ${bak}"

install -m 0755 "${WORKDIR}/x-ui-new" "${XUI_DIR}/x-ui"

echo "Starting x-ui ..."
systemctl start x-ui
echo "Done. Hard-refresh the browser (Ctrl+F5)."
