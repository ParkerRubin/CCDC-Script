# CCDC-Script

Change local administrator password.


Install Git package:

winget install --id Git.Git -e --source winget
VERIFY
git --version
______________
Git Clone:

(place yourself in regular directory)
cd ~

git clone <repository_url>
ex. git clone https://github.com/ParkerRubin/CCDC-Script.git

THEN cd <repo name>
ex. cd CCDC-Script

RUN ls (see inside file)

AFTER cd <sub folder>
ex. cd scripts
RUN ls (see inside file)

RUN Git Files:

./tools.ps1
./triage.ps1
And etc to run additional files.

IF execution bypass needed, run
Set-ExecutionPolicy -Scope Process Bypass

Order: Snapshots → Triage → Tools → Firewall → Watch
___________________________
Now that backups are created, triage displays vulnerabiltiies and shit, manual tools are installed (download 64bit ones) and firewall is set, and watch list is displaying correctly.

Monitor processes, run watch every hour or so. 
