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
