Firewall + Network Snapshot Script User Guide

--------------------------------------------------

What this script does

Creates a timestamped snapshot folder containing firewall configuration
and related system/network state so you can restore or compare later.

It captures:
- Firewall export (restore-ready)
- Firewall profiles and rules (readable)
- Local users and administrators
- Services (with paths and start info)
- Listening ports (netstat)
- Running processes (with paths)
- Scheduled tasks

Purpose: preserve a known-good network/security baseline or enable quick rollback.

--------------------------------------------------

How to run

Run PowerShell as Administrator when possible.

From the folder containing the script:

    .\Snapshot.ps1

Optional: choose a different root folder:

    .\Snapshot.ps1 -Root C:\IR\Snapshots

If script execution is blocked:

    Set-ExecutionPolicy Bypass -Scope Process -Force

Then run again.

--------------------------------------------------

Output location

The script creates:

    C:\CCDC\Backups\YYYYMMDD_HHMMSS\

Example:

    C:\CCDC\Backups\20260226_231530\

--------------------------------------------------

Files created

firewall.wfw
Full firewall export. Can be imported to restore firewall state.

firewall_profiles.txt
Readable firewall profile settings (on/off, default actions).

firewall_rules.csv
All firewall rules in searchable CSV format.

local_users.txt
Local user accounts.

local_admins.txt
Members of local Administrators group.

services.csv
Services with state, start mode, account, and binary path.

netstat.txt
All listening/connected ports with owning PID.

processes.csv
Running processes with PID and executable path.

scheduled_tasks.csv
Scheduled tasks with name, path, state, and author.

--------------------------------------------------

When to use this script

Before firewall hardening
So you can restore if scoring or services break.

After scoring is stable
Creates a known-good baseline.

When compromise is suspected
Preserves firewall and exposure state for comparison.

Before major network or service changes
Example: enabling RDP, WinRM, or changing firewall profiles.

--------------------------------------------------

How to restore firewall from snapshot

Open elevated PowerShell and run:

    netsh advfirewall import "C:\CCDC\Backups\TIMESTAMP\firewall.wfw"

This replaces current firewall rules with the snapshot state.

--------------------------------------------------

How to compare snapshots

Compare firewall_rules.csv or services.csv between two timestamps
to identify added rules, ports, or services.

Example workflow:
- open two snapshot folders
- open firewall_rules.csv
- sort by DisplayName or Direction
- look for differences

--------------------------------------------------

Notes

Running without Administrator may reduce visibility.
Firewall export may fail without elevation.

Script does not change system configuration.
It only reads settings and writes snapshot files.

--------------------------------------------------

End of guide
