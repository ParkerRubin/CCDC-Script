#!/usr/bin/env bash
# ============================================================
# CYBERFORCE 2026 — FIREWALL BASELINE — PLC2 (Debian 13, DNP3)
# *** ASSUME-BREACH MACHINE — EXTREME CAUTION ***
# Required scored inbound (per official AWS doc):
#   DNP3   20000/tcp
#   MQTT   1883/tcp    (sensor feed from scoreboard)
#   SSH    22/tcp      (team access)
# !!! IMPORTANT RULES FOR THIS BOX !!!
#  - Red team ALREADY has access (that is the point of the box).
#  - If scoreboard or Red team cannot reach this box -> point loss.
#  - Monitoring tools are allowed AT YOUR OWN RISK.
#  - No IP blocking of any kind here. Nothing but these rules.
# A firewall here will mostly just INFORM you (failed-conn logs).
# Ruinning it can interfere with Red team -> run ONLY with
# --confirm-ab. Consider NOT enabling it and relying on logging.
# ============================================================
set -u

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run with sudo (sudo bash firewall.sh)" >&2
  exit 1
fi

if [[ "${1:-}" != "--confirm-ab" ]]; then
  echo "ASSUME-BREACH BOX. Refusing to run without --confirm-ab."
  echo "First re-read the Assume-Breach cautions in the header, then decide."
  exit 1
fi

REQ_TCP="22 1883 20000"
TS=$(date +%Y%m%d-%H%M%S)
BACKUP="$HOME/cf-firewall-backup-$TS.txt"

echo "=== CYBERFORCE FIREWALL — PLC2 (Debian 13, DNP3) ==="
echo "Required ports: $REQ_TCP (TCP)"
echo

( ufw status verbose 2>/dev/null || true ) > "$BACKUP"
echo "Backup of current config: $BACKUP"

read -rp "Extra inbound TCP ports to ALLOW, comma-separated (blank=none): " extra
EXTRA_TCP=$(echo "$extra" | tr -d ' ' | tr ',' ' ' | tr -s ' ')

read -rp "APPLY to assume-breach box: mean this? [type YES in caps] " a
[[ "$a" == "YES" ]] || { echo "Aborted."; exit 1; }

# Debian ships without ufw — install it if missing
if ! command -v ufw >/dev/null 2>&1; then
  echo "Installing ufw (Debian 13)..."
  apt-get update -qq && apt-get install -y -qq ufw || { echo "No ufw available; manual nftables only. Aborting."; exit 1; }
fi

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
echo "--- ICS services ---"
systemctl is-active dnp3.service >/dev/null 2>&1 \
  && echo "  OK    dnp3.service active" \
  || echo "  MISS  dnp3.service NOT active — sudo systemctl restart dnp3.service"
echo
echo "FINAL CHECK: from a teammate box verify Red team + scoreboard can still reach 20000/1883."
echo "If anything stops responding: sudo ufw disable (immediate rollback) "
