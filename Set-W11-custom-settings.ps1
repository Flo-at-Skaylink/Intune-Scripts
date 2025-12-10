<#
.SYNOPSIS
    Applies custom Windows 11 device settings by updating specific registry keys.

.DESCRIPTION
    This script:
      - Sets File Explorer to open "This PC"
      - Aligns the taskbar to the left
      - Enables Compact Mode in File Explorer
      - Enables the classic right-click context menu (Windows 11)
      - Configures Kerberos MaxTokenSize
      - Disables UPnP Device Host and SSDP Discovery services

    All registry settings are defined in an array and processed in a foreach loop.
    Missing paths are created, values are overwritten if different, and changes are logged.

.EXAMPLE
    .\Set-W11-Custom-Settings.ps1

.NOTES
    Author: Florian Aschbichler
    Date: 10.12.2025
    Version: 1.1
    Requires: Administrative privileges
#>

# Init & Logging
$logFolder = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$logFile = Join-Path $logFolder "Set-W11-custom-settings.log"

# Function to write logs
Function Write-Log {
    param ([string]$Message)
    $TimeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Add-Content -Path $logFile -Value "$TimeStamp - $Message"
}

Write-Output "=== Applying Windows 11 Custom Settings ==="
Write-Log "=== Applying Windows 11 Custom Settings ==="

# Define registry settings in an array
$registrySettings = @(
    # Explorer opens "This PC"
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "LaunchTo"; DesiredValue = 1; Type = "DWord" },
    # Kerberos token size
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"; Name = "MaxTokenSize"; DesiredValue = 48000; Type = "DWord" },
    # Taskbar alignment (0 = left)
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarAl"; DesiredValue = 0; Type = "DWord" },
    # Explorer Compact mode
    @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "UseCompactMode"; DesiredValue = 1; Type = "DWord" },
    # Classic context menu
    @{ Path = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"; Name = "(default)"; DesiredValue = ""; Type = "String" },
    # Disable Windows UPnP services
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\upnphost"; Name = "Start"; DesiredValue = 4; Type = "DWord" },
    # Disable SSDP Discovery service
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\SSDPSRV"; Name = "Start"; DesiredValue = 4; Type = "DWord" }
)

# Process each registry setting
foreach ($setting in $registrySettings) {
    try {
        # Create path if missing
        if (-not (Test-Path $setting.Path)) {
            New-Item -Path $setting.Path -Force -ErrorAction SilentlyContinue
            Write-Log "Created missing registry path: $($setting.Path)"
            Write-Output "Created missing registry path: $($setting.Path)"
        }

        # Get current value
        $currentValue = (Get-ItemProperty -Path $setting.Path -ErrorAction SilentlyContinue).$($setting.Name)
        Write-Log "Current value of $($setting.Path)\$($setting.Name) is '$currentValue'"
        Write-Output "Current value of $($setting.Path)\$($setting.Name) is '$currentValue'"

        # Compare and update
        if ($currentValue -ne $setting.DesiredValue) {
            New-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.DesiredValue -PropertyType $setting.Type -Force | Out-Null
            Write-Log "Updated $($setting.Path)\$($setting.Name) to $($setting.DesiredValue)"
            Write-Output "Updated: $($setting.Path)\$($setting.Name) to $($setting.DesiredValue)"
        }
        else {
            Write-Log "No change needed for $($setting.Path)\$($setting.Name); already set to $($setting.DesiredValue)"
            Write-Output "No change: $($setting.Path)\$($setting.Name) is already $($setting.DesiredValue)"
        }
    }
    catch {
        Write-Warning "Failed to process $($setting.Path)\$($setting.Name): $($_.Exception.Message)"
        Write-Log "Error processing $($setting.Path)\$($setting.Name): $($_.Exception.Message)"
    }
}

Write-Output "=== Windows 11 Custom Settings Applied Successfully ==="
Write-Log "=== Windows 11 Custom Settings Applied Successfully ==="
