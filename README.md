# linspect

A single-file Bash tool that inspects the health and basic security posture of a Linux machine — CPU, memory, disk, top processes, listening ports, failed SSH logins, and pending updates — with colored terminal output and JSON export.

No dependencies beyond standard coreutils; works on any Linux box (Debian/Ubuntu, Fedora, Arch) even without root.

## Preview

```
  _ _                           _
 | (_)_ __  ___ _ __   ___  ___| |_
 | | | '_ \/ __| '_ \ / _ \/ __| __|
 | | | | | \__ \ |_) |  __/ (__| |_
 |_|_|_| |_|___/ .__/ \___|\___|\__|
               |_|
  linux system inspector · v1.0.0

▸ System overview
  Hostname               web-01
  OS                     Ubuntu 24.04 LTS
  Kernel                 6.8.0-generic
  Uptime                 up 4 days, 2 hours
  Active users           1

▸ Resources
  CPU cores              4
  CPU load               0.42, 0.38, 0.31 (1/5/15 min)
  Memory                 2.1G / 7.8G used (5.2G available)
  Disk (/)               / 40G total, 18G used, 20G avail (47%)

  ✔ Memory usage is normal (27%)
  ✔ Disk space is sufficient (47%)
```

## Install

```bash
git clone https://github.com/<your-username>/linspect.git
cd linspect
chmod +x linspect.sh
./linspect.sh
```

Or run the installer to put it on your `$PATH` as `linspect`:

```bash
./install.sh
```

## Usage

```bash
./linspect.sh              # full report
./linspect.sh -q           # quick summary (CPU, RAM, disk, uptime)
./linspect.sh -s           # security checks only
./linspect.sh -j           # JSON output
./linspect.sh -j -o out.json   # export JSON to a file
./linspect.sh -o report.txt    # export full text report to a file
```

| Flag | Description |
|------|-------------|
| `-q`, `--quick` | quick summary only |
| `-s`, `--security` | security checks only |
| `-j`, `--json` | output as JSON |
| `-o`, `--output FILE` | write report to a file |
| `-h`, `--help` | show help |
| `-v`, `--version` | show version |

## What it checks

- **Overview** — hostname, OS, kernel, uptime, active users
- **Resources** — CPU load, memory usage, disk usage, with pass/warn thresholds
- **Processes** — top 5 processes by CPU usage
- **Security** — failed SSH login attempts (last 7 days), pending package updates, listening ports

## Why

Built as a learning/portfolio project for a systems programming course — a compact example of structured Bash: argument parsing, functions, error handling, and portable use of standard Linux tools (`free`, `df`, `ps`, `ss`, `journalctl`).

## License

MIT — see [LICENSE](LICENSE).
