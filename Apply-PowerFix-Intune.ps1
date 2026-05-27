#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Applies PlatformAoAcOverride registry fix on Lenovo 12RRS3F700 devices.

.NOTES
    Intended for Intune deployment. No logging or data collection.
    Exits with code 0 on success or skip, 1 on failure.
#>

$TargetModel = "12RRS3F700"
$RegPath     = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
$RegName     = "PlatformAoAcOverride"
$RegValue    = 0

# ── Model Check ───────────────────────────────────────────────────────────────

$Model = (Get-CimInstance -ClassName Win32_ComputerSystem).Model.Trim()

if ($Model -notlike "*$TargetModel*") {
    Write-Output "Model is '$Model' - not targeted. Exiting."
    exit 0
}

Write-Output "Model matched: $Model - applying fix."

# ── Apply Registry Fix ────────────────────────────────────────────────────────

try {
    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }

    New-ItemProperty -Path $RegPath -Name $RegName -Value $RegValue `
        -PropertyType DWORD -Force | Out-Null

    $Verify = (Get-ItemProperty -Path $RegPath -Name $RegName).$RegName
    if ($Verify -eq $RegValue) {
        Write-Output "Success: $RegName set to $RegValue."
        exit 0
    } else {
        Write-Output "Verification failed: expected $RegValue, got $Verify."
        exit 1
    }
} catch {
    Write-Output "Error applying registry fix: $($_.Exception.Message)"
    exit 1
}
