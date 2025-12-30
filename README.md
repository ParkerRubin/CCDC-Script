# CCDC-Script

Install Git package:

winget install --id Git.Git -e --source winget
VERIFY
git --version
______________
Git Clone:

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

Order: Snapshots → Triage → Tools → Firewall → Watch
