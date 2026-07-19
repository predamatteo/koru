<#
.SYNOPSIS
    Koru vs. stock-launcher real-battery A/B harness (OnePlus 8T 6d05b840, OxygenOS 15).
    Measures the hardware coulomb counter (cmd battery get counter, microamp-hours) drop
    across one self-driving, on-device workload, phone UNPLUGGED, and appends a CSV row.

    Companion runbook: docs/battery-ab-test-protocol.md  (READ IT FIRST.)
    PowerShell 5.1 compatible: no ternary (?:), no null-coalescing (??).

.DESCRIPTION
    HEADLINE metric is STANDBY (screen OFF, 90-120 min, normal Doze). ACTIVE (screen ON) is
    DIAGNOSTIC ONLY (sub-quantization + panel-pixel confound between the two launchers).

    The fuel gauge is quantized to 1000 uAh steps -> +/-1 mAh per endpoint, +/-2 mAh per delta.
    So size each window to drain FAR more than 2 mAh (standby 90-120 min; active 10-15 min).

    Sign convention (verified): counter RISES while charging, so unplugged it FALLS, and
    energy used = start - end (uAh). A non-positive delta means the cable carried power -> VOID.

    Per run, the script:
      1. GUARDS that the device is unplugged (battery status != 2/3 charging, != 5 full).
      2. (active only) resets batterystats for a clean per-UID attribution window.
      3. Latches the START counter + on-device timestamp to /data/local/tmp/latch_<Label>.txt
         (timestamp taken with `date +%s` INSIDE the device shell -- never Get-Date -UFormat).
      4. For standby: issues KEYCODE_SLEEP, then CONFIRMS mWakefulness is Asleep/Dozing
         BEFORE latching, so the CSV never records Awake for a standby window.
      5. Runs the self-driving on-device workload (sh) synchronously for DurationSec.
      6. Reads the END counter, computes the delta, POST-GUARDS delta > 0 (else VOID),
         and (active only) reads the UID-1000 system_server estimated-power line for the
         A-B difference. Appends ONE row to battery_runs.csv (single fixed 17-column schema).

    USAGE -- you must UNPLUG right after the run starts and RE-PLUG only after it ends.
    Because adb keeps the data link over USB even unplugged on this device, the simplest
    flow is: unplug, run this (it blocks for DurationSec via the on-device sleep/loop),
    re-plug when it prints "end". If your cable carries power you are charging -> the
    post-guard will VOID the run.

    PRE-RUN (operator): set the correct launcher (A=Koru / B=stock) and, for B, after a 60 s
    settle confirm `dumpsys activity services com.dev.koru` prints NO ServiceRecord. See the
    runbook Section 4 for the full neutralization (a11y + NotificationListener + appops).

.EXAMPLE
    # One Koru (A) standby window, 90 min:
    .\battery_ab_session.ps1 -Label A_koru -Mode standby -DurationSec 5400
.EXAMPLE
    # One stock (B) active diagnostic run, 12 min:
    .\battery_ab_session.ps1 -Label B_stock -Mode active -DurationSec 720
#>
#requires -version 5
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet('A_koru','B_stock')] [string]$Label,
    [ValidateSet('standby','active')]                        [string]$Mode = 'standby',
    [int]$DurationSec = 5400,                                  # 5400=90min standby; ~720=12min active
    [string]$Serial = '6d05b840',
    [string]$Csv = "$PSScriptRoot\battery_runs.csv",
    [switch]$PushScripts                                       # (re)write the on-device workload scripts
)

$ErrorActionPreference = 'Stop'

function Adb { param([string[]]$a) & adb -s $Serial @a }

# ---- VERIFIED device reads ----------------------------------------------------------------
function Get-CounterUAh {
    # framework BatteryManager charge counter, micro-amp-hours. Trim the STRING, THEN cast.
    [int64](((Adb @('shell','cmd','battery','get','counter')) | Out-String).Trim())
}
function Get-LevelPct {
    [int](((Adb @('shell','cmd','battery','get','level')) | Out-String).Trim())
}
function Get-BatteryStatus {
    # dumpsys battery -> "status: N"  (1 unknown, 2 charging, 3 discharging, 4 not charging, 5 full)
    $b = (Adb @('shell','dumpsys','battery')) | Out-String
    if ($b -match 'status:\s*(\d+)') { [int]$Matches[1] } else { -1 }
}
function Test-Plugged {
    # Robust: charging(2) or full(5) means a power source is attached. status 3/4 = unplugged.
    $s = Get-BatteryStatus
    ($s -eq 2) -or ($s -eq 5)
}
function Get-TempC {
    $b = (Adb @('shell','dumpsys','battery')) | Out-String
    if ($b -match 'temperature:\s*(-?\d+)') { [double]$Matches[1] / 10.0 } else { [double]::NaN }
}
function Get-Wakefulness {
    $p = (Adb @('shell','dumpsys','power')) | Out-String
    if ($p -match 'mWakefulness=(\w+)') { $Matches[1] } else { 'unknown' }
}

# ---- on-device workload scripts (write on demand) -----------------------------------------
function Push-WorkScripts {
    $active = @'
#!/system/bin/sh
DUR=${1:-600}
END=$(( $(date +%s) + DUR ))
rm -f /data/local/tmp/work_done.flag /data/local/tmp/work_abort.flag
i=0
while [ "$(date +%s)" -lt "$END" ]; do
  input keyevent KEYCODE_WAKEUP
  input keyevent KEYCODE_HOME
  TOP=$(dumpsys activity activities | grep -m1 'topResumedActivity')
  case "$TOP" in *FallbackHome*) echo "ABORT_FALLBACKHOME" > /data/local/tmp/work_abort.flag ; exit 7 ;; esac
  sleep 2
  input swipe 540 1900 540 300 200
  sleep 2
  input swipe 540 1500 540 400 250
  sleep 1
  input swipe 540 400 540 1500 250
  sleep 1
  input keyevent KEYCODE_HOME
  sleep 2
  i=$(( i + 1 ))
done
echo "DONE $i" > /data/local/tmp/work_done.flag
'@
    $standby = @'
#!/system/bin/sh
input keyevent KEYCODE_SLEEP
DUR=${1:-5400}
rm -f /data/local/tmp/work_done.flag
sleep $DUR
echo "DONE" > /data/local/tmp/work_done.flag
'@
    # Write with LF endings (device sh chokes on CRLF) via a temp file push.
    $ta = New-TemporaryFile; $ts = New-TemporaryFile
    [IO.File]::WriteAllText($ta.FullName, ($active  -replace "`r`n","`n"))
    [IO.File]::WriteAllText($ts.FullName, ($standby -replace "`r`n","`n"))
    Adb @('push', $ta.FullName, '/data/local/tmp/work_active.sh')  | Out-Null
    Adb @('push', $ts.FullName, '/data/local/tmp/work_standby.sh') | Out-Null
    Adb @('shell','chmod','755','/data/local/tmp/work_active.sh','/data/local/tmp/work_standby.sh') | Out-Null
    Remove-Item $ta.FullName, $ts.FullName -Force
    Write-Host "Pushed work_active.sh + work_standby.sh to /data/local/tmp."
}

# ==========================================================================================
if ($PushScripts) { Push-WorkScripts }

# Ensure the scripts exist on-device (push if missing).
$haveActive = (((Adb @('shell','ls','/data/local/tmp/work_active.sh')) | Out-String) -match 'work_active.sh')
if (-not $haveActive) { Push-WorkScripts }

$script = if ($Mode -eq 'active') { '/data/local/tmp/work_active.sh' } else { '/data/local/tmp/work_standby.sh' }

# ---- GUARD: must be UNPLUGGED -------------------------------------------------------------
if (Test-Plugged) {
    Write-Error "Device battery status indicates PLUGGED/charging (status 2 or 5). UNPLUG before measuring. Aborting run '$Label'."
    return
}

# active diagnostic: reset batterystats so the per-UID window is just this run
if ($Mode -eq 'active') { Adb @('shell','dumpsys','batterystats','--reset') | Out-Null }

# clear stale on-device flags
Adb @('shell','rm','-f','/data/local/tmp/work_done.flag','/data/local/tmp/work_abort.flag') | Out-Null

# ---- STANDBY: sleep the screen and CONFIRM it slept BEFORE latching ------------------------
if ($Mode -eq 'standby') {
    Adb @('shell','input','keyevent','KEYCODE_SLEEP') | Out-Null
    $ok = $false
    for ($k = 0; $k -lt 10; $k++) {
        $w = Get-Wakefulness
        if ($w -eq 'Asleep' -or $w -eq 'Dozing') { $ok = $true; break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ok) {
        Write-Error "Standby run '$Label': screen did not reach Asleep/Dozing (mWakefulness=$([string](Get-Wakefulness))). Aborting."
        return
    }
}

# ---- latch START --------------------------------------------------------------------------
$startUAh = Get-CounterUAh
$startLvl = Get-LevelPct
$startTmp = Get-TempC
$scr0     = Get-Wakefulness
$startUtc = (Get-Date).ToUniversalTime().ToString('o')
if ([double]::IsNaN($startTmp)) { Write-Error "Could not read start temperature for '$Label'. Aborting (thermal guard would be defeated)." ; return }

# on-device latch: timestamp via `date +%s` INSIDE the device shell (no PowerShell locale issues)
Adb @('shell',"echo START $startUAh `$(date +%s) > /data/local/tmp/latch_$Label.txt") | Out-Null

Write-Host ("[{0}/{1}] start  uAh={2}  level={3}%  temp={4} C  screen={5}  dur={6}s" -f `
            $Label,$Mode,$startUAh,$startLvl,$startTmp,$scr0,$DurationSec)
Write-Host "  -> If still plugged, UNPLUG NOW. Re-plug only after this run reports 'end'." -ForegroundColor Yellow

# ---- run the self-driving workload ON THE DEVICE, synchronously ---------------------------
Adb @('shell',"sh $script $DurationSec") | Out-Null

# ---- check the device-side abort flag (active FallbackHome guard) -------------------------
$abort = ((Adb @('shell','cat','/data/local/tmp/work_abort.flag','2>/dev/null')) | Out-String).Trim()
if ($abort -match 'ABORT_FALLBACKHOME') {
    Write-Error "Run '$Label' landed on FallbackHome mid-workload (stock launcher not materialized). VOID this run."
    return
}

# ---- latch END ----------------------------------------------------------------------------
$endUAh = Get-CounterUAh
$endLvl = Get-LevelPct
$endTmp = Get-TempC
$scr1   = Get-Wakefulness
$endUtc = (Get-Date).ToUniversalTime().ToString('o')
if ([double]::IsNaN($endTmp)) { Write-Error "Could not read end temperature for '$Label'. Aborting append (thermal guard defeated)." ; return }

$durActual = [int]((Get-Date $endUtc) - (Get-Date $startUtc)).TotalSeconds
$deltaUAh  = $startUAh - $endUAh           # discharge => start > end => positive
$deltaMAh  = [math]::Round($deltaUAh / 1000.0, 3)

# ---- POST-GUARD: a non-positive delta means the cable was carrying power -------------------
if ($deltaUAh -le 0) {
    Write-Error ("Run '{0}' VOID: counter did not fall (start={1} end={2} delta={3} uAh). The device was charging during the window. NOT appended." -f `
                 $Label,$startUAh,$endUAh,$deltaUAh)
    return
}

# ---- M3 sanity (active only): UID-1000 (system_server) estimated-power line ----------------
# NOTE: use the DEFAULT dumpsys batterystats "Estimated power use (mAh)" block, NOT --usage
# (--usage on this device is the no-auto-reset WRITER flag, not a per-UID selector). Report the
# raw UID-1000 line so analysis can take the A-B DIFFERENCE. Do NOT sum Koru-UID + UID-1000.
$sysLine = ''; $koruLine = ''
if ($Mode -eq 'active') {
    $stats = (Adb @('shell','dumpsys','batterystats')) | Out-String
    foreach ($ln in ($stats -split "`n")) {
        if ($ln -match 'UID\s+1000\b')   { $sysLine  = ($ln -replace '\s+',' ').Trim() }
        if ($ln -match 'UID\s+u0a942\b')  { $koruLine = ($ln -replace '\s+',' ').Trim() }
    }
}

# ---- append ONE row (single fixed 17-column schema, single writer) ------------------------
if (-not (Test-Path $Csv)) {
    'label,mode,start_utc,end_utc,duration_s,start_uAh,end_uAh,delta_uAh,delta_mAh,start_level,end_level,start_temp_c,end_temp_c,screen_start,screen_end,sys_uid1000_line,koru_uid_line' |
        Out-File -FilePath $Csv -Encoding ascii
}
('"{0}","{1}","{2}","{3}",{4},{5},{6},{7},{8},{9},{10},{11},{12},"{13}","{14}","{15}","{16}"' -f `
    $Label,$Mode,$startUtc,$endUtc,$durActual,$startUAh,$endUAh,$deltaUAh,$deltaMAh,`
    $startLvl,$endLvl,$startTmp,$endTmp,$scr0,$scr1,$sysLine,$koruLine) |
    Add-Content -Path $Csv

Write-Host ("[{0}/{1}] end    uAh={2}  delta={3} mAh over {4}s  temp {5}->{6} C  level {7}->{8}%" -f `
            $Label,$Mode,$endUAh,$deltaMAh,$durActual,$startTmp,$endTmp,$startLvl,$endLvl) -ForegroundColor Green

# Thermal-drift hint (NaN already excluded above). Tight 2 C threshold per the protocol.
if ([math]::Abs($startTmp - $endTmp) -gt 2.0) {
    Write-Warning ("Intra-run temp drift {0:N1} C (> 2 C). Flag this run / its pair for review." -f [math]::Abs($startTmp - $endTmp))
}
if ($Mode -eq 'standby') {
    Write-Host ("  per-hour drain = {0:N2} mAh/h" -f ($deltaMAh * 3600.0 / [math]::Max($durActual,1))) -ForegroundColor Cyan
}
Write-Host "  Row appended to $Csv. Re-plug now if you need to recharge into the SOC band." -ForegroundColor Yellow
