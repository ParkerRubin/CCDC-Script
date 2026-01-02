import openpyxl

IN_PATH = "Great Cretaceous Inject Timeline.xlsx"
OUT_PATH = "Great Cretaceous Inject Timeline_autofilled.xlsx"

NEW_HEADERS = [
    "Hostnames",
    "IPs",
    "OS",
    "Role",
    "Required Processes/Services",
    "Required Ports",
    "Good Checks/Commands",
    "Notes",
]

def suggestions_for(title: str) -> dict:
    t = title.lower().strip()

    base = {h: "" for h in NEW_HEADERS}

    def setv(**k):
        for kk, vv in k.items():
            base[kk] = vv

    if "zerologon" in t:
        setv(
            **{
                "Hostnames": "dc01",
                "IPs": "10.0.0.10",
                "OS": "Windows Server (2019/2022)",
                "Role": "Domain Controller (AD DS/DNS)",
                "Required Processes/Services": "lsass.exe; Netlogon; DNS; KDC",
                "Required Ports": "53/TCP+UDP, 88/TCP+UDP, 135/TCP, 389/TCP+UDP, 445/TCP, 464/TCP+UDP, 636/TCP, 3268/TCP",
                "Good Checks/Commands": "dcdiag; nltest /dbflag:0x2080ffff; Get-ADDomain; Get-WinEvent (System/Security); netstat -ano | findstr :445",
                "Notes": "Example assets for exploit evidence + AD health validation.",
            }
        )
    elif "siem" in t:
        setv(
            **{
                "Hostnames": "siem01",
                "IPs": "10.0.0.20",
                "OS": "Linux (Ubuntu 22.04 or similar)",
                "Role": "SIEM / log aggregation",
                "Required Processes/Services": "elasticsearch; kibana; logstash/ingest; syslog/agent",
                "Required Ports": "5601/TCP (UI), 9200/TCP (ES), 5044/TCP (Beats/ingest), 514/UDP (syslog), 22/TCP (SSH)",
                "Good Checks/Commands": "systemctl status elasticsearch kibana; ss -lntup; df -h; tail -n 200 /var/log/*",
                "Notes": "Swap in whatever SIEM you actually run (Splunk/Wazuh/ELK/etc.).",
            }
        )
    elif "code scanning" in t or "ci/cd" in t:
        setv(
            **{
                "Hostnames": "git01, runner01",
                "IPs": "10.0.0.30, 10.0.0.31",
                "OS": "Linux (Git server) + Linux/Windows (runner)",
                "Role": "SCM + CI/CD runner",
                "Required Processes/Services": "git service (GitLab/Gitea); runner service; scanner (semgrep/trivy/sonarqube)",
                "Required Ports": "443/TCP (web), 22/TCP (SSH), 80/TCP (optional), 9000/TCP (SonarQube example)",
                "Good Checks/Commands": "curl -I https://git01; systemctl status gitlab-runner; verify pipeline logs; confirm secrets/tokens",
                "Notes": "Example infra for code scanning pipeline inject.",
            }
        )
    elif "code review" in t or "threat model" in t:
        setv(
            **{
                "Hostnames": "repo01",
                "IPs": "N/A",
                "OS": "N/A",
                "Role": "Documentation / SDLC",
                "Required Processes/Services": "N/A",
                "Required Ports": "N/A",
                "Good Checks/Commands": "Review repo; run tests/lints; map trust boundaries + data flows",
                "Notes": "Mostly paperwork deliverable, not host-based.",
            }
        )
    elif "onboarding" in t:
        setv(
            **{
                "Hostnames": "ad01, file01, vpn01",
                "IPs": "10.0.0.10, 10.0.0.40, 10.0.0.50",
                "OS": "Windows Server (AD/File) + Linux/Appliance (VPN)",
                "Role": "Identity + file shares + remote access",
                "Required Processes/Services": "AD DS; DNS; SMB; VPN daemon",
                "Required Ports": "53, 88, 389, 445, 443 (VPN/web), 3389 (if RDP allowed)",
                "Good Checks/Commands": "List accounts/groups; verify MFA; confirm share perms; audit last logons",
                "Notes": "Example onboarding inventory items.",
            }
        )
    else:
        # default for non-technical / comms / feedback injects
        setv(
            **{
                "Hostnames": "N/A",
                "IPs": "N/A",
                "OS": "N/A",
                "Role": "Documentation / comms",
                "Required Processes/Services": "N/A",
                "Required Ports": "N/A",
                "Good Checks/Commands": "N/A",
                "Notes": "Non-technical inject; inventory fields not applicable.",
            }
        )

    return base

def main():
    wb = openpyxl.load_workbook(IN_PATH)
    ws = wb.active

    start_col = 10  # column J

    # write headers if empty
    for i, h in enumerate(NEW_HEADERS):
        cell = ws.cell(1, start_col + i)
        if cell.value is None or str(cell.value).strip() == "":
            cell.value = h

    # find Inject Title col (fallback to 2)
    title_col = 2
    for c in range(1, ws.max_column + 1):
        if (ws.cell(1, c).value or "").strip() == "Inject Title":
            title_col = c
            break

    for r in range(2, ws.max_row + 1):
        title = ws.cell(r, title_col).value
        if not title:
            continue
        sug = suggestions_for(str(title))
        for i, h in enumerate(NEW_HEADERS):
            cell = ws.cell(r, start_col + i)
            if cell.value is None or str(cell.value).strip() == "":
                cell.value = sug[h]

    wb.save(OUT_PATH)

if __name__ == "__main__":
    main()
