#!/usr/bin/env bash
set -euo pipefail
echo "3x-ui DarkSSH: badvpn (udpgw) install helper"
if command -v badvpn-udpgw >/dev/null 2>&1; then
  echo "badvpn-udpgw is already installed."
  command -v badvpn-udpgw
  exit 0
fi
if ! command -v apt-get >/dev/null 2>&1; then
  echo "This helper only supports apt-based systems (Debian/Ubuntu)."
  exit 1
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
if apt-get install -y badvpn 2>/dev/null; then
  echo "Installed via apt package badvpn."
elif apt-get install -y badvpn-udpgw 2>/dev/null; then
  echo "Installed via apt package badvpn-udpgw."
else
  echo "Could not install from default APT repositories."
  echo "Try building badvpn from source or enable universe/multiverse on Ubuntu."
  exit 1
fi
command -v badvpn-udpgw || true
