#!/usr/bin/env bash
set -euo pipefail
PORT="${DARKSSH_UDPGW_PORT:-7300}"
BIN="$(command -v badvpn-udpgw || true)"

if [[ -z "$BIN" ]]; then
  echo "badvpn-udpgw not found. Run the BadVPN package install helper first."
  exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1024 || PORT > 65535 )); then
  echo "Port must be between 1024 and 65535."
  exit 1
fi

cat > /etc/systemd/system/badvpn-udpgw.service <<EOF
[Unit]
Description=badvpn udpgw (3x-ui DarkSSH helper)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BIN} --listen-addr 0.0.0.0:${PORT} --max-clients 512
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable badvpn-udpgw.service
if systemctl is-active --quiet badvpn-udpgw.service 2>/dev/null; then
  systemctl restart badvpn-udpgw.service
else
  systemctl start badvpn-udpgw.service
fi
echo "Installed and started badvpn-udpgw.service on port ${PORT}"
