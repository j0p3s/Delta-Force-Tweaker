# Changelog

All notable changes to **Delta Force Tweaker** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html):
`MAJOR.MINOR.PATCH` — MAJOR for changes that break existing behavior or backups,
MINOR for new features, PATCH for fixes.

## [Unreleased]

## [1.0.0-beta] - 2026-10-22

First public beta. Tested on one PC (Windows 10 22H2, RTX 3080 Laptop, game version 1.102.37117); reports from other hardware are welcome.

### Added
- Hardware detection: CPU, RAM, GPU (real VRAM read from the registry), resolution and refresh rate, with a hardware tier (Low / Medium / High / Epic).
- Recommended in-game settings for two profiles, **Balanced** and **Competitive**, shown on screen and saved to `DeltaForce_Recommended_<profile>.txt`.
- Option **[W]**: writes the recommended values to `UserSystemSettingHD.ini` after a warning, a `YES` confirmation and an automatic backup. Value scales were confirmed against the in-game menu (game version 1.102.37117). Keys the game omits (default values) are added; token-protected files are never touched.
- Game folder detection: Steam libraries, uninstall entries (official launcher), Windows registry traces (Compatibility Assistant, MuiCache, firewall rules, GPU preferences) and a search across all drives.
- Installation check at startup and on demand (**[C]**), listing the game folder, executable, config folder, intro videos and settings file.
- In-game Config Management guidance (press **S**, keep **LocalConfig** applied) before writing settings.
- Shader cache cleanup (**[3]**).
- Intro video skip (**[V]**): renames the three logo videos to `.bak`; the same option restores them.
- Local config backup, restore and open folder (**[4]**, **[8]**, **[9]**).
- NVIDIA driver profile via NVIDIA Profile Inspector (**[5]**, **[6]**, **[7]**): automatic download, backup of customized profiles, merge into the official "Delta Force" profile, verification of every setting, restore to the original state, and high-performance GPU selection on laptops with an integrated GPU.
- Windows 10/11 gaming settings (**[G]**): Game Mode, Hardware-accelerated GPU scheduling, background recording (Game Bar), optimizations for windowed games (Windows 11 22H2+) and power plan.
- Start without UAC prompt through a scheduled task (**[A]** / **[R]**).
- Web app (`index.html`, GitHub Pages) in English, Portuguese, Spanish, French, German and Russian: hardware selection with browser auto-detection, recommended settings, in-browser editing of `UserSystemSettingHD.ini` (nothing is uploaded) and a downloadable NVIDIA Profile Inspector profile.
- NVIDIA Profile Inspector download from the project's fork, with fallback to the original project.
- Version number in the file name, window title, menu, reports, web app and scheduled task description.

[Unreleased]: https://github.com/j0p3s/Delta-Force-Tweaker/compare/v1.0.0-beta...HEAD
[1.0.0-beta]: https://github.com/j0p3s/Delta-Force-Tweaker/releases/tag/v1.0.0-beta
