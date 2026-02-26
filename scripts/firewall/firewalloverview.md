Firewallupgrade.ps1 includes a backup inside for ONLY firewall rules. This overview is for "firewallupgrade.ps1" NOT "firewall.ps1".

WRCCDC Firewall Baseline Script Overview

--------------------------------------------------

What this script does

Applies a scoring-safe Windows Firewall baseline that:

- Blocks inbound traffic by default
- Allows outbound traffic
- Preserves existing allow rules (to avoid breaking scoring)
- Allows only required service ports you specify
- Optionally restricts RDP access
- Enables firewall logging
- Removes only prior WRCCDC_* rules
- Creates a restore-ready firewall backup

Purpose: reduce exposed attack surface without disrupting required services.

--------------------------------------------------

What gets locked down

Default inbound behavior becomes:

    Block all unsolicited inbound traffic

Only inbound traffic allowed:

- Existing Windows/service allow rules
- Ports explicitly listed in AllowedInboundTCP/UDP
- Optional RDP rule (restricted if configured)

This prevents:

- Random port listeners from being reachable
- Many lateral movement techniques
- Remote exploitation of non-required services
- Unauthorized inbound connections

--------------------------------------------------

What remains allowed (intentionally)

To avoid breaking scoring and services:

- Existing inbound allow rules remain active
- All outbound traffic remains allowed
- Local Windows service rules remain intact
- Domain/service dependencies remain functional

This ensures:

- Scoring agents still connect
- Required services still reachable
- Domain communications not broken
- Team remote access not lost

--------------------------------------------------

What the firewall does NOT handle

Firewall controls network exposure only.
It does not stop or detect:

- Malicious processes already running
- Persistence via services or tasks
- Credential theft or abuse
- Local privilege escalation
- Scheduled task backdoors
- Registry persistence
- Malware beaconing outbound
- Living-off-the-land execution

Firewall reduces entry points, not compromise state.

--------------------------------------------------

What to monitor after applying

After baseline deployment, check:

1) Required services reachable
   - Web
   - RDP
   - App ports
   - Domain services

2) Firewall log activity
   File:
       %SystemRoot%\System32\LogFiles\Firewall\pfirewall.log

   Look for:
   - Repeated blocked inbound attempts
   - Unexpected allowed ports
   - External scanning

3) New listening ports
   Use:
       netstat -ano
       or inventory/triage scripts

4) Unexpected inbound allow rules
   Check:
       firewall_rules.csv
       or Get-NetFirewallRule

5) Scoring stability
   If scoring drops:
       add required port to AllowedInboundTCP
       rerun script

--------------------------------------------------

When to use this script

- Immediately after initial access
- After confirming scoring services
- After compromise cleanup
- Before opening services externally
- When firewall state is unknown
- When ports/services changed

--------------------------------------------------

Rollback

Firewall backup is saved as:

    C:\fwbackup_TIMESTAMP.wfw

Restore with:

    netsh advfirewall import C:\fwbackup_TIMESTAMP.wfw

--------------------------------------------------

Relationship to triage scripts

Firewall baseline controls exposure.

Triage scripts detect:

- malicious processes
- persistence
- abnormal services
- suspicious tasks
- account abuse

Both should be used together.

--------------------------------------------------

Key operator reminder

Firewall baseline reduces attack surface.
It does not mean the system is clean.

Always follow with triage.

--------------------------------------------------

End of overview
