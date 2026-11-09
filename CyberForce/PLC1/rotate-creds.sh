#!/usr/bin/env bash
# ============================================================
# CYBERFORCE 2026 — ROTATE CREDS — PLC1 (Ubuntu 24, Modbus)
# blueteam:BlueTeam2026! + openplc:openplc are PUBLIC in the
# comp repo. Rotate day one. NEVER touch: SCORE1, SCORE2, PATCH.
# PLC1 extras handled here:
#   - OpenPLC web creds (8080) — guided manual change (no easy
#     silent path; effective and auditable)
#   - modbus.service health check after changes
# ============================================================
set -u

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run with sudo (sudo bash rotate-creds.sh)" >&2
  exit 1
fi

PROTECTED="SCORE1|SCORE2|PATCH|historian|root|openplc$"
TS=$(date +%Y%m%d-%H%M%S)
CREDFILE="$HOME/cf-creds-$TS.txt"
touch "$CREDFILE" && chmod 600 "$CREDFILE"

log() { echo "$1" | tee -a "$CREDFILE"; }
genpw() { tr -dc 'A-HJ-NP-Za-km-z2-9' < /dev/urandom | head -c 20; echo; }

log "== CF rotate-creds — PLC1 — $TS =="

# ---------------- 1. local user audit ----------------
log ""
log "--- Local human accounts (uid>=1000) ---"
getent passwd | awk -F: '$3>=1000 && $3<60000 {printf "  %-16s shell=%s home=%s\n",$1,$7,$6}' | tee -a "$CREDFILE"
log ""
log "--- Accounts with usable shells ---"
getent passwd | awk -F: '$7 ~ /(bash|sh|zsh)$/ {printf "  %-16s %s\n",$1,$7}' | tee -a "$CREDFILE"

# ---------------- 2. rotate blueteam ----------------
echo
read -rp "Rotate the linux user 'blueteam'? [Y/n] " a
if [[ ${a:-Y} =~ ^[Yy]$ ]]; then
  NEWPW=$(genpw); NEWPW="${NEWPW}Pa1"
  echo "blueteam:${NEWPW}" | chpasswd && log "ROTATED  linux blueteam -> $NEWPW"
fi

# ---------------- 3. OpenPLC web creds (8080) ----------------
echo
cat <<'EOF'
OpenPLC web (8080) default is openplc:openplc — PUBLIC knowledge.
Rotate it in the UI, then verify the program still starts:
  1. http://<this-ip>:8080 -> login openplc:openplc
  2. Menu: OpenPLC -> Settings / change admin user+password
  3. Note BOTH new values -> they go into the creds sheet
  4. Dashboard -> confirm the Separator Geothermal program shows running
EOF
read -rp "Type the NEW OpenPLC password after changing it in the UI (blank=skipped): " op
[[ -n $op ]] && log "MANUAL   openplc web -> $op"

# ---------------- 4. ICS service check ----------------
echo
log ""
log "--- ICS services ---"
for svc in modbus.service dnp3.service mqtt; do
  systemctl is-active "$svc" >/dev/null 2>&1 \
    && log "  OK    $svc active" \
    || log "  BREAK $svc not found/inactive (ok if it lives on the other PLC)"
done

echo
log "=== DONE. Creds saved in: $CREDFILE (chmod 600) ==="
echo "Next: firewall.sh, then keep 502/8080 + modbus.service monitored."
