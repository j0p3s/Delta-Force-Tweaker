<div align="center">

# Delta Force Tweaker

**Hardware-aware graphics settings, a ready-to-use config file and a tuned NVIDIA driver profile for Delta Force.**

[![Version](https://img.shields.io/badge/version-1.1.0--beta-orange)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-blue)](#requirements)
[![Web app](https://img.shields.io/badge/web%20app-open-22c55e)](https://j0p3s.github.io/Delta-Force-Tweaker/)

### 👉 [Open the web app](https://j0p3s.github.io/Delta-Force-Tweaker/) — no download, runs in your browser

</div>

---

> [!NOTE]
> **Beta release.** Version 1.1.0-beta. The 1.0.0-beta base was tested on one PC (Windows 10 22H2, RTX 3080 Laptop, game version 1.102.37117). Please [report issues](../../issues) with your hardware and Windows version so it can be verified on more systems.

## Table of contents

- [What it does](#what-it-does)
- [Option 1: Web app (recommended)](#option-1-web-app-recommended)
- [Option 2: Windows script](#option-2-windows-script)
- [Safety and anti-cheat](#safety-and-anti-cheat)
- [How settings are chosen](#how-settings-are-chosen)
- [Config file reference](#config-file-reference)
- [NVIDIA driver profile](#nvidia-driver-profile)
- [Troubleshooting](#troubleshooting)
- [Undo everything](#undo-everything)
- [Contributing](#contributing)
- [Credits and license](#credits-and-license)

## What it does

| Feature | Web app | Windows script |
|---|:---:|:---:|
| Detects your hardware and picks a tier (Low / Medium / High / Epic) | ✅ | ✅ |
| Recommended in-game settings: **Balanced** or **Competitive** | ✅ | ✅ |
| **Potato shadows** switch: Shadows + Shadow Map at Low in any profile | ✅ | ✅ |
| Writes those settings to `UserSystemSettingHD.ini` (with backup) | ✅ download | ✅ in place |
| NVIDIA Profile Inspector profile (`.nip`) for Delta Force only | ✅ download | ✅ applied and verified |
| Finds the game folder (Steam, launcher, registry, all drives) | — | ✅ |
| Skips the intro videos (reversible) | instructions | ✅ |
| Clears the game's shader cache | — | ✅ |
| Backs up and restores the game's local config | — | ✅ |
| Windows 10/11 gaming settings (Game Mode, GPU scheduling, ...) | instructions | ✅ |
| Languages | EN, PT, ES, FR, DE, RU | EN |

## Option 1: Web app (recommended)

**[j0p3s.github.io/Delta-Force-Tweaker](https://j0p3s.github.io/Delta-Force-Tweaker/)**

Everything runs locally in your browser. There is no server, no tracking and no upload: your file is read and edited on your own PC.

1. **Choose your hardware** (or click *Detect automatically* and then check VRAM and RAM) and a profile. Tick **Potato shadows** for the biggest FPS gain on weak GPUs and laptops.
2. **Read the recommended settings.** You can simply set them in the game menu, which is the risk-free way.
3. **Optional, edit the config file:**
   1. In the game: *Settings* → press <kbd>S</kbd> (*Config Management*) → make sure **LocalConfig** is **APPLIED**, then exit from the game menu.
   2. In Steam: *Library* → right-click **Delta Force** → *Manage* → *Browse local files*.
   3. Open `Game\DeltaForce\Saved\Config\WindowsClient` and back up `UserSystemSettingHD.ini`.
   4. Drop the file on the page, download the edited copy and put it back in the same folder.
4. **Optional, NVIDIA cards:** download the `.nip` profile, open [NVIDIA Profile Inspector](https://github.com/j0p3s/nvidiaProfileInspector), click *Import user defined profiles*, choose **Merge** if asked, then *Apply changes*.

## Option 2: Windows script

For people who want everything done automatically.

### Requirements

- Windows 10 (1809 or newer) or Windows 11
- Windows PowerShell 5.1 (built into Windows)
- Administrator rights (asked once, see below)

### Run it

1. Download `Delta-Force-Tweaker_v1.1.0-beta.cmd` from [Releases](../../releases).
2. Close Delta Force.
3. Double-click the file. Windows may show *"Windows protected your PC"* because the file is new and unsigned: click *More info* → *Run anyway*. The script is plain text, so you can open it in Notepad and read every line first.
4. Accept the UAC prompt **once**. The script creates a scheduled task called **Delta Force Tweaker** so later runs open as administrator without asking again. Remove it any time with option **[R]**.

### Menu

| Key | Action |
|---|---|
| `1` / `2` | Show and save recommended settings (Balanced / Competitive) |
| `P` | Potato shadows on/off (Shadows + Shadow Map at Low in any profile) |
| `W` | Write the settings to `UserSystemSettingHD.ini` (warning, `YES` confirmation, automatic backup) |
| `3` | Clear the game's shader cache |
| `V` | Skip / restore the intro videos |
| `4` / `8` / `9` | Back up / restore / open the game's local config |
| `5` / `6` / `7` | NVIDIA profile: optimize / open Profile Inspector / restore original |
| `G` | Windows gaming settings: Game Mode, Hardware-accelerated GPU scheduling, background recording, windowed game optimizations (Windows 11), power plan |
| `C` | Check the installation and files again |
| `A` / `R` | Enable / remove start without UAC prompt |

At startup the script checks that it found the game, the executable, the config folder, the intro videos and the settings file, and shows what is missing.

### Files it creates (next to the script)

| Path | Content |
|---|---|
| `DeltaForce_Backups\<date_time>\` | Copies of the game's `Saved\Config` folder |
| `DeltaForce_Recommended_<profile>.txt` | The recommended settings report |
| `nvidiaProfileInspector\` | NVIDIA Profile Inspector (downloaded on first use) |
| `nvidiaProfileInspector\Backups\` | Exports of your NVIDIA profiles before every change |
| `.no_task`, `.previous_power_plan` | Small state files |

## Safety and anti-cheat

> [!WARNING]
> Team Jade has warned that changing configuration files outside the game may lead to anti-cheat (ACE) penalties. Writing the config file (web app step 3, script option **W**) is **optional and at your own risk**. The risk-free way is to set the recommended values in the game menu yourself.

What this project does and does not touch:

| | Touched? |
|---|---|
| `UserSystemSettingHD.ini`, graphics section only, only with values the in-game menu also allows | Only if you choose to (with backup) |
| `Engine.ini`, `Scalability.ini`, `DeviceProfiles.ini`, `GPSystemSetting.ini` (token-protected) | **Never** |
| Game executables, `.pak` files, memory, network | **Never** |
| Intro video files (`Content\Movies_HD\*.bin`) | Renamed to `.bak` only if you choose option **V** |
| NVIDIA driver profile for Delta Force | Only if you choose to (backup + restore) |

## How settings are chosen

The tier comes from VRAM, then it is lowered for integrated GPUs, older GPU generations (GTX 900/10/16, RX 400/500, Vega) and limited RAM or CPU threads. Texture quality depends on VRAM only.

Example for an RTX 3080 Laptop (16 GB VRAM, 1080p 144 Hz, tier **Epic**):

| Setting | Balanced | Competitive |
|---|---|---|
| Textures | Ultra | Ultra |
| Shadows | High | Low |
| Scene View Distance | Ultra | High |
| Lumen (GI) | Ultra | Low |
| Shadow Map, Shaders, Post-Processing, Volumetric Fog, Particles | High | Low |
| Ambient Occlusion | High | Off |
| Super Resolution (DLSS) | Quality | Balanced |
| NVIDIA Reflex | Low Latency | Enhanced |
| In-Match Frame Rate Cap | 144 | Unlimited |

## Config file reference

Delta Force stores its graphics settings in
`<Steam library>\steamapps\common\Delta Force\Game\DeltaForce\Saved\Config\WindowsClient\UserSystemSettingHD.ini`,
section `[/Script/GPGlobalDefines.ClientVideoSettingHD]`. The scales below were confirmed against the in-game menu (game version 1.102.37117):

| Scale | Values |
|---|---|
| Quality settings | `0` Low · `1` Medium · `2` High · `3` Ultra · `4` Extreme · `5` Ultimate |
| `AmbientOcclusionQuality` | `0` Off · `1` Medium · `2` High · `3` Ultra · `4` Extreme · `5` Ultimate |
| `SuperResolutionQualityDLSS` | `0` Auto · `1` Ultra Performance · `2` Performance · `3` Balanced · `4` Quality |
| `MaxFPS` (In-Match Frame Rate Cap) | `0` Unlimited · `1` 30 · `2` 60 · `3` 75 · `4` 100 · `5` 120 · `6` 144 |
| `NVIDIAReflexMode` | `0` Off · `1` Low Latency · `2` Enhanced |
| `GraphicsPreset` | `0` Custom |

| Menu name | File key |
|---|---|
| Textures | `TextureQuality` |
| Texture Filtering | `TextureFilteringQuality` |
| Streaming | `StreamingQuality` |
| Scene Details | `SceneDetailLevel` |
| Scene View Distance | `ViewDistanceLevel` |
| Shaders | `ShadingQuality` |
| Shadows | `ShadowQuality` |
| Shadow Map | `ShadowMapResolution` |
| Lumen (GI) | `GIQuality` |
| Reflections | `ReflectionQuality` |
| Ambient Occlusion | `AmbientOcclusionQuality` |
| Particles | `ParticleQuality` |
| Distortion | `DistortionQuality` |
| Post-Processing | `PostProcessQuality` |
| Volumetric Fog | `VolumetricFogQuality` |
| Animation | `AnimationQuality` |

Good to know:

- The game **omits keys that are at their default value**, so a key may be missing from your file. The tools add it.
- `SuperResolutionMethod` is **not** positional (Nvidia DLSS is `4` although it is 3rd in the list), so it is never changed.
- `RealViewportResolution` shows the internal render resolution, a quick way to confirm the DLSS mode (960×540 at 1080p = Performance, 1113×626 = Balanced).

## NVIDIA driver profile

Merged into NVIDIA's official **Delta Force** profile (executables `deltaforceclient-win64-shipping.exe`, `deltaforce-win64-shipping.exe`, `deltaforce.exe`, `bhdclient-win64-shipping.exe`):

| Setting | Value | Why |
|---|---|---|
| Power management mode | Prefer maximum performance | GPU does not drop clocks mid-match |
| Texture filtering - Quality | High performance | Minimal visual difference |
| Texture filtering - Anisotropic sample optimization | On | Small performance gain |
| Texture filtering - Negative LOD bias | Allow | Keeps DLSS/FSR sharp |
| Maximum pre-rendered frames | 1 | Low latency (Reflex overrides it when on) |
| Threaded optimization | On | The game runs in DirectX 11 |
| Enable FXAA | Off | The game uses its own AA/upscaler |

V-sync and G-SYNC are left exactly as NVIDIA set them in the official profile (G-SYNC is off for this game by NVIDIA).

## Troubleshooting

<details>
<summary><b>My settings went back after starting the game</b></summary>

A Cloud Config was applied on top of the local file. In the game press <kbd>S</kbd> in Settings (*Config Management*), apply **LocalConfig**, and optionally save it as a Cloud Config.
</details>

<details>
<summary><b>The intro videos came back</b></summary>

Game updates and Steam's *Verify integrity of game files* restore them. Run option **V** again or rename the three files again.
</details>

<details>
<summary><b>"Could not confirm the profile in the driver"</b></summary>

Your driver may use a different profile name. Open NVIDIA Profile Inspector (option **6**), search for "delta force", and import `nvidiaProfileInspector\DeltaForce_Tweaker.nip` manually choosing **Merge**. Please open an issue with the profile name you see.
</details>

<details>
<summary><b>The script does not find the game</b></summary>

Launch the game once (so Windows records its path), then use option **C**. The script searches Steam libraries, uninstall entries, registry traces and every internal drive.
</details>

<details>
<summary><b>Stutter after a driver update</b></summary>

Use option **3** (clear shader cache) or *Recompile Shaders* (<kbd>G</kbd>) in the game's settings.
</details>

## Undo everything

| What | How |
|---|---|
| Config file | Script option **8**, or copy your backup of `UserSystemSettingHD.ini` back |
| NVIDIA profile | Script option **7**, or *Restore profile to NVIDIA defaults* in Profile Inspector |
| Intro videos | Script option **V** again |
| Windows settings | Script option **G** (each setting switches back) |
| Scheduled task | Script option **R** |

## Contributing

Bug reports and confirmations on other hardware are very welcome. Please use the [issue templates](../../issues/new/choose) and include the script version, Windows version, GPU and, if possible, your `UserSystemSettingHD.ini` graphics section.

Changes are listed in [CHANGELOG.md](CHANGELOG.md). Versions follow [Semantic Versioning](https://semver.org/); the version is set in the `VERSION` line of the script and the `VERSION` constant in `index.html`.

## Credits and license

- [NVIDIA Profile Inspector](https://github.com/Orbmu2k/nvidiaProfileInspector) by Orbmu2k (MIT). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- Delta Force Tweaker is released under the [MIT License](LICENSE).

*Not affiliated with Team Jade, TiMi Studio Group, Tencent or NVIDIA. Delta Force is a trademark of its respective owners. Use at your own risk.*
