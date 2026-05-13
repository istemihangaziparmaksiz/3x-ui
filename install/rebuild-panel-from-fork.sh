#!/usr/bin/env bash
# Rebuild the 3x-ui panel binary from a git fork (embeds Vite web/dist) and restart systemd.
# Use this when you installed via install.sh (upstream release tarball) and need custom UI/routes
# such as DarkSSH. Requires Debian/Ubuntu as root.
#
#   curl -fsSL https://raw.githubusercontent.com/istemihangaziparmaksiz/3x-ui/main/install/rebuild-panel-from-fork.sh | sudo bash
#
# Optional env: REPO_URL, BRANCH, XUI_DIR, GO_VER

set -euo pipefail

[[ ${EUID:-99} -eq 0 ]] || {
  echo "Run as root (e.g. sudo bash)."
  exit 1
}

REPO_URL="${REPO_URL:-https://github.com/istemihangaziparmaksiz/3x-ui.git}"
BRANCH="${BRANCH:-main}"
XUI_DIR="${XUI_DIR:-/usr/local/x-ui}"
GO_VER="${GO_VER:-1.26.3}"

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

WORKDIR="$(mktemp -d)"
cleanup() {
  rm -rf "${WORKDIR}"
}
trap cleanup EXIT

echo "Cloning ${REPO_URL} (${BRANCH}) ..."
git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${WORKDIR}/src"

cd "${WORKDIR}/src/frontend"
echo "npm ci ..."
npm ci --no-audit --no-fund
echo "vite build ..."
npx vite build

cd "${WORKDIR}/src"
export CGO_ENABLED=1
echo "go build ..."
go build -trimpath -ldflags="-s -w" -o "${WORKDIR}/x-ui-new" .

if systemctl is-active --quiet x-ui 2>/dev/null; then
  echo "Stopping x-ui ..."
  systemctl stop x-ui
fi

bak="${XUI_DIR}/x-ui.bak.$(date +%s)"
cp -a "${XUI_DIR}/x-ui" "${bak}"
echo "Backup saved: ${bak}"

install -m 0755 "${WORKDIR}/x-ui-new" "${XUI_DIR}/x-ui"

echo "Starting x-ui ..."
systemctl start x-ui
echo "Done. Open your panel and hard-refresh (Ctrl+F5). /panel/darkssh should load."
