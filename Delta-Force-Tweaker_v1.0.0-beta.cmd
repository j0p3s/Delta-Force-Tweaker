@echo off
setlocal EnableExtensions
set "VERSION=1.0.0-beta"
title Delta Force Tweaker v%VERSION%

:: ------------------------------------------------------------------
::  Delta Force Tweaker v1.0.0-beta
::  https://github.com/j0p3s/Delta-Force-Tweaker
::
::  - Detects CPU, RAM, GPU (VRAM), resolution and refresh rate
::  - Shows and saves (.txt) recommended in-game settings for your
::    hardware (Balanced or Competitive profile)
::  - Option [W] (optional, with warning): writes those values to
::    UserSystemSettingHD.ini, after a backup. Value scales were
::    confirmed against the in-game menu. Never touches the token-
::    protected files (Engine.ini, Scalability.ini, DeviceProfiles.ini,
::    GPSystemSetting.ini). Team Jade warns that editing .ini files
::    may lead to anti-cheat (ACE) penalties.
::  - Clears the game's shader cache (optional)
::  - Skips the intro videos (renames the 3 .bin files to .bak;
::    reversible with the same option)
::  - Backs up and restores the game's local config (copies files
::    the game itself writes; edits nothing)
::  - Downloads NVIDIA Profile Inspector and applies a tuned driver
::    profile for Delta Force only (with backup and restore)
::  - Windows 10/11 gaming checks: Game Mode, Hardware-accelerated GPU
::    scheduling, background recording, windowed game optimizations
::    (Windows 11) and power plan
::
::  Runs as administrator. The first run asks for UAC once and creates
::  the scheduled task "Delta Force Tweaker"; after that a double-click
::  is enough. To undo: option [R] in the menu.
::
::  Requires Windows 10 (1809 or newer) or Windows 11.
:: ------------------------------------------------------------------

set "TASK=Delta Force Tweaker"
set "SELF=%~f0"
set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PSEXE%" set "PSEXE=powershell.exe"

rem Admin check (fltmc works even when the Server service is disabled)
fltmc >nul 2>&1
if %errorlevel% neq 0 (
    rem If the elevated task exists and points to this file, start through it (no UAC prompt)
    "%PSEXE%" -NoProfile -Command "$t = Get-ScheduledTask -TaskName '%TASK%' -ErrorAction SilentlyContinue; if ($t -and $t.Actions[0].Arguments.ToLower().Contains($env:SELF.ToLower())) { Start-ScheduledTask -TaskName '%TASK%' -ErrorAction Stop; exit 0 } else { exit 1 }" 2>nul
    if not errorlevel 1 exit /b
    echo Requesting administrator privileges ^(only this time^)...
    "%PSEXE%" -NoProfile -Command "Start-Process -FilePath $env:SELF -Verb RunAs"
    exit /b
)

set "PS1=%TEMP%\delta_force_tweaker_%RANDOM%.ps1"
"%PSEXE%" -NoProfile -Command "$l = Get-Content -LiteralPath $env:SELF; $i = [array]::IndexOf($l, '::__PS_BEGIN__'); $l[($i+1)..($l.Count-1)] | Set-Content -LiteralPath '%PS1%' -Encoding UTF8"
if not exist "%PS1%" (
    echo ERROR: could not prepare the script.
    pause
    exit /b 1
)
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Here "%~dp0." -Self "%~f0" -Version "%VERSION%"
del /q "%PS1%" >nul 2>&1
echo.
pause
exit /b 0

::__PS_BEGIN__
param([string]$Here = (Get-Location).Path, [string]$Self = '', [string]$Version = '1.0.0-beta')
$Here = [IO.Path]::GetFullPath($Here)
$ErrorActionPreference = 'SilentlyContinue'
$Host.UI.RawUI.WindowTitle = "Delta Force Tweaker v$Version"
$Q = @('Low', 'Medium', 'High', 'Epic', 'Cinematic')

# ======================= Windows version =======================
$os      = Get-CimInstance Win32_OperatingSystem
$osBuild = [int]$os.BuildNumber
$osUbr   = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR
$osDisp  = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
$isWin11 = $osBuild -ge 22000
$osName  = $(if ($isWin11) { 'Windows 11' } elseif ($osBuild -ge 10240) { 'Windows 10' } else { $os.Caption })
$osText  = "$osName $osDisp (build $osBuild.$osUbr)"
$osSupported = $osBuild -ge 17763

# ======================= Hardware detection =======================
$cpu     = Get-CimInstance Win32_Processor
$cpuName = (($cpu | Select-Object -First 1).Name).Trim()
$threads = ($cpu | Measure-Object NumberOfLogicalProcessors -Sum).Sum
$cores   = ($cpu | Measure-Object NumberOfCores -Sum).Sum
$ramGB   = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)

# GPU: reads the real VRAM from the registry (WMI caps it at 4 GB) and picks the GPU
# with the most VRAM (on an Optimus/Intel + NVIDIA laptop this is the dedicated one)
$gpus = @()
$classKey = 'HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
foreach ($k in Get-ChildItem -LiteralPath $classKey) {
    if ($k.PSChildName -notmatch '^\d{4}$') { continue }
    $p = Get-ItemProperty -LiteralPath $k.PSPath
    if (-not $p.DriverDesc) { continue }
    $mem = 0
    $q = $p.'HardwareInformation.qwMemorySize'
    if ($q) { $mem = [double]$q }
    else {
        $m = $p.'HardwareInformation.MemorySize'
        if ($m -is [byte[]]) { $mem = [double][BitConverter]::ToUInt32($m, 0) }
        elseif ($m) { $mem = [double]$m }
    }
    $gpus += [pscustomobject]@{ Name = $p.DriverDesc; VRAM = $mem }
}
if ($gpus.Count -eq 0) {
    $gpus = Get-CimInstance Win32_VideoController | ForEach-Object { [pscustomobject]@{ Name = $_.Name; VRAM = [double]$_.AdapterRAM } }
}
$gpu = $gpus | Where-Object { $_.Name -notmatch 'Basic Display|Remote|Virtual|Parsec|Meta' } | Sort-Object VRAM -Descending | Select-Object -First 1
$gpuName = $gpu.Name
$vramGB  = [math]::Round($gpu.VRAM / 1GB, 1)

# Monitor: current resolution and refresh rate
$vc = Get-CimInstance Win32_VideoController | Where-Object { $_.CurrentHorizontalResolution -gt 0 } | Sort-Object CurrentRefreshRate -Descending | Select-Object -First 1
$resX = [int]$vc.CurrentHorizontalResolution
$resY = [int]$vc.CurrentVerticalResolution
$hz   = [int]$vc.CurrentRefreshRate
if ($resX -le 0) { $resX = 1920; $resY = 1080 }
if ($hz -le 0) { $hz = 60 }

# ======================= Hardware tier =======================
# 0 Low, 1 Medium, 2 High, 3 Epic
if     ($vramGB -lt 4)  { $tier = 0 }
elseif ($vramGB -lt 6)  { $tier = 1 }
elseif ($vramGB -lt 10) { $tier = 2 }
else                    { $tier = 3 }
$reason = "VRAM $vramGB GB"

$isIntegrated = ($gpuName -match 'Intel\(R\) (UHD|HD|Iris)|Radeon\(TM\) Graphics|Radeon Graphics|Vega \d+ Graphics') -and ($gpuName -notmatch 'Arc')
if ($isIntegrated) { $tier = 0; $reason = 'integrated GPU' }
if ($gpuName -match 'GTX\s*(9\d\d|10[0-6]\d|16\d\d)|RX\s*(4\d\d|5\d\d)\b|R9|R7') { if ($tier -gt 1) { $tier = 1; $reason = 'older GPU generation' } }
if ($gpuName -match 'GTX\s*10[78]0|RX\s*5[67]00|Vega\s*(56|64)')                 { if ($tier -gt 2) { $tier = 2; $reason = 'older GPU generation' } }
if ($ramGB -lt 12 -or $threads -lt 6) { if ($tier -gt 1) { $tier = 1; $reason = 'limited by RAM/CPU' } }
elseif ($ramGB -lt 16 -or $threads -lt 8) { if ($tier -gt 2) { $tier = 2; $reason = 'limited by RAM/CPU' } }

# Texture quality depends on VRAM only
if     ($vramGB -lt 4) { $tex = 0 }
elseif ($vramGB -lt 6) { $tex = 1 }
elseif ($vramGB -lt 8) { $tex = 2 }
else                   { $tex = 3 }
if ($isIntegrated) { $tex = 0 }

# ======================= Upscaler =======================
if     ($gpuName -match 'RTX')        { $upAuto = 'DLSS - Quality';  $upNote = 'With FPS to spare you can use DLAA.' }
elseif ($gpuName -match 'NVIDIA|GTX') { $upAuto = 'FSR - Quality';   $upNote = 'Your GPU does not support DLSS.' }
elseif ($gpuName -match 'Arc')        { $upAuto = 'XeSS - Quality';  $upNote = '' }
elseif ($gpuName -match 'AMD|Radeon') { $upAuto = 'FSR - Quality';   $upNote = '' }
else                                  { $upAuto = 'FSR - Balanced';  $upNote = 'Integrated GPU: if you stay below 60 FPS, use FSR Performance.' }
$isNvidia = $gpuName -match 'NVIDIA|GeForce|RTX|GTX|Quadro'

function Test-GameRunning {
    return [bool](Get-Process | Where-Object { $_.ProcessName -match 'deltaforce' })
}

# ======================= Value scales confirmed in the game menu =======================
# (Graphics menu screenshots + UserSystemSettingHD.ini, game version 1.102.37117)
# Quality settings:  0 Low | 1 Medium | 2 High | 3 Ultra | 4 Extreme | 5 Ultimate
# Ambient Occlusion: 0 Off | 1 Medium | 2 High | 3 Ultra | 4 Extreme | 5 Ultimate
# DLSS:              0 Auto | 1 Ultra Performance | 2 Performance | 3 Balanced | 4 Quality
# Frame Rate Cap:    0 Unlimited | 1 30 | 2 60 | 3 75 | 4 100 | 5 120 | 6 144
# Reflex:            0 Off | 1 Low Latency | 2 Enhanced (= On + Boost)
# Shadows (ShadowQuality) and Scene View Distance (ViewDistanceLevel): same quality scale.
# GraphicsPreset=0 = Custom.
# The game only writes keys that differ from their default value (confirmed by comparing
# configs before/after); missing keys are added by the script.
# SuperResolutionMethod is NOT positional (DLSS = 4 although it is 3rd in the list),
# so the script never changes it.
$QN    = @('Low', 'Medium', 'High', 'Ultra', 'Extreme', 'Ultimate')
$AON   = @('Off', 'Medium', 'High', 'Ultra', 'Extreme', 'Ultimate')
$DLSSN = @('Auto', 'Ultra Performance', 'Performance', 'Balanced', 'Quality')
$RFXN  = @('Off', 'Low Latency', 'Enhanced')
$FpsMap = @{ 30 = 1; 60 = 2; 75 = 3; 100 = 4; 120 = 5; 144 = 6 }

function Get-FpsIndex($target) {
    if ($target -le 0) { return @{ Idx = 0; Txt = 'Unlimited' } }
    if ($FpsMap.ContainsKey([int]$target)) { return @{ Idx = $FpsMap[[int]$target]; Txt = "$target" } }
    if ($target -gt 144) { return @{ Idx = 0; Txt = 'Unlimited (the menu has no option for your refresh rate)' } }
    $best = ($FpsMap.Keys | Where-Object { $_ -le $target } | Sort-Object -Descending | Select-Object -First 1)
    if (-not $best) { $best = 30 }
    return @{ Idx = $FpsMap[$best]; Txt = "$best" }
}

# Values (file indices) for each profile, based on the hardware tier
function Get-DFProfile($mode) {
    $t = [math]::Min($tier, 3); $c = ($mode -eq 'Competitive')
    $p = [ordered]@{}
    #   key in the file                       name in the menu           value                                                        scale
    $p['TextureQuality']          = @('Textures',            $tex,                                                        'Q')
    $p['GraphicsPreset']          = @('Graphics Preset',     0,                                                           'PRE')
    $p['ShadowQuality']           = @('Shadows',             $(if ($c) { 0 } else { [math]::Min($t, 2) }),                'Q')
    $p['ViewDistanceLevel']       = @('Scene View Distance', $(if ($c) { [math]::Max([math]::Min($t, 2), 1) } else { $t }), 'Q')
    $p['TextureFilteringQuality'] = @('Texture Filtering',   [math]::Min([math]::Max($t, 2), 3),                          'Q')
    $p['StreamingQuality']        = @('Streaming',           $(if ($c) { [math]::Min($t, 1) } else { [math]::Min($t, 2) }), 'Q')
    $p['SceneDetailLevel']        = @('Scene Details',       $(if ($c) { 0 } else { $t }),                                'Q')
    $p['ShadingQuality']          = @('Shaders',             $(if ($c) { 0 } else { [math]::Min($t, 2) }),                'Q')
    $p['ShadowMapResolution']     = @('Shadow Map',          $(if ($c) { 0 } else { [math]::Min($t, 2) }),                'Q')
    $p['GIQuality']               = @('Lumen (GI)',          $(if (-not $c -and $t -ge 3) { 3 } else { 0 }),              'Q')
    $p['ReflectionQuality']       = @('Reflections',         $(if ($c) { 0 } else { [math]::Max($t - 1, 0) }),            'Q')
    $p['AmbientOcclusionQuality'] = @('Ambient Occlusion',   $(if (-not $c -and $t -ge 2) { 2 } else { 0 }),              'AO')
    $p['ParticleQuality']         = @('Particles',           $(if ($c) { 0 } else { [math]::Min($t, 2) }),                'Q')
    $p['DistortionQuality']       = @('Distortion',          $(if ($c) { 0 } else { [math]::Min($t, 2) }),                'Q')
    $p['PostProcessQuality']      = @('Post-Processing',     $(if ($c) { 0 } else { [math]::Min($t, 2) }),                'Q')
    $p['VolumetricFogQuality']    = @('Volumetric Fog',      $(if ($c) { 0 } else { [math]::Min($t, 2) }),                'Q')
    $p['AnimationQuality']        = @('Animation',           $(if ($c) { 0 } else { [math]::Min($t, 2) }),                'Q')
    if ($gpuName -match 'RTX') {
        $p['SuperResolutionQualityDLSS'] = @('Super Resolution (DLSS)', $(if ($c) { 3 } else { 4 }), 'DLSS')
    }
    if ($isNvidia) { $p['NVIDIAReflexMode'] = @('NVIDIA REFLEX Low Latency', $(if ($c) { 2 } else { 1 }), 'RFX') }
    $fps = Get-FpsIndex $(if ($c) { 0 } else { $hz })
    $p['MaxFPS'] = @('In-Match Frame Rate Cap', $fps.Idx, 'FPS', $fps.Txt)
    return $p
}

function Get-ValueName($e) {
    switch ($e[2]) {
        'Q'    { return $QN[$e[1]] }
        'AO'   { return $AON[$e[1]] }
        'DLSS' { return $DLSSN[$e[1]] }
        'RFX'  { return $RFXN[$e[1]] }
        'FPS'  { return $e[3] }
        'PRE'  { return 'Custom' }
    }
}

function Show-Recommendations($mode) {
    $p = Get-DFProfile $mode
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add('==================================================================')
    $out.Add("  DELTA FORCE - RECOMMENDED SETTINGS ($($mode.ToUpper()))")
    $out.Add("  Delta Force Tweaker v$Version")
    $out.Add('==================================================================')
    $out.Add("Generated:  $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
    $out.Add("Windows:    $osText")
    $out.Add("CPU:        $cpuName ($cores cores / $threads threads)")
    $out.Add("RAM:        $ramGB GB")
    $out.Add("GPU:        $gpuName ($vramGB GB VRAM)")
    $out.Add("Monitor:    ${resX}x${resY} @ ${hz} Hz")
    $out.Add("Tier:       $($Q[$tier]) ($reason)")
    $out.Add('')
    $out.Add('Settings > GRAPHICS (names as shown in the game):')
    $out.Add('  Display Mode'.PadRight(42, '.') + ' Fullscreen or Borderless Windowed')
    $out.Add('  V-sync'.PadRight(42, '.') + ' Off')
    foreach ($k in $p.Keys) { $out.Add(('  ' + $p[$k][0]).PadRight(42, '.') + ' ' + (Get-ValueName $p[$k])) }
    $out.Add('  Super Resolution Mode'.PadRight(42, '.') + $(if ($gpuName -match 'RTX') { ' Nvidia DLSS' } else { " $upAuto" }))
    $out.Add('  DLSS Frame Generation'.PadRight(42, '.') + ' Off')
    $out.Add('  Depth of Field / Weapon Motion Blur'.PadRight(42, '.') + ' Off')
    $out.Add('  Default FOV'.PadRight(42, '.') + $(if ($mode -eq 'Competitive') { ' 105 to 120' } else { ' 90 to 105' }))
    if ($upNote) { $out.Add(''); $out.Add("Note: $upNote") }
    $out.Add('')
    $out.Add('Option [W] writes the values above to UserSystemSettingHD.ini')
    $out.Add('automatically (with a warning and a backup).')
    $file = Join-Path $Here "DeltaForce_Recommended_$mode.txt"
    $out | Out-File -LiteralPath $file -Encoding UTF8
    Write-Host ''
    $out | ForEach-Object { Write-Host $_ }
    Write-Host ''
    Write-Host "Saved to: $file" -ForegroundColor Green
}

# ======================= Write to UserSystemSettingHD.ini =======================
function Write-DFSettings {
    if (Test-GameRunning) { Write-Host 'Close Delta Force first (the game writes this file when it exits).' -ForegroundColor Red; return }
    $chk = Test-DFInstall
    $f = $chk.Video
    if (-not $f) { Write-Host ''; Write-Host 'Cannot continue: UserSystemSettingHD.ini is missing (see above).' -ForegroundColor Red; return }
    Show-LocalConfigHelp
    Write-Host ''
    if ((Read-Host 'Is LocalConfig APPLIED and the game closed? (Y/N)') -notmatch '^[yY]') { Write-Host 'Cancelled. Follow the steps above and come back to this option.'; return }

    Write-Host ''
    Write-Host '  [1] Balanced   [2] Competitive'
    $m = Read-Host 'Profile (Enter to cancel)'
    $mode = if ($m -eq '1') { 'Balanced' } elseif ($m -eq '2') { 'Competitive' } else { return }

    Write-Host ''
    Write-Host '!!! WARNING !!!' -ForegroundColor Yellow
    Write-Host 'Team Jade has warned that changing configuration files outside the game may'
    Write-Host 'lead to anti-cheat penalties. This file is not one of the token-protected'
    Write-Host 'ones and only receives values the in-game menu also allows, but it is still'
    Write-Host 'a change made outside the game. Use at your own risk.'
    Write-Host 'Risk-free alternative: options 1/2 and change the settings by hand in the menu.'
    Write-Host ''
    if ((Read-Host 'Type YES to continue') -cne 'YES') { Write-Host 'Cancelled.'; return }

    Write-Host 'Backing up the local config...'
    Backup-LocalConfig

    # keep the file's original encoding
    $b = [IO.File]::ReadAllBytes($f)
    if ($b.Length -ge 2 -and $b[0] -eq 0xFF -and $b[1] -eq 0xFE) { $enc = New-Object System.Text.UnicodeEncoding($false, $true) }
    elseif ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { $enc = New-Object System.Text.UTF8Encoding($true) }
    else { $enc = New-Object System.Text.UTF8Encoding($false) }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.AddRange([string[]][IO.File]::ReadAllLines($f, $enc))
    $start = -1; $end = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '[/Script/GPGlobalDefines.ClientVideoSettingHD]') { $start = $i; continue }
        if ($start -ge 0 -and $lines[$i].Trim() -match '^\[') { $end = $i; break }
    }
    if ($start -lt 0) { Write-Host 'Section [ClientVideoSettingHD] not found. Nothing was changed.' -ForegroundColor Red; return }

    # Only touch DLSS quality if the game is already using DLSS (SuperResolutionMethod=4)
    $method = ($lines[($start + 1)..($end - 1)] | Where-Object { $_ -match '^SuperResolutionMethod=' } | Select-Object -First 1) -replace '^SuperResolutionMethod=', ''

    $p = Get-DFProfile $mode
    Write-Host ''
    foreach ($k in $p.Keys) {
        if ($k -eq 'SuperResolutionQualityDLSS' -and $method -ne '4') { Write-Host "  [--] $($p[$k][0]): the game is not using DLSS, not changed" -ForegroundColor DarkGray; continue }
        $done = $false
        for ($i = $start + 1; $i -lt $end; $i++) {
            if ($lines[$i] -match ('^' + [regex]::Escape($k) + '=(.*)$')) {
                $old = $Matches[1]
                $lines[$i] = "$k=$($p[$k][1])"
                $done = $true
                $tag = if ($old -eq "$($p[$k][1])") { '[==]' } else { '[OK]' }
                Write-Host ("  $tag " + $p[$k][0].PadRight(28) + (Get-ValueName $p[$k]))
                break
            }
        }
        if (-not $done) {
            # the game omits keys that are at their default value: add them at the end of the section
            $ins = $end
            while ($ins -gt $start + 1 -and $lines[$ins - 1].Trim() -eq '') { $ins-- }
            $lines.Insert($ins, "$k=$($p[$k][1])")
            $end++
            Write-Host ("  [+]  " + $p[$k][0].PadRight(28) + (Get-ValueName $p[$k]))
        }
    }
    [IO.File]::WriteAllText($f, (($lines -join "`r`n") + "`r`n"), $enc)
    Write-Host ''
    Write-Host "Profile '$mode' written to: $f" -ForegroundColor Green
    Write-Host 'Open the game and check Settings > GRAPHICS (Graphics Preset should show Custom).' -ForegroundColor Yellow
    Write-Host 'If the game applies a Cloud Config on startup, it may replace these values:' -ForegroundColor DarkGray
    Write-Host 'in that case, open Config Management and save the LocalConfig over the Cloud Config.' -ForegroundColor DarkGray
}

# ======================= Shader cache =======================
function Clear-ShaderCache {
    if (Test-GameRunning) { Write-Host 'Close Delta Force first.' -ForegroundColor Red; return }
    $roots = @(Join-Path $env:LOCALAPPDATA 'DeltaForce\Saved')
    foreach ($g in Get-GameDirs) { $roots += (Join-Path $g 'Game\DeltaForce\Saved') }
    $found = @()
    foreach ($r in $roots) {
        if (-not (Test-Path -LiteralPath $r)) { continue }
        $found += Get-ChildItem -LiteralPath $r -Directory | Where-Object { $_.Name -match '^(ShaderCache|D3DSCache|PipelineCaches)$' }
    }
    if ($found.Count -eq 0) { Write-Host 'No Delta Force shader cache found.' -ForegroundColor Yellow; return }
    Write-Host ''
    foreach ($f in $found) {
        $mb = [math]::Round((Get-ChildItem -LiteralPath $f.FullName -Recurse -File | Measure-Object Length -Sum).Sum / 1MB)
        Write-Host "  $($f.FullName)  ($mb MB)"
    }
    Write-Host ''
    Write-Host 'Useful after a driver update or if the game stutters. The game rebuilds the'
    Write-Host 'shaders on the next launch (the first launch takes longer).'
    if ((Read-Host 'Delete? (Y/N)') -notmatch '^[yY]') { return }
    foreach ($f in $found) { Remove-Item -LiteralPath $f.FullName -Recurse -Force }
    Write-Host 'Shader cache deleted.' -ForegroundColor Green
}

# ======================= Game folder detection =======================
# Order: Steam libraries, uninstall entries (official launcher), other Windows registry
# traces and, if nothing is found, a search across all drives.
# The result is cached while the script is open (option [C] searches again).
$script:gameDirsCache = $null

function Test-GameDir($d) {
    return ($d -and (Test-Path -LiteralPath (Join-Path $d 'Game\DeltaForce')))
}

function Find-GameDirsOnDisks {
    $found = @()
    $drives = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { $_.DeviceID + '\' })
    $rel = @('SteamLibrary\steamapps\common\Delta Force', 'Steam\steamapps\common\Delta Force',
             'Program Files (x86)\Steam\steamapps\common\Delta Force', 'Program Files\Steam\steamapps\common\Delta Force',
             'Games\Steam\steamapps\common\Delta Force', 'Games\SteamLibrary\steamapps\common\Delta Force',
             'Games\Delta Force', 'Delta Force', 'Program Files\Delta Force', 'Program Files (x86)\Delta Force')
    foreach ($dr in $drives) {
        foreach ($r in $rel) { $p = Join-Path $dr $r; if (Test-GameDir $p) { $found += $p } }
    }
    if ($found.Count -gt 0) { return $found }
    # Deeper search (up to 4 levels) for a "Delta Force" folder that contains Game\DeltaForce
    Write-Host 'Searching all drives for Delta Force (this may take a moment)...' -ForegroundColor DarkGray
    foreach ($dr in $drives) {
        Get-ChildItem -LiteralPath $dr -Directory -Recurse -Depth 4 -Filter 'Delta Force*' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\(Windows|\$Recycle\.Bin|System Volume Information|ProgramData\\Microsoft)\\' } |
            ForEach-Object { if (Test-GameDir $_.FullName) { $found += $_.FullName } }
    }
    return $found
}

# Windows registry traces: Windows records the path of executables that have run
# (Compatibility Assistant, MuiCache), firewall rules and GPU preferences.
# The game only needs to have been launched once.
function Find-GameDirsInRegistry {
    $paths = @()
    $valueNameKeys = @(
        'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store',
        'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache',
        'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences',
        'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers',
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    )
    foreach ($k in $valueNameKeys) {
        $item = Get-Item -LiteralPath $k
        if ($item) { $paths += @($item.GetValueNames() | Where-Object { $_ -match 'DeltaForce' }) }
    }
    # Firewall rules (App=C:\...\DeltaForceClient-Win64-Shipping.exe)
    $fw = Get-Item -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules'
    if ($fw) {
        foreach ($n in $fw.GetValueNames()) {
            $v = [string]$fw.GetValue($n)
            if ($v -match 'App=([^|]*DeltaForce[^|]*\.exe)') { $paths += $Matches[1] }
        }
    }
    # Steam uninstall entry for the game's AppID
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2507950', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 2507950') {
        $loc = (Get-ItemProperty -LiteralPath $k).InstallLocation
        if ($loc) { $paths += $loc }
    }
    $dirs = @()
    foreach ($p in $paths) {
        $p = [Environment]::ExpandEnvironmentVariables(($p -replace '/', '\').Trim('"'))
        if ($p -match '^(.*?)\\Game\\DeltaForce(\\|$)') { $dirs += $Matches[1] }
        elseif ($p -notmatch '\.exe$') { $dirs += $p.TrimEnd('\') }
    }
    return @($dirs | Where-Object { Test-GameDir $_ } | Sort-Object -Unique)
}

function Get-GameDirs {
    if ($null -ne $script:gameDirsCache) { return $script:gameDirsCache }
    $dirs = @()
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam').SteamPath
    if (-not $steam) { $steam = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam').InstallPath }
    $libs = @()
    if ($steam) {
        $libs += $steam
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $libs += ($m.Groups[1].Value -replace '\\\\', '\')
            }
        }
    }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $acf = Join-Path $lib 'steamapps\appmanifest_2507950.acf'
        if (Test-Path -LiteralPath $acf) {
            $dir = [regex]::Match((Get-Content -LiteralPath $acf -Raw), '"installdir"\s+"([^"]+)"').Groups[1].Value
            if ($dir) { $dirs += (Join-Path $lib "steamapps\common\$dir") }
        }
    }
    # Installation outside Steam (official launcher)
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        foreach ($u in Get-ItemProperty $k | Where-Object { $_.DisplayName -match 'Delta Force' -and $_.InstallLocation }) {
            $dirs += $u.InstallLocation.TrimEnd('\')
        }
    }
    $dirs = @($dirs | ForEach-Object { $_ -replace '/', '\' } | Where-Object { Test-GameDir $_ } | Sort-Object -Unique)
    # Nothing found via Steam/uninstall entries: try other registry traces, then the drives
    if ($dirs.Count -eq 0) { $dirs = @(Find-GameDirsInRegistry) }
    if ($dirs.Count -eq 0) { $dirs = @(Find-GameDirsOnDisks | Sort-Object -Unique) }
    $script:gameDirsCache = $dirs
    return $dirs
}

# ======================= Installation check =======================
$dfVideoKeys = @('TextureQuality', 'TextureFilteringQuality', 'StreamingQuality', 'SceneDetailLevel', 'ShadingQuality',
                 'ShadowMapResolution', 'GIQuality', 'ReflectionQuality', 'AmbientOcclusionQuality', 'ParticleQuality',
                 'DistortionQuality', 'PostProcessQuality', 'VolumetricFogQuality', 'AnimationQuality',
                 'SuperResolutionMethod', 'SuperResolutionQualityDLSS', 'NVIDIAReflexMode', 'MaxFPS')

function Test-DFInstall([switch]$Quiet) {
    $r = [ordered]@{ Ok = $true; Game = $null; Config = $null; Video = $null; Movies = $null; Exe = $null; MissingKeys = @() }
    $g = @(Get-GameDirs)
    if ($g.Count -gt 0) { $r.Game = $g[0] }
    $lines = @()
    if ($osSupported) { $lines += @('OK', "Windows ................. $osText") }
    else { $lines += @('AV', "Windows ................. $osText (Windows 10 1809+ or Windows 11 recommended)") }
    if ($r.Game) {
        $lines += @('OK', "Game .................... $($r.Game)")
        $exe = Join-Path $r.Game 'Game\DeltaForce\Binaries\Win64\DeltaForceClient-Win64-Shipping.exe'
        if (Test-Path -LiteralPath $exe) { $r.Exe = $exe; $lines += @('OK', 'Executable .............. DeltaForceClient-Win64-Shipping.exe') }
        else { $lines += @('AV', 'Executable .............. not found in Binaries\Win64 (the NVIDIA profile uses the known name)') }
        $cfg = Join-Path $r.Game 'Game\DeltaForce\Saved\Config\WindowsClient'
        if (Test-Path -LiteralPath $cfg) { $r.Config = $cfg; $lines += @('OK', "Config folder ........... $cfg") }
        else { $r.Ok = $false; $lines += @('KO', "Config folder ........... does not exist: $cfg") }
        $mv = Join-Path $r.Game 'Game\DeltaForce\Content\Movies_HD'
        if (Test-Path -LiteralPath $mv) { $r.Movies = $mv; $lines += @('OK', 'Intro videos ............ Movies_HD folder found') }
        else { $lines += @('AV', 'Intro videos ............ Movies_HD folder not found (option V unavailable)') }
    } else {
        $r.Ok = $false
        $lines += @('KO', 'Game .................... not found in Steam, the registry or any drive')
    }
    if ($r.Config) {
        $v = Join-Path $r.Config 'UserSystemSettingHD.ini'
        if (Test-Path -LiteralPath $v) {
            $txt = Get-Content -LiteralPath $v
            $sec = $false; $keys = @()
            foreach ($l in $txt) {
                if ($l.Trim() -eq '[/Script/GPGlobalDefines.ClientVideoSettingHD]') { $sec = $true; continue }
                if ($sec -and $l.Trim() -match '^\[') { break }
                if ($sec -and $l -match '^([^=]+)=') { $keys += $Matches[1] }
            }
            if (-not $sec) { $r.Ok = $false; $lines += @('KO', 'UserSystemSettingHD.ini . exists but has no graphics section') }
            else {
                $r.Video = $v
                $r.MissingKeys = @($dfVideoKeys | Where-Object { $keys -notcontains $_ })
                $n = $dfVideoKeys.Count - $r.MissingKeys.Count
                $lines += @('OK', "UserSystemSettingHD.ini . found, graphics section with $n of $($dfVideoKeys.Count) settings")
                if ($r.MissingKeys.Count -gt 0) { $lines += @('OK', '  (the rest are at their default value - the game does not write them; the script adds them)') }
            }
        } else { $r.Ok = $false; $lines += @('KO', 'UserSystemSettingHD.ini . missing (open the game and save the settings once)') }
        foreach ($tk in 'Engine.ini', 'Scalability.ini', 'GPSystemSetting.ini') {
            if (Test-Path -LiteralPath (Join-Path $r.Config $tk)) { $lines += @('OK', ("$tk (token) ").PadRight(25, '.') + ' present - the script never changes it') }
        }
    }
    if (-not $Quiet) {
        Write-Host ''
        Write-Host 'Installation check:'
        for ($i = 0; $i -lt $lines.Count; $i += 2) {
            switch ($lines[$i]) {
                'OK' { Write-Host "  [OK] $($lines[$i + 1])" -ForegroundColor Gray }
                'AV' { Write-Host "  [!]  $($lines[$i + 1])" -ForegroundColor Yellow }
                'KO' { Write-Host "  [X]  $($lines[$i + 1])" -ForegroundColor Red }
            }
        }
    }
    return $r
}

function Show-LocalConfigHelp {
    Write-Host ''
    Write-Host 'IMPORTANT - the game''s local config:' -ForegroundColor Yellow
    Write-Host '  Delta Force can apply a config saved in the cloud on top of the local file.'
    Write-Host '  Before using this option, in the game:'
    Write-Host '    1. Settings > press S (Config Management)'
    Write-Host '    2. Under LOCAL CONFIG, make sure "LocalConfig" exists and is APPLIED'
    Write-Host '       (if it is not, click APPLY on it)'
    Write-Host '    3. Optional: under CLOUD CONFIG click "+ Save Cloud Config" to keep a copy in the cloud'
    Write-Host '    4. Exit the game from its menu (not from Task Manager)'
    Write-Host '  After applying, open the game again and press S to confirm LocalConfig is still APPLIED.'
}

# ======================= NVIDIA Profile Inspector =======================
$hasIGPU = @($gpus | Where-Object { $_.Name -match 'Intel\(R\) (UHD|HD|Iris)|Radeon\(TM\) Graphics|Radeon Graphics' }).Count -gt 0
# Download sources, in order: the project's fork, then the original project by Orbmu2k
$npiUrls = @('https://github.com/j0p3s/nvidiaProfileInspector/releases/latest/download/nvidiaProfileInspector.zip',
             'https://github.com/Orbmu2k/nvidiaProfileInspector/releases/latest/download/nvidiaProfileInspector.zip')
$npiDir  = Join-Path $Here 'nvidiaProfileInspector'
$npiExe  = Join-Path $npiDir 'nvidiaProfileInspector.exe'
$npiBak  = Join-Path $npiDir 'Backups'

# Profile settings (NVAPI IDs, verified against the Profile Inspector source code)
$nvSettings = @(
    @{ Name = 'Power management mode';                               Id = 0x1057EB71; Value = 1;  Txt = 'Prefer maximum performance (GPU does not drop clocks mid-game)' }
    @{ Name = 'Texture filtering - Quality';                         Id = 0x00CE2691; Value = 20; Txt = 'High performance (minimal visual difference)' }
    @{ Name = 'Texture filtering - Anisotropic sample optimization'; Id = 0x00E73211; Value = 1;  Txt = 'On' }
    @{ Name = 'Texture filtering - Negative LOD bias';               Id = 0x0019BB68; Value = 0;  Txt = 'Allow (needed for sharp DLSS/FSR)' }
    @{ Name = 'Maximum pre-rendered frames';                         Id = 0x007BA09E; Value = 1;  Txt = '1 = low latency (in-game Reflex overrides it when enabled)' }
    @{ Name = 'Threaded optimization';                               Id = 0x20C1221E; Value = 1;  Txt = 'On (helps in DirectX 11 mode)' }
    @{ Name = 'Enable FXAA';                                         Id = 0x1074C972; Value = 0;  Txt = 'Off (the game uses its own AA/upscaler)' }
)

function Get-Npi {
    if (Test-Path -LiteralPath $npiExe) { return $true }
    Write-Host 'Downloading NVIDIA Profile Inspector...'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $zip = Join-Path $env:TEMP 'nvidiaProfileInspector.zip'
    Remove-Item -LiteralPath $zip -Force
    foreach ($u in $npiUrls) {
        Write-Host "  $u" -ForegroundColor DarkGray
        try { Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $zip -ErrorAction Stop } catch { & curl.exe -L -s -f -o $zip $u }
        # a valid zip starts with "PK"; anything else (404 page, empty file) is discarded
        $ok = $false
        if (Test-Path -LiteralPath $zip) { $h = [IO.File]::ReadAllBytes($zip)[0..1]; $ok = ($h[0] -eq 0x50 -and $h[1] -eq 0x4B) }
        if ($ok) { break }
        Remove-Item -LiteralPath $zip -Force
    }
    if (-not (Test-Path -LiteralPath $zip)) { return $false }
    New-Item -ItemType Directory -Path $npiDir -Force | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $npiDir -Force
    Remove-Item -LiteralPath $zip -Force
    # remove the "downloaded from the internet" mark so SmartScreen does not block the tool
    Get-ChildItem -LiteralPath $npiDir -File | Unblock-File
    return (Test-Path -LiteralPath $npiExe)
}

# Game executables (scans the install folder; falls back to the known names)
function Get-GameExes {
    # names NVIDIA's official profile (driver 621.01) assigns to the game
    $list = @('DeltaForceClient-Win64-Shipping.exe', 'DeltaForce-Win64-Shipping.exe', 'DeltaForce.exe', 'BHDClient-Win64-Shipping.exe')
    $paths = @()
    foreach ($g in Get-GameDirs) {
        foreach ($f in Get-ChildItem -LiteralPath $g -Recurse -Filter '*-Win64-Shipping.exe') { $list += $f.Name; $paths += $f.FullName }
    }
    return @{ Names = @($list | Sort-Object -Unique); Paths = @($paths | Sort-Object -Unique) }
}

# Exports all customized profiles (Profile Inspector writes them to its own folder)
function Export-Npi {
    $before = Get-Date
    Start-Process -FilePath $npiExe -ArgumentList '-exportCustomized' -WorkingDirectory $npiDir -Wait
    Get-ChildItem -LiteralPath $npiDir -Filter 'CustomProfiles_*.nip' | Where-Object { $_.LastWriteTime -ge $before.AddSeconds(-2) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Find-NvProfile($nipPath, $exeNames) {
    if (-not $nipPath -or -not (Test-Path -LiteralPath $nipPath)) { return $null }
    [xml]$x = Get-Content -LiteralPath $nipPath -Raw
    foreach ($p in @($x.ArrayOfProfile.Profile)) {
        foreach ($e in @($p.Executeables.string)) {
            if ($exeNames -contains $e) { return $p }
        }
    }
    return $null
}

function New-Nip($path, $profileName, $exeNames, $settings) {
    $esc = { param($s) [Security.SecurityElement]::Escape([string]$s) }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
    [void]$sb.AppendLine('<ArrayOfProfile>')
    [void]$sb.AppendLine('  <Profile>')
    [void]$sb.AppendLine('    <ProfileName>' + (& $esc $profileName) + '</ProfileName>')
    [void]$sb.AppendLine('    <Executeables>')
    foreach ($e in $exeNames) { [void]$sb.AppendLine('      <string>' + (& $esc $e.ToLower()) + '</string>') }
    [void]$sb.AppendLine('    </Executeables>')
    [void]$sb.AppendLine('    <Settings>')
    foreach ($s in $settings) {
        [void]$sb.AppendLine('      <ProfileSetting>')
        [void]$sb.AppendLine('        <SettingNameInfo>' + (& $esc $s.Name) + '</SettingNameInfo>')
        [void]$sb.AppendLine('        <SettingID>' + [uint32]$s.Id + '</SettingID>')
        [void]$sb.AppendLine('        <SettingValue>' + [uint32]$s.Value + '</SettingValue>')
        [void]$sb.AppendLine('        <ValueType>Dword</ValueType>')
        [void]$sb.AppendLine('      </ProfileSetting>')
    }
    [void]$sb.AppendLine('    </Settings>')
    [void]$sb.AppendLine('  </Profile>')
    [void]$sb.AppendLine('</ArrayOfProfile>')
    [IO.File]::WriteAllText($path, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
}

function Test-NvChecks {
    if (-not $isNvidia) { Write-Host "The detected GPU ($gpuName) is not NVIDIA. This option only works with NVIDIA cards." -ForegroundColor Red; return $false }
    if (Test-GameRunning) { Write-Host 'Close Delta Force first.' -ForegroundColor Red; return $false }
    if (-not (Get-Npi)) { Write-Host 'ERROR: could not download NVIDIA Profile Inspector.' -ForegroundColor Red; return $false }
    return $true
}

function Optimize-Nvidia {
    if (-not (Test-NvChecks)) { return }
    $exes = Get-GameExes

    # 1. Back up all customized profiles
    Write-Host 'Backing up the current NVIDIA profiles...'
    New-Item -ItemType Directory -Path $npiBak -Force | Out-Null
    $exp = Export-Npi
    $bk = $null
    if ($exp) {
        $bk = Join-Path $npiBak ('NVIDIA_profiles_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.nip')
        Move-Item -LiteralPath $exp.FullName -Destination $bk -Force
    }

    # 2. If the game already has a (driver or user) profile, use that name to avoid conflicts.
    #    Otherwise try the names NVIDIA's driver usually uses.
    $existing = Find-NvProfile $bk $exes.Names
    $names = if ($existing) { @($existing.ProfileName) } else { @('Delta Force', 'Delta Force: Hawk Ops', 'Delta Force Hawk Ops', 'DeltaForce') }

    # 3. Import only this script's settings (merge: the rest of the profile stays the same) and verify
    $nip = Join-Path $npiDir 'DeltaForce_Tweaker.nip'
    $p = $null
    foreach ($profName in $names) {
        New-Nip $nip $profName $exes.Names $nvSettings
        Write-Host "Applying profile '$profName'..."
        Start-Process -FilePath $npiExe -ArgumentList '-silentImport', '-mergeImport', ('"' + $nip + '"') -WorkingDirectory $npiDir -Wait
        $chk = Export-Npi
        $p = Find-NvProfile $chk.FullName $exes.Names
        if ($chk) { Remove-Item -LiteralPath $chk.FullName -Force }
        if ($p) { break }
    }
    Write-Host ''
    if (-not $p) {
        Write-Host 'Could not confirm the profile in the driver.' -ForegroundColor Red
        Write-Host 'Likely cause: the driver already has the Delta Force executable in a profile with another name.'
        Write-Host 'Open NVIDIA Profile Inspector (option 6), search for "delta force" and check the profile name.'
        Write-Host "File to import manually: $nip"
        return
    }
    $ok = 0
    Write-Host "NVIDIA profile '$($p.ProfileName)' applied:" -ForegroundColor Green
    foreach ($s in $nvSettings) {
        $cur = @($p.Settings.ProfileSetting) | Where-Object { [uint32]$_.SettingID -eq [uint32]$s.Id } | Select-Object -First 1
        if ($cur -and [uint32]$cur.SettingValue -eq [uint32]$s.Value) { $ok++; $m = '[OK]'; $c = 'Gray' } else { $m = '[!!]'; $c = 'Red' }
        Write-Host ("  $m " + $s.Name.PadRight(53) + $s.Txt) -ForegroundColor $c
    }
    Write-Host "  $ok of $($nvSettings.Count) settings confirmed."

    # 4. Laptops with an integrated GPU: force the game onto the NVIDIA GPU (Windows setting)
    if ($hasIGPU -and $exes.Paths.Count -gt 0) {
        foreach ($path in $exes.Paths) { Set-GpuPreferenceValue $path 'GpuPreference' '2' }
        Write-Host '  [OK] Windows: Delta Force set to use the high-performance GPU (NVIDIA)'
    }

    Write-Host ''
    if ($bk) { Write-Host "Backup of the previous profiles: $bk" }
    Write-Host 'VSync (controlled by the game) and G-SYNC (off) were left as NVIDIA set them in the official profile.' -ForegroundColor DarkGray
}

function Restore-Nvidia {
    if (-not (Test-NvChecks)) { return }
    $exes = Get-GameExes
    # oldest backup = state before the first optimization (also accepts backups from older versions)
    $first = Get-ChildItem -LiteralPath $npiBak -Filter 'NVIDIA_*.nip' | Sort-Object LastWriteTime | Select-Object -First 1
    $orig = Find-NvProfile $first.FullName $exes.Names
    $nip = Join-Path $npiDir 'DeltaForce_Restore.nip'
    if ($orig) {
        # The profile was already customized before: restore it exactly as it was
        $set = foreach ($s in @($orig.Settings.ProfileSetting)) { @{ Name = $s.SettingNameInfo; Id = [uint32]$s.SettingID; Value = [uint32]$s.SettingValue } }
        $nonDword = @($orig.Settings.ProfileSetting | Where-Object { $_.ValueType -ne 'Dword' }).Count
        if ($nonDword -gt 0) {
            # has non-Dword values: import the original profile exactly as it was exported
            [xml]$x = Get-Content -LiteralPath $first.FullName -Raw
            foreach ($p in @($x.ArrayOfProfile.Profile)) { if ($p.ProfileName -ne $orig.ProfileName) { [void]$p.ParentNode.RemoveChild($p) } }
            $x.Save($nip)
        } else {
            New-Nip $nip $orig.ProfileName @($orig.Executeables.string) @($set)
        }
        $name = $orig.ProfileName
    } else {
        # There was no customized profile: restore the driver defaults
        $name = 'Delta Force'
        New-Nip $nip $name $exes.Names @()
    }
    Start-Process -FilePath $npiExe -ArgumentList '-silentImport', '-replaceImport', ('"' + $nip + '"') -WorkingDirectory $npiDir -Wait
    foreach ($path in $exes.Paths) { Set-GpuPreferenceValue $path 'GpuPreference' $null }
    Write-Host "NVIDIA profile '$name' restored." -ForegroundColor Green
}

function Open-Npi {
    if (-not $isNvidia) { Write-Host 'This option only works with NVIDIA cards.' -ForegroundColor Red; return }
    if (Get-Npi) { Start-Process -FilePath $npiExe -WorkingDirectory $npiDir }
}

# ======================= Windows 10/11 gaming settings =======================
# Values in HKCU\Software\Microsoft\DirectX\UserGpuPreferences are strings like
# "GpuPreference=2;SwapEffectUpgradeEnable=1;". This helper changes one field and keeps the rest.
$gpuPrefKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'

function Set-GpuPreferenceValue($valueName, $field, $fieldValue) {
    New-Item -Path $gpuPrefKey -Force | Out-Null
    $cur = [string](Get-ItemProperty -LiteralPath $gpuPrefKey).$valueName
    $parts = [ordered]@{}
    foreach ($kv in ($cur -split ';')) { if ($kv -match '^([^=]+)=(.*)$') { $parts[$Matches[1]] = $Matches[2] } }
    if ($null -eq $fieldValue) { $parts.Remove($field) } else { $parts[$field] = $fieldValue }
    if ($parts.Count -eq 0) { Remove-ItemProperty -LiteralPath $gpuPrefKey -Name $valueName; return }
    $new = (($parts.Keys | ForEach-Object { "$_=$($parts[$_])" }) -join ';') + ';'
    Set-ItemProperty -LiteralPath $gpuPrefKey -Name $valueName -Value $new
}

function Get-GpuPreferenceValue($valueName, $field) {
    $cur = [string](Get-ItemProperty -LiteralPath $gpuPrefKey).$valueName
    foreach ($kv in ($cur -split ';')) { if ($kv -match "^$([regex]::Escape($field))=(.*)$") { return $Matches[1] } }
    return $null
}

function Get-WinGamingState {
    $s = [ordered]@{}
    # Game Mode (on by default; only "0" turns it off)
    $gm = (Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar').AutoGameModeEnabled
    $s.GameMode = ($null -eq $gm -or $gm -eq 1)
    # Hardware-accelerated GPU scheduling (Windows 10 2004+ / Windows 11, supported GPU and driver)
    $hw = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers').HwSchMode
    $s.HagsAvailable = ($osBuild -ge 19041)
    $s.Hags = ($hw -eq 2)
    # Background recording (Xbox Game Bar captures)
    $cap = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR').AppCaptureEnabled
    $dvr = (Get-ItemProperty 'HKCU:\System\GameConfigStore').GameDVR_Enabled
    $s.Recording = -not ($cap -eq 0 -and $dvr -eq 0)
    # Optimizations for windowed games (Windows 11 22H2+)
    $s.WindowedAvailable = ($osBuild -ge 22621)
    $s.Windowed = ((Get-GpuPreferenceValue 'DirectXUserGlobalSettings' 'SwapEffectUpgradeEnable') -eq '1')
    # Active power plan
    $plan = (powercfg /getactivescheme) -join ' '
    $s.PowerPlan = $(if ($plan -match '\(([^)]+)\)') { $Matches[1] } else { 'unknown' })
    $s.PowerGuid = $(if ($plan -match '([0-9a-fA-F-]{36})') { $Matches[1] } else { '' })
    $s.HighPerfGuid = $(if (((powercfg /list) -join ' ') -match '(8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c)') { $Matches[1] } else { '' })
    return $s
}

function Show-WindowsGaming {
    while ($true) {
        $s = Get-WinGamingState
        $on  = { param($b) if ($b) { 'On' } else { 'Off' } }
        Clear-Host
        Write-Host '=================================================================='
        Write-Host "  WINDOWS GAMING SETTINGS - $osText"
        Write-Host '=================================================================='
        Write-Host ('  [1] Game Mode ............................. ' + (& $on $s.GameMode) + '   (recommended: On)')
        if ($s.HagsAvailable) { Write-Host ('  [2] Hardware-accelerated GPU scheduling ... ' + (& $on $s.Hags) + '   (recommended: On, needs a restart)') }
        else { Write-Host '  [2] Hardware-accelerated GPU scheduling ... not available (needs Windows 10 2004 or newer)' -ForegroundColor DarkGray }
        Write-Host ('  [3] Background recording (Game Bar) ....... ' + (& $on $s.Recording) + '   (recommended: Off, frees GPU/disk)')
        if ($s.WindowedAvailable) { Write-Host ('  [4] Optimizations for windowed games ...... ' + (& $on $s.Windowed) + '   (recommended: On for Borderless)') }
        else { Write-Host '  [4] Optimizations for windowed games ...... Windows 11 22H2 or newer only' -ForegroundColor DarkGray }
        Write-Host ("  [5] Power plan ............................ $($s.PowerPlan)")
        Write-Host '  [0] Back'
        Write-Host ''
        Write-Host '  Each option switches between On and Off.' -ForegroundColor DarkGray
        $o = Read-Host 'Option'
        switch ($o) {
            '1' {
                New-Item -Path 'HKCU:\Software\Microsoft\GameBar' -Force | Out-Null
                Set-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -Value $(if ($s.GameMode) { 0 } else { 1 }) -Type DWord
            }
            '2' {
                if (-not $s.HagsAvailable) { continue }
                Set-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -Value $(if ($s.Hags) { 1 } else { 2 }) -Type DWord
                Write-Host 'Restart Windows for this change to take effect. If your GPU or driver does not support it, Windows ignores it.' -ForegroundColor Yellow
                Read-Host 'Enter to continue' | Out-Null
            }
            '3' {
                $v = $(if ($s.Recording) { 0 } else { 1 })
                New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Force | Out-Null
                Set-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value $v -Type DWord
                New-Item -Path 'HKCU:\System\GameConfigStore' -Force | Out-Null
                Set-ItemProperty -LiteralPath 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value $v -Type DWord
            }
            '4' {
                if (-not $s.WindowedAvailable) { continue }
                Set-GpuPreferenceValue 'DirectXUserGlobalSettings' 'SwapEffectUpgradeEnable' $(if ($s.Windowed) { '0' } else { '1' })
            }
            '5' {
                Write-Host ''
                Write-Host "  Active plan: $($s.PowerPlan)"
                if ($s.HighPerfGuid -and $s.PowerGuid -ne $s.HighPerfGuid) {
                    if ((Read-Host 'Switch to High performance? (Y/N)') -match '^[yY]') {
                        Set-Content -LiteralPath (Join-Path $Here '.previous_power_plan') -Value $s.PowerGuid -Encoding ASCII
                        powercfg /setactive $s.HighPerfGuid | Out-Null
                    }
                } elseif ($s.PowerGuid -eq $s.HighPerfGuid -and (Test-Path -LiteralPath (Join-Path $Here '.previous_power_plan'))) {
                    if ((Read-Host 'Switch back to the previous plan? (Y/N)') -match '^[yY]') {
                        powercfg /setactive ((Get-Content -LiteralPath (Join-Path $Here '.previous_power_plan')).Trim()) | Out-Null
                        Remove-Item -LiteralPath (Join-Path $Here '.previous_power_plan') -Force
                    }
                } else {
                    Write-Host '  The High performance plan is not available on this PC (common on laptops with Modern Standby).' -ForegroundColor DarkGray
                    Write-Host '  Use Settings > System > Power > Power mode > Best performance instead.' -ForegroundColor DarkGray
                    Read-Host 'Enter to continue' | Out-Null
                }
            }
            '0' { return }
        }
    }
}

# ======================= Start without UAC prompt =======================
$taskName = 'Delta Force Tweaker'
$noTaskFlag = Join-Path $Here '.no_task'

function Test-NoUac {
    $t = Get-ScheduledTask -TaskName $taskName
    return [bool]($t -and $Self -and $t.Actions[0].Arguments.ToLower().Contains($Self.ToLower()))
}

function Install-NoUac {
    if (-not $Self) { return }
    Remove-Item -LiteralPath $noTaskFlag -Force
    $a  = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/c ""' + $Self + '""') -WorkingDirectory $Here
    $pr = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Highest
    $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $taskName -Action $a -Principal $pr -Settings $st -Description "Starts Delta Force Tweaker v$Version as administrator without a UAC prompt" -Force | Out-Null
    $script:noUac = Test-NoUac
    if ($script:noUac) { Write-Host 'Start without UAC prompt enabled: next time a double-click on the .cmd is enough.' -ForegroundColor Green }
    else { Write-Host 'Could not create the scheduled task.' -ForegroundColor Red }
}

function Remove-NoUac {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    New-Item -ItemType File -Path $noTaskFlag -Force | Out-Null
    $script:noUac = Test-NoUac
    Write-Host 'Start without UAC prompt removed. The .cmd will ask for UAC confirmation again.' -ForegroundColor Green
}

# Create (or fix, if the .cmd was moved or renamed) the task automatically
$script:noUac = Test-NoUac
if (-not $script:noUac -and -not (Test-Path -LiteralPath $noTaskFlag)) {
    Install-NoUac
    Start-Sleep -Seconds 2
}

# ======================= Intro videos =======================
# Renames (does not delete) the 3 logo videos to .bak; the same option restores them.
# A game update or "Verify integrity of game files" in Steam brings them back.
$introFiles = @('V_logo_HD.bin', 'V_logo2_HD.bin', 'V_logo2_looping_HD.bin')

function Get-MoviesDir {
    foreach ($g in Get-GameDirs) {
        $m = Join-Path $g 'Game\DeltaForce\Content\Movies_HD'
        if (Test-Path -LiteralPath $m) { return $m }
    }
    return $null
}

function Get-IntroState {
    $m = Get-MoviesDir
    if (-not $m) { return 'nogame' }
    $active = @($introFiles | Where-Object { Test-Path -LiteralPath (Join-Path $m $_) }).Count
    if ($active -eq 0) { return 'off' }
    return 'on'
}

function Switch-IntroVideos {
    if (Test-GameRunning) { Write-Host 'Close Delta Force first.' -ForegroundColor Red; return }
    $m = Get-MoviesDir
    if (-not $m) { Write-Host 'Could not find the Delta Force Content\Movies_HD folder.' -ForegroundColor Red; return }
    if ((Get-IntroState) -eq 'on') {
        foreach ($f in $introFiles) {
            $src = Join-Path $m $f
            if (Test-Path -LiteralPath $src) {
                Move-Item -LiteralPath $src -Destination ($src + '.bak') -Force
                if (Test-Path -LiteralPath ($src + '.bak')) { Write-Host "  [OK] $f -> $f.bak" } else { Write-Host "  [!!] $f was not renamed" -ForegroundColor Red }
            }
        }
        Write-Host 'Intro videos disabled.' -ForegroundColor Green
        Write-Host 'If the videos come back after a game update, run this option again.' -ForegroundColor DarkGray
    } else {
        foreach ($f in $introFiles) {
            $bak = Join-Path $m ($f + '.bak')
            if (Test-Path -LiteralPath $bak) { Move-Item -LiteralPath $bak -Destination (Join-Path $m $f) -Force; Write-Host "  [OK] $f restored" }
        }
        if ((Get-IntroState) -eq 'on') { Write-Host 'Intro videos restored.' -ForegroundColor Green }
        else { Write-Host 'There were no .bak copies to restore. Use "Verify integrity of game files" in Steam.' -ForegroundColor Yellow }
    }
}

# ======================= Local config backup =======================
# Only copies files the game itself writes (edits nothing).
$dfBak = Join-Path $Here 'DeltaForce_Backups'

function Get-LocalConfigDirs {
    $c = @(Join-Path $env:LOCALAPPDATA 'DeltaForce\Saved\Config')
    foreach ($g in Get-GameDirs) { $c += (Join-Path $g 'Game\DeltaForce\Saved\Config') }
    return @($c | Where-Object { Test-Path -LiteralPath $_ } | Sort-Object -Unique)
}

function Backup-LocalConfig {
    if (Test-GameRunning) { Write-Host 'Close Delta Force first (the game writes its config when it exits).' -ForegroundColor Red; return }
    $dirs = Get-LocalConfigDirs
    if ($dirs.Count -eq 0) { Write-Host 'Could not find the Delta Force Saved\Config folder.' -ForegroundColor Red; return }
    $dst = Join-Path $dfBak (Get-Date -Format 'yyyyMMdd_HHmmss')
    $i = 0
    foreach ($d in $dirs) {
        $i++
        $to = Join-Path $dst "Config$i"
        New-Item -ItemType Directory -Path $to -Force | Out-Null
        Copy-Item -Path (Join-Path $d '*') -Destination $to -Recurse -Force
        Set-Content -LiteralPath (Join-Path $to '_source.txt') -Value $d -Encoding UTF8
        $n = @(Get-ChildItem -LiteralPath $to -Recurse -File).Count - 1
        Write-Host "  [OK] $d  ($n files)"
    }
    Write-Host "Backup saved to: $dst" -ForegroundColor Green
}

function Restore-LocalConfig {
    if (Test-GameRunning) { Write-Host 'Close Delta Force first.' -ForegroundColor Red; return }
    $list = @(Get-ChildItem -LiteralPath $dfBak -Directory | Sort-Object Name -Descending)
    if ($list.Count -eq 0) { Write-Host 'No backups yet (use option 4).' -ForegroundColor Red; return }
    Write-Host ''
    for ($i = 0; $i -lt [math]::Min($list.Count, 9); $i++) { Write-Host "  [$($i + 1)] $($list[$i].Name)" }
    $c = Read-Host 'Choose a backup (Enter to cancel)'
    if ($c -notmatch '^[1-9]$' -or [int]$c -gt $list.Count) { return }
    $sel = $list[[int]$c - 1]
    # back up the current state before restoring, so you can go back
    Write-Host 'Backing up the current config before restoring...'
    Backup-LocalConfig | Out-Null
    foreach ($sub in Get-ChildItem -LiteralPath $sel.FullName -Directory) {
        $srcFile = Join-Path $sub.FullName '_source.txt'
        if (-not (Test-Path -LiteralPath $srcFile)) { $srcFile = Join-Path $sub.FullName '_origem.txt' }   # backups made by older versions
        $orig = (Get-Content -LiteralPath $srcFile -Raw).Trim()
        if (-not $orig) { continue }
        New-Item -ItemType Directory -Path $orig -Force | Out-Null
        Get-ChildItem -LiteralPath $sub.FullName | Where-Object { $_.Name -notin '_source.txt', '_origem.txt' } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $orig -Recurse -Force }
        Write-Host "  [OK] Restored: $orig"
    }
    Write-Host "Local config restored from $($sel.Name)." -ForegroundColor Green
    Write-Host 'In the game, open Config Management and make sure LocalConfig is applied.' -ForegroundColor DarkGray
}

function Open-LocalConfig {
    $dirs = Get-LocalConfigDirs
    if ($dirs.Count -eq 0) { Write-Host 'Could not find the Delta Force Saved\Config folder.' -ForegroundColor Red; Start-Sleep 2; return }
    foreach ($d in $dirs) { Start-Process explorer.exe $d }
}

# ======================= Initial check =======================
Clear-Host
Write-Host '=================================================================='
Write-Host "  DELTA FORCE TWEAKER v$Version - checking the installation"
Write-Host '=================================================================='
$null = Test-DFInstall
Write-Host ''
Read-Host 'Enter to continue' | Out-Null

# ======================= Menu =======================
while ($true) {
    Clear-Host
    $gd = @(Get-GameDirs)
    Write-Host '=================================================================='
    Write-Host "  DELTA FORCE TWEAKER v$Version"
    Write-Host '=================================================================='
    Write-Host "  Windows ... $osText"
    Write-Host "  CPU ....... $cpuName ($cores cores / $threads threads)"
    Write-Host "  RAM ....... $ramGB GB"
    Write-Host "  GPU ....... $gpuName ($vramGB GB VRAM)"
    Write-Host "  Monitor ... ${resX}x${resY} @ ${hz} Hz"
    Write-Host "  Tier ...... $($Q[$tier]) ($reason)" -ForegroundColor Cyan
    if ($gd.Count -gt 0) { Write-Host "  Game ...... $($gd[0])" } else { Write-Host '  Game ...... installation not detected' -ForegroundColor DarkYellow }
    Write-Host '------------------------------------------------------------------'
    Write-Host "  [1] Recommended settings - Balanced (quality/performance)"
    Write-Host "  [2] Recommended settings - Competitive (maximum FPS)"
    Write-Host "  [W] Write the settings to the game file (with warning and backup)"
    Write-Host "  [3] Clear the game's shader cache"
    $iv = Get-IntroState
    if ($iv -eq 'on') { Write-Host "  [V] Skip the intro videos" }
    elseif ($iv -eq 'off') { Write-Host "  [V] Restore the intro videos (currently disabled)" }
    Write-Host '  ---- Game local config (copies only, edits nothing) ----'
    Write-Host "  [4] Back up the local config"
    Write-Host "  [8] Restore a local config backup"
    Write-Host "  [9] Open the local config folder"
    if ($isNvidia) {
        Write-Host '  ---- NVIDIA ----'
        Write-Host "  [5] Optimize the game's NVIDIA profile (Profile Inspector)"
        Write-Host "  [6] Open NVIDIA Profile Inspector"
        Write-Host "  [7] Restore the original NVIDIA profile"
    }
    Write-Host '  ---- Windows ----'
    Write-Host "  [G] Windows 10/11 gaming settings (Game Mode, GPU scheduling...)"
    Write-Host '  ----------------'
    Write-Host "  [C] Check the installation and files again"
    if ($script:noUac) { Write-Host "  [R] Remove start without UAC prompt" }
    else { Write-Host "  [A] Enable start without UAC prompt" }
    Write-Host "  [0] Exit"
    Write-Host ''
    $op = Read-Host 'Option'
    switch ($op) {
        '1' { Show-Recommendations 'Balanced'; Read-Host "`nEnter to continue" | Out-Null }
        '2' { Show-Recommendations 'Competitive'; Read-Host "`nEnter to continue" | Out-Null }
        'W' { Write-DFSettings; Read-Host "`nEnter to continue" | Out-Null }
        'C' { $script:gameDirsCache = $null; $null = Test-DFInstall; Show-LocalConfigHelp; Read-Host "`nEnter to continue" | Out-Null }
        '3' { Clear-ShaderCache; Read-Host "`nEnter to continue" | Out-Null }
        'V' { Switch-IntroVideos; Read-Host "`nEnter to continue" | Out-Null }
        '4' { Backup-LocalConfig; Read-Host "`nEnter to continue" | Out-Null }
        '8' { Restore-LocalConfig; Read-Host "`nEnter to continue" | Out-Null }
        '9' { Open-LocalConfig }
        '5' { Optimize-Nvidia; Read-Host "`nEnter to continue" | Out-Null }
        '6' { Open-Npi }
        '7' { Restore-Nvidia; Read-Host "`nEnter to continue" | Out-Null }
        'G' { Show-WindowsGaming }
        'A' { Install-NoUac; Read-Host "`nEnter to continue" | Out-Null }
        'R' { Remove-NoUac; Read-Host "`nEnter to continue" | Out-Null }
        '0' { exit 0 }
    }
}
