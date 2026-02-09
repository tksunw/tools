# Hurricane Electric DDNS Updater

This folder contains two implementations for updating Hurricane Electric dynamic DNS records:

- `he-ddns-updater.py` (Python)
- `he-ddns-updater.ps1` (PowerShell)

Both scripts use HTTPS, environment-based credentials, and strict IP validation.

## Requirements

- Hurricane Electric DNS account
- DDNS key for the target host
- Python: `requests`
- PowerShell 7+ (recommended)

## Configuration

Set these environment variables:

- `HE_DDNS_HOSTNAME` (for example `home.example.com`)
- `HE_DDNS_KEY` (your HE dynamic DNS key)

## Usage

Python:

```bash
python3 ./he-ddns-updater.py
```

PowerShell:

```powershell
pwsh ./he-ddns-updater.ps1 -Verbose
```

## Behavior

- Detects current public IPv4 using trusted lookup services.
- Validates the returned value is a real IPv4 address before update.
- Sends update request to `https://dyn.dns.he.net/nic/update`.
- Treats both `good` and `nochg` responses as success.
- Python script caches last successful IP at `~/.cache/he-ddns-last-ip` to avoid unnecessary calls.

## Security Notes

- Do not hardcode DDNS keys in scripts.
- Prefer environment variables or your platform secret store.
- Avoid passing secrets directly on command lines where possible.
