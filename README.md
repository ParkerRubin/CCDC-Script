# CCDC-Script
_____________
**Install Git package:**

winget install --id Git.Git -e --source winget
VERIFY
git --version
_____________
Wifi is down, Git is not accessible, try SSH through PuTTy.

Putty needs Ip/Host name.
Run: ipconfig 

Proceed with Git Clone.
______________
**Git Clone:**

(place yourself in base directory)
cd ~

git clone <repository_url>
ex. **git clone https://github.com/ParkerRubin/CCDC-Script.git** 

THEN cd <repo name>
ex. **cd CCDC-Script**

AFTER cd <sub folder>
ex. **cd scripts**
run ls for script names
______________
**RUN Git Script Files:**

First: **Set-ExecutionPolicy -Scope Process Bypass**

Next,

./(filename).ps1
ex. ./tools.ps1

Order: Snapshots → Triage → Tools → Firewall → Watch
___________________________
**Snapshots**   ./snapshots.ps1     

**netsh advfirewall import "C:\CCDC\Backups\YYYYMMDD_HHMMSS\firewall.wfw"**
Time stamps are provided in file directory

Roll back firewall rules thats it.
_________
**Users/Accounts:**

Guest Accounts:

Disable-LocalUser -Name "Guest"
   To Verify:
Get-LocalUser Guest

Admin Accounts:

Disable-LocalUser -Name "Administrator"
   Verify:
Get-LocalUser Administrator
_________

Password Change:
Set-LocalUser -Name "username" -Password (Read-Host -AsSecureString)
(invisible box to type password into)
_________
