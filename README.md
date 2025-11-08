# Linux Server Utilities

This repository is a collection of Linux server-related tools, scripts, and other configuration instructions that I have used with my own servers and projects.

The goal is to provide a structured, reusable, and documented set of utilities for everyday sysadmin tasks.

---

## Repository Structure

```
linux-server-utils/
├── backup/              # Backup scripts (e.g. databases, files)
├── docs/                # Step-by-step guides and notes
├── monitoring/          # Monitoring script (PHP, server)
├── README.md
└── CHANGELOG.md
```

## Highlights

- Shell scripts for automating common sysadmin tasks  
- Configuration guides for PHP, Nginx, and other services  
- Basic firewall setup examples  
- Easy-to-understand layout with folder-based categorization

## Requirements & Compatibility

- Scripts are written in **Bash**
- Target environment: **Ubuntu/Debian-based systems**
- Tested on Ubuntu 24.04 LTS

_Note: Some commands or paths (like PHP config locations) may vary slightly between different distributions._

---

## Getting Started

Clone this repository and start using or adapting the scripts as needed:
```
git clone https://github.com/yourusername/linux-server-utils.git
cd linux-server-utils
```

### Make scripts executable before running them:
```
chmod +x backup/backup-db.sh
```

## License
MIT — feel free to use, modify, and share.