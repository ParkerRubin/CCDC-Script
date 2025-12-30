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
Now that backups are created, triage displays vulnerabiltiies and shit, manual tools are installed (download 64bit ones) and firewall is set, and watch list is displaying correctly.

Monitor processes, run watch every hour or so. 

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
