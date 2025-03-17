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
    if ($policy.Conditions.Users.IncludeUsers.Count -eq 1 -and $policy.Conditions.Users.IncludeUsers -contains "All")
    {
        $results.containsAllUsers = $true
    }

    $results.containsAllCloudApps = $false
    if ($policy.Conditions.Applications.IncludeApplications.Count -eq 1 -and $policy.Conditions.Applications.IncludeApplications -contains "All")
    {
        $results.containsAllCloudApps = $true
    }

    $results.containsRequiredManagedDevice = $false
    if ($policy.GrantControls.BuiltInControls -contains 'compliantDevice' -and $policy.GrantControls.BuiltInControls -contains 'domainJoinedDevice' -and $policy.GrantControls.Operator -eq 'OR')
    {
        $results.containsRequiredManagedDevice = $true
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
        ResourceName          = 'AADCustomConditionalAccessPolicyRequireManagedDevice'
        ResourceInstanceName  = 'CIS-5.2.2.10'
        Id                    = 'Ensure a managed device is required for authentication'
        FoundRequiredCAPolicy = $true
    }
}
else
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName          = 'AADCustomConditionalAccessPolicyRequireManagedDevice'
        ResourceInstanceName  = 'CIS-5.2.2.10'
        Id                    = 'Ensure a managed device is required for authentication'
        FoundRequiredCAPolicy = $false
    }
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
