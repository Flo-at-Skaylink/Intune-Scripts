<#
.SYNOPSIS
    Disables Virtualization Based Security (VBS) on Windows devices.

.DESCRIPTION
    This script disables Virtualization Based Security (VBS) by turning off related Windows features,
    updating registry settings, and configuring the boot manager to ensure VBS is disabled on the next reboot.
    It also disables Core Isolation settings.

.EXAMPLE
    .\Set-VBS-disabled.ps1

.NOTES
    Author: Florian Aschbichler
    Date: 03.12.2025
    Version: 1.0
    Requires: Administrative privileges
#>

# Init & Logging
$logFolder = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$logFile = Join-Path $logFolder "Set-VBS-disabled.log"

# Function to write logs
Function Write-Log {
    param ([string]$Message)
    $TimeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Add-Content -Path $logFile -Value "$TimeStamp - $Message"
}

Write-Output "=== Applying Windows VBS Custom Settings ==="
Write-Log "=== Applying Windows VBS Custom Settings ==="

function Find-FreeDriveLetter() {
    $reserved = "ABCZ".ToCharArray()
    $drvlist = (Get-PSDrive -PSProvider filesystem).Name
    foreach ($drvletter in [char[]](65..90)) {
        if ($drvletter -notin $reserved -and $drvlist -notcontains $drvletter) {
            return "${drvletter}:"
            Write-Log "Found free drive letter: ${drvletter}:"
            Write-Output "Found free drive letter: ${drvletter}:"
        }
    }
    throw "no free, unreserved drive letters"
}
 
function DisableFeature($FeatureName) {
    $Feature = Get-WindowsOptionalFeature -FeatureName $FeatureName -Online
    if ($Feature.State -eq 'Disabled') {
        Write-Output "$FeatureName is already disabled"
        Write-Log "$FeatureName is already disabled"
        return $true;
    }
    if ($Feature) {
        Disable-WindowsOptionalFeature -FeatureName $FeatureName -Online -NoRestart
        Write-Log "Disabled feature $FeatureName"
        Write-Output "Disabled feature $FeatureName"
    }
    return $true;
}
 
function DisableVBS() {
    try {
        $DeviceGuard = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard 
        Write-Output "VirtualizationBasedSecurityStatus $($DeviceGuard.VirtualizationBasedSecurityStatus)"
        Write-Log "VirtualizationBasedSecurityStatus $($DeviceGuard.VirtualizationBasedSecurityStatus)"
        if ($DeviceGuard.VirtualizationBasedSecurityStatus -eq 0) {
            Write-Output "VirtualizationBasedSecurityStatus already disabled";
            Write-Log "VirtualizationBasedSecurityStatus already disabled"
        }
 
        # Feature which require a disable
        foreach ($Feature in @('Containers-DisposableClientVM', 'Microsoft-Hyper-V', 'VirtualMachinePlatform', 'Windows-Defender-ApplicationGuard')) {
            if (!(DisableFeature $Feature)) {
                Write-Output "Abort the process"
                Write-Log "Abort the process"
            }
        }
        return $true;
    }
    catch {
        Write-Output "Failed to read DeviceGuard status"
        Write-Log "Failed to read DeviceGuard status"
        return $false;
    }

 
    # Disable VBS via registry
    try {
        New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" `
            -Name "EnableVirtualizationBasedSecurity" `
            -PropertyType DWORD `
            -Value 0 `
            -Force | Out-Null
        Write-Log "Disabled VirtualizationBasedSecurity via registry"
        Write-Output "Disabled VirtualizationBasedSecurity via registry"
        return $true;
    }
    catch {
        Write-Output "Failed to disable VirtualizationBasedSecurity via registry"
        Write-Log "Failed to disable VirtualizationBasedSecurity via registry"
        return $false;
    }

 
    # Disable VBS when UEFI lock might be set

    try {
        $FreeDrive = Find-FreeDriveLetter
        & mountvol $FreeDrive /s

        Copy-Item 'C:\Windows\System32\SecConfig.efi' "$FreeDrive\EFI\Microsoft\Boot\SecConfig.efi" -Force
        & bcdedit /create { 0cb3b571-2f2e-4343-a879-d86a476d7215 } /d "DisableVBS" /application osloader
        & bcdedit /set { 0cb3b571-2f2e-4343-a879-d86a476d7215 } path '\EFI\Microsoft\Boot\SecConfig.efi'
        & bcdedit /set { bootmgr } bootsequence { 0cb3b571-2f2e-4343-a879-d86a476d7215 }
        & bcdedit /set { 0cb3b571-2f2e-4343-a879-d86a476d7215 } loadoptions DISABLE-LSA-ISO, DISABLE-VBS
        & bcdedit /set vsmlaunchtype off
        & bcdedit /set { 0cb3b571-2f2e-4343-a879-d86a476d7215 } device partition=$FreeDrive
    }
    finally {
        & mountvol $FreeDrive /d
        Write-Log "Unmounted EFI system partition from $FreeDrive"
        Write-Output "Unmounted EFI system partition from $FreeDrive"
    }
 
    # Disable Core Isolation
    try {
        New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" `
            -Name "Enabled" `
            -PropertyType DWORD `
            -Value 0 `
            -Force | Out-Null       
            
        Write-Log "Disabled Core Isolation"
        Write-Output "Disabled Core Isolation"
        return $true;
    }
    catch {
        Write-Output "Failed to disable Core Isolation"
        Write-Log "Failed to disable Core Isolation"
        return $false;
    }
}

$result = DisableVBS

if ($result -eq $true) {
    Write-Output "VBS disable process completed successfully. A reboot is required."
    Write-Log "VBS disable process completed successfully. A reboot is required."
    exit 0
}
else {
    Write-Output "VBS disable process encountered errors."
    Write-Log "VBS disable process encountered errors."
    exit 1
}