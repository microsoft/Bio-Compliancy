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

    $results.allRolesCovered = $true
    foreach ($requiredRole in $requiredRoles)
    {
        if ($roleLookup[$requiredRole] -notin $policy.Conditions.Users.IncludeRoles)
        {
            $results.allRolesCovered = $false
        }
    }

    $results.containsAllCloudApps = $false
    if ($policy.Conditions.Applications.IncludeApplications.Count -eq 1 -and $policy.Conditions.Applications.IncludeApplications -contains 'All')
    {
        $results.containsAllCloudApps = $true
    }

    $results.noExcludedApplications = $false
    if ($policy.Conditions.Applications.ExcludeApplications.Count -eq 0)
    {
        $results.noExcludedApplications = $true
    }

    $results.requiresMFA = $false
    if ($policy.GrantControls.BuiltInControls -contains 'mfa')
    {
        $results.requiresMFA = $true
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
        ResourceName          = 'AADCustomConditionalAccessPolicyMFAEnabledForAdmins'
        ResourceInstanceName  = 'CIS-5.2.2.1'
        Id                    = 'Ensure multifactor authentication is enabled for all users in administrative roles'
        FoundRequiredCAPolicy = $true
    }
}
else
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName          = 'AADCustomConditionalAccessPolicyMFAEnabledForAdmins'
        ResourceInstanceName  = 'CIS-5.2.2.1'
        Id                    = 'Ensure multifactor authentication is enabled for all users in administrative roles'
        FoundRequiredCAPolicy = $false
    }
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
