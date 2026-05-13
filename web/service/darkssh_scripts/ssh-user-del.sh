#!/usr/bin/env bash
set -euo pipefail
u="${DARKSSH_SUBUSER:-}"

if [[ ! "$u" =~ ^[a-z][a-z0-9_-]{2,31}$ ]]; then
  echo "Invalid username pattern."
  exit 1
fi

case "$u" in
  root|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|nobody|_apt|systemd-network|systemd-resolve|systemd-timesync|istmhn|admin|ubuntu|debian)
    echo "Refusing to delete reserved user."
    exit 1
    ;;
esac

if ! id "$u" &>/dev/null; then
  echo "User does not exist: $u"
  exit 1
fi

uid="$(id -u "$u")"
if [[ "$uid" -lt 1000 ]]; then
  echo "Refusing to delete system user (uid < 1000)."
  exit 1
fi

userdel -r "$u" 2>/dev/null || userdel "$u"
echo "Deleted user: $u"
