Triage Script User Guide

--------------------------------------------------

What this script does

Creates a quick incident-response triage bundle in a timestamped folder.
It collects common system, network, user, process, service, and log data
so you can review it fast or exfil it for offline analysis.

Outputs include:
- system.txt (host/OS/user/IP summary)
- firewall.txt (firewall profile settings)
- netstat.txt (netstat -ano output)
- shares.txt (network shares)
- users_admins.txt (local users and local admins)
- processes.txt and processes.csv (top processes by CPU, includes path when available)
- services.csv (services with path/start info)
- scheduled_tasks.csv (scheduled tasks)
- recent_security_events.txt (common security-related event IDs)
- summary.txt (quick snapshot and suggested next steps)

--------------------------------------------------

How to run

Run PowerShell as Administrator when possible, then execute:

    .\triage.ps1

If script execution is blocked:

    Set-ExecutionPolicy Bypass -Scope Process -Force

Then rerun the script.

--------------------------------------------------

Output location

The script writes to:

    C:\IR\TRIAGE\COMPUTERNAME_YYYY-MM-dd_HHmm\

Example:

    C:\IR\TRIAGE\DESKTOP-1234_2026-02-26_2310\

--------------------------------------------------

What gets collected (and why)

system.txt
- Hostname, current user, time, OS version/build, manufacturer/model, BIOS, domain/workgroup, IPv4 addresses
Use for quick identification of the machine and basic environment.

firewall.txt
- Firewall profile status and default inbound/outbound behavior
Use to confirm firewall state and logging settings.

netstat.txt
- Full netstat -ano output (connections + listening + owning PID)
Use to spot suspicious listeners and map ports to process IDs.

shares.txt
- Output of "net share"
Use to find unexpected shares or exposed paths.

users_admins.txt
- Local user accounts and members of the local Administrators group
Use to spot unexpected admin access or rogue accounts.

processes.txt and processes.csv
- Top 200 processes by CPU, includes PID, CPU, memory, and path (when available)
Use to spot suspicious processes and where they run from.

services.csv
- Services with state, start mode, start account, and binary path
Use to identify persistence or suspicious service binaries (temp paths, weird names).

scheduled_tasks.csv
- Scheduled task name/path/state/author
Use to identify persistence via tasks.

recent_security_events.txt
- Last 200 Security log events for IDs:
  4624, 4625 (logons)
  4720-4726 (user account create/enable/password reset/disable/delete)
  4732, 4733 (added/removed from local groups)
Use to quickly review auth activity and account changes.

summary.txt
- Firewall status, listening TCP ports, local admins, and basic next steps
Use as a quick overview to start your investigation.

--------------------------------------------------

How to use it during a triage workflow (fast)

1) Open summary.txt
- Check firewall status
- Check listening TCP ports
- Check local admins list

2) If you see a weird port or PID:
- Use netstat.txt to find the PID (look for LISTENING and the PID column)
- Use processes.txt or processes.csv to identify the process name and path for that PID

3) Check persistence indicators:
- Review services.csv for weird service names, unusual StartName, or suspicious PathName
- Review scheduled_tasks.csv for unfamiliar tasks or odd authors

4) Check account activity:
- Review users_admins.txt for unexpected admins
- Review recent_security_events.txt for logon spikes, failed logons, or account creations/changes

--------------------------------------------------

What is suspicious (quick rules)

- A process path running from Temp, AppData, Downloads, Public, or random user folders
- Unknown process listening on common remote ports (3389, 445, 5985/5986)
- New or unexpected local admin accounts
- Services with random names or weird binary paths
- Scheduled tasks that run from temp paths or obscure scripts
- Lots of 4625 failures followed by 4624 success (possible brute force then success)

--------------------------------------------------

Notes and limitations

- Running without admin may reduce visibility for some process paths and security log access.
- processes.csv is best for sorting/filtering quickly.
- netstat.txt gives PIDs; processes.txt/csv helps map PID to name/path.

--------------------------------------------------

End of guide
