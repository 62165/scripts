#!/usr/bin/env python3
"""
Fetch a local snapshot of UniFi Network configuration and save it as a
JSON export for later documentation and analysis.

This script intentionally keeps raw config data local and only writes a
sanitized summary for public-facing docs. It never commits secrets or
private infra details to Git.
"""

from __future__ import annotations

import argparse
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def _safe_bool(value: Any) -> bool:
    return bool(value)


def _normalize_ip_value(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def _sanitize_string(value: Any) -> str:
    if value is None:
        return ""
    value = str(value).strip()
    if not value:
        return ""
    if re.match(r"^\d{1,3}(?:\.\d{1,3}){3}$", value):
        return "PRIVATE_IP"
    if re.match(r"^\d{1,3}(?:\.\d{1,3}){3}/\d{1,2}$", value):
        return "PRIVATE_CIDR"
    if re.match(r"^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$", value):
        return "example.internal"
    return value


def _sanitize_for_public(payload: Any) -> Any:
    if isinstance(payload, dict):
        return {str(k): _sanitize_for_public(v) for k, v in payload.items()}
    if isinstance(payload, list):
        return [_sanitize_for_public(v) for v in payload]
    if isinstance(payload, str):
        return _sanitize_string(payload)
    return payload


def _login(host: str, username: str, password: str) -> requests.Session:
    session = requests.Session()
    session.verify = False
    url = f"https://{host}/api/auth/login"
    response = session.post(url, json={"username": username, "password": password}, timeout=20)
    if response.status_code != 200:
        raise RuntimeError(f"UniFi login failed: HTTP {response.status_code}")
    return session


def _fetch(session: requests.Session, host: str, path: str) -> Any:
    url = f"https://{host}{path}"
    response = session.get(url, timeout=20)
    if response.status_code != 200:
        raise RuntimeError(f"UniFi request failed for {path}: HTTP {response.status_code}")
    try:
        data = response.json()
    except ValueError as exc:
        raise RuntimeError(f"Invalid JSON from {path}: {exc}") from exc
    return data


def _fetch_first_available(session: requests.Session, host: str, candidate_paths: list[str]) -> Any:
    last_error: Exception | None = None
    for path in candidate_paths:
        try:
            payload = _fetch(session, host, path)
            return payload
        except RuntimeError as exc:
            last_error = exc
            if "HTTP 404" in str(exc):
                continue
            raise
    if last_error is not None:
        raise last_error
    raise RuntimeError(f"No valid UniFi endpoint found for {candidate_paths}")


def _safe_network_entry(network: dict[str, Any]) -> dict[str, Any]:
    subnet = network.get("ip_subnet") or network.get("subnet") or ""
    vlan = network.get("vlan") or network.get("vlan_id") or ""
    return {
        "name": network.get("name", "unnamed"),
        "purpose": network.get("purpose") or network.get("name", "unnamed"),
        "vlan": vlan,
        "subnet": subnet,
        "gateway": network.get("gateway") or "",
        "dhcp_start": network.get("dhcpd_start") or "",
        "dhcp_end": network.get("dhcpd_end") or "",
        "is_nat": _safe_bool(network.get("is_nat")),
        "is_guest": _safe_bool(network.get("is_guest")),
        "domain_name": network.get("domain_name") or "",
    }


def _safe_wireless_entry(wlan: dict[str, Any]) -> dict[str, Any]:
    return {
        "name": wlan.get("name", "unnamed"),
        "ssid": wlan.get("ssid") or "",
        "security": wlan.get("security") or "",
        "is_guest": _safe_bool(wlan.get("is_guest")),
        "network_id": wlan.get("networkconf_id") or "",
        "vlan": wlan.get("vlan") or "",
        "enabled": _safe_bool(wlan.get("enabled")),
    }


def _safe_firewall_entry(rule: dict[str, Any]) -> dict[str, Any]:
    return {
        "name": rule.get("name") or "unnamed",
        "action": rule.get("action") or "",
        "src": _normalize_ip_value(rule.get("src")),
        "dst": _normalize_ip_value(rule.get("dst")),
        "proto": rule.get("proto") or "",
        "port": rule.get("dport") or rule.get("port") or "",
        "enabled": _safe_bool(rule.get("enabled")),
        "description": rule.get("description") or "",
    }


def _safe_device_entry(device: dict[str, Any]) -> dict[str, Any]:
    return {
        "name": device.get("name") or device.get("hostname") or "unnamed",
        "model": device.get("model") or "",
        "type": device.get("type") or "",
        "mac": device.get("mac") or "",
        "ip": _normalize_ip_value(device.get("ip")),
        "uptime": device.get("uptime") or "",
        "last_seen": device.get("last_seen") or "",
    }


def _build_summary(raw_data: dict[str, Any]) -> dict[str, Any]:
    networks = raw_data.get("networks", [])
    wlans = raw_data.get("wlans", [])
    rules = raw_data.get("firewall_rules", [])
    devices = raw_data.get("devices", [])

    return {
        "generated_at": raw_data.get("generated_at", datetime.now(timezone.utc).isoformat()),
        "counts": {
            "networks": len(networks),
            "wlans": len(wlans),
            "firewall_rules": len(rules),
            "devices": len(devices),
        },
        "networks": [_safe_network_entry(network) for network in networks],
        "wireless": [_safe_wireless_entry(wlan) for wlan in wlans],
        "firewall_rules": [_safe_firewall_entry(rule) for rule in rules],
        "devices": [_safe_device_entry(device) for device in devices],
    }


def _collect_unifi_data(host: str, username: str, password: str) -> dict[str, Any]:
    session = _login(host, username, password)
    raw_data: dict[str, Any] = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "host": host,
        "networks": _fetch_first_available(
            session,
            host,
            [
                "/proxy/network/api/s/default/rest/networkconf",
            ],
        ).get("data", []),
        "wlans": _fetch_first_available(
            session,
            host,
            [
                "/proxy/network/api/s/default/rest/wlanconf",
            ],
        ).get("data", []),
        "firewall_rules": _fetch_first_available(
            session,
            host,
            [
                "/proxy/network/api/s/default/rest/firewallrule",
            ],
        ).get("data", []),
        "devices": _fetch_first_available(
            session,
            host,
            [
                "/proxy/network/api/s/default/stat/device",
                "/proxy/network/api/s/default/rest/device",
            ],
        ).get("data", []),
    }
    return raw_data


def _write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export UniFi config data for local network docs and troubleshooting.")
    parser.add_argument("--host", default=os.getenv("UNIFI_HOST", ""), help="UniFi controller hostname or IP")
    parser.add_argument("--user", default=os.getenv("UNIFI_USER", ""), help="UniFi admin username")
    parser.add_argument("--password", default=os.getenv("UNIFI_PASS", ""), help="UniFi admin password")
    parser.add_argument("--raw-output", default=os.getenv("UNIFI_RAW_EXPORT", "data/unifi_network_raw.json"), help="Path for the raw local export")
    parser.add_argument("--summary-output", default=os.getenv("UNIFI_SUMMARY_EXPORT", "data/unifi_network_summary.json"), help="Path for the sanitized summary")
    parser.add_argument("--no-sanitize", action="store_true", help="Write the raw exported data without sanitizing it for public docs")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.host or not args.user or not args.password:
        print("Missing required UniFi connection information.", file=os.sys.stderr)
        print("Set UNIFI_HOST, UNIFI_USER, and UNIFI_PASS or pass --host/--user/--password.", file=os.sys.stderr)
        return 2

    try:
        raw_data = _collect_unifi_data(args.host, args.user, args.password)
    except Exception as exc:  # pragma: no cover - CLI convenience
        print(f"Failed to collect UniFi data: {exc}", file=os.sys.stderr)
        return 1

    raw_output = Path(args.raw_output)
    summary_output = Path(args.summary_output)

    _write_json(raw_output, raw_data)

    summary = _build_summary(raw_data)
    if args.no_sanitize:
        _write_json(summary_output, summary)
        print(f"Saved raw summary export to: {summary_output}")
    else:
        sanitized_summary = _sanitize_for_public(summary)
        _write_json(summary_output, sanitized_summary)
        print(f"Saved sanitized summary export to: {summary_output}")

    print(f"Saved raw UniFi export to: {raw_output}")
    print("Remember: keep raw exports local and do not commit them to GitHub.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
