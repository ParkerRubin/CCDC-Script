# Windows Command Cheat Sheet (Blue Team / CCDC)

Not the fancy scripts, just the raw commands worth having memorized or
copy-pasted mid-comp when you need something fast.

---

## Network basics

**`ipconfig /all`**
Your IP, gateway, DNS, MAC address. First thing to check if something
feels off about where traffic's going.

**`arp -a`**
IP-to-MAC table for your local network. If an IP you know suddenly maps
to a MAC that doesn't match, that's classic ARP spoofing.

**`route print`**
Routing table. Look for a default gateway that doesn't match what it
should, or a static route that showed up out of nowhere.

**`nslookup <domain>`**
Manual DNS lookup. Good for checking where a sketchy domain actually
points before you decide whether to worry about it.

**`net share`**
Lists active SMB shares on the box. An unexpected share is a common way
attackers stage stuff for exfil or move laterally - worth knowing what's
supposed to be shared vs what showed up on its own.

---

## Processes + PIDs

**`netstat -ano`**
Every connection and listening port, with the owning PID. Your starting
point for "what's talking to what."

**`tasklist /svc`**
Turns a PID into a process name and tells you what Windows services are
riding on it.

**`tasklist /v`**
Same idea but verbose - window titles, CPU time, session info. No admin
needed, good fallback if PowerShell's locked down.

**`wmic process where processid=<PID> get commandline`**
The thing `tasklist` won't show you: the actual command line args a
process was launched with. This is where the real signal is -
`powershell.exe` alone means nothing, `powershell.exe -enc <base64 blob>`
means a lot.

**`Get-Process -Id <PID> | Select Path`** (PowerShell)
Quick way to get the file path behind a PID without opening Task
Manager.

---

## Accounts + access

**`whoami /priv`**
Shows what privileges your current session actually has. Useful right
after you elevate, to confirm what you can and can't do.

**`whoami /groups`**
Group memberships for whoever you're logged in as.

**`net user`**
Every local account on the box.

**`net user <username>`**
Deep-dive on one account - last logon, password age, group membership.

**`net localgroup administrators`**
Who's actually in local admins. Check this against what you expect -
anyone extra here is a big deal.

---

## System identity

**`hostname`**
Sanity check you're on the box you think you're on.

**`systeminfo`**
OS version, patch level, uptime, installed hotfixes, all in one dump.
Handy for quickly checking if a box is missing a patch tied to a known
CVE.

**`wmic qfe list`**
Just the installed patches, faster to skim than full `systeminfo` if
that's all you need.

---

## Persistence checks

**`schtasks /query /fo LIST /v`**
Full detail on every scheduled task from the command line - what runs,
when, and as who.

**`reg query HKLM\Software\Microsoft\Windows\CurrentVersion\Run`**
Peek at one startup registry key at a time. Swap `HKLM` for `HKCU` to
check the current user's version instead of the machine-wide one.

**`net start`**
Quick list of what services are actually running right now.

---

## File / binary verification

**`Get-FileHash <path> -Algorithm SHA256`** (PowerShell)
Hash a file so you can check it against VirusTotal.

**`Get-AuthenticodeSignature <path>`** (PowerShell)
Tells you if a binary is signed and whether that signature is valid.
Unsigned + sitting somewhere weird (AppData, Temp) is a red flag.

---

## Getting scripts to actually run

**`Set-ExecutionPolicy Bypass -Scope Process -Force`**
Lets scripts run for just this PowerShell window/session without
touching the system-wide policy. This is also a flag attackers abuse in
malicious one-liners, so seeing `-ep bypass` in a process you didn't run
yourself is worth investigating, not just using it yourself without a
second thought.

**`Get-ExecutionPolicy -List`**
Check what your current policy actually is before you override it.

---

## Quick mental model for using all this

1. `netstat -ano` → see something weird
2. `tasklist /svc` or `Get-Process -Id` → what process/service owns it
3. `wmic process ... get commandline` → what was it actually told to do
4. `Get-AuthenticodeSignature` / hash + VirusTotal → is the binary legit
5. `whoami /priv`, `net localgroup administrators`, `schtasks` → check if
   it's touched accounts or persistence too

That's basically the same flow your triage scripts automate - this is
just the manual version for when you need one specific answer fast
instead of a full report.
