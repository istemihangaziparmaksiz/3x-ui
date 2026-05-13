#!/usr/bin/env bash
set -euo pipefail
F=/etc/stunnel/x-ui-darkssh-sample.conf
cat > "$F" <<'STCONF'
; Sample stunnel fragment — rename the section, set cert/key, then wire
; /etc/default/stunnel4 or systemd unit to include this file.
; Requires: stunnel4 + TLS certificate (e.g. fullchain.pem + privkey.pem merged to stunnel.pem)

[sample-tls-terminate]
client = no
accept = 8443
connect = 127.0.0.1:443
cert = /etc/stunnel/stunnel.pem
; key = /etc/stunnel/stunnel.key
STCONF
echo "Wrote ${F} — edit [section], cert paths, accept/connect, then enable stunnel."
