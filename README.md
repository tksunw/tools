# tools

### DiceWords-Password-Generator
* a powershell script to generate random passwords from the EFF Large Wordlist, by simulating rolls of 5 6-sided dice
* validates downloaded wordlist structure (7,776 unique dice keys in `11111`-`66666` format, non-empty words)
* uses local trust-on-first-use (TOFU) hash tracking for the default managed wordlist
* if the managed wordlist hash changes, rerun with `-AllowWordlistChange` to explicitly trust and persist the new hash
* trusted hash file location (default managed wordlist only):

| Platform | Hash file path |
| --- | --- |
| Windows | `%LOCALAPPDATA%\EFF\eff_large_wordlist.sha256` |
| macOS | `$TMPDIR/EFF/eff_large_wordlist.sha256` |
| Linux | `~/.local/share/EFF/eff_large_wordlist.sha256` |

* examples:

| Purpose | Command |
| --- | --- |
| Generate a 6-word passphrase | `pwsh ./DiceWords-Password-Generator/Get-DiceWords.ps1 -NumberofWords 6` |
| Accept and persist a changed managed wordlist hash | `pwsh ./DiceWords-Password-Generator/Get-DiceWords.ps1 -AllowWordlistChange` |

### he-ddns-updater:
* a small script to update dyndns entries at Hurricane Electric

### zfs:
* zfs related scripts

### mac:
* Mac OS X related scripts.
