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

    $results.containsClientApps = $false
    if ($policy.Conditions.ClientAppTypes -contains 'exchangeActiveSync' -and $policy.Conditions.ClientAppTypes -contains 'other')
    {
        $results.containsClientApps = $true
    }

    $results.blocked = $false
    if ($policy.GrantControls.BuiltInControls -contains 'block')
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
        ResourceName          = 'AADCustomConditionalAccessPolicyBlockLegacyAuth'
        ResourceInstanceName  = 'CIS-5.2.2.3'
        Id                    = 'Enable Conditional Access policies to block legacy authentication '
        FoundRequiredCAPolicy = $true
    }
}
else
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName          = 'AADCustomConditionalAccessPolicyBlockLegacyAuth'
        ResourceInstanceName  = 'CIS-5.2.2.3'
        Id                    = 'Enable Conditional Access policies to block legacy authentication '
        FoundRequiredCAPolicy = $false
    }
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
