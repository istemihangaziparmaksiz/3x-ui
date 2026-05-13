#!/usr/bin/env bash
set -euo pipefail
u="${DARKSSH_SUBUSER:-}"
p="${DARKSSH_SUBPASS:-}"

if [[ ! "$u" =~ ^[a-z][a-z0-9_-]{2,31}$ ]]; then
  echo "Invalid username pattern."
  exit 1
fi

case "$u" in
  root|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|nobody|_apt|systemd-network|systemd-resolve|systemd-timesync|istmhn|admin|ubuntu|debian)
    echo "Reserved username."
    exit 1
    ;;
esac

if [[ "$p" == *:* || "$p" == *$'\n'* || ${#p} -lt 8 || ${#p} -gt 128 ]]; then
  echo "Invalid password (length 8–128, no colon, no newline)."
  exit 1
fi

if id "$u" &>/dev/null; then
  echo "User already exists: $u"
  exit 1
fi

useradd -m -s /bin/bash "$u"
printf '%s:%s\n' "$u" "$p" | chpasswd
echo "Created user: $u"
