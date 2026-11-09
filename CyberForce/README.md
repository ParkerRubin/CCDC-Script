# CyberForce 2026 Section

Blue Team toolkit for the **DOE CyberForce Competition — November 13–14, 2026, Tinley Park Convention Center (Chicagoland)**.
Scenario: operations team for **Vulcana Dynamics Ltd. (VDL)**, the sole geothermal power utility of the Kaldera Archipelago. Opened with an unexplained **2:36 grid outage**; the **Island Defense Radar Network** depends on your grid staying up.

Official docs: https://github.com/CyberForceCompetition/2026_CyberForce_Competition (keep an eye on Rules-Expectations for updates — rule changes are announced in Discord #announcements).

---

## Competition environment (7 VMs, AWS VPC `10.0.x.0/27`, OpenVPN access)

### Traditional infrastructure — full hardening allowed (40% of score riding on these)

| VM | OS | IP | Required scored services | Local creds (day 1) |
|---|---|---|---|---|
| Task | OpenSUSE Leap | 10.0.x.145 | HTTP 80, MySQL 3306, SMB 139/445, SSH 22 | blueteam:BlueTeam2026! |
| Mail/File | Windows Server 2019 | 10.0.x.140 | HFS 1080, SMTP 25, SSH 22 | blueteam:BlueTeam2026! |
| AD | Windows Server 2022 | 10.0.x.141 | LDAP 389, SNMP 161, SSH 22 | blueteam:BlueTeam2026! |
| PLC1 | Ubuntu 24 | 10.0.x.144 | Modbus 502, OpenPLC 8080 (`openplc:openplc`) | blueteam:BlueTeam2026! |

### Assume-breach infrastructure — MONITOR ONLY, extreme caution (Red team already inside; 1000 Red pts = report their attack chains)

| VM | OS | IP | Required scored services | Local creds (day 1) |
|---|---|---|---|---|
| PLC2 (DNP3) | Debian 13 | 10.0.x.143 | DNP3 20000, MQTT 1883 | blueteam:BlueTeam2026! |
| HMI/CnC | Windows Server 2019 | 10.0.x.142 | Ignition Gateway 8088 (`blueteam:BlueTeam2026!`), MySQL historian 3306 (`historian:CyberForce2026!` — NEVER change this one) | blueteam:BlueTeam2026! |

Plus **1 Anomaly VM** — credentials given competition day only.

### ICS pipeline (how Blue/ICS points flow)

Scoreboard → **MQTT** (sensor topics) → **PLC1 Modbus** + **PLC2 DNP3** → **Ignition HMI** reconciles + visualizes + MySQL data historian.
- PLC1: OpenPLC web UI at `10.0.x.144:8080`, "Start PLC" button, Modbus registers 2048–2094 / coils 0000–0005 (ESD, StartSystem, StopSystem, Separator Valve %, flash factor, turbine…).
- PLC2/PLC1 services: `sudo systemctl status dnp3.service` / `modbus.service` (restart the same way; **never remove these services**).
- HMI Radar page = live ICS score view. Keep **Radar Array uptime + geothermal production** up.
- Alert thresholds: Wellhead pressure > 2001, flow > 400, temp > 271, Separator pressure > 2001, temp > 240, level > 1800 → ESD trips; you must manually reset (enable Start toggle) after ESD.

### Scoring (10,000 total)

| Bucket | Pts | Notes |
|---|---|---|
| Red | 2500 | Assume-breach attack-chain reporting 1000 + external pentest 1500 |
| Blue | 2500 | Service uptime on required ports + geothermal production + radar uptime |
| Green | 1500 | Website survey (WordPress-style site on **Task VM**) — 12 checklist items |
| Orange | 2000 | C-Suite video 1000 (due **Nov 2, 8AM PT**) + Security Documentation 1000 (due **Nov 9, 8AM PT**) |
| Anomalies | 1500 | Distributed via **USB on Friday Nov 14**; 7zip/gpg to open |

### Key dates
- Oct 26: C-Suite scenario + controller access
- Nov 2: AWS access opens; C-Suite video due
- Nov 9: Security Documentation due (use official template, PDF, team number only)
- Nov 13: mandatory Red-Blue check-in at venue, 9AM–6PM CT (15-min slots, book in Controller)
- Nov 14: competition day

---

## Critical rules (these constrain what scripts may do)

1. **NO allow-lists, NO full-subnet blocks.** You may block specific individual IPs only (e.g. 192.168.0.14), never a subnet/CIDR (e.g. 10.0.3.0/27), and never "allow only these IPs" logic. Blocked IPs may still be used for scoring — wrong block = point loss.
2. **Never modify SCORE1, SCORE2, or PATCH** (SSH/RDP scoring accounts) — no config or permission changes.
3. **Assume-breach VMs**: monitoring tools allowed *at your own risk*; anything that breaks scoring/Red-engagement costs points. No port/IP blocking there at all.
4. **VM naming**: restored snapshots must keep the identical provided name — **150 pts penalty per misnamed VM**.
5. Snapshot revert limit: **2 reverts/VM/hour**; fresh re-image = **75 pts penalty/box** (snapshot early, snapshot often, via Controller "Manage AWS Instances").
6. Password-reset help requests: > 2 = 50 pts each. DMing staff = 10 pts each. Use #ticket-system.
7. Free/open-source software only; **no AI tools** for anomaly resolution or infrastructure defense.
8. Any infra change must appear in Security Documentation.

---

## Script inventory (this folder)

### Per-machine folders (tuned to each box — the same scripts, machine-specific ports/creds)

| Folder | Box | OS | Script engine | Scored ports baked in |
|---|---|---|---|---|
| `Task\` | Task | OpenSUSE Leap | bash | 22, 80, 3306, 139, 445 |
| `Mail-File\` | Mail/File | Windows Server 2019 | PowerShell | 25, 1080, 22 (+ RDP/WinRM team) |
| `AD\` | AD DC | Windows Server 2022 | PowerShell | 389, 161/udp, 22 + full DC baseline + RPC dynamic |
| `PLC1\` | PLC1 (Modbus) | Ubuntu 24 | bash | 22, 502, 8080 |
| `PLC2\` | PLC2 (DNP3) **ASSUME-BREACH** | Debian 13 | bash | 22, 1883, 20000 (`--confirm-ab` guard) |
| `HMI\` | HMI/CnC **ASSUME-BREACH** | Windows Server 2019 | PowerShell | 8088, 3306 (+ RDP only — no SSH) (`-ConfirmAB` / `-ReportOnly` guard) |

Each folder contains:
- **firewall.(sh|ps1)** — deny-all-inbound baseline that opens ONLY that machine's scored ports + team access; exports a rollback file first; self-checks that scored ports are actually listening; warns on rules-of-play violations.
- **rotate-creds.(sh|ps1)** — audits accounts, rotates all documented default creds for that machine (`BlueTeam2026!`, `openplc:openplc`, Ignition gateway), NEVER touches SCORE1/SCORE2/PATCH (plus `historian` on HMI), greps services/configs still carrying the default password (landmines that break scored services after rotation), and writes a `chmod 600`/protected cred sheet.

Run order per box on Nov 2: `rotate-creds` → `firewall` → exported toolkit (`snapshot.ps1`, `wininfo.ps1`, `triage_full.ps1` on Windows; manual/triage notes on Linux).

### windows\ (generic copies from the proven WRCCDC toolkit — maintain/verify, then fall back)
1. **snapshot.ps1** — baseline capture: firewall `.wfw` export, users/admins, services, netstat, processes, scheduled tasks → your before/after truth for Red-chain reporting + drift detection. Run FIRST on every box, then every ~15 min.
2. **wininfo.ps1** — inventory + exposure correlation: listening ports ↔ firewall rules, unsigned binaries, LLMNR/mDNS/SSDP, Run keys, non-MS tasks.
3. **triage_full.ps1** — fast triage: SUMMARY.txt, LOLBin process hints with command lines, CPU-sorted processes, targeted Security event IDs (no time bound), optional containment (disable non-MS running scheduled tasks only).
4. **tools.ps1** — Sysinternals installer (ProcExp, Autoruns, Sigcheck, TCPView) — user-run drills after triage flags something.
5. **firewall.ps1** — generic firewall baseline. **⚠️ CYBERFORCE SETTINGS FIRST** (below).
6. **firewall-ad.ps1** — AD/DC-aware firewall baseline (baseline ports 53/88/135/139/389/445/464/636/3268/3269 + RPC dynamic) — intended for the **AD box**.

### linux\ (generic copies — supersedes manual work while per-machine scripts cover the rest)
1. **linuxinfo.sh** — bash-native Linux inventory (`--save` writes a timestamped `Inventory_<host>_<ts>/inventory.txt`; run with sudo for process-path evidence on listening ports). *(Note: this file was previously saved as `linuxinfo.ps1` — renamed; it is a bash script.)*
2. **readme.md** — manual hardening notes (passwd reset, user purging, ufw port allows, threat hunt).

### reference\ (documentation work)
**cmd-cheatsheet.md** — quick command reference for SecDoc writing + anomaly hunting.

### ⚠️ CYBERFORCE SETTINGS FIRST — firewall.ps1 adjustments
Before running `firewall.ps1` on any CyberForce box:
- **Do NOT source-restrict RDP.** The script prompts for RDP source IPs/CIDR — leaving it blank makes it fall back to RFC1918-only, which is **allow-list/subnet-block behavior and violates 2026 rules**. Choose the option to keep RDP open on 3389 (or add a single rule for 3389 from any) and rely on strong credentials instead.
- Keep `$KeepExistingInboundRules = $true` (default) — do not purge required scored services.
- Required ports to allow inbound per box (traditional only): see the VM table above. Never touch the Assume-breach boxes' firewall.

### Suggested run order (competition day / prep day)
1. AWS access opens Nov 2 → **snapshot every VM via Controller immediately** (pre-hydration baseline).
2. Rotate every documented default credential (`blueteam:BlueTeam2026!` on all boxes, `openplc:openplc`) — EXCEPT `historian`, `SCORE1`, `SCORE2`, `PATCH`.
3. Box-by-box: snapshot → wininfo → (Windows) tools.ps1 → OS/Appropriate hardening.
4. Verify scored services come up on the right ports (`netstat`/`ss` + external port test + Controller scoreboard test week before).
5. Re-run snapshot on an interval for drift; watch dnp3.service / modbus.service / Ignition 8088 / MySQL 3306 continuously.
6. Harden Assume-breach VMs **only on competition day** per SecDoc plan (they must be left vulnerable until then).

### TODO — scripts to add for CyberForce
- [x] `rotate-creds` per machine (Windows PS + Linux bash) — **done, per-machine folders**
- [x] `firewall.(sh|ps1)` per machine, allow-only-required ports — **done, per-machine folders**
- [ ] `servicewatch.ps1` / `servicewatch.sh` — required-port uptime logger (Blue points evidence) + dnp3/modbus/Ignition health
- [ ] Linux triage/inventory (`triage.sh`, `snapshot.sh`) — bash-native equivalents for OpenSUSE/Ubuntu/Debian
- [ ] `ics-monitor` — Modbus register/coil watch (read-only) + pcap capture on 502/20000/1883
- [ ] `ab-evidence` — assume-breach read-only log pack (auditd on Debian, Windows event pull on HMI)
- [ ] `green-check.ps1` / `green-check.sh` — automate the 12-item Green survey checklist against the Task VM website
- [ ] SecDoc asset-inventory generator (merge snapshot/wininfo CSVs into the 2026 template)

---

Sources: cyberforce.energy.gov 2026 pages; official Scenario PDF; official Expectations PDF; official AWS PDF; official ICS PDF (all in the comp repo linked above). Verify against the live repo/Discord closer to the event.
