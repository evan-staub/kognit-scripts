<#
.SYNOPSIS
    The script retrieves PIM role assignment notification recipients for Entra directory roles.
    
.DESCRIPTION
    This script :
        - Installs and imports the necessary Microsoft Graph PowerShell modules for identity sign-ins and governance
        - Connects to Microsoft Graph with RoleManagement.Read.All scope
        - Retrieves all directory role definitions, role management policies and policy assignments
        - Matches role definitions to policies via the policy assignment
        - Retrieves notification rules for each role management policy
        - Outputs a table of role name, role definition ID and notification recipients for each notification rule

    The script does not:
        - Distinguish between direct and inherited notification recipients
        - Specifically handle custom roles or policies with unique configurations
        - Handle search for specific roles or policies - it retrieves all and outputs them in a table
    
.NOTES
    Execution context: User
    Intended deployment: Manual execution
    Release notes: Initial version for retrieving role notification recipients
    Release date: 2026-06-12
    Release version: 1.0
    Author: evan-staub
#>

# Install and import necessary Microsoft Graph modules for identity sign-ins and governance
$mods = @(
    "Microsoft.Graph.Identity.Signins",
    "Microsoft.Graph.Identity.Governance"
)

foreach ($mod in $mods) {
    # Check if the module is imported
    $checkModImport = Get-Module -Name $mod -EA 0
    if (!$checkModImport) {
        # Check if the module is installed
        $checkModInstall = Get-InstalledModule -Name $mod -EA 0
        if (!$checkModInstall) {
            Write-Host "Module $mod is not installed. Installing now..."
            Install-Module -Name $mod -Scope CurrentUser -Force | Out-Null
            Write-Host "Module $mod installed succesfully."
        } else {
            Write-Host "Module $mod is already installed. Importing now..."
        }
        $modDependencies = Get-Module -Name $mod -ListAvailable | Select-Object -ExpandProperty RequiredModules | Select-Object -ExpandProperty Name
        if ($modDependencies) {
            Write-Host "Module $mod has the following dependencies installed: $($modDependencies -join ', ')."
        }
        Write-Host "Importing module $mod..."
        Import-Module -Name $mod -Force | Out-Null
        Write-Host "Module $mod imported successfully."
    }
}

# Connect to Microsoft Graph with large reader scope for role management policies
Write-Host "Connecting to Microsoft Graph with RoleManagement.Read.All scope..."
Connect-MgGraph -Scopes "RoleManagement.Read.All" -NoWelcome
Write-Host "Connected to Microsoft Graph successfully."

# Get all role definitions
$roleDefs = Get-MgRoleManagementDirectoryRoleDefinition -All

# Get all notification rules for role management policies
$rolePolicies = Get-MgPolicyRoleManagementPolicy -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole'" -ExpandProperty "Rules,EffectiveRules"

# Get all role management policy assignments - linking policies to roles is done via the policy assignment
$rolePolicyAssignments = Get-MgPolicyRoleManagementPolicyAssignment -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole'"

# Get table of role name, role definition ID and role policy ID by matching the role definition ID in the policy assignment to the role definition list
$roleTable  = foreach ($roleDefinition in $roleDefs){
    $roleAssignment = $rolePolicyAssignments | Where-Object { $_.Id -like "*_$($roleDefinition.Id)" }
    $rolePolicyId = $roleAssignment.PolicyId

    # Get notifications rules for the role policy
    $notifRulesAdmin = $rolePolicies | Where-Object { $_.Id -eq $rolePolicyId } | Select-Object -ExpandProperty Rules

    [PSCustomObject]@{
        RoleName = $roleDefinition.DisplayName
        RoleId = $roleDefinition.Id
        RecipientsAdminAssignment = $notifRulesAdmin | Where-Object { $_.Id -eq "Notification_Admin_Admin_Assignment" } | Select-Object -ExpandProperty AdditionalProperties | ForEach-Object { $_.notificationRecipients }
        RecipientsAdminEligibility = $notifRulesAdmin | Where-Object { $_.Id -eq "Notification_Admin_Admin_Eligibility" } | Select-Object -ExpandProperty AdditionalProperties | ForEach-Object { $_.notificationRecipients }
        RecipientsEndUserAssignment = $notifRulesAdmin | Where-Object { $_.Id -eq "Notification_Admin_EndUser_Assignment" } | Select-Object -ExpandProperty AdditionalProperties | ForEach-Object { $_.notificationRecipients }
    }
}

Write-Host "Role notification recipients retrieved successfully. Displaying results..."
$roleTable | Sort-Object RoleName | Format-Table -AutoSize