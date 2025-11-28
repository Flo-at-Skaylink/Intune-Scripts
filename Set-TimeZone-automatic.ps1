
<#
.SYNOPSIS
    Sets Windows time zone to automatic by updating registry settings.

.DESCRIPTION
    Updates registry keys to enable automatic time zone updates and allow location access.

.NOTES
    Author: Florian Aschbichler
    Date: 03.09.2025
    Version: 1.1
    Intune-ready, requires system context.
#>

# Registry settings
$registrySettings = @(
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"; Name = "Value"; DesiredValue = "Allow" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"; Name = "Start"; DesiredValue = 3 }
)

$success = $true

foreach ($setting in $registrySettings) {
    try {
        # Create path if missing
        if (-not (Test-Path $setting.Path)) {
            New-Item -Path $setting.Path -Force | Out-Null
        }

        # Get current value
        $currentValue = (Get-ItemProperty -Path $setting.Path -ErrorAction SilentlyContinue).$($setting.Name)

        # Update if needed
        if ($currentValue -ne $setting.DesiredValue) {
            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.DesiredValue
        }
    }
    catch {
        $success = $false
        Write-Output "Failed to update $($setting.Path): $_"
    }
}

# Exit code for Intune
if ($success) {
    exit 0
}
else {
    exit 1
}