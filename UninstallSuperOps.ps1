<#  
    SuperOps RMM – Full Manual Removal Script
    Author: Ben (MSP)
    Purpose: Completely remove SuperOps RMM from Windows endpoints.
#>

Write-Host "=== SuperOps RMM Full Removal Script Starting ==="

# --- 1. Stop and Remove Services ---
$services = @(
    "SuperOps Updater",
    "SuperOps"
)

foreach ($svc in $services) {
    Get-Service -Name $svc -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "Stopping service: $($_.Name)"
        Stop-Service $_.Name -Force -ErrorAction SilentlyContinue
        Write-Host "Deleting service: $($_.Name)"
        sc.exe delete "$($_.Name)" | Out-Null
    }
}

# --- 2. Kill any running processes ---
$procs = "SuperOps"
foreach ($p in $procs) {
    Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# --- 3. Remove Installation Directory ---
$paths = @(
    "C:\Program Files\superopsrmm",
    "C:\ProgramData\SuperOps"
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Write-Host "Removing folder: $path"
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- 4. Remove Registry Keys ---
$regPaths = @(
    "HKLM:\SOFTWARE\SuperOps",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SuperOps"
)

foreach ($reg in $regPaths) {
    if (Test-Path $reg) {
        Write-Host "Removing registry key: $reg"
        Remove-Item -Path $reg -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Remove asset ID persistence (documented by SuperOps)
$assetKey = "HKLM:\SOFTWARE\SuperOps\Asset"
if (Test-Path $assetKey) {
    Write-Host "Removing SuperOps asset ID key"
    Remove-Item -Path $assetKey -Recurse -Force -ErrorAction SilentlyContinue
}

# --- 5. Remove MSI Registration (if present) ---
$superOpsProducts = Get-WmiObject Win32_Product | Where-Object {
    $_.Name -like "*SuperOps*" -or $_.Vendor -like "*SuperOps*"
}

foreach ($prod in $superOpsProducts) {
    Write-Host "Unregistering MSI product: $($prod.Name)"
    msiexec.exe /x $prod.IdentifyingNumber /qn
}

# --- 6. Remove Scheduled Tasks ---
$tasks = schtasks /Query /FO LIST | Select-String "SuperOps"
foreach ($t in $tasks) {
    $taskName = ($t.ToString() -split ":")[1].Trim()
    Write-Host "Deleting scheduled task: $taskName"
    schtasks /Delete /TN "$taskName" /F | Out-Null
}

Write-Host "=== SuperOps RMM Removal Complete ==="