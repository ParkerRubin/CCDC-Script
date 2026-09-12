FirewallUpgrade.ps1 includes a backup inside for ONLY firewall rules.
This overview is for "FirewallUpgrade.ps1" NOT "firewall.ps1".

WRCCDC Firewall Baseline Script Overview
--------------------------------------------------

What this script does

Applies a scoring-safe Windows Firewall baseline that:

- Blocks inbound traffic by default
- Allows outbound traffic
- Preserves existing allow rules (to avoid breaking scoring)
- Allows only required service ports you specify
- Prompts interactively for allowed RDP source IP(s)/CIDR range(s)
- Optionally restricts RDP access to those sources
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
- RDP rule, restricted to the IP(s)/CIDR range(s) entered at runtime
  (falls back to RFC1918 private ranges if left blank)

This prevents:

- Random port listeners from being reachable
- Many lateral movement techniques
- Remote exploitation of non-required services
- Unauthorized inbound connections
- RDP access from sources outside the range you specify at runtime

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
- Team remote access not lost (as long as the correct RDP source
  range was entered when prompted)

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

Before running: know these two things

1) Required service port(s) and protocol(s)
   - Fill into AllowedInboundTCP / AllowedInboundUDP
   - TCP and UDP are separate port spaces: a service listening on
     UDP/53 is NOT reached by an allow rule for TCP/53, and vice
     versa. Confirm the actual protocol (netstat -ano on the running
     service) before filling in the array — a wrong-protocol entry
     creates a rule that does nothing and gives no error.

2) Your team's actual RDP source range
   - Usually your VPN-assigned subnet on the comp network, not your
     home IP or a broad guess.
   - Entered at runtime when the script prompts:
         "RDP allowed sources"
   - Accepts comma-separated IPs and/or CIDR ranges
     (e.g. 10.0.5.10,192.168.1.0/24)
   - Invalid entries are dropped and reported; leaving it blank
     falls back to RFC1918 ranges (10.0.0.0/8, 172.16.0.0/12,
     192.168.0.0/16) as a default, which is broader than a single
     known-good range.

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
       Get-NetFirewallRule

5) Scoring stability
   If scoring drops:
       add required port to AllowedInboundTCP or AllowedInboundUDP
       rerun script (you will be re-prompted for RDP sources)

--------------------------------------------------

When to use this script

- Immediately after initial access
- After confirming scoring services
- After compromise cleanup
- Before opening services externally
- When firewall state is unknown
- When ports/services changed
- When your team's RDP source range changes

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
