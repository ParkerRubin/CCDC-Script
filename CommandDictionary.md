# CDCC Command Dictionary

A lookup reference for blue-team competitions (CCDC / CPTC / NCAE) plus CTF and AD notes. Ctrl-F for what you need, or use the table of contents.

## Contents
- [Grep & searching](#grep--searching)
- [File permissions & attributes](#file-permissions--attributes)
- [Find command patterns](#find-command-patterns)
- [SSH hardening](#ssh-hardening)
- [PAM (auth & passwords)](#pam-auth--passwords)
- [sysctl / kernel hardening](#sysctl--kernel-hardening)
- [sudoers](#sudoers)
- [Users & groups](#users--groups)
- [Web servers (nginx / apache)](#web-servers-nginx--apache)
- [Firewall (UFW / iptables)](#firewall-ufw--iptables)
- [Services & systemd](#services--systemd)
- [Networking & ports](#networking--ports)
- [Hidden data & stego](#hidden-data--stego)
- [Log analysis](#log-analysis)
- [Packages & disk cleanup](#packages--disk-cleanup)
- [GRUB & lockdown](#grub--lockdown)
- [Cron & scheduled tasks](#cron--scheduled-tasks)
- [Bash persistence checks](#bash-persistence-checks)
- [Offensive / CTF](#offensive--ctf)
- [Windows & PowerShell](#windows--powershell)
- [Active Directory](#active-directory)
- [Docker](#docker)
- [MikroTik router (NCAE)](#mikrotik-router-ncae)
- [Netplan / IP config](#netplan--ip-config)
- [Vim quick keys](#vim-quick-keys)
- [Distro notes (Gentoo / Alpine / RedHat)](#distro-notes-gentoo--alpine--redhat)
- [Service config file reference](#service-config-file-reference)

---

## Grep & searching

```bash
grep -r "word" .            # search every file in a dir (recursive)
grep -i "word" file         # case-insensitive
grep -w "Donald" file       # exact word only (McDonald won't match)
grep "text" *               # every file in current dir
grep -A 4 "text" file       # match + 4 lines after
grep -B 4 "text" file       # match + 4 lines before
grep -C 4 "text" file       # match + 4 lines before and after
grep -l "text" *            # print filenames that match, not the lines
grep -c "text" *            # count matches
grep -n "text" file         # show line numbers
```
War story: `grep -r "kernel.kptr_restrict" /` found the file that was overwriting the value → `/etc/sysctl.d/10-kernel-hardening.conf`.

```bash
cat * | grep -i passw*      # sweep a dir for passwords
grep -Rin file_upload .     # find upload handlers (web)
grep -irln "text"           # recursive, case-insensitive, filenames only
```

---

## File permissions & attributes

**chmod** works as `user,group,other`, where `r=4 w=2 x=1` (so `7` = all):
```bash
chmod 600 file              # owner read/write only
chmod 640 -R /root          # lock down all of /root (stops privesc)
chmod 600 /etc/passwd /etc/shadow   # make sure these aren't world-writable
```

**Immutable / append-only attributes:**
```bash
chattr +i file              # immutable: nobody (not even root) can modify
chattr -i file              # remove immutable
chattr +a file              # append-only
lsattr file                 # check which attributes are set
```
Find all immutable files (point it where it counts, `/` takes forever):
```bash
find . | xargs -I file lsattr -a file 2>/dev/null | grep '^....i'
sudo lsattr / -R 2>/dev/null | grep "\----i"
```
If `chattr` isn't working, reinstall it.

**ACLs (finer-grained than chmod):**
```bash
getfacl file                                  # view ACL
setfacl -m g:testsubjects:--- /home/glados/   # give a group zero perms
setfacl -x g:testsubjects /home/glados/       # remove that group entry
```

---

## Find command patterns

```bash
find / -perm -4000 -type f 2>/dev/null        # SUID files (privesc risk)
find / -xdev -perm -4000 2>/dev/null          # SUID, stay on one filesystem
find / -perm -o+w -not -type l 2>/dev/null    # world-writable files
find /home/*/ -type f -iname "*.jpg"          # a filetype across all users
find / -name "*.sh" -o -name "*.py"           # scripts by extension
find ~/.ssh                                     # current user's ssh keys
find / -type d -iname "*.ssh"                  # all .ssh directories on box
```
Make sure `bash` itself doesn't have the SUID bit.

---

## SSH hardening

Config lives at `/etc/ssh/sshd_config`. Force protocol 2 and set:
```
PermitRootLogin no
PermitEmptyPasswords no
```
Ownership should be root:
```bash
chown root /etc/ssh/sshd_config
chgrp root /etc/ssh/sshd_config
```
- **X11 forwarding**: SSH can hand out a GUI over the session. Not evil by default, but can be abused. Watch for it.
- **Public key auth**: if you switch to keys, disable password login.
- **DenyGroups** in the config blocks whole groups from logging in.

Set up key auth:
```bash
cp /root/id_rsa.pub /home/user/.ssh/authorized_keys
ssh-keygen -f key -N ''          # generate a keypair, no passphrase
ssh -i ~/.ssh/id_rsa root@localhost
```
Firewall: `ufw allow 22` or `ufw allow 'OpenSSH'`.

---

## PAM (auth & passwords)

PAM lives in `/etc/pam.d/`. Modules live in `/lib/x86_64-linux-gnu/security/`.

**Classic backdoor:** in `/etc/pam.d/common-auth`, a line reading `auth requisite pam_permit.so` skips the first auth stage. Change it to `pam_deny.so`.

Verify modules aren't tampered by comparing hashes (if `pam_permit.so` and `pam_deny.so` share a hash, one was swapped):
```bash
md5sum pam_permit.so
sha256sum pam_permit.so
```

**Lockout policy** in `common-auth`:
```
auth requisite pam_faillock.so preauth
auth [default=die] pam_faillock.so authfail
auth sufficient pam_faillock.so authsucc
```

**Password history** in `common-password`:
```
password required pam_unix.so remember=1000
```

**Password quality** in `common-password`:
```
password requisite pam_pwquality.so retry=3 minlen=12 ucredit=-1 lcredit=-1 ocredit=-1 dcredit=-1
```

Reinstall PAM if it breaks:
```bash
pam-auth-update --package --force
apt-get -y --reinstall install libpam-runtime libpam-modules
```

`pwquality.conf` block:
```
difok = 5
minlen = 10
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
dictcheck = 1
usercheck = 1
minclass = 4
maxrepeat = 3
maxclassrepeat = 4
```

---

## sysctl / kernel hardening

Configs: `/etc/sysctl.conf` and `/etc/sysctl.d/10-kernel-hardening.conf`. Apply with `sysctl -p`.
```
net.ipv4.tcp_syncookies = 1     # blocks SYN flood attacks
kernel.randomize_va_space = 2   # ASLR on, buffer overflows harder
kernel.sysrq = 0                # kill magic-key functions at console
kernel.kptr_restrict = 2        # hide kernel memory pointers
```

---

## sudoers

`/etc/sudoers` sets groups and their privileges. `Defaults !authenticate` has to go (it lets sudo run without a password).

---

## Users & groups

```bash
id -u user                      # get a user's UID
userdel -r user                 # remove user + their home
adduser user                    # (better than useradd, sets up home/prompts)
```
UID rules: `root=0`, services `<1000`, real users `>999`.

Lock down system accounts:
- `/etc/shadow` → system accounts should have `!`, `*`, or `*!` (no login).
- `/etc/passwd` → shells should be `/usr/sbin/nologin` or `/bin/false`.

Password aging in `/etc/login.defs`: set `PASS_MAX_DAYS 30`, `PASS_MIN_DAYS 0-10`, `PASS_WARN_AGE 14`. Also update the encryption method there.

Quick user loop:
```bash
for i in {1..10}; do sudo useradd user$i; done
```

---

## Web servers (nginx / apache)

**Nginx** config: `/etc/nginx/nginx.conf`, sites at `/etc/nginx/sites-available/default`.
- `server_tokens off;` (hide version)
- Add a trailing slash to location blocks, e.g. `/cdn/`
- Make sure root is served from the right place
- Own the webroot: `chown www-data:www-data /var/www/html`

**Apache** config: `/etc/apache2/apache2.conf`, `/etc/apache2/sites-available/000-default.conf`. In `conf-enabled/security.conf` set `ServerTokens Prod` and `ServerSignature Off`.

Manage: `systemctl status|restart|stop nginx`. Allow ports 80 / 443.

**Self-signed SSL cert for nginx:**
```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt \
  -subj "/CN=localhost/O=Acme/OU=IT Department/L=Geneva/ST=Geneva/C=CH"
```
Check an existing cert (expiry, subject/issuer):
```bash
openssl x509 -in /etc/nginx/ssl/nginx.crt -text -noout | head
```
Restart nginx after cert changes.

---

## Firewall (UFW / iptables)

```bash
sudo ufw enable
sudo ufw app list
sudo ufw allow 'AppName'
sudo ufw delete allow 'AppName'
sudo ufw allow from <Web_Server_IP> to any port 3306   # scope a rule to a host
```

**iptables** (for Gentoo/Alpine and where ufw isn't used):
```bash
rc-update add iptables default
```
Known ufw error when kernel modules can't load (note it, don't panic):
```
ERROR: problem running ufw-init
modprobe: ERROR: could not insert 'nf_conntrack_ftp': Operation not permitted
```

---

## Services & systemd

```bash
systemctl status ssh                     # newer systems
service ssh status                       # older systems
systemctl stop <service>                 # stop it
systemctl list-unit-files                # ALL services, incl. dead ones
systemctl list-units -t service --state=running
systemctl list-timers --all              # find systemd timers
```
Malicious services/timers hide in `/etc/systemd/system/` and `/usr/lib/systemd/system/`. `cat` the `.service` / `.timer` file to see what it runs BEFORE removing it, then stop → disable → delete. Timers also at `/etc/systemd/system/*.timer`.

For any unknown service, check `/etc/systemd/system/` for its unit + config.

---

## Networking & ports

```bash
netstat -tulpn        # open ports + listening services (use sudo to see PIDs)
ss -plunt             # same idea, modern replacement
lsof -i               # open network connections
lsof -i :80           # what's using port 80
ps <PID>              # name the process behind a port
netstat -ano          # Windows
```

---

## Hidden data & stego

```bash
steghide extract -sf meme.jpg      # pull hidden file out of an image (blank passphrase)
getfattr -d secret.txt             # dump extended attributes
getfattr -n user.shhh secret.txt   # read a specific attribute (found via getfattr -d)
strings binary                     # readable text inside a binary
cat binary                         # quick peek
```

---

## Log analysis

```bash
awk '{print $1}' access.log | sort | uniq -c   # count hits per IP
tail -f /var/log/auth.log &                    # watch logins live, keep your shell
```
Log locations: `/var/log/auth.log`, `/var/log/secure/`, `/var/log/nginx/`, `/var/log/messages` (Alpine sshd errors).

---

## Packages & disk cleanup

```bash
apt list --installed | grep -v automatic     # manually installed pkgs
sudo apt remove wireshark                     # remove a tool
sudo dnf upgrade                              # RedHat update
sudo dnf -y install <pkg>                     # RedHat install
```
Common attacker tools to look for: `john`, `wireshark`, `nikto`, `hydra`, `nmap`, `snort`, `ophcrack`.

Free up space mid-competition:
```bash
apt-get clean
apt-get autoremove -y
journalctl --vacuum-size=100M
docker system prune -a
```
```bash
df -ah        # disk usage, all files
```

---

## GRUB & lockdown

`/sys/kernel/security/lockdown` shows lockdown state. To enforce it, edit `/etc/default/grub`:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash lockdown=integrity,confidentiality"
```
Then `sudo update-grub`.

- Bootloader password: `grub2-mkpasswd-pbkdf2`
- Check `/etc/grub.d/40_custom` for unauthorized users
- Set `check_signatures=enforce` and export it

---

## Cron & scheduled tasks

```bash
crontab -l                       # current user's crontabs
```
- Root crontabs: `/etc/crontab` (and `/etc/cron.*`)
- User crontabs: `/var/spool/cron/crontabs`

Idea: schedule a job to restart critical services if they go down.

---

## Bash persistence checks

Malicious aliases hide in shell startup files:
- User: `~/.bashrc`
- System: `/etc/bash.bashrc`
- Login shells: `~/.profile`, `~/.bash_profile`
- Logout: `~/.bash_logout`

Other hardening:
- `auditd`: make sure `local events = yes`
- `/etc/security/limits.conf`: cap processes (`* hard nproc 2500`), disable core dumps (`* hard core 0`)
- `/etc/X11/xinit/xserverrc`: TCP should be `-nolisten`
- GDM3 `/etc/gdm3/custom.conf`: auto-login False, `DisallowTCP=true`
- LightDM `/etc/lightdm/lightdm.conf`: disable guest users
- Stop unneeded daemons: `sudo systemctl stop cups avahi`
- Make sure AppArmor is enabled

---

## Offensive / CTF

The full "why / what you'll see" writeups are in `PentestingNewbie.md`. The working commands are mirrored here so this dictionary stands on its own; where they overlap, these match PentestingNewbie exactly.

**Nmap:**
```bash
sudo nmap -p- -T4 -v --open <IP> -oN open_ports.txt   # phase 1: find all open ports
sudo nmap -sV -sC -p <port,port,etc> <IP> -Pn         # phase 2: versions + default scripts
sudo nmap -sV --script=vuln,auth -p 22,8080 10.65.190.186 # Built in script for web vulnerabilities with CVE databases. 
```
Anonymous FTP shows up in nmap as response code `230`.

**Hydra:**
```bash
sudo hydra -l <user> -P <wordlist.txt> -t 10 -f -I ssh://<IP>
sudo hydra -L <users.txt> -p "<password>" -t 16 -f <IP> http-post-form "/admin/login.php:username=^USER^&password=^PASS^:F=Invalid credentials"
```
Web form: the `F=` text must match the site's real "bad login" message exactly, or every attempt looks like a hit.

**Gobuster:**
```bash
gobuster dir -u <URL> -w <wordlist.txt> -t 50 -x php,txt,html
```

**FTP / SMB:**
```bash
ftp <IP>                          # anon login: user 'anonymous', blank pass (localhost box: ftp 127.0.0.1)
smbclient -L //<IP> -N            # list shares (null session)
smbclient //<IP>/<share> -N       # connect to a specific share
```

**Privilege escalation:**
```bash
sudo -l                                    # what can you run as root? do this first
find / -perm -4000 -type f 2>/dev/null     # SUID binaries
```
Take any SUID binary or `NOPASSWD` entry to **GTFOBins** (https://gtfobins.github.io) for the exact escape line. **LinPEAS** automates the whole privesc hunt.
**Reverse shell:** point your backdoor at your IP + netcat port, then:
```bash
nc -lvnp 1234
```
**Upgrade a dumb shell to a real TTY:**
```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
```
**Post-access recon:**
```bash
id                                # your user/group + any SUID context
lsof -i                           # open connections
```
**Redirection tricks:**
```bash
cmd 2> errors.txt                 # send errors to a file
cmd 2>&1 | grep "text"            # grep the error output too
curl -s <url>                     # fetch quietly (no error codes)
```
**SQLi test string:** `jim404' OR '1'='1`

**PHP info probe** (drop in a test file to leak server config):
```php
<?php phpinfo(); ?>
```

---

## Windows & PowerShell

```powershell
netstat -ano                                 # ports + PIDs
net user "User" /add                         # /delete /active:yes|no
net localgroup Administrators "User" /add    # /delete
Get-SmbShare                                 # all shares ($ = hidden share)
Get-SmbShareAccess -Name <share>             # access rights
(Get-ADDomain).NetBIOSName
(Get-ChildItem -Path . -File | Measure-Object).Count   # count files
Get-Content -Path .\file                     # cat a file
attrib +r C:\path\flag.txt                   # set read-only
```
PowerShell basics:
```powershell
Write-Host "lol"                     # print
Read-Host                            # take input
Get-Command -CommandType cmdlet      # list cmdlets
Get-Help <cmd>                       # man page
"lol" | Out-File lol.txt             # write to file
$x = 5.5; $x.GetType()               # variable type
Get-Member -InputObject $x           # methods available
$a = @('lolz','lelz','lulz'); $a[0]  # arrays
$h = @{"Wizard"="Gandalf"}           # hashtable
$h.Add("Dwarf","Gimli")              # add pair
$h.Remove("Dwarf")                   # remove pair
```
Everything in PowerShell is an object.

Consoles: `dsa.msc` (AD), `sysdm.msc` (system properties), `dnsmgmt.msc` (DNS).

---

## Active Directory

**AD backups live in** `\Windows\NTDS\` and `\Windows\SYSVOL`.

```bash
nxc smb 10.0.0.0/24                                   # sweep SMB
nxc smb <ip> -u <user> -p <pass> --sam               # dump (--lsa/--ntds/--dpapi)
nxc ldap <ip> -u <user> -p '' --kerberoasting out.txt
impacket-GetUserSPNs -request -dc-ip <ip> domain/user:pass
impacket-secretsdump domain/user:pass@<ip> -just-dc
hashcat -a 0 output.txt /usr/share/wordlists/rockyou.txt
evil-winrm -i <ip> -u Administrator -H <NTLM_hash>    # pass-the-hash
```
User admin:
```
net user username password /add /domain
New-ADUser
NET USERS /DOMAIN > USERS.TXT
NET LOCALGROUP > LGRP.TXT
```
Notes: impacket is king for dumps. `sssd.service` is what joins Linux boxes to AD. Give each service its own bind/service account (`svc` = service).

---

## Docker

```bash
docker ps                          # running containers + ports
docker exec -it <name> /bin/sh     # shell into a container's config
docker restart <name>
docker inspect <name>
docker logs <name>
docker system prune -a             # reclaim space
```
Dockerized service configs live under `/etc/docker`. Check the container's exposed port with `docker ps`.

---

## MikroTik router (NCAE)

```
/ip address print                                   # current IPs
/interface print                                    # NICs (ethernet, etc.)
/ip address add address=10.1.10.1/16 interface=<name>
/ip route print                                     # routing table
/ip service print                                   # running services
/ip service disable <name|number>                   # kill telnet/ftp
```
Setup flow: add the router to the subnet so it can ping everything. Internal LAN `172.20.xx.1/16`, external LAN `192.168.xx.1/24` (use the net1/ether6 interface; internal LAN needs its own interface). `xx` = team number.

On the internal LAN: enable NAT (bridges external traffic to internal) and enable bridging on LAN ports. Then port-map the web server box (`192.168.xx.2`) to port 80 over both TCP and UDP. Log into the router UI at `172.20.xx.1:8080`; set the gateway to the engine `172.20.0.1`.

---

## Netplan / IP config

Edit `/etc/netplan/01-network-manager-all.yaml`. Format matters (spaces, not tabs, or the YAML breaks):
```yaml
renderer: NetworkManager
ethernets:
  ens18:
    addresses:
      - 192.168.45.2/24
    gateway4: 192.168.45.1     # no /24 here
```
Apply with `sudo netplan apply`. Check your adapter name first with `ip a`.

---

## Vim quick keys

```
vi <file>       open
i               insert mode
ESC             leave insert
:wq             save + quit
```

---

## Distro notes (Gentoo / Alpine / RedHat)

**Gentoo / Alpine** use OpenRC + iptables:
```bash
rc-service <service> restart|start
rc-update add <service> default        # add to boot
```
Gentoo configs: `/etc/conf.d/net` (network), `/etc/portage/make.conf` (packages), `/etc/init.d/` (services).

**RedHat:** `sudo dnf upgrade`, `sudo dnf -y install <pkg>`. Sudo group is `wheel`.

---

## Service config file reference

Quick "where does it live / how do I lock it" table.

| Service | Config | Harden | Manage | Port |
|---|---|---|---|---|
| SSH | `/etc/ssh/sshd_config` | `PermitRootLogin no`, pick password *or* key auth | `systemctl status ssh` | 22 |
| Nginx | `/etc/nginx/nginx.conf`, `sites-available/default` | `server_tokens off;`, own `/var/www/html` www-data | `systemctl restart nginx` | 80/443 |
| Apache | `/etc/apache2/apache2.conf`, `000-default.conf` | `ServerTokens Prod`, `ServerSignature Off` | `systemctl restart apache2` | 80/443 |
| MySQL | `/etc/mysql/mysql.conf.d/mysqld.cnf` | `mysql_secure_installation` | `systemctl status mysql` | 3306 |
| PostgreSQL | `/etc/postgresql/<ver>/main/postgresql.conf`, `pg_hba.conf` | limit `pg_hba` to web host, `scram-sha-256` | `systemctl status postgresql` | 5432 |
| Postfix | `/etc/postfix/main.cf` | no open relay (`mynetworks 127.0.0.0/8`), enforce TLS | `systemctl restart postfix` | 587 |
| Dovecot | `/etc/dovecot/dovecot.conf` | IMAPS only | `systemctl restart dovecot` | 993 |
| Samba | `/etc/samba/smb.conf` | `hosts allow` = local subnet, disable guest | `systemctl restart smbd` | 445 |

**SQL commands cheat:**
```sql
show databases;
use <db>;
show tables;
select * from <table>;
ALTER USER '<user>'@'localhost' IDENTIFIED BY '<new_password>';
drop user <user>@localhost;
```
Postgres firewall: `sudo ufw allow from <Web_Server_IP> to any port 5432`. MySQL data dir: `/var/lib/mysql`.

Mail: block plaintext 25/143 where you can, use 587 (submission) and 993 (IMAPS). Postfix TLS: `smtpd_tls_security_level = may` (or `encrypt` for strict).

Samba: `sudo smbpasswd -a <user>` to create SMB users.

---

## Extra one-liners worth keeping

```bash
cat /etc/os-release              # basic system info (neofetch if installed)
file ./*                         # identify every file in a dir
ln -s target linkname            # symbolic link
cat /proc/<PID>/environ          # env of a running process (even if hidden)
```
Hosts file `/etc/hosts` — check for injected/insecure entries.
