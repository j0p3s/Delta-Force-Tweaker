# Security

## What the tools do

- **Web app (`index.html`)**: a single static page. It has no server, no analytics and no network requests after loading. Files you select are read and edited in your browser and are never uploaded.
- **Windows script (`.cmd`)**: plain text that you can read in Notepad before running. It needs administrator rights only because NVIDIA Profile Inspector writes to the driver settings and some Windows gaming settings live in `HKLM`. The only download it performs is NVIDIA Profile Inspector from GitHub Releases.

## Verifying a download

Release notes list the SHA-256 hash of the script. In PowerShell:

```powershell
Get-FileHash .\Delta-Force-Tweaker_v1.0.0-beta.cmd -Algorithm SHA256
```

Only download the script from this repository's [Releases](https://github.com/j0p3s/Delta-Force-Tweaker/releases) page.

## Reporting a problem

If you find a security problem, please open an issue without exploit details and ask for a private contact, or use GitHub's *Report a vulnerability* button on the Security tab if it is enabled.
