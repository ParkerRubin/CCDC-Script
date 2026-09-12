Sysinternals Installer Script - Quick Overview
--------------------------------------------------

What this script does

Downloads four Sysinternals tools directly (x64 only, no full suite
zip) into a local tools folder, and unblocks them so Windows
doesn't flag them as downloaded-from-the-internet on first run.

Tools installed:
- procexp64.exe   - Process Explorer (deeper alternative to Task Manager;
                     shows parent/child trees, loaded DLLs, handles)
- Autoruns64.exe  - Autoruns (shows everything configured to run at
                     startup - Run keys, services, scheduled tasks,
                     drivers, etc. in one place)
- sigcheck64.exe  - Sigcheck (checks digital signatures on binaries;
                     -vt flag checks the file hash against VirusTotal)
- tcpview64.exe   - TCPView (live-updating GUI view of network
                     connections - like netstat, but real-time)

--------------------------------------------------

How to run

    .\Install_Sysinternals.ps1

No parameters. Re-running is safe - any tool already present in the
destination folder is skipped rather than re-downloaded.

--------------------------------------------------

Output location

    C:\CCDC\Tools\Sysinternals\

--------------------------------------------------

Notes

- Downloads come from live.sysinternals.com (Microsoft's own
  per-tool mirror), not a third-party rehost.
- If a download fails (no internet, blocked outbound), the script
  says so and assumes the tool may already be staged in a local
  repo/copy instead of failing the whole run.
- Sigcheck's -vt (VirusTotal) lookup requires outbound internet
  access. If outbound is locked down, sigcheck64.exe still works
  for local signature verification without -vt.
- x64 only. If you land on a 32-bit box, the download URLs and
  filenames for 32-bit versions follow the same live.sysinternals.com
  pattern without the "64".

--------------------------------------------------

End of overview
