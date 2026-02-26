WRCCDC Full Triage Script User Guide

--------------------------------------------------

What this script does

Creates a full triage case folder containing system, user, service,
network, process, task, and event log data for fast review.

It also builds a SUMMARY.txt file with quick-view sections so you
can see important findings immediately without digging through
all output files.

Optional ContainmentMode can disable running non-Microsoft
scheduled tasks.

--------------------------------------------------

How to run

Basic run:

    .\triage_full.ps1

Specify a custom base directory:

    .\triage_full.ps1 -BaseDir C:\IR

Change event log lookback window (default 12 hours):

    .\triage_full.ps1 -LookbackHours 24

Enable containment mode (disables running non-Microsoft tasks):

    .\triage_full.ps1 -ContainmentMode

If script execution is blocked:

    Set-ExecutionPolicy Bypass -Scope Process -Force

Then run again.

Run as Administrator for best visibility.

--------------------------------------------------

Output location

Creates:

    C:\WRCCDC\triage_YYYYMMDD_HHMMSS\

Inside that folder:

    SUMMARY.txt
    admins.txt
    local_users.txt
    services_autostart.txt
    services_running.txt
    tasks_all.txt
    tasks_non_microsoft.txt
    netstat_ano.txt
    ipconfig_all.txt
    arp_a.txt
    route_print.txt
    shares.txt
    firewall_profiles.txt
    process_hints.txt
    process_pid_map.txt
    event_system_lastXXh.txt
    event_application_lastXXh.txt
    event_security_lastXXh.txt

--------------------------------------------------

How to use it (fast workflow)

1) Open SUMMARY.txt first.
   - Check Admins (quick view)
   - Check Non-Microsoft scheduled tasks
   - Check Process hints
   - Check Enabled local users

2) If something looks suspicious:
   - Use process_pid_map.txt to match PID to name/path
   - Use netstat_ano.txt to match open ports to PIDs
   - Check services_autostart.txt for persistence
   - Check tasks_non_microsoft.txt for suspicious tasks

3) Review event logs for:
   - Account creation or modification
   - Failed or unusual logons
   - Service or system errors

--------------------------------------------------

Containment Mode

If -ContainmentMode is used:

- Disables running scheduled tasks that are not under \Microsoft\
- Logs actions taken into SUMMARY.txt

It does not:
- Kill processes
- Delete services
- Modify firewall
- Remove users

Use only if you believe malicious tasks are actively running.

--------------------------------------------------

What this script does NOT do

- Does not change firewall rules
- Does not remove services
- Does not reset passwords
- Does not modify registry
- Does not delete files

It is primarily evidence collection with optional light task containment.

--------------------------------------------------

When to use this script

- Immediately after gaining system access
- When suspicious behavior is observed
- After suspected compromise
- Before major system hardening
- During incident response or competition scoring issues

--------------------------------------------------

Notes

Running without Administrator may limit:
- Security event log access
- Process path visibility
- Scheduled task visibility

SUMMARY.txt is designed for rapid operator review.
Deep investigation should use the detailed dump files.

--------------------------------------------------

End of guide
