#!/usr/bin/env bash
# ============================================================
# CYBERFORCE 2026 — FIREWALL BASELINE — PLC1 (Ubuntu 24, Modbus)
# Required scored inbound (per official AWS doc):
#   Modbus   502/tcp
#   OpenPLC  8080/tcp   (web UI - openplc:openplc default!)
#   SSH      22/tcp      (team access)
# Rules of play: NO allow-lists, NO subnet/CIDR blocks.
# Default: block all inbound, allow outbound.
# CAUTION: the modbus service + MQTT (1883 local) feed the
# scoreboard sensor data. 502 and the services must stay up —
# if you break them, geothermal/radar (Blue/ICS pts) stop.
# ============================================================
set -u

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run with sudo (sudo bash firewall.sh)" >&2
  exit 1
fi

REQ_TCP="22 502 8080"
TS=$(date +%Y%m%d-%H%M%S)
BACKUP="$HOME/cf-firewall-backup-$TS.txt"

echo "=== CYBERFORCE FIREWALL — PLC1 (Ubuntu 24) ==="
echo "Required ports: $REQ_TCP (TCP)"
echo

( ufw status verbose 2>/dev/null || true ) > "$BACKUP"
echo "Backup of current config: $BACKUP"

read -rp "Extra inbound TCP ports to ALLOW, comma-separated (blank=none): " extra
EXTRA_TCP=$(echo "$extra" | tr -d ' ' | tr ',' ' ' | tr -s ' ')

read -rp "Proceed: ufw reset, deny-all inbound, allow ONLY $REQ_TCP $EXTRA_TCP? [y/N] " a
[[ $a =~ ^[Yy] ]] || { echo "Aborted."; exit 1; }

ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
for p in $REQ_TCP $EXTRA_TCP; do
  ufw allow "$p/tcp" && echo "allowed $p/tcp"
done
ufw --force enable

echo; echo "=== RESULT ==="; ufw status verbose

echo
echo "=== SELF-CHECK ==="
for p in $REQ_TCP; do
  if ss -tlnH "( sport = :$p )" 2>/dev/null | grep -q .; then
    echo "  OK    $p/tcp listening"
  else
    echo "  MISS  $p/tcp NOT listening"
  fi
done
echo "--- ICS services (MUST stay running) ---"
systemctl is-active modbus.service >/dev/null 2>&1 \
  && echo "  OK    modbus.service active" \
  || echo "  MISS  modbus.service NOT active — sudo systemctl restart modbus.service"
echo
echo "OpenPLC UI: http://<this-ip>:8080  (default creds openplc:openplc — rotate cred identity first!)"
echo "NOTE: MQTT 1883 is NOT scored here; PLC2 reads it. Outbound stays allowed by default."
echo "Rollback: restore from $BACKUP (ufw reset + re-add), snapshot via Controller."
