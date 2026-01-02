$OutDir = ".\inject-responses"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Write-InjectFile {
    param ($Name, $Content)

    $SafeName = $Name -replace '[^a-zA-Z0-9_-]', '_'
    $Path = Join-Path $OutDir "$SafeName.txt"
    $Content | Out-File -Encoding UTF8 $Path
}

# ===============================
# Network Inventory (FULL ENV)
# ===============================
Write-InjectFile "Network_Inventory" @"
Inject: Network Inventory

Hostnames:
- dc01
- web01
- db01
- siem01
- fw01

IPs:
- 10.0.0.10
- 10.0.0.20
- 10.0.0.30
- 10.0.0.40
- 10.0.0.1

Operating Systems:
- Windows Server 2022 (dc01)
- Ubuntu 22.04 (web01, siem01)
- Windows Server 2019 (db01)
- Network Appliance OS (fw01)

Roles:
- Domain Controller
- Web Server
- Database Server
- SIEM
- Firewall

Required Services:
- AD DS, DNS, Kerberos
- HTTP/HTTPS
- Database Engine
- Log Ingestion
- NAT / Filtering

Required Ports:
- 53, 88, 389, 445
- 80, 443
- 3306 / 1433
- 514, 5044
"@

# ===============================
# IR Policy (NON-TECHNICAL)
# ===============================
Write-InjectFile "IR_Policy" @"
Inject: IR Policy

This inject is documentation-based.

Artifacts:
- Incident Response Policy
- Escalation Procedures
- Contact List

No hosts, IPs, or ports are directly involved.
"@

# ===============================
# Evidence of Zerologon
# ===============================
Write-InjectFile "Evidence_of_Zerologon" @"
Inject: Evidence of Zerologon

Relevant System:
- Hostname: dc01
- IP: 10.0.0.10
- OS: Windows Server 2022
- Role: Domain Controller

Affected Services:
- Netlogon
- Kerberos
- LSASS
- DNS

Required Ports:
- 88 (Kerberos)
- 389 (LDAP)
- 445 (SMB)

Validation Performed:
- dcdiag
- nltest
- Event Log Review
"@

# ===============================
# SIEM Documentation
# ===============================
Write-InjectFile "SIEM_Documentation" @"
Inject: SIEM Documentation

SIEM Host:
- Hostname: siem01
- IP: 10.0.0.40
- OS: Ubuntu 22.04
- Role: Log Aggregation / SIEM

Services:
- Elasticsearch
- Kibana
- Log Ingest Agent

Ports:
- 5601 (Web UI)
- 9200 (Backend)
- 5044 (Ingest)
- 514 (Syslog)
"@

# ===============================
# Code Scanning / CI/CD
# ===============================
Write-InjectFile "Code_Scanning_CICD" @"
Inject: Code Scanning CI/CD

Systems:
- git01 (Source Control)
- runner01 (CI Runner)

Services:
- Git Service
- CI Runner
- Static Code Scanner

Ports:
- 443 (Web)
- 22 (SSH)
- 9000 (Scanner UI)

Purpose:
Automated detection of insecure code and dependencies.
"@

Write-Host "Inject response files generated in $OutDir"
