# updateubuntu

This repository contains an Ansible playbook to update Debian/Ubuntu systems.

## Playbook

| File | Description |
|------|-------------|
| `updateubuntu.yml` | Updates apt cache, upgrades installed packages, and reboots hosts when required. |

## Usage

```bash
ansible-playbook -i <inventory> updateubuntu.yml --ask-pass --ask-become-pass
```
