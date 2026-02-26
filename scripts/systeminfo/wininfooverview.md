🧾 Inventory Script — Quick User Guide
What this script does

Makes a clean snapshot of:

OS + hostname

IP / network info

Open listening ports

Which process owns each port

Services tied to those processes

Docker containers (if present)

Basically: “what is this machine exposing right now?”

▶️ How to run
.\Inventory.ps1

Save somewhere specific:

.\Inventory.ps1 -OutRoot C:\Temp

If blocked:

Set-ExecutionPolicy Bypass -Scope Process -Force
📂 Where output goes

Creates folder:

Inventory_PCNAME_DATE

Inside:

inventory.txt
🔎 How to read results (fast)
Listening Ports (Quick Summary)

Shows common ports like:

3389 = RDP

445 = SMB

80/443 = web

5985/5986 = WinRM

👉 Quick “what’s exposed” view

Required Ports (mapped)

Only important known ports
👉 Check if they should exist on this system

Other Listening Ports

Everything else
👉 Weird = investigate

Evidence (grouped by process) ⭐

Most important section

Shows:

Proc: svchost
Ports: 135, 445
Svcs: RpcSs, LanmanServer

👉 Tells you what program owns the port

🚩 What’s suspicious

Unknown process listening

Non-Windows process on 445 / 3389 / 5985

Random high port listener

Ports but no service listed

✅ Normal examples

svchost → 135/445

System → 135

lsass → 389/636 (DC)

IIS / nginx → 80/443

🧠 When to use this

Use when you want:

exposed services

attack surface

lateral movement paths

unexpected listeners
