WRCCDC Full Triage Script User Guide
--------------------------------------------------

What this script does

Creates a full triage case folder containing system, user, service,
network, process, task, and event log data for fast review.

It also builds a SUMMARY.txt file with quick-view sections so you
can see important findings immediately without digging through
all output files.

Any section that fails to collect writes a matching *_error.txt
file instead of silently producing an empty result.

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

Any of the above can instead appear as <name>_error.txt if that
section failed to collect (see "Reading error files" below).

--------------------------------------------------

How to use it (fast workflow)

1) Open SUMMARY.txt first.
   - Check for any mention of failed sections, or check the case
     folder for *_error.txt files
   - Check Admins (quick view)
   - Check Non-Microsoft scheduled tasks
   - Check Process hints - review the command line next to each
     hit, not just the process name
   - Check Enabled local users

2) If something looks suspicious:
   - Use process_pid_map.txt to match PID to name/path
   - Use process_hints.txt for the full command line and parent
     process ID of anything flagged
   - Use netstat_ano.txt to match open ports to PIDs
   - Check services_autostart.txt for persistence
   - Check tasks_non_microsoft.txt for suspicious tasks

3) Review event logs for:
   - Account creation or modification
   - Failed or unusual logons
   - Service or system errors

--------------------------------------------------

Reading error files

Sections that fail to collect (permissions, missing data, query
errors) write a <name>_error.txt file instead of an empty or
partial output file. This matters most for:

- event_security_error.txt - the Security log can fail to read for
  audit-policy/SACL reasons even when running as Administrator. An
  empty or missing event_security_lastXXh.txt does NOT necessarily
  mean no security events occurred - check for this error file
  before treating a quiet Security log as a clean one.
- admins_error.txt / local_users_error.txt - a query failure here
  looks identical to "no results" unless you check for the error
  file specifically.

Treat any *_error.txt as an unknown, not a clean result, and re-run
with elevation or investigate the specific error message inside it.

--------------------------------------------------

Containment Mode

If -ContainmentMode is used:

- Disables running scheduled tasks that are not under \Microsoft\
- Logs the exact action taken into SUMMARY.txt under
  "CONTAINMENT ACTIONS TAKEN: disable non-Microsoft running
  scheduled tasks"

It does not:
- Kill processes
- Delete services
- Modify firewall
- Remove users
- Isolate the network

This is one narrow containment step, not full incident containment.
Use only if you believe malicious scheduled tasks are actively
running, and expect to take further manual action for anything
beyond that.

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
- Process path and command-line visibility
- Scheduled task visibility

A process name matching the hint list (powershell, rundll32,
regsvr32, mshta, certutil, etc.) is common and not inherently
suspicious - most run legitimately on any Windows box. The command
line captured for each hit is what actually distinguishes normal
use from suspicious use.

SUMMARY.txt is designed for rapid operator review.
Deep investigation should use the detailed dump files.

--------------------------------------------------

End of guide
