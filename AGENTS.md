# AGENTS.md

## Purpose
This repository is a collection of small operational scripts for admin and system-maintenance tasks. It is not a single application; each folder is an independent utility with its own scope and behavior.

## Canonical documentation
This repo participates in the shared environment documentation model. The documentation repository is the canonical source for standards, network model context, and AI behavior rules.

Primary reference:
- `../environment-docs/README.md`
- `../environment-docs/docs/standards.md`
- `../environment-docs/docs/llm-rules.md`
- `../environment-docs/docs/server-documentation.md`

## Repository overview
This repo contains four main areas:
- `file_copy/`: batch copy utility for folders listed in a CSV
- `tautulli_scripts/`: scripts for querying Tautulli and summarizing encryption status
- `unifi/`: UniFi network snapshot and sanitized summary export utility
- `updateubuntu/`: Ansible playbook for Debian/Ubuntu updates and reboot logic

## How the project works
Each script is designed to be simple, predictable, and easy to run manually or from cron.

### 1) file_copy
The script reads a CSV list of folder names and copies each source folder into a destination root using `rsync`. It supports dry-run mode and logs progress to a per-script log file.

### 2) tautulli_scripts
The script calls a Tautulli API, reads user and history data, and classifies entries as encrypted, unencrypted, or unknown based on common security fields.

### 3) unifi
The script `unifi_network_snapshot.py` connects to the UniFi controller API, dumps raw network configuration (networks, WLANs, firewall rules, devices) locally, and creates a sanitized summary for documentation.

### 4) updateubuntu
The Ansible playbook updates package caches, performs a distribution upgrade, checks whether a reboot is required, and reboots the host if needed.

## Conventions for all scripts
- Prefer portable bash or standard Linux tooling.
- Keep scripts idempotent where possible.
- Log output clearly for operational troubleshooting.
- Support dry-run or preview modes when safe.
- Keep local secrets in per-folder config files or environment variables, not in version control.

## File responsibilities
- `file_copy/copy_folders_from_csv.sh`: batch folder copy job
- `file_copy/copy_list.csv`: example CSV input list
- `tautulli_scripts/tatulli_encryption_report.sh`: API report script
- `unifi/unifi_network_snapshot.py`: UniFi configuration exporter and doc sanitizer
- `updateubuntu/updateubuntu.yml`: server update automation
- `README.md`: overview and usage documents for the collection

## Editing guidelines
- Do not add hidden state or cloud dependencies unless explicitly required.
- If a script reads configuration, prefer a local file in the same directory with obvious names such as `.tatulli_config.sh`.
- Keep arguments explicit and documented in `usage` output or README sections.
- Maintain compatibility with Linux shells and standard package managers.

## Adding new directories and scripts
When creating a new tool or directory in this repository:
1. **Self-contained directory**: Create a dedicated directory named for the tool/service (e.g. `unifi/`, `file_copy/`).
2. **Dedicated README.md**: Provide a clear `README.md` inside the directory covering:
   - Purpose and high-level description
   - Requirements / dependencies
   - Configuration (environment variables or config files with `.example` templates)
   - Usage syntax and arguments table
   - Safety notes (handling sensitive data, idempotency, dry-run options)
3. **Update root documentation**:
   - Add the new folder and summary to `README.md` under **Repository layout** and **Tool summaries**.
   - Add the script responsibilities and operational details to `AGENTS.md`.
4. **Security & Git hygiene**: Ensure any local credentials, state files, or raw exports are added to `.gitignore`.

## Validation
For each script, validate against its intended runtime environment:
- `bash -n <script>` for shell syntax checks
- run with `--help` or a safe preview mode before production execution
- for Ansible, run `ansible-playbook --syntax-check updateubuntu.yml` when possible

## Summary for an LLM
Treat this repo as a toolbox of small operational automation scripts. Each task is standalone, environment-specific, and intentionally simple so it can be run safely by humans or automation without a large framework or backend.
