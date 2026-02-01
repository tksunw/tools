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
IP_LOOKUP_SITE = "https://4.ifcfg.me/ip"
HE_UPDATE_URL = "https://dyn.dns.he.net/nic/update"
CACHE_FILE = Path.home() / '.cache' / 'he-ddns-last-ip'

# Validate configuration
if HOSTNAME.startswith('<') or KEY.startswith('<'):
    print("Error: Please set HE_DDNS_HOSTNAME and HE_DDNS_KEY environment variables", file=sys.stderr)
    sys.exit(1)


def get_current_ip():
    """Fetch current public IP address."""
    try:
        response = requests.get(IP_LOOKUP_SITE, timeout=10)
        response.raise_for_status()
    except requests.RequestException as e:
        print(f"Error contacting IP lookup site {IP_LOOKUP_SITE}: {e}", file=sys.stderr)
        return None

    # More robust IP validation
    ip_pattern = r'\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b'
    ips = re.findall(ip_pattern, response.text)

    if not ips:
        print("Error: No valid IP address found in response", file=sys.stderr)
        return None

    if len(ips) > 1:
        print(f"Warning: Multiple IPs found, using first: {ips[0]}", file=sys.stderr)

    return ips[0]


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
    except Exception as e:
        print(f"Warning: Could not write cache file: {e}", file=sys.stderr)


def update_dns(ip):
    """Update Hurricane Electric DDNS with new IP."""
    try:
        # Security: Use standard cert verification instead of custom cert
        update = requests.post(
            HE_UPDATE_URL,
            data={
                'password': KEY,
                'hostname': HOSTNAME,
                'myip': ip
            },
            timeout=10
        )
        update.raise_for_status()
    except requests.RequestException as e:
        print(f"Error updating DNS: {e}", file=sys.stderr)
        return False

    # Check response status
    if update.status_code == 200 and 'good' in update.text.lower():
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

    if update_dns(current_ip):
        save_cached_ip(current_ip)
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()

