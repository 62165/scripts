# UniFi Network Snapshot

A Python utility that fetches configuration state from the UniFi Controller / Gateway API, saves a full raw JSON backup locally, and creates a sanitized summary suitable for documentation and troubleshooting.

## What it does

- Authenticates to the local UniFi Controller / UDM API (`/api/auth/login`).
- Fetches active configurations:
  - Networks and subnets (`networkconf`)
  - Wireless networks / SSIDs (`wlanconf`)
  - Firewall rules (`firewallrule`)
  - Connected devices and network appliances (`stat/device`)
- Exports raw responses to a local JSON file (default: `data/unifi_network_raw.json`).
- Generates a sanitized summary (default: `data/unifi_network_summary.json`) that strips out private IPs, subnets, and hostnames with placeholders (`PRIVATE_IP`, `PRIVATE_CIDR`, `example.internal`) for safe documentation sharing.

## Requirements

- Python 3.9+
- `requests`
- `urllib3`

Install dependencies:

```bash
pip install requests urllib3
```

## Configuration

Credentials can be passed via command-line arguments or environment variables:

| Environment Variable | CLI Argument | Default | Description |
|----------------------|--------------|---------|-------------|
| `UNIFI_HOST` | `--host` | *(required)* | UniFi controller hostname or IP |
| `UNIFI_USER` | `--user` | *(required)* | Admin username |
| `UNIFI_PASS` | `--password` | *(required)* | Admin password |
| `UNIFI_RAW_EXPORT` | `--raw-output` | `data/unifi_network_raw.json` | Path for raw JSON export |
| `UNIFI_SUMMARY_EXPORT` | `--summary-output` | `data/unifi_network_summary.json` | Path for sanitized summary |

## Usage

```bash
python3 unifi_network_snapshot.py --host <unifi-ip> --user <username> --password <password>
```

Or using environment variables:

```bash
export UNIFI_HOST="192.168.1.1"
export UNIFI_USER="admin"
export UNIFI_PASS="secret"

python3 unifi_network_snapshot.py
```

### Options

- `--no-sanitize`: Write the raw summary without scrubbing internal IPs and domain names.
- `--raw-output <path>`: Custom destination for the raw controller payload.
- `--summary-output <path>`: Custom destination for the processed summary.

## Safety notes

- Raw exports (`data/unifi_network_raw.json`) contain live internal network details and should **never** be committed to Git.
- Always verify that output files are kept in `.gitignore` or written outside version-controlled directories.
