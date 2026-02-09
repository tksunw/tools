#!/usr/bin/env python3

import os
import re
import sys
import requests
from pathlib import Path

# Security: Load credentials from environment variables instead of hardcoding
HOSTNAME = os.getenv('HE_DDNS_HOSTNAME', '< fqdn to update >')
KEY = os.getenv('HE_DDNS_KEY', '< provided key >')

# Configuration
IP_LOOKUP_SITES = (
    "https://4.ifcfg.me/ip",
    "https://api4.ipify.org",
    "https://ipv4.icanhazip.com",
)
HE_UPDATE_URL = "https://dyn.dns.he.net/nic/update"
CACHE_FILE = Path.home() / '.cache' / 'he-ddns-last-ip'
REQUEST_TIMEOUT_SECONDS = 10

# Validate configuration
if HOSTNAME.startswith('<') or KEY.startswith('<'):
    print("Error: Please set HE_DDNS_HOSTNAME and HE_DDNS_KEY environment variables", file=sys.stderr)
    sys.exit(1)


def get_current_ip():
    """Fetch current public IP address."""
    for site in IP_LOOKUP_SITES:
        try:
            response = requests.get(site, timeout=REQUEST_TIMEOUT_SECONDS)
            response.raise_for_status()
        except requests.RequestException as e:
            print(f"Warning: Error contacting IP lookup site {site}: {e}", file=sys.stderr)
            continue

        # More robust IP validation
        ip_pattern = r'\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b'
        ips = re.findall(ip_pattern, response.text)

        if not ips:
            print(f"Warning: No valid IPv4 address found in response from {site}", file=sys.stderr)
            continue

        if len(ips) > 1:
            print(f"Warning: Multiple IPs found from {site}, using first: {ips[0]}", file=sys.stderr)

        return ips[0]

    print("Error: Failed to determine current public IPv4 address from all lookup sites", file=sys.stderr)
    return None


def get_cached_ip():
    """Read last known IP from cache file."""
    try:
        if CACHE_FILE.exists():
            return CACHE_FILE.read_text().strip()
    except Exception as e:
        print(f"Warning: Could not read cache file: {e}", file=sys.stderr)
    return None


def save_cached_ip(ip):
    """Save current IP to cache file."""
    try:
        CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
        CACHE_FILE.write_text(ip)
        CACHE_FILE.chmod(0o600)
    except Exception as e:
        print(f"Warning: Could not write cache file: {e}", file=sys.stderr)

def parse_he_response(response_text):
    """Parse Hurricane Electric dynamic DNS response."""
    # Expected prefixes include: good, nochg, badauth, notfqdn, abuse, 911
    result_token = response_text.strip().split(maxsplit=1)[0].lower() if response_text else ""
    return result_token


def update_dns(ip, session):
    """Update Hurricane Electric DDNS with new IP."""
    try:
        update = session.post(
            HE_UPDATE_URL,
            data={
                'password': KEY,
                'hostname': HOSTNAME,
                'myip': ip
            },
            timeout=REQUEST_TIMEOUT_SECONDS
        )
        update.raise_for_status()
    except requests.RequestException as e:
        print(f"Error updating DNS: {e}", file=sys.stderr)
        return False

    result = parse_he_response(update.text)
    if update.status_code == 200 and result in {"good", "nochg"}:
        print(f"Success: Dynamic DNS for {HOSTNAME} updated to {ip}")
        return True
    else:
        print(f"Failure updating Dynamic DNS for {HOSTNAME}: {update.text}", file=sys.stderr)
        return False


def main():
    """Main execution flow."""
    current_ip = get_current_ip()
    if not current_ip:
        sys.exit(1)

    cached_ip = get_cached_ip()

    # Efficiency: Only update if IP has changed
    if current_ip == cached_ip:
        print(f"IP unchanged ({current_ip}), skipping update")
        return

    print(f"IP changed from {cached_ip} to {current_ip}, updating DNS...")

    with requests.Session() as session:
        if update_dns(current_ip, session):
            save_cached_ip(current_ip)
            sys.exit(0)
        else:
            sys.exit(1)


if __name__ == '__main__':
    main()
