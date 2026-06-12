<#
.SYNOPSIS
    The script installs Padoa Devices Manager from a public URI in user context.
    
.DESCRIPTION
    This script :
        - downloads the last release of PDM from pdm.padoa.fr
        - installs Padoa Devices Manager in %localappdata%/programs
        - enables launch at user sign-in
        - creates an user desktop shortcut
        - logs are stored at the path C:\it\logs

    The script does not:
        - Whitelist the "padoa.devices" protocol for padoa.fr, aodap-staging.fr, or aodap-dev.fr
        - Associate PadoaDevicesManagerCore.exe with "padoa.devices://" links for the current Windows user
        - Install the .NET Windows Desktop Runtime
    
.NOTES
    Execution context:      User
    Intended deployment:    Microsoft Intune
    Release notes:          Initial version for PDM installation from URI
    Release date:           2026-04-28
    Release version:        1.0
    Author:                 evan-staub
#>

# Logs
if (-not (Test-Path "C:\IT\logs")) {
    New-Item -ItemType Directory -Path "C:\IT\logs" -Force
}
$logPath = "C:\IT\logs\PDM.log"
Start-Transcript -Path $logPath -Append -Force

# Variables
$appPath                = "$env:LOCALAPPDATA\Programs\Padoa Devices Manager\PadoaDevicesManagerCore.exe"
$installerParams        = "desktopicon,!whitelist_chrome,!whitelist_edge,!install_dotnet_8,run_on_startup"

# Create temp folder and set installer path
if (-not (Test-Path "C:\IT\Temp")) {
    New-Item -ItemType Directory -Path "C:\IT\Temp" -Force
}
$installerURI           = "https://pdm.padoa.fr/PadoaDevicesManagerInstaller.exe"
$installerPath          = "C:\IT\Temp\PadoaDevicesManagerInstaller.exe"


# Check if app is already installed
if (Test-Path -Path $appPath) {
    Write-Host "[INFO] The application Padoa Devices Manager is already installed."
    return
}

# Download installer if not already downloaded
if (-not (Test-Path $installerPath)){
    Write-Host "[INFO] Downloading installer..."
    Invoke-WebRequest -Uri $installerURI -OutFile $installerPath
}
else {
    Write-Host "[INFO] Installer already downloaded"
}

# Install and configure app
Write-Host "[INFO] Running installer..."
$process = Start-Process -FilePath $installerPath `
    -ArgumentList "/VERYSILENT", "/MERGETASKS=`"$installerParams`"" `
    -Wait -PassThru -NoNewWindow

# Output
if ($process.ExitCode -eq 0) {
    Write-Host '[SUCCESS] Application "Padoa Devices Manager" successfully installed'
}
else {
    Write-Host "[ERROR] An error occured installing the application `"Padoa Devices Manager`", error code: $($process.ExitCode)"
}
Stop-Transcript