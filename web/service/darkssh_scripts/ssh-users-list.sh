#!/usr/bin/env bash
set -euo pipefail
awk -F: '$3 >= 1000 && $1 != "nobody" { print $1 }' /etc/passwd | sort -u
