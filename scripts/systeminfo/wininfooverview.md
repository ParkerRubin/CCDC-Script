Inventory Script User Guide
--------------------------------------------------

What this script does

Creates a snapshot of the system showing:

- Hostname and OS version
- IPv4 network configuration
- Listening TCP and UDP ports
- Which process owns each port
- Services tied to those processes
- Enabled inbound firewall rules
- Local Administrators group membership
- Non-Microsoft scheduled tasks
- Startup registry entries (Run/RunOnce)
- Signature status of binaries behind listening ports
- LLMNR / mDNS / SSDP exposure
- Docker containers (if installed)

Purpose: identify what services the machine is exposing, whether
the firewall actually matches that exposure, and whether any
persistence or account changes have occurred.

--------------------------------------------------

How to run

Run in the folder containing the script:

    .\Inventory.ps1

Save output somewhere specific:

    .\Inventory.ps1 -OutRoot C:\Temp

If script execution is blocked:

    Set-ExecutionPolicy Bypass -Scope Process -Force

Run as Administrator. Several sections (local admins, scheduled
tasks, HKLM run keys, firewall rules) return incomplete or empty
results without elevation.

--------------------------------------------------

Output location

The script creates a folder:

    Inventory_COMPUTERNAME_TIMESTAMP

Inside that folder:

    inventory.txt

--------------------------------------------------

How to read the results

Listening Ports (Quick Summary)

Shows common listening ports such as:

- 3389 (RDP)
- 445 (SMB)
- 80 / 443 (web)
- 5985 / 5986 (WinRM)

Use this for a quick view of exposed services.

--------------------------------------------------

Required Ports (mapped)

Shows only known important ports.

Check whether these should exist on this system.

--------------------------------------------------

Other Listening Ports

All remaining listening ports not in the known list.

Unexpected entries should be investigated.

--------------------------------------------------

Evidence (grouped by process)

Shows which process owns each listening port and related services.

Example:

    ProcId:1234  Proc:svchost
      Ports: 135/tcp, 445/tcp
      Svcs: RpcSs, LanmanServer

Use this to determine what program is exposing a port.

--------------------------------------------------

Firewall Rules (enabled, inbound)

Every currently enabled inbound allow/block rule, by name, action,
and profile.

Cross-reference this against the listening-ports sections above.
A port showing up as LISTENING with no corresponding allow rule
means it's only reachable locally or the rule lives somewhere this
script didn't check. A broad set of legacy consumer-feature rules
(Cast to Device, Wi-Fi Direct, Network Discovery, Remote Assistance,
mDNS) still enabled after a hardening pass means the baseline
script only added new rules — it did not remove pre-existing allow
rules that predate it.

Use this to confirm the firewall baseline actually matches what's
running, not just that it applied without errors.

--------------------------------------------------

Local Administrators Group Membership

Every account and group currently in the local Administrators
group.

Compare against a known-good baseline taken before the competition
or before any suspected compromise. An account you don't recognize,
a service account, or a duplicate/near-duplicate username here is
one of the most common signs of privilege escalation.

--------------------------------------------------

Non-Microsoft Scheduled Tasks

All scheduled tasks outside the built-in \Microsoft\ path.

Most entries here will be legitimate (OneDrive, Edge update tasks,
vendor software). Anything with an unfamiliar name, a task pointed
at a script in a temp or user-writable directory, or a task set to
run at logon/startup that you can't account for is worth pulling
the full task definition on before dismissing it.

--------------------------------------------------

Startup Registry Entries (Run/RunOnce)

Contents of the HKLM and HKCU Run/RunOnce keys — programs set to
launch automatically at login.

This only covers Run/RunOnce keys. It does not cover services,
scheduled tasks (checked separately above), WMI event subscriptions,
or other persistence locations. Treat this as one data point, not
a complete persistence check.

--------------------------------------------------

Unsigned/Invalid-Signature Executables

Checks the binary behind every currently listening process for a
valid Authenticode signature. Only reports entries that are NOT
valid — an empty/"(none found)" result is the good outcome.

A process here means either an unsigned binary, a self-signed one,
or a signature that failed validation. Any of those is worth
identifying the file path and checking the hash against VirusTotal
before assuming it's benign — legitimate unsigned software exists,
but this is also exactly what a renamed or dropped malicious binary
looks like.

--------------------------------------------------

Name Resolution Poisoning Surface

Reports whether LLMNR has an explicit disable policy set, and
whether mDNS (5353/udp) or SSDP/UPnP (1900/udp) are currently
listening.

LLMNR and mDNS are both exploitable via Responder-style poisoning
attacks on a shared network segment — an attacker answers name
resolution requests before the real DNS server does, potentially
harvesting credentials. "No explicit policy set" means LLMNR is
enabled by Windows default. This section identifies exposure, it
does not fix it — disabling LLMNR and unneeded discovery protocols
is a firewall/policy change to make separately.

--------------------------------------------------

What is suspicious

- Unknown process listening
- Non-Windows process using 445, 3389, or 5985
- Random high-numbered listening port
- Ports listed with no associated service
- Firewall rules allowing traffic with no matching legitimate service
- Unrecognized accounts in Local Administrators
- Scheduled tasks running from temp/user-writable paths
- Run/RunOnce entries pointing to unfamiliar or relocated binaries
- Any entry in the Unsigned Executables section
- LLMNR/mDNS/SSDP enabled on a box that has no reason to need them

--------------------------------------------------

Normal examples

- svchost using 135 or 445
- System using 135
- Web server using 80 or 443
- Domain controller using 389 or 636
- lsass listening on a high ephemeral port (normal Windows behavior,
  still worth knowing it's the highest-value target on the box)
- OneDrive, Edge, and Windows Update tasks/run-keys on a standard
  desktop image

--------------------------------------------------

When to use this script

Use when you need to identify:

- exposed services
- attack surface
- unexpected listeners
- possible lateral movement paths
- whether firewall rules match actual exposure
- account or persistence changes since a known-good baseline

Run once early to establish a baseline on a known-clean system.
Run again after applying the firewall baseline script, and again
any time compromise is suspected, to compare against that baseline.

--------------------------------------------------

Relationship to firewall baseline script

This script detects and reports. It does not change anything on
the system.

The firewall baseline script controls exposure going forward.

Run this inventory script before and after applying the firewall
baseline to confirm what changed, and periodically afterward to
catch new listeners, new accounts, or new persistence that appear
later.

--------------------------------------------------

End of guide
