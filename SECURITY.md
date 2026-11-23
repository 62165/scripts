# Security Policy

This repository must never contain secrets, personal data, or private infrastructure details.

## Required rules

- Never commit passwords, API keys, tokens, private keys, or credentials.
- Never store secrets in source code, shell scripts, notebooks, or example files.
- Keep all real credentials in local environment variables or a secure secret manager.
- Never commit `.env` files, local config files, or runtime state that includes secrets.
- Never publish PII such as names, email addresses, phone numbers, or personal account details.
- Never publish internal URLs, hostnames, IP addresses, or network topology details.
- Replace any sensitive value with a generic placeholder like `CHANGE_ME` or `YOUR_API_KEY`.

## GitHub-safe practices

Before committing or pushing:

- confirm no credential is present
- confirm no personal data is present
- confirm no private network details are present
- confirm no production or internal endpoint is included

If a value cannot be safely shared, do not add it to the repository.

## Safe examples

- `YOUR_API_KEY`
- `CHANGE_ME`
- `example.com`
- `203.0.113.10`

## Unsafe examples

- real passwords
- actual API tokens
- private hostnames
- LAN IPs
- personal email addresses
- internal URLs

## Rules for AI and automation

AI agents working in this repository must avoid writing secrets, PII, or internal network details into code or documentation. Any generated content should use placeholders and anonymized examples only.
