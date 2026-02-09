# DiceWords Password Generator

`Get-DiceWords.ps1` generates Diceware-style passphrases using the EFF large wordlist.

## Features

- Cryptographically secure random number generation.
- Strict EFF wordlist structure validation (7,776 entries).
- Local trust-on-first-use (TOFU) hash tracking for managed wordlist downloads.
- Entropy and approximate combination count output.

## Usage

```powershell
pwsh ./DiceWords-Password-Generator/Get-DiceWords.ps1
```

Generate a stronger passphrase:

```powershell
pwsh ./DiceWords-Password-Generator/Get-DiceWords.ps1 -NumberofWords 6
```

If the managed wordlist changes and you trust the new content:

```powershell
pwsh ./DiceWords-Password-Generator/Get-DiceWords.ps1 -AllowWordlistChange
```

## Notes

- Default wordlist storage:
  - Windows: `%LOCALAPPDATA%\EFF\eff_large_wordlist.txt`
  - macOS: `$TMPDIR/EFF/eff_large_wordlist.txt`
  - Linux: `~/.local/share/EFF/eff_large_wordlist.txt`
- Trusted hash file is stored alongside the managed wordlist as `eff_large_wordlist.sha256`.
