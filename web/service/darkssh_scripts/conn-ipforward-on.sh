#!/usr/bin/env bash
set -euo pipefail
sysctl -w net.ipv4.ip_forward=1
if [[ -f /proc/sys/net/ipv6/conf/all/forwarding ]]; then
  sysctl -w net.ipv6.conf.all.forwarding=1 || true
fi
echo "IPv4 (and IPv6 if present) forwarding enabled."
