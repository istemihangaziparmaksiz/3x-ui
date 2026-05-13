#!/usr/bin/env bash
set -euo pipefail
echo "3x-ui DarkSSH: stunnel install helper"
if command -v stunnel4 >/dev/null 2>&1 || command -v stunnel >/dev/null 2>&1; then
  echo "stunnel is already installed."
  command -v stunnel4 2>/dev/null || command -v stunnel
  exit 0
fi
if ! command -v apt-get >/dev/null 2>&1; then
  echo "This helper only supports apt-based systems (Debian/Ubuntu)."
  exit 1
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y stunnel4
echo "stunnel4 installed. Configure /etc/stunnel/ and enable the service separately."
