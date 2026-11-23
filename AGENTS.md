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
This repo contains three main areas:
- `file_copy/`: batch copy utility for folders listed in a CSV
- `tautulli_scripts/`: scripts for querying Tautulli and summarizing encryption status
- `updateubuntu/`: Ansible playbook for Debian/Ubuntu updates and reboot logic

## How the project works
Each script is designed to be simple, predictable, and easy to run manually or from cron.

### 1) file_copy
The script reads a CSV list of folder names and copies each source folder into a destination root using `rsync`. It supports dry-run mode and logs progress to a per-script log file.

### 2) tautulli_scripts
The script calls a Tautulli API, reads user and history data, and classifies entries as encrypted, unencrypted, or unknown based on common security fields.

### 3) updateubuntu
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
- `updateubuntu/updateubuntu.yml`: server update automation
- `README.md`: overview and usage documents for the collection

## Editing guidelines
- Do not add hidden state or cloud dependencies unless explicitly required.
- If a script reads configuration, prefer a local file in the same directory with obvious names such as `.tatulli_config.sh`.
- Keep arguments explicit and documented in `usage` output or README sections.
- Maintain compatibility with Linux shells and standard package managers.

## Validation
For each script, validate against its intended runtime environment:
- `bash -n <script>` for shell syntax checks
- run with `--help` or a safe preview mode before production execution
- for Ansible, run `ansible-playbook --syntax-check updateubuntu.yml` when possible

## Summary for an LLM
Treat this repo as a toolbox of small operational automation scripts. Each task is standalone, environment-specific, and intentionally simple so it can be run safely by humans or automation without a large framework or backend.
