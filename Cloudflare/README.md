# Cloudflare DDNS Updater

`Update-CloudflareDDNS.ps1` updates Cloudflare DNS records with your current public IP address for dynamic DNS use cases.

## Features

- Supports single-record updates for `A` (IPv4) or `AAAA` (IPv6).
- Supports dual-stack mode to update both `A` and `AAAA` records in one run.
- Uses idempotency checks (no update when IP is already current).
- Uses `PATCH` updates so existing record settings are preserved.
- Uses timeout + bounded retries for transient Cloudflare API failures.

## Requirements

- PowerShell 7+
- Cloudflare API token with DNS edit permissions for the target zone

## Environment Variables

Required for all modes:

- `CLOUDFLARE_ZONE_ID`
- `CLOUDFLARE_API_KEY`

Single-record mode:

- `CLOUDFLARE_RECORD_ID`
- `CLOUDFLARE_RECORD_NAME`

Dual-stack mode:

- `CLOUDFLARE_RECORD_ID_V4`
- `CLOUDFLARE_RECORD_NAME_V4`
- `CLOUDFLARE_RECORD_ID_V6`
- `CLOUDFLARE_RECORD_NAME_V6`

## Usage

Single IPv4 (`A`) record:

```powershell
pwsh ./Update-CloudflareDDNS.ps1 -RecordType A -Verbose
```

Single IPv6 (`AAAA`) record:

```powershell
pwsh ./Update-CloudflareDDNS.ps1 -RecordType AAAA -Verbose
```

Dual-stack update:

```powershell
pwsh ./Update-CloudflareDDNS.ps1 -DualStack -Verbose
```

Dual-stack with explicit record IDs/names:

```powershell
pwsh ./Update-CloudflareDDNS.ps1 `
  -DualStack `
  -RecordIDv4 "record-id-v4" `
  -RecordNamev4 "home.example.com" `
  -RecordIDv6 "record-id-v6" `
  -RecordNamev6 "home.example.com" `
  -Verbose
```

## Notes

- Keep API tokens in environment variables instead of passing them on the command line.
- In dual-stack mode, use separate Cloudflare record IDs for `A` and `AAAA`.
- The script verifies the existing record name and type before applying updates.
