<#
.SYNOPSIS
    Snippets of code to manage PowerShell modules. Intended for use in scripts or as a reference for manual module management.
    
.DESCRIPTION
    The first snippet: :
    - Checks if specified modules are imported, and if not, checks if they are installed.
    - For each module, if it is not installed, it installs it. Then it imports the module and displays its dependencies.

    The second snippet:
    - Checks if specified module are imported, and if so, prompts the user to close all sessions before uninstalling.
    - If modules are installed but not imported, it uninstalls modules and their dependencies.

.NOTES
    Execution context:      User
    Intended deployment:    Manual execution
    Author:                 evan-staub
    Release date:           2026-06-10
    Release version:        1.0
    Release notes:          Initial version with module management snippets.
#>

### First snippet for importing modules ###

# List of modules to import in your script
$modsToInstall = @(
    "ExampleModule1",
    "ExampleModule2"
)

# Loop through each module in the list and manage it
foreach ($mod in $modsToInstall) {
    # Check if the module is imported
    $checkModImport = Get-Module -Name $mod -EA 0
    if (!$checkModImport) {
        # Check if the module is installed
        $checkModInstall = Get-InstalledModule -Name $mod -EA 0
        # If the module is not installed, install it.
        if (!$checkModInstall) {
            Write-Host "[INFO] Module $mod is not installed. Installing now..."
            Install-Module -Name $mod -Scope CurrentUser -Force | Out-Null
            Write-Host "[INFO] Module $mod installed succesfully."
        } else {
            Write-Host "[INFO] Module $mod is already installed. Importing now..."
        }
        # Display dependencies and import the module
        $modDependencies = Get-Module -Name $mod -ListAvailable | Select-Object -ExpandProperty RequiredModules | Select-Object -ExpandProperty Name
        if ($modDependencies) {
            Write-Host "[INFO] Module $mod has the following dependencies installed: $($modDependencies -join ', ')."
        }
        Write-Host "[INFO] Importing module $mod..."
        Import-Module -Name $mod -Force | Out-Null
        Write-Host "[INFO] Module $mod imported successfully."
    }
}


### Second snippet for uninstalling modules ###

# List of modules to uninstall in your script
$modsToUninstall = @(
    "ExampleModule1",
    "ExampleModule2"
)

# Loop through each module in the list and uninstall it
foreach ($mod in $modsToUninstall) {
    # Check if the module is imported or installed
    $checkModInstall = Get-InstalledModule -Name $mod -EA 0
    $checkModImport = Get-Module -Name $mod -EA 0
    # If the module is imported, prompt the user to close all sessions before uninstalling. If the module is installed but not imported, uninstall it and its dependencies.
    if ($checkModImport) {
        Write-Host "[INFO] Module $mod is currently imported. Close all sessions and try again to uninstall."
    } elseif ($checkModInstall) {
        Write-Host "[INFO] Module $mod is installed. Uninstalling now..."
        $modDependencies = Get-Module -Name $mod -ListAvailable | Select-Object -ExpandProperty RequiredModules | Select-Object -ExpandProperty Name
        Uninstall-Module -Name $mod -AllVersions -Force
        foreach ($dependency in $modDependencies) {
            if (Get-InstalledModule -Name $dependency -EA 0) {
                Write-Host "[INFO] Uninstalling dependency module $dependency..."
                Uninstall-Module -Name $dependency -AllVersions -Force
            }
        }
    } else {
        Write-Host "[INFO] Module $mod is not installed. No action needed."
    }
}