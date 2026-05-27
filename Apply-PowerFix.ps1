#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Applies PlatformAoAcOverride registry fix and logs machine details to a CSV.

.DESCRIPTION
    Collects logged-in user, serial number, model, and system type, appends a row
    to a cumulative CSV log stored alongside this script (USB drive), then applies:
    HKLM\SYSTEM\CurrentControlSet\Control\Power > PlatformAoAcOverride = DWORD 0

.NOTES
    Run as Administrator. Intended for USB-based deployment across ~150 machines.
#>

# ── Configuration ─────────────────────────────────────────────────────────────

# PSScriptRoot can be empty when launched via Start-Process; fall back to the
# directory of the invocation path, then the working directory.
$ScriptDir = if ($PSScriptRoot) {
    $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path $MyInvocation.MyCommand.Path -Parent
} else {
    (Get-Location).Path
}

$LogFile    = Join-Path $ScriptDir "PowerFix_Log.csv"
$RegPath    = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
$RegName    = "PlatformAoAcOverride"
$RegValue   = 0

# ── Collect Machine Info ───────────────────────────────────────────────────────

$Timestamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$Hostname   = $env:COMPUTERNAME

# Logged-in user (console session, not the SYSTEM account running the script)
$LoggedInUser = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
if ([string]::IsNullOrWhiteSpace($LoggedInUser)) {
    # Fallback: query active console session via quser
    try {
        $QuserOutput = (quser 2>&1) | Where-Object { $_ -match "console|Active" } | Select-Object -First 1
        if ($QuserOutput) {
            $LoggedInUser = ($QuserOutput -split '\s+')[1]
        } else {
            $LoggedInUser = "No user logged in"
        }
    } catch {
        $LoggedInUser = "Unknown"
    }
}

$CS         = Get-CimInstance -ClassName Win32_ComputerSystem
$BIOS       = Get-CimInstance -ClassName Win32_BIOS

$SerialNumber   = $BIOS.SerialNumber.Trim()
$Manufacturer   = $CS.Manufacturer.Trim()
$Model          = $CS.Model.Trim()

# PCSystemType: 1=Desktop, 2=Mobile/Laptop, 3=Workstation, 4=Enterprise Server,
#               8=Tablet, 9=Convertible, 10=Detachable
$SystemTypeCode = $CS.PCSystemType
$SystemTypeMap  = @{
    0  = "Unspecified"
    1  = "Desktop"
    2  = "Laptop/Mobile"
    3  = "Workstation"
    4  = "Enterprise Server"
    5  = "SOHO Server"
    6  = "Appliance PC"
    7  = "Performance Server"
    8  = "Tablet"
    9  = "Convertible"
    10 = "Detachable"
}
$SystemType = if ($SystemTypeMap.ContainsKey($SystemTypeCode)) {
    $SystemTypeMap[$SystemTypeCode]
} else {
    "Unknown ($SystemTypeCode)"
}

# ── Apply Registry Change ──────────────────────────────────────────────────────

$RegStatus  = ""
$RegBefore  = ""

try {
    # Capture existing value if present
    $Existing = Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction SilentlyContinue
    $RegBefore = if ($null -ne $Existing) { $Existing.$RegName.ToString() } else { "Not set" }

    # Ensure the key exists (it should, but be safe)
    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }

    New-ItemProperty -Path $RegPath -Name $RegName -Value $RegValue `
        -PropertyType DWORD -Force | Out-Null

    # Verify
    $Verify = (Get-ItemProperty -Path $RegPath -Name $RegName).$RegName
    if ($Verify -eq $RegValue) {
        $RegStatus = "Success"
    } else {
        $RegStatus = "Verification failed (got $Verify)"
    }
} catch {
    $RegStatus = "Error: $($_.Exception.Message)"
}

# ── Build Log Row ──────────────────────────────────────────────────────────────

$Row = [PSCustomObject]@{
    Timestamp       = $Timestamp
    Hostname        = $Hostname
    LoggedInUser    = $LoggedInUser
    Manufacturer    = $Manufacturer
    Model           = $Model
    SystemType      = $SystemType
    SerialNumber    = $SerialNumber
    RegPath         = "$RegPath\$RegName"
    RegValueBefore  = $RegBefore
    RegValueApplied = $RegValue
    Status          = $RegStatus
    RunningAs       = $env:USERNAME
}

# ── Append to CSV ──────────────────────────────────────────────────────────────

try {
    $Row | Export-Csv -Path $LogFile -Append -NoTypeInformation -Encoding UTF8 -Force
    $CsvStatus = "Logged to: $LogFile"
} catch {
    # USB write failed — fall back to the logged-in user's desktop, not SYSTEM's
    $DesktopOwner = if ($LoggedInUser -and $LoggedInUser -notmatch "No user|Unknown") {
        ($LoggedInUser -split '\\')[-1]   # strip domain prefix if present
    } else {
        $env:USERNAME
    }
    $FallbackLog = "C:\Users\$DesktopOwner\Desktop\PowerFix_Log_$Hostname.csv"
    try {
        $Row | Export-Csv -Path $FallbackLog -Append -NoTypeInformation -Encoding UTF8 -Force
        $CsvStatus = "WARNING: Could not write to USB. Logged locally to: $FallbackLog"
    } catch {
        $CsvStatus = "ERROR: Failed to write log anywhere. $_"
    }
}

# ── Console Summary ────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "------------------------------------------" -ForegroundColor Cyan
Write-Host "  PlatformAoAcOverride Fix - BNIT Solutions" -ForegroundColor Cyan
Write-Host "------------------------------------------" -ForegroundColor Cyan
Write-Host "  Host       : $Hostname"
Write-Host "  User       : $LoggedInUser"
Write-Host "  Model      : $Manufacturer $Model"
Write-Host "  Type       : $SystemType"
Write-Host "  Serial     : $SerialNumber"
Write-Host ""
Write-Host "  Reg Before : $RegBefore"
Write-Host "  Reg After  : $RegValue"
Write-Host "  Status     : $RegStatus" -ForegroundColor $(if ($RegStatus -eq "Success") { "Green" } else { "Red" })
Write-Host ""
Write-Host "  $CsvStatus" -ForegroundColor $(if ($CsvStatus -like "WARNING*") { "Yellow" } else { "Gray" })
Write-Host "------------------------------------------" -ForegroundColor Cyan
Write-Host ""
read-host "Press enter to exit"