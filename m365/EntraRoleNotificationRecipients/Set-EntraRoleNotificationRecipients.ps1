<#
.SYNOPSIS
    The script updates PIM role assignment notification recipients for Entra directory roles.
    
.DESCRIPTION
    This script :
        - Installs and imports the necessary Microsoft Graph PowerShell modules for identity sign-ins and governance
        - Connects to Microsoft Graph with RoleManagement.Read.All and RoleManagement.ReadWrite.Directory scopes
        - Retrieves all directory role definitions, role management policies and policy assignments
        - Matches role definitions to policies via the policy assignment
        - Retrieves notification rules for each role management policy
        - Updates notification recipients for target notification rules for each role to a specified list of recipients

    The script does not:
        - Distinguish between direct and inherited notification recipients
        - Specifically handle custom roles or policies with unique configurations
        - Handle search for specific roles or policies - it retrieves all and updates target notification rules for all roles
        - Exception about roles : User, Guest User and Restricted Guest User roles are excluded from updates as they are default roles.
    
.NOTES
    Execution context: User
    Intended deployment: Manual execution
    Release notes: Initial version for updating role notification recipients
    Release date: 2026-06-12
    Release version: 1.0
    Author: evan-staub
#>

# Define the target notification rules to update
$targetRoleNotifRules = @(
    "Notification_Admin_Admin_Assignment",
    "Notification_Admin_Admin_Eligibility",
    "Notification_Admin_EndUser_Assignment"
)

# Define the target recipients to set for the notification rules
$targetRecipients = @(
    "example@domain.com"
)

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

# Connect to Microsoft Graph with large reader scope for role management policies and write scope for updating notification rules
Write-Host "Connecting to Microsoft Graph with RoleManagement.Read.All and RoleManagement.ReadWrite.Directory scopes..."
Connect-MgGraph -Scopes "RoleManagement.Read.All","RoleManagement.ReadWrite.Directory" -NoWelcome
Write-Host "Connected to Microsoft Graph successfully."


# Get all role definitions - except user, guest user and restricted guest user
$roleDefs = Get-MgRoleManagementDirectoryRoleDefinition -All | Where-Object { $_.DisplayName -notin @("User", "Guest User", "Restricted Guest User") }

# Get all notification rules for role management policies
$rolePolicies = Get-MgPolicyRoleManagementPolicy -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole'" -ExpandProperty "Rules,EffectiveRules"

# Get all role management policy assignments - linking policies to roles is done via the policy assignment
$rolePolicyAssignments = Get-MgPolicyRoleManagementPolicyAssignment -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole'"

# Update notification rules for all roles
foreach ($roleDefinition in $roleDefs){
    $roleAssignment = $rolePolicyAssignments | Where-Object { $_.Id -like "*_$($roleDefinition.Id)" }
    $rolePolicyId = $roleAssignment.PolicyId

    # Get notifications rules for the role policy
    $notifRulesAdmin = $rolePolicies | Where-Object { $_.Id -eq $rolePolicyId } | Select-Object -ExpandProperty Rules
    foreach ($targetRule in $targetRoleNotifRules) {
        $ruleToUpdate = $notifRulesAdmin | Where-Object { $_.Id -eq $targetRule }
        $ruleProps = $ruleToUpdate.AdditionalProperties
        # Compare current recipients with target recipients - if they do not match, update the notification rule with the target recipients
        $recipientsNotmatch = (Compare-Object $ruleProps.notificationRecipients $targetRecipients -SyncWindow 0) -as [bool]
        if ($recipientsNotmatch) {
            Write-Host "Updating notification recipients for rule '$targetRule' in role '$($roleDefinition.DisplayName)'..."
            $ruleProps.notificationRecipients = $targetRecipients
            Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $rolePolicyId -UnifiedRoleManagementPolicyRuleId $targetRule -AdditionalProperties $ruleProps
            Write-Host "Updated notification recipients for rule '$targetRule' in role '$($roleDefinition.DisplayName)'."
        } else {
            Write-Host "Notification recipients for rule '$targetRule' in role '$($roleDefinition.DisplayName)' are already up to date. No update needed."
        }
    }
}