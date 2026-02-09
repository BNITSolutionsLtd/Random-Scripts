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
    "HKEY_CLASSES_ROOT\Installer\Products\14939BB3FBF0E6E4FC2C100CAFF43910"
)

$installerRoot = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products"
# Search all product keys for one with DisplayName = "SuperOps RMM"
$superOpsKey = Get-ChildItem $installerRoot -ErrorAction SilentlyContinue | ForEach-Object {
    $installProps = Join-Path $_.PsPath "InstallProperties"
    if (Test-Path $installProps) {
        $props = Get-ItemProperty $installProps -ErrorAction SilentlyContinue
        if ($props.DisplayName -eq "SuperOps RMM") {
            return $_.PsPath
        }
    }
}

if ($superOpsKey) {
    Write-Host "Found SuperOps RMM installer key: $superOpsKey"
    Write-Host "Removing key..."
    Remove-Item -Path $superOpsKey -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "SuperOps RMM installer key not found in MSI database."
}

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
