How to Use the Triage Output (Beginner Guide)

When you run triage.ps1, it makes a folder like:

C:\IR\TRIAGE\COMPUTERNAME_YYYY-MM-DD_HHMM\

Inside are a bunch of .txt files + a few .csv files. Don’t try to read everything. Start with the stuff that gives you the quickest “is this box cooked?” signal.

The 5-minute starting path (do this first)
1) Open summary.txt first

This is your “dashboard.”

Firewall status (Domain/Private/Public enabled or not)

Listening TCP ports (what the machine is exposing)

Local admins list

Quick “what to check next” reminders

If summary.txt looks normal, the machine is probably not actively on fire.

2) Check users_admins.txt

This answers: “Did someone add a weird local admin?”
Look for:

Unknown usernames

“Enabled” accounts that shouldn’t exist

Admin group members you don’t recognize

Big red flag: random new user + in Administrators.

3) Check processes.txt (NOT the CSV)

This is the readable process list.
Look for:

Stuff running out of weird locations: C:\Users\...\AppData\Temp\ or random folders

Sketchy names that look like system files but slightly off (svch0st.exe, expl0rer.exe, etc.)

PowerShell or cmd running when nobody is doing admin work

Quick rule: if the path is in a user profile and it’s not Discord/Zoom/Chrome/etc, look closer.

4) Check netstat.txt

This answers: “Who is this box talking to?”
Look for:

Lots of outbound connections to random IPs

Weird listening ports you didn’t expect

A connection tied to a suspicious PID (you can match PID to processes.txt)

If you see something listening that shouldn’t be, that’s a “pause and investigate” moment.

5) Check recent_security_events.txt

This is your “did anyone mess with accounts/logins” log snapshot.
Look for:

Login failures spam (brute force attempts)

New user created

User added to admins

Account enabled/disabled

If you see user creation/admin group changes you didn’t do, treat it as hostile until proven otherwise.

What each file is for (simple)

summary.txt — quick overview, start here

system.txt — machine identity + OS + IPs

firewall.txt — firewall profile status (Domain/Private/Public)

users_admins.txt — local users + who’s in Administrators

processes.txt / processes.csv — running processes (txt = readable, csv = sortable)

services.csv — services (useful for spotting persistence)

scheduled_tasks.csv — scheduled tasks (also persistence)

netstat.txt — network connections + listening ports

shares.txt — shared folders (sometimes attackers open shares)

“What should I worry about?” cheat list
🚩 Big red flags

Unknown user in Administrators

Tasks/services pointing to weird paths (Temp/AppData/random folder)

Lots of outbound connections to strange IPs

Suspicious processes with no legit path

Security logs showing new users / admin group changes

✅ Usually normal (context matters)

svchost.exe, lsass.exe, explorer.exe

Browser processes (msedge, chrome)

Discord/Zoom/Teams (if people actually use them)

What to do when you spot something weird

Write down the name + path + PID

Search that PID in:

processes.txt

netstat.txt

Check if it shows up as a service/task:

services.csv

scheduled_tasks.csv

If it connects out AND has persistence (task/service), that’s usually not an accident.
