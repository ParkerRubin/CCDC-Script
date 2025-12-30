# CCDC-Script

**Install Git package:**

winget install --id Git.Git -e --source winget
VERIFY
git --version
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
______________
**RUN Git Script Files:**

First: **Set-ExecutionPolicy -Scope Process Bypass**

Next,

./(filename).ps1
ex. ./tools.ps1
run ls for names

Order: Snapshots → Triage → Tools → Firewall → Watch
___________________________

For snapshots, creates files with current proceeses, users, etc.
To rollback firewall             
**netsh advfirewall import "C:\CCDC\Backups\YYYYMMDD_HHMMSS\firewall.wfw"**
Time stamps are provided in file directory
_________
Accounts:

Guest:

Disable-LocalUser -Name "Guest"
Verify:
Get-LocalUser Guest

Admin:

Disable-LocalUser -Name "Administrator"
Verify:
Get-LocalUser Administrator
_________

Password Change:
Set-LocalUser -Name "username" -Password (Read-Host -AsSecureString)
_________
