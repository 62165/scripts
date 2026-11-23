# Scripts Repository

This repository is a small collection of operational utilities for system administration, data copying, and monitoring tasks. Each folder is intentionally self-contained and designed to be run directly from a shell or cron job.

## Overview
The repo contains multiple independent tools rather than a single application. Each tool solves one narrow task and keeps its logic simple, portable, and easy to review.

## Repository layout
- `file_copy/` — copies folder trees from a source root to a destination root using a CSV list
- `tautulli_scripts/` — queries Tautulli and summarizes encryption status for users and clients
- `unifi/` — UniFi network configuration snapshot and sanitized public export utility
- `updateubuntu/` — Ansible playbook for Debian/Ubuntu package upgrades and reboot handling
- `README.md` — repository overview and usage guide

## Tool summaries
### file_copy
Copies named folders from a source directory into a target directory based on an input CSV file. The script uses `rsync` for idempotent, resumable copies and supports dry-run mode.

### tautulli_scripts
Fetches Tautulli API data and groups results by encryption status: encrypted, unencrypted, or unknown. This is useful for identifying clients that may not be using secure streaming connections.

### unifi
Fetches configuration snapshots from the UniFi Controller API (networks, WLANs, firewall rules, active devices), writes a local raw JSON export, and produces a sanitized, public-safe JSON summary masking internal IPs and domains.

### updateubuntu
Applies a system update and distribution upgrade across Debian/Ubuntu hosts, then reboots if the kernel or package state requires it.

## Operating conventions
- Prefer standard Linux shells and utility commands.
- Keep scripts idempotent whenever possible.
- Log output clearly to support troubleshooting.
- Keep secrets local to config files or environment variables.
- Avoid adding frameworks or service dependencies unless absolutely needed.

## Validation
Use the most relevant checks for each tool:
```bash
bash -n file_copy/copy_folders_from_csv.sh
bash -n tautulli_scripts/tatulli_encryption_report.sh
ansible-playbook --syntax-check updateubuntu/updateubuntu.yml
```

## Notes
This repository is best treated as a toolbox: each script should be easy to understand, easy to run manually, and safe to schedule in automation.

