<#
.SYNOPSIS
    The script uninstalls Padoa Devices Manager from the user's system.
    
.DESCRIPTION
    This script :
        - locates the Padoa Devices Manager installation
        - stops the Padoa Devices Manager active process if running
        - runs the uninstaller
        - logs are stored at the path C:\it\logs
    
.NOTES
    Execution context:      User
    Intended deployment:    Microsoft Intune or manual execution
    Release notes:          Initial version for PDM uninstallation
    Release date:           2026-05-26
    Release version:        1.0
    Author:                 evan-staub
#>

# Variables
$uninstallerPath    = "$env:LOCALAPPDATA\Programs\Padoa Devices Manager\unins000.exe"
$appPath            = "$env:LOCALAPPDATA\Programs\Padoa Devices Manager\PadoaDevicesManagerCore.exe"

# Logs
if (-not (Test-Path "C:\IT\logs")) {
    New-Item -ItemType Directory -Path "C:\IT\logs" -Force
}
$logPath = "C:\IT\logs\PDM.log"
Start-Transcript -Path $logPath -Append -Force

# Check if app is present
if (-not(Test-Path $appPath)){
    Write-Host "[INFO] App not found"
    return
}

# Stop app process if running
$appProcess = get-process -Name "PadoaDevicesManagerCore" -EA 0
if ($appProcess) {
    $appProcess | Stop-Process
}

# Run uninstaller
if (Test-Path $uninstallerPath) {
    Write-Host "[INFO] Running uninstaller..."
    $process = Start-Process -FilePath $uninstallerPath `
        -ArgumentList "/VERYSILENT /FORCECLOSEAPPLICATIONS" `
        -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -eq 0) {
    Write-Host '[SUCCESS] Application "Padoa Devices Manager" successfully uninstalled'
    }
    else {
        Write-Host "[ERROR] An error occured uninstalling the application `"Padoa Devices Manager`", error code: $($process.ExitCode)"
    }
}
else {
    Write-Host "[ERROR] Uninstaller file not found"
    exit 1
}

Stop-Transcript