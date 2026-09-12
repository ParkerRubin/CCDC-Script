CCDC-Script Toolkit Overview (WRCCDC)
--------------------------------------------------

Purpose

This repo is a scoring-safe Blue Team toolkit for fast deployment on
Windows boxes during WRCCDC/CCDC-style competitions.

The goal is to:
- capture baselines fast
- triage quickly
- harden without breaking scoring
- keep rollback options ready

--------------------------------------------------

Recommended order (operator flow)

1) Snapshot
2) Inventory
3) Triage
4) Tools (Sysinternals)
5) Firewall baseline
6) Watch / continuous checks (re-run Snapshot + Inventory periodically)

Reason:
Snapshot gives rollback and a broad baseline.
Inventory gives a readable, correlated view of exposure specifically
  (listening ports vs firewall rules, unsigned binaries, LLMNR/mDNS/SSDP).
Triage tells you what is wrong right now.
Tools (Sysinternals) help you investigate deeper once something looks off.
Firewall reduces exposure once you know required services.
Re-running Snapshot/Inventory on an interval catches drift and tampering.

--------------------------------------------------

1) Snapshot Script (Firewall + Network Snapshot)

What it captures:
- firewall.wfw (restore-ready firewall export)
- firewall profiles (readable)
- firewall rules (CSV)
- local users and local admins
- services (CSV with path, start mode, account)
- netstat output
- running processes (CSV with paths when available)
- scheduled tasks (CSV)

Retention:
- Keeps the most recent N snapshot folders (default 20, set with
  -MaxSnapshots) and automatically prunes older ones
- Safe to run on a recurring schedule (e.g. every 15 min) without
  manually clearing old snapshots

Why it matters:
- Creates a known-good baseline to compare against later
- Gives a firewall rollback file if hardening breaks scoring
- Helps detect tampering (new rules, new tasks, new services, new ports)

What it does NOT do:
- Does not change existing system settings (only manages its own
  snapshot folders - creating new ones, pruning old ones)
- Does not fix issues
- Does not remove malware
- Does not restore services or accounts

How to rollback firewall:
    netsh advfirewall import "C:\CCDC\Backups\<timestamp>\firewall.wfw"

What to monitor after snapshot:
- compare firewall_rules.csv between timestamps
- compare services.csv and scheduled_tasks.csv for new persistence
- check netstat.txt for new listeners
- check for local_users_error.txt / local_admins_error.txt - a
  failure here looks identical to "no results" unless you check
  for the error file specifically

--------------------------------------------------

2) Inventory Script (systeminfo/wininfo.ps1, see systeminfo/wininfooverview.md)

What it captures:
- Host, OS, IPv4 network config
- Listening TCP/UDP ports, grouped by owning process and service
- Enabled inbound firewall rules (cross-reference against the
  listening-ports sections above them)
- Local Administrators group membership
- Non-Microsoft scheduled tasks
- Startup registry entries (Run/RunOnce)
- Signature status of binaries behind listening processes
  (only reports non-valid signatures - empty is the good result)
- LLMNR policy status, mDNS (5353/udp) and SSDP (1900/udp) exposure

Why it matters:
- The only script that directly answers "does the firewall actually
  match what's running" - a port can be listening with no matching
  allow rule, or an allow rule can exist with nothing behind it
- Flags Responder-style name-resolution poisoning exposure (LLMNR/
  mDNS/SSDP) that firewall hardening alone won't catch, since those
  are pre-existing Windows allow rules, not new inbound attempts
- Unsigned-binary check gives a fast first pass before reaching for
  Sigcheck manually

What it does NOT do:
- Does not change system settings
- Does not fix or remove anything
- Does not check outbound connections (see Snapshot/Triage netstat
  output for that)

What to monitor after inventory:
- any legacy consumer-feature firewall rules still enabled after a
  hardening pass (Cast to Device, Network Discovery, Remote
  Assistance, mDNS, SSDP)
- anything in the Unsigned Executables section
- LLMNR with no explicit disable policy set

--------------------------------------------------

3) Triage Script (monitoring/triage_full.ps1, see monitoring/triage_fulloverview.md)

What it captures:
- SUMMARY.txt with quick-view sections
- admins and local users
- autostart services and running services
- scheduled tasks (all + non-Microsoft)
- network commands (netstat, ipconfig, arp, route, shares)
- firewall profile summary
- process hint list (common LOLBins) WITH full command line and
  parent process ID for each hit
- process list sorted by CPU (process_by_cpu.txt) - surfaces
  runaway/heavy processes a PID-ordered list won't
- PID map for quick correlation
- event logs (System/Application/Security) for LookbackHours window
- targeted Security event IDs (event_security_targeted.txt) -
  logon success/fail, account creation/modification, admin group
  membership changes - not time-bounded, so it catches relevant
  events even outside the lookback window

Why it matters:
- SUMMARY.txt gives fast answers under pressure
- Finds persistence and obvious abuse quickly
- Correlates ports -> PID -> process name/path/command line
- A LOLBin name match alone is not suspicious - review the command
  line, that's where the real signal is
- Event logs show recent suspicious activity; the targeted pull
  narrows straight to the highest-value event IDs

ContainmentMode (optional):
- "CONTAINMENT ACTIONS TAKEN: disable non-Microsoft running
  scheduled tasks" - this is the only action it takes
- Does not isolate the network, kill processes, or lock accounts
- Intended as one narrow containment step, not full cleanup

What it does NOT do:
- Does not remove services
- Does not reset passwords
- Does not kill processes
- Does not rewrite firewall rules

What to monitor after triage:
- new local admins
- new non-Microsoft tasks
- suspicious command lines behind flagged processes (not just names)
- any *_error.txt file - especially event_security_error.txt, since
  the Security log can fail to read for audit-policy reasons even
  when running as Administrator, and an empty result there does NOT
  necessarily mean no events occurred
- event log spikes (logons, account changes)

--------------------------------------------------

4) Tools - Sysinternals Installer (tools/tools.ps1, see tools/tooloverview.md)

What it installs (x64 only, direct from live.sysinternals.com):
- procexp64.exe   - Process Explorer (parent/child trees, loaded
                     DLLs, handles - deeper than Task Manager)
- Autoruns64.exe  - full persistence view (Run keys, services,
                     scheduled tasks, drivers, etc. in one place)
- sigcheck64.exe  - signature verification; -vt flag checks the
                     file hash against VirusTotal (requires outbound)
- tcpview64.exe   - live-updating GUI equivalent of netstat

Why it matters:
- Gives GUI/interactive tools to dig deeper once Inventory or
  Triage output has flagged something worth a closer look
- Sigcheck extends the unsigned-binary check from Inventory with a
  reputation lookup, when outbound access allows it

What it does NOT do:
- Does not run any analysis itself - these are tools you use
  manually after triage flags something
- Re-running the installer is safe; anything already present is
  skipped rather than re-downloaded

--------------------------------------------------

5) Firewall Baseline Script (firewall/firewall.ps1, see firewall/firewalloverview.md)

Goal:
Reduce exposed attack surface without nuking scoring.

What it changes:
- Turns firewall ON
- Sets defaults: Inbound=Block, Outbound=Allow
- Enables firewall logging
- Adds allow rules for required inbound ports you specify
- Prompts interactively at runtime for allowed RDP source IP(s)/
  CIDR range(s); falls back to RFC1918 ranges only if left blank

Scoring-safe behavior:
- Preserves existing inbound allow rules by default
  (this prevents accidental scoring loss - see the Inventory
  script's firewall-rules section for what that leaves enabled)

What it locks down:
- Most unsolicited inbound connections
- Random listener exposure
- Many remote exploitation paths
- RDP access from outside whatever source range you enter at
  runtime

What firewall does NOT handle:
- malicious processes already running
- persistence (services/tasks/registry)
- credential abuse
- outbound beacons (outbound is allowed)
- local privilege escalation
- pre-existing legacy allow rules (Network Discovery, Cast to
  Device, Remote Assistance, mDNS, SSDP, etc.) - deny-by-default
  only blocks NEW inbound attempts with no matching allow rule; it
  does not remove rules that already existed. Check the Inventory
  script's firewall-rules output to see what's still enabled.

What to monitor after applying firewall baseline:
- scoring services connectivity
- firewall log: %SystemRoot%\System32\LogFiles\Firewall\pfirewall.log
- netstat -ano for new listeners
- unexpected new firewall allow rules
- confirm the RDP source range you entered is actually correct -
  a wrong range locks your own team out

Rollback:
- Firewall baseline script exports a backup .wfw before changes
- Snapshot script also exports firewall.wfw per timestamp folder
- Restore with netsh advfirewall import <backup>

--------------------------------------------------

Operational notes (WRCCDC)

Run as Administrator when possible.
Without admin you may lose:
- security event log visibility
- process path and command-line visibility
- complete task/service enumeration

Do not assume "firewall applied" means "system clean".
Always snapshot + inventory + triage before and after hardening.

Keep required ports minimal:
Only allow what is needed for scoring and actual business services -
and double check the protocol (TCP vs UDP) matches what the service
actually uses before adding it.

Know your actual RDP/access source range before running the firewall
script - usually your team's VPN-assigned subnet on the comp network,
not a guessed private range.

--------------------------------------------------

Linux

linux/linuxinfo.ps1 and linux/readme.md cover the Linux side of the
toolkit separately - see that readme for details. This overview
currently documents the Windows-side scripts only.

--------------------------------------------------

End of overview
