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

    $results.noExcludedApplications = $false
    if ($policy.Conditions.Applications.ExcludeApplications.Count -eq 0)
    {
        $results.noExcludedApplications = $true
    }

    $results.containsHighMediumRiskUserLevel = $false
    if ($policy.Conditions.SignInRiskLevels -contains 'high' -and $policy.Conditions.SignInRiskLevels -contains 'medium')
    {
        $results.containsHighMediumRiskUserLevel = $true
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
        ResourceName          = 'AADCustomConditionalAccessPolicyBlockMediumHighSigninRisk'
        ResourceInstanceName  = 'CIS-5.2.2.9'
        Id                    = 'Ensure sign-in risk is blocked for medium and high risk'
        FoundRequiredCAPolicy = $true
    }
}
else
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName          = 'AADCustomConditionalAccessPolicyBlockMediumHighSigninRisk'
        ResourceInstanceName  = 'CIS-5.2.2.9'
        Id                    = 'Ensure sign-in risk is blocked for medium and high risk'
        FoundRequiredCAPolicy = $false
    }
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
