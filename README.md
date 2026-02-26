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
2) Triage
3) Tools
4) Firewall baseline
5) Watch / continuous checks

Reason:
Snapshot gives rollback and baseline.
Triage tells you what is wrong.
Tools help you investigate and fix.
Firewall reduces exposure once you know required services.
Watch helps catch changes and tampering.

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

Why it matters:
- Creates a known-good baseline to compare against later
- Gives a firewall rollback file if hardening breaks scoring
- Helps detect tampering (new rules, new tasks, new services, new ports)

What it does NOT do:
- Does not change system settings
- Does not fix issues
- Does not remove malware
- Does not restore services or accounts

How to rollback firewall:
    netsh advfirewall import "C:\CCDC\Backups\<timestamp>\firewall.wfw"

What to monitor after snapshot:
- compare firewall_rules.csv between timestamps
- compare services.csv and scheduled_tasks.csv for new persistence
- check netstat.txt for new listeners

--------------------------------------------------

2) Triage Script (triage_full.ps1)

What it captures:
- SUMMARY.txt with quick-view sections
- admins and local users
- autostart services and running services
- scheduled tasks (all + non-Microsoft)
- network commands (netstat, ipconfig, arp, route, shares)
- firewall profile summary
- process hint list (common LOLBins)
- PID map for quick correlation
- event logs (System/Application/Security) for LookbackHours window

Why it matters:
- SUMMARY.txt gives fast answers under pressure
- Finds persistence and obvious abuse quickly
- Correlates ports -> PID -> process name/path
- Event logs show recent suspicious activity

ContainmentMode (optional):
- Disables running non-Microsoft scheduled tasks only
- Intended as light containment, not a full cleanup

What it does NOT do:
- Does not remove services
- Does not reset passwords
- Does not kill processes
- Does not rewrite firewall rules

What to monitor after triage:
- new local admins
- new non-Microsoft tasks
- suspicious processes and paths
- event log spikes (logons, account changes)

--------------------------------------------------

3) Firewall Baseline Script (WRCCDC_Firewall_Baseline.ps1)

Goal:
Reduce exposed attack surface without nuking scoring.

What it changes:
- Turns firewall ON
- Sets defaults: Inbound=Block, Outbound=Allow
- Enables firewall logging
- Adds allow rules for required inbound ports you specify
- Optional RDP allow rule (restricted to RFC1918 ranges if enabled)

Scoring-safe behavior:
- Preserves existing inbound allow rules by default
  (this prevents accidental scoring loss)

What it locks down:
- Most unsolicited inbound connections
- Random listener exposure
- Many remote exploitation paths

What firewall does NOT handle:
- malicious processes already running
- persistence (services/tasks/registry)
- credential abuse
- outbound beacons (outbound is allowed)
- local privilege escalation

What to monitor after applying firewall baseline:
- scoring services connectivity
- firewall log: %SystemRoot%\System32\LogFiles\Firewall\pfirewall.log
- netstat -ano for new listeners
- unexpected new firewall allow rules

Rollback:
- Firewall baseline script exports a backup .wfw before changes
- Snapshot script also exports firewall.wfw per timestamp folder
- Restore with netsh advfirewall import <backup>

--------------------------------------------------

Operational notes (WRCCDC)

Run as Administrator when possible.
Without admin you may lose:
- security event log visibility
- process path visibility
- complete task/service enumeration

Do not assume "firewall applied" means "system clean".
Always snapshot + triage before hardening.

Keep required ports minimal:
Only allow what is needed for scoring and actual business services.

--------------------------------------------------

End of overview
