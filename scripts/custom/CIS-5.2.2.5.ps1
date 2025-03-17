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
    if ($policy.Conditions.Applications.IncludeApplications.Count -eq 1 -and $policy.Conditions.Applications.IncludeApplications -contains "All")
    {
        $results.containsAllCloudApps = $true
    }

    $results.noExcludedApplications = $false
    if ($policy.Conditions.Applications.ExcludeApplications.Count -eq 0)
    {
        $results.noExcludedApplications = $true
    }

    $results.requiresStrongMFA = $false
    if ($policy.GrantControls.AuthenticationStrength.DisplayName -eq "Phishing-resistant MFA" -and $policy.GrantControls.AuthenticationStrength.Id -eq "00000000-0000-0000-0000-000000000004")
    {
        $results.requiresStrongMFA = $true
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
        ResourceName          = 'AADCustomConditionalAccessPolicySignInFrequencyEnabledForAdmins'
        ResourceInstanceName  = 'CIS-5.2.2.5'
        Id                    = 'Ensure Phishing-resistant MFA strength is required for Administrators'
        FoundRequiredCAPolicy = $true
    }
}
else
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName          = 'AADCustomConditionalAccessPolicySignInFrequencyEnabledForAdmins'
        ResourceInstanceName  = 'CIS-5.2.2.5'
        Id                    = 'Ensure Phishing-resistant MFA strength is required for Administrators'
        FoundRequiredCAPolicy = $false
    }
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
