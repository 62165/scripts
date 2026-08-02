# Tautulli Scripts

This folder contains helper scripts for working with Tautulli.

## Encryption report

The included script calls the Tautulli API and reports which users and clients appear to be encrypted, unencrypted, or unknown.

## Configuration

The script reads its base URL and API key from a local file named .tatulli_config.sh in this folder. That file is gitignored and should contain values like:

```bash
BASE_URL="http://your-tautulli-host:8181"
TOKEN="your-api-key"
```

## Usage

```bash
./tatulli_encryption_report.sh
```

You can also override the values on the command line:

```bash
./tatulli_encryption_report.sh --base-url http://your-tautulli-host:8181 --token "$TAUTULLI_API_KEY"
```

## Notes

The script looks for common field names such as `secure`, `encrypted`, `is_encrypted`, and `encryption_status`. If your Tautulli instance exposes different fields, update the detection logic in the Python block inside the script.
