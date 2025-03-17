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

    $results.containsRegisterSecurityInfo = $false
    if ($policy.Conditions.Applications.IncludeUserActions -contains "urn:user:registersecurityinfo")
    {
        $results.containsRegisterSecurityInfo = $true
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
        ResourceName          = 'AADCustomConditionalAccessPolicyManagedDeviceForMFARegistration'
        ResourceInstanceName  = 'CIS-5.2.2.11'
        Id                    = 'Ensure a managed device is required for MFA registration'
        FoundRequiredCAPolicy = $true
    }
}
else
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName          = 'AADCustomConditionalAccessPolicyManagedDeviceForMFARegistration'
        ResourceInstanceName  = 'CIS-5.2.2.11'
        Id                    = 'Ensure a managed device is required for MFA registration'
        FoundRequiredCAPolicy = $false
    }
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
