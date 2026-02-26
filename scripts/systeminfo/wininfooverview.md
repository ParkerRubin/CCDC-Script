Inventory Script User Guide

--------------------------------------------------

What this script does

Creates a snapshot of the system showing:

- Hostname and OS version
- IPv4 network configuration
- Listening TCP and UDP ports
- Which process owns each port
- Services tied to those processes
- Docker containers (if installed)

Purpose: identify what services the machine is exposing.

--------------------------------------------------

How to run

Run in the folder containing the script:

    .\Inventory.ps1

Save output somewhere specific:

    .\Inventory.ps1 -OutRoot C:\Temp

If script execution is blocked:

    Set-ExecutionPolicy Bypass -Scope Process -Force

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

Most important section.

Shows which process owns each listening port and related services.

Example:

    ProcId:1234  Proc:svchost
      Ports: 135/tcp, 445/tcp
      Svcs: RpcSs, LanmanServer

Use this to determine what program is exposing a port.

--------------------------------------------------

What is suspicious

- Unknown process listening
- Non-Windows process using 445, 3389, or 5985
- Random high-numbered listening port
- Ports listed with no associated service

--------------------------------------------------

Normal examples

- svchost using 135 or 445
- System using 135
- Web server using 80 or 443
- Domain controller using 389 or 636

--------------------------------------------------

When to use this script

Use when you need to identify:

- exposed services
- attack surface
- unexpected listeners
- possible lateral movement paths

--------------------------------------------------

End of guide
