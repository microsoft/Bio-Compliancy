Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
    ApplicationId         = $ApplicationId
    TenantId              = $TenantId
    CertificateThumbprint = $CertificateThumbprint
}

$policies = Get-MgBetaIdentityConditionalAccessPolicy

$state = 'enabled' #'enabledForReportingButNotEnforced'

$correctPolicyFound = $false
foreach ($policy in $policies)
{
    $results = @{}

    $results.containsAllUsers = $false
    if ($policy.Conditions.Users.IncludeUsers.Count -eq 1 -and $policy.Conditions.Users.IncludeUsers -contains 'All')
    {
        $results.containsAllUsers = $true
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
        ResourceName          = 'AADCustomConditionalAccessPolicyMFAEnabledForUsers'
        ResourceInstanceName  = 'CIS-5.2.2.2'
        Id                    = 'Ensure multifactor authentication is enabled for all users'
        FoundRequiredCAPolicy = $true
    }
}
else
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName          = 'AADCustomConditionalAccessPolicyMFAEnabledForUsers'
        ResourceInstanceName  = 'CIS-5.2.2.2'
        Id                    = 'Ensure multifactor authentication is enabled for all users'
        FoundRequiredCAPolicy = $false
    }
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
