function Convert-MSIProductCodeToInstallerKey {
    param([string]$guid)

    $guid = $guid.Trim('{}')
    $parts = $guid.Split('-')

    $p1 = ($parts[0][6..7] + $parts[0][4..5] + $parts[0][2..3] + $parts[0][0..1]) -join ''
    $p2 = ($parts[1][2..3] + $parts[1][0..1]) -join ''
    $p3 = ($parts[2][2..3] + $parts[2][0..1]) -join ''
    $p4 = ($parts[3][0..1] + $parts[3][2..3]) -join ''
    $p5 = ($parts[4][0..1] + $parts[4][2..3] + $parts[4][4..5] + $parts[4][6..7] + $parts[4][8..9] + $parts[4][10..11]) -join ''

    return "$p1$p2$p3$p4$p5"
}

#Convert-MSIProductCodeToInstallerKey "{3BB93941-0FBF-4E6E-CFC2-01C0FA4F9301}"
$SuperOpsProductCode = Convert-MSIProductCodeToInstallerKey ((Get-WmiObject -Class Win32_Product -Filter "Name LIKE '%SuperOps%'").IdentifyingNumber)
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
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SuperOps",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{3BB93941-0FBF-4E6E-CFC2-01C0FA4F9301}",
    "HKLM:\SYSTEM\ControlSet002\Services\superops",
    "HKLM:\SYSTEM\ControlSet002\Services\superops Updater",
    "HKEY_CLASSES_ROOT\Installer\Products\14939BB3FBF0E6E4FC2C100CAFF43910",
    "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\$SuperOpsProductCode"
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
