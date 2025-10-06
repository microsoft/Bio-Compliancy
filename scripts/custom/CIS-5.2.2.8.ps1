Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
    ApplicationId         = $ApplicationId
    TenantId              = $TenantId
    CertificateThumbprint = $CertificateThumbprint
}

$requiredRoles = @(
    'Application administrator',
    'Authentication administrator',
    'Billing administrator',
    'Cloud application administrator',
    'Conditional Access administrator',
    'Exchange administrator',
    'Global administrator',
    'Global reader',
    'Helpdesk administrator',
    'Password administrator',
    'Privileged authentication administrator',
    'Privileged role administrator',
    'Security administrator',
    'SharePoint administrator',
    'User administrator'
)

$allRoles = Get-MgBetaDirectoryRoleTemplate -All

$roleLookup = @{}
foreach ($role in $allRoles)
{
    $roleLookup[$role.DisplayName] = $role.Id
}

$policies = Get-MgBetaIdentityConditionalAccessPolicy

$state = 'enabled' #'enabledForReportingButNotEnforced'

$correctPolicyFound = $false
foreach ($policy in $policies)
{
    $results = @{}

    $results.containsAllUsers = $false
    if ($policy.Conditions.Users.IncludeUsers.Count -eq 1 -and $policy.Conditions.Users.IncludeUsers -contains "All")
    {
        $results.containsAllUsers = $true
    }

    $results.allRolesExcluded = $true
    foreach ($requiredRole in $requiredRoles)
    {
        if ($roleLookup[$requiredRole] -notin $policy.Conditions.Users.ExcludeRoles)
        {
            $results.allRolesExcluded = $false
        }
    }

    $results.containsAdminPortals = $false
    if ($policy.Conditions.Applications.IncludeApplications.Count -eq 1 -and $policy.Conditions.Applications.IncludeApplications -contains "MicrosoftAdminPortals")
    {
        $results.containsAdminPortals = $true
    }

    $results.blocked = $false
    if ($policy.GrantControls.BuiltInControls -contains "block")
    {
        $results.blocked = $true
    }

    $results.enabled = $false
    if ($policy.State -eq $state)
    {
        $results.enabled = $true
    }

    if ($results.ContainsValue($false) -eq $false)
    {
        $correctPolicyFound = $true
    }
}

if ($correctPolicyFound)
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName          = 'AADCustomConditionalAccessPolicyLimitAdminCenterToAdmins'
        ResourceInstanceName  = 'CIS-5.2.2.8'
        Id                    = 'Ensure admin center access is limited to administrative roles'
        FoundRequiredCAPolicy = $true
    }
}
else
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName          = 'AADCustomConditionalAccessPolicyLimitAdminCenterToAdmins'
        ResourceInstanceName  = 'CIS-5.2.2.8'
        Id                    = 'Ensure admin center access is limited to administrative roles'
        FoundRequiredCAPolicy = $false
    }
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
